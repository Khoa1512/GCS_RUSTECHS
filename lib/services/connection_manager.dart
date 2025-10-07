import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:skylink/api/5G/services/mqtt_service.dart';
import 'package:skylink/services/telemetry_service.dart';
import 'package:skylink/services/mqtt_data_adapter.dart';

enum ConnectionType { mavlink, mqtt, none }

enum ConnectionStatus { connected, connecting, disconnected, failed, switching }

class ConnectionState {
  final ConnectionType type;
  final ConnectionStatus status;
  final String? error;
  final DateTime lastUpdate;

  ConnectionState({
    required this.type,
    required this.status,
    this.error,
    DateTime? lastUpdate,
  }) : lastUpdate = lastUpdate ?? DateTime.now();

  @override
  String toString() =>
      'ConnectionState(type: $type, status: $status, error: $error)';
}

/// Manages automatic fallback between MAVLink and MQTT connections
class ConnectionManager extends GetxController {
  static ConnectionManager get instance => Get.find<ConnectionManager>();

  // Services
  late final TelemetryService _telemetryService;
  late final MqttService _mqttService;

  // State
  final Rx<ConnectionState> _connectionState = ConnectionState(
    type: ConnectionType.none,
    status: ConnectionStatus.disconnected,
  ).obs;

  // Configuration
  static const Duration _connectionTimeout = Duration(seconds: 10);
  static const Duration _heartbeatInterval = Duration(seconds: 5);
  static const Duration _retryDelay = Duration(seconds: 3);
  static const int _maxRetries = 3;

  // Timers
  Timer? _heartbeatTimer;
  Timer? _retryTimer;
  StreamSubscription? _telemetrySubscription;
  StreamSubscription? _mqttSubscription;

  // Counters
  int _mavlinkRetries = 0;
  int _mqttRetries = 0;

  // Getters
  ConnectionState get connectionState => _connectionState.value;
  ConnectionType get currentConnectionType => _connectionState.value.type;
  bool get isConnected =>
      _connectionState.value.status == ConnectionStatus.connected;
  bool get isMavlinkConnected =>
      currentConnectionType == ConnectionType.mavlink && isConnected;
  bool get isMqttConnected =>
      currentConnectionType == ConnectionType.mqtt && isConnected;

  @override
  void onInit() {
    super.onInit();
    _telemetryService = Get.find<TelemetryService>();
    _mqttService = MqttService();

    // Check if MQTT-only mode is enabled via environment or debug flag
    const bool mqttOnlyMode = bool.fromEnvironment(
      'MQTT_ONLY',
      defaultValue: false,
    );

    if (mqttOnlyMode) {
      log('🧪 MQTT_ONLY mode enabled - starting MQTT-only mode');
      startMqttOnlyMode();
    } else {
      // Start with MAVLink
      _attemptConnection();
    }
  }

  /// Force MQTT-only mode for testing (skip MAVLink)
  Future<void> startMqttOnlyMode() async {
    log('🧪 Starting MQTT-only mode (bypassing MAVLink)');

    // Reset counters
    _mavlinkRetries = _maxRetries; // Max out MAVLink retries to skip it
    _mqttRetries = 0;

    // Stop any existing connections
    _stopHeartbeat();
    _stopRetryTimer();
    _telemetrySubscription?.cancel();
    _mqttSubscription?.cancel();

    // Go directly to MQTT
    await _tryMqttConnection();
  }

  @override
  void onClose() {
    _stopHeartbeat();
    _stopRetryTimer();
    _telemetrySubscription?.cancel();
    _mqttSubscription?.cancel();
    super.onClose();
  }

  /// Start connection process (prefer MAVLink first)
  Future<void> _attemptConnection() async {
    log('🔄 Starting connection attempt...');
    await _tryMavlinkConnection();
  }

  /// Try MAVLink connection first
  Future<void> _tryMavlinkConnection() async {
    if (_mavlinkRetries >= _maxRetries) {
      log('❌ MAVLink max retries reached, switching to MQTT');
      await _tryMqttConnection();
      return;
    }

    _updateState(ConnectionType.mavlink, ConnectionStatus.connecting);
    _mavlinkRetries++;

    try {
      log(
        '📡 Attempting MAVLink connection (attempt $_mavlinkRetries/$_maxRetries)',
      );

      // Try to connect via telemetry service (assuming default port)
      final success = await _telemetryService
          .connect('/dev/ttyUSB0')
          .timeout(_connectionTimeout);

      if (success && _telemetryService.isConnected) {
        _onMavlinkConnected();
      } else {
        throw Exception('MAVLink connection failed');
      }
    } catch (e) {
      log('❌ MAVLink connection failed: $e');
      _updateState(
        ConnectionType.mavlink,
        ConnectionStatus.failed,
        error: e.toString(),
      );

      if (_mavlinkRetries < _maxRetries) {
        _scheduleRetry(() => _tryMavlinkConnection());
      } else {
        await _tryMqttConnection();
      }
    }
  }

  /// Try MQTT connection as fallback
  Future<void> _tryMqttConnection() async {
    if (_mqttRetries >= _maxRetries) {
      log('❌ All connection methods failed');
      _updateState(
        ConnectionType.none,
        ConnectionStatus.failed,
        error: 'Both MAVLink and MQTT connections failed',
      );
      return;
    }

    _updateState(ConnectionType.mqtt, ConnectionStatus.connecting);
    _mqttRetries++;

    try {
      log('📶 Attempting MQTT connection (attempt $_mqttRetries/$_maxRetries)');

      await _mqttService.connect();
      await _mqttService.subscribeAllDevices();

      if (_mqttService.isConnected) {
        _onMqttConnected();
      } else {
        throw Exception('MQTT connection failed');
      }
    } catch (e) {
      log('❌ MQTT connection failed: $e');
      _updateState(
        ConnectionType.mqtt,
        ConnectionStatus.failed,
        error: e.toString(),
      );

      if (_mqttRetries < _maxRetries) {
        _scheduleRetry(() => _tryMqttConnection());
      } else {
        // Reset counters and try MAVLink again
        _mavlinkRetries = 0;
        _mqttRetries = 0;
        _scheduleRetry(() => _tryMavlinkConnection());
      }
    }
  }

  /// Handle successful MAVLink connection
  void _onMavlinkConnected() {
    log('✅ MAVLink connected successfully');
    _updateState(ConnectionType.mavlink, ConnectionStatus.connected);
    _mavlinkRetries = 0; // Reset retry counter
    _startHeartbeat();
    _listenToMavlinkData();
  }

  /// Handle successful MQTT connection
  void _onMqttConnected() {
    log('✅ MQTT connected successfully');
    _updateState(ConnectionType.mqtt, ConnectionStatus.connected);
    _mqttRetries = 0; // Reset retry counter
    _startHeartbeat();
    _listenToMqttData();
  }

  /// Start heartbeat monitoring
  void _startHeartbeat() {
    _stopHeartbeat();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      _checkConnectionHealth();
    });
  }

  /// Stop heartbeat monitoring
  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  /// Check connection health
  void _checkConnectionHealth() {
    bool isHealthy = false;

    switch (currentConnectionType) {
      case ConnectionType.mavlink:
        isHealthy = _telemetryService.isConnected;
        break;
      case ConnectionType.mqtt:
        isHealthy = _mqttService.isConnected;
        break;
      case ConnectionType.none:
        isHealthy = false;
        break;
    }

    if (!isHealthy &&
        _connectionState.value.status == ConnectionStatus.connected) {
      log('💔 Connection lost, attempting fallback...');
      _onConnectionLost();
    }
  }

  /// Handle connection loss
  void _onConnectionLost() {
    _stopHeartbeat();
    _updateState(currentConnectionType, ConnectionStatus.disconnected);

    // Try alternative connection
    if (currentConnectionType == ConnectionType.mavlink) {
      _mavlinkRetries = _maxRetries; // Skip MAVLink retries
      _tryMqttConnection();
    } else {
      _mqttRetries = _maxRetries; // Skip MQTT retries
      _tryMavlinkConnection();
    }
  }

  /// Listen to MAVLink data
  void _listenToMavlinkData() {
    _telemetrySubscription?.cancel();
    // TODO: Subscribe to MAVLink data stream
    // _telemetrySubscription = _telemetryService.dataStream.listen(
    //   (data) {
    //     // Process MAVLink data
    //   },
    //   onError: (error) {
    //     log('MAVLink data error: $error');
    //     _onConnectionLost();
    //   },
    // );
  }

  /// Listen to MQTT data (ULTRA-FAST 10ms pipeline)
  void _listenToMqttData() {
    _mqttSubscription?.cancel();

    // ZERO-LATENCY pipeline for 10ms real-time
    _mqttSubscription = _mqttService.listenTelemetryData().listen(
      (data) {
        // Instant convert and render - no delays for 10ms intervals
        final telemetryData = MqttDataAdapter.convertMqttToTelemetry(
          jsonEncode(data),
        );

        if (telemetryData.isNotEmpty) {
          _telemetryService.updateTelemetryFromMqtt(telemetryData);
        }
      },
      onError: (error) {
        log('MQTT ultra-fast error: $error');
        _onConnectionLost();
      },
    );
  }

  /// Schedule retry attempt
  void _scheduleRetry(VoidCallback retryFunction) {
    _stopRetryTimer();
    log('⏰ Scheduling retry in ${_retryDelay.inSeconds} seconds...');
    _retryTimer = Timer(_retryDelay, retryFunction);
  }

  /// Stop retry timer
  void _stopRetryTimer() {
    _retryTimer?.cancel();
    _retryTimer = null;
  }

  /// Update connection state
  void _updateState(
    ConnectionType type,
    ConnectionStatus status, {
    String? error,
  }) {
    _connectionState.value = ConnectionState(
      type: type,
      status: status,
      error: error,
    );

    debugPrint('🔗 Connection State: ${_connectionState.value}');
  }

  /// Force switch to specific connection type
  Future<void> switchTo(ConnectionType type) async {
    log('🔄 Manual switch to $type');
    _stopHeartbeat();
    _stopRetryTimer();

    // Reset retry counters based on target
    if (type == ConnectionType.mavlink) {
      _mavlinkRetries = 0;
      _mqttRetries = _maxRetries;
      await _tryMavlinkConnection();
    } else if (type == ConnectionType.mqtt) {
      _mqttRetries = 0;
      _mavlinkRetries = _maxRetries;
      await _tryMqttConnection();
    }
  }

  /// Force reconnect current connection
  Future<void> reconnect() async {
    log('🔄 Force reconnect');
    _stopHeartbeat();
    _stopRetryTimer();

    // Reset retry counters and start fresh
    _mavlinkRetries = 0;
    _mqttRetries = 0;
    await _attemptConnection();
  }

  /// Get connection info for UI
  Map<String, dynamic> getConnectionInfo() {
    return {
      'type': currentConnectionType.name,
      'status': _connectionState.value.status.name,
      'error': _connectionState.value.error,
      'lastUpdate': _connectionState.value.lastUpdate.toIso8601String(),
      'mavlinkRetries': _mavlinkRetries,
      'mqttRetries': _mqttRetries,
    };
  }
}
