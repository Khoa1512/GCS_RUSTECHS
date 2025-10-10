import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:skylink/api/telemetry/mavlink_api.dart';
import 'package:skylink/data/telemetry_data_manager.dart';
import 'package:skylink/services/telemetry_service.dart';

/// Configuration for drone connection
class DroneConfig {
  final String id;
  final String port;
  final int baudRate;

  const DroneConfig({
    required this.id,
    required this.port,
    this.baudRate = 115200,
  });
}

/// Optimized multi-drone connection manager with parallel processing
class MultiDroneService {
  static final MultiDroneService _instance = MultiDroneService._internal();
  factory MultiDroneService() => _instance;
  MultiDroneService._internal();

  // Map to store multiple drone connections
  final Map<String, DroneConnection> _connections = {};

  // Connection pool for parallel operations
  final Map<String, Completer<bool>> _connectionCompleters = {};

  // Event streams
  final _connectionStateController =
      StreamController<Map<String, bool>>.broadcast();
  final _telemetryDataController =
      StreamController<Map<String, Map<String, dynamic>>>.broadcast();

  // Performance monitoring
  final Map<String, DateTime> _lastDataReceived = {};
  final Map<String, int> _dataRateCounters = {};

  // Public streams
  Stream<Map<String, bool>> get connectionStateStream =>
      _connectionStateController.stream;
  Stream<Map<String, Map<String, dynamic>>> get telemetryDataStream =>
      _telemetryDataController.stream;

  // Public getters
  Map<String, DroneConnection> get connections =>
      Map.unmodifiable(_connections);
  int get connectedDroneCount =>
      _connections.values.where((conn) => conn.isConnected).length;
  List<String> get connectedDroneIds => _connections.entries
      .where((entry) => entry.value.isConnected)
      .map((entry) => entry.key)
      .toList();

  /// Add multiple drones in parallel (OPTIMIZED)
  Future<Map<String, bool>> addMultipleDrones(List<DroneConfig> configs) async {
    if (configs.isEmpty) return {};

    debugPrint(
      '🚀 Starting parallel connection to ${configs.length} drones...',
    );
    final startTime = DateTime.now();

    // Create all connections simultaneously
    final connectionFutures = configs.map((config) async {
      final success = await addDrone(
        config.id,
        config.port,
        baudRate: config.baudRate,
      );
      return MapEntry(config.id, success);
    });

    // Wait for all connections to complete in parallel
    final results = await Future.wait(connectionFutures);
    final resultMap = Map.fromEntries(results);

    final duration = DateTime.now().difference(startTime);
    final successCount = resultMap.values.where((success) => success).length;

    debugPrint(
      '✅ Parallel connection completed: $successCount/${configs.length} drones in ${duration.inMilliseconds}ms',
    );

    return resultMap;
  }

  /// Add and connect a new drone (OPTIMIZED with timeout)
  Future<bool> addDrone(
    String droneId,
    String port, {
    int baudRate = 115200,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    try {
      debugPrint('🔗 Adding drone $droneId on port $port...');

      // Check if drone already exists
      if (_connections.containsKey(droneId)) {
        debugPrint('⚠️ Drone $droneId already exists');
        return false;
      }

      // Create connection completer for tracking
      final completer = Completer<bool>();
      _connectionCompleters[droneId] = completer;

      // Create new drone connection
      final connection = DroneConnection(
        droneId: droneId,
        port: port,
        baudRate: baudRate,
      );

      // Setup listeners for this drone
      _setupDroneListeners(connection);

      // Attempt to connect with timeout
      final success = await connection.connect().timeout(
        timeout,
        onTimeout: () {
          debugPrint('⏰ Connection timeout for drone $droneId');
          return false;
        },
      );

      if (success) {
        _connections[droneId] = connection;
        _emitConnectionState();
        debugPrint('✅ Drone $droneId connected successfully');

        // Initialize performance tracking
        _dataRateCounters[droneId] = 0;
        _lastDataReceived[droneId] = DateTime.now();

        completer.complete(true);
        return true;
      } else {
        debugPrint('❌ Failed to connect drone $droneId');
        completer.complete(false);
        return false;
      }
    } catch (e) {
      debugPrint('💥 Error adding drone $droneId: $e');
      _connectionCompleters[droneId]?.complete(false);
      return false;
    } finally {
      _connectionCompleters.remove(droneId);
    }
  }

  /// Remove and disconnect a drone
  Future<void> removeDrone(String droneId) async {
    final connection = _connections[droneId];
    if (connection == null) return;

    debugPrint('Removing drone $droneId...');

    // Disconnect and cleanup
    await connection.disconnect();
    _connections.remove(droneId);

    _emitConnectionState();
    _emitTelemetryData();

    debugPrint('Drone $droneId removed');
  }

  /// Get specific drone connection
  DroneConnection? getDrone(String droneId) {
    return _connections[droneId];
  }

  /// Get telemetry data for all drones
  Map<String, Map<String, dynamic>> getAllTelemetryData() {
    final data = <String, Map<String, dynamic>>{};
    for (final entry in _connections.entries) {
      if (entry.value.isConnected) {
        data[entry.key] = entry.value.currentTelemetry;
      }
    }
    return data;
  }

  /// Add drone from existing TelemetryService connection
  /// This allows single drone connections to be displayed in swarm view
  Future<void> addPrimaryDroneFromTelemetryService() async {
    try {
      final telemetryService = TelemetryService();

      if (!telemetryService.isConnected) {
        debugPrint('TelemetryService not connected, cannot add to swarm');
        return;
      }

      // Create a primary drone entry that references TelemetryService data
      const droneId = 'PRIMARY';

      // Remove existing primary if any
      await removeDrone(droneId);

      // Create a wrapper connection that syncs with TelemetryService
      final primaryConnection = _PrimaryDroneConnection(telemetryService);

      // Add to connections map
      _connections[droneId] = primaryConnection;

      // Notify listeners about new drone
      _emitConnectionState();

      debugPrint('✅ Primary drone added to MultiDroneService swarm');
    } catch (e) {
      debugPrint('❌ Error adding primary drone: $e');
    }
  }

  /// Check if primary drone (from TelemetryService) is available
  bool get hasPrimaryDrone {
    final telemetryService = TelemetryService();
    return telemetryService.isConnected;
  }

  /// Get primary drone telemetry data
  Map<String, dynamic> get primaryDroneTelemetry {
    final telemetryService = TelemetryService();
    if (!telemetryService.isConnected) return {};

    // Convert Map<String, double> to Map<String, dynamic>
    return Map<String, dynamic>.from(telemetryService.currentTelemetry);
  }

  /// Send command to specific drone
  Future<void> sendCommandToDrone(
    String droneId,
    String command, [
    Map<String, dynamic>? params,
  ]) async {
    final connection = _connections[droneId];
    if (connection == null || !connection.isConnected) {
      debugPrint('Drone $droneId not connected');
      return;
    }

    await connection.sendCommand(command, params);
  }

  /// Send command to all connected drones in parallel (OPTIMIZED)
  Future<Map<String, bool>> sendCommandToAllParallel(
    String command, [
    Map<String, dynamic>? params,
  ]) async {
    if (_connections.isEmpty) return {};

    debugPrint(
      '🎯 Sending command "$command" to ${_connections.length} drones in parallel...',
    );
    final startTime = DateTime.now();

    // Create parallel command futures
    final commandFutures = _connections.entries
        .where((entry) => entry.value.isConnected)
        .map((entry) async {
          try {
            await entry.value.sendCommand(command, params);
            return MapEntry(entry.key, true);
          } catch (e) {
            debugPrint('❌ Command failed for drone ${entry.key}: $e');
            return MapEntry(entry.key, false);
          }
        });

    // Execute all commands in parallel
    final results = await Future.wait(commandFutures);
    final resultMap = Map.fromEntries(results);

    final duration = DateTime.now().difference(startTime);
    final successCount = resultMap.values.where((success) => success).length;

    debugPrint(
      '✅ Parallel command completed: $successCount/${resultMap.length} drones in ${duration.inMilliseconds}ms',
    );

    return resultMap;
  }

  /// Get performance statistics for all drones
  Map<String, Map<String, dynamic>> getPerformanceStats() {
    final stats = <String, Map<String, dynamic>>{};
    final now = DateTime.now();

    for (final droneId in _connections.keys) {
      final lastReceived = _lastDataReceived[droneId];
      final dataCount = _dataRateCounters[droneId] ?? 0;

      stats[droneId] = {
        'dataPacketsReceived': dataCount,
        'lastDataReceived': lastReceived?.millisecondsSinceEpoch,
        'isDataFresh':
            lastReceived != null && now.difference(lastReceived).inSeconds < 5,
        'connection': _connections[droneId]?.isConnected ?? false,
        'hasData': _connections[droneId]?.hasReceivedData ?? false,
      };
    }

    return stats;
  }

  /// Batch disconnect all drones with progress tracking
  Future<void> disconnectAllOptimized() async {
    if (_connections.isEmpty) return;

    debugPrint('🔌 Disconnecting ${_connections.length} drones in parallel...');
    final startTime = DateTime.now();

    // Create parallel disconnect futures
    final disconnectFutures = _connections.values.map((conn) async {
      try {
        await conn.disconnect();
        return true;
      } catch (e) {
        debugPrint('❌ Disconnect error for ${conn.droneId}: $e');
        return false;
      }
    });

    // Wait for all disconnections
    final results = await Future.wait(disconnectFutures);
    final successCount = results.where((success) => success).length;

    // Clear all data
    _connections.clear();
    _connectionCompleters.clear();
    _dataRateCounters.clear();
    _lastDataReceived.clear();

    _emitConnectionState();
    _emitTelemetryData();

    final duration = DateTime.now().difference(startTime);
    debugPrint(
      '✅ Parallel disconnect completed: $successCount/${results.length} drones in ${duration.inMilliseconds}ms',
    );
  }

  /// Setup optimized listeners for a drone connection
  void _setupDroneListeners(DroneConnection connection) {
    final droneId = connection.droneId;

    // Listen to connection state changes
    connection.connectionStream.listen((connected) {
      if (connected) {
        debugPrint('🟢 Drone $droneId connected');
      } else {
        debugPrint('🔴 Drone $droneId disconnected');
        // Clean up performance tracking
        _dataRateCounters.remove(droneId);
        _lastDataReceived.remove(droneId);
      }
      _emitConnectionState();
    });

    // Listen to telemetry data with performance tracking
    connection.telemetryStream.listen((data) {
      // Update performance counters
      _dataRateCounters[droneId] = (_dataRateCounters[droneId] ?? 0) + 1;
      _lastDataReceived[droneId] = DateTime.now();

      // Process data efficiently
      _processTelemetryData(droneId, data);
      _emitTelemetryData();
    });
  }

  /// Process telemetry data with optimization
  void _processTelemetryData(String droneId, Map<String, dynamic> data) {
    // Calculate data rate (for monitoring)
    final now = DateTime.now();
    final lastReceived = _lastDataReceived[droneId];
    if (lastReceived != null) {
      final interval = now.difference(lastReceived).inMilliseconds;
      // Store data rate separately, don't modify the telemetry data
      _dataRateCounters[droneId] = interval > 0
          ? (1000.0 / interval).round()
          : 0;
    }

    // Update timestamp tracking
    _lastDataReceived[droneId] = now;
  }

  /// Emit connection state for all drones
  void _emitConnectionState() {
    final state = <String, bool>{};
    for (final entry in _connections.entries) {
      state[entry.key] = entry.value.isConnected;
    }
    _connectionStateController.add(state);
  }

  /// Emit telemetry data for all drones
  void _emitTelemetryData() {
    final data = getAllTelemetryData();
    _telemetryDataController.add(data);
  }

  /// Get available serial ports
  List<String> getAvailablePorts() {
    try {
      return SerialPort.availablePorts;
    } catch (e) {
      return [];
    }
  }

  /// Quick test method to add multiple simulated drones
  Future<void> addTestDrones({int count = 3}) async {
    final configs = List.generate(
      count,
      (index) => DroneConfig(
        id: 'DRONE_${index + 1}',
        port: '/dev/ttyUSB$index', // Simulated ports
        baudRate: 115200,
      ),
    );

    debugPrint('🧪 Adding $count test drones...');
    final results = await addMultipleDrones(configs);

    final successCount = results.values.where((success) => success).length;
    debugPrint('🧪 Test completed: $successCount/$count drones connected');
  }

  /// Batch command utility for common operations
  Future<Map<String, bool>> armAllDrones() => sendCommandToAllParallel('arm');
  Future<Map<String, bool>> disarmAllDrones() =>
      sendCommandToAllParallel('disarm');

  Future<Map<String, bool>> setAllToMode(int mode) =>
      sendCommandToAllParallel('setMode', {'mode': mode});

  /// Health check for all drones
  Map<String, String> getSwarmHealthStatus() {
    final health = <String, String>{};
    final now = DateTime.now();

    for (final entry in _connections.entries) {
      final droneId = entry.key;
      final connection = entry.value;
      final lastData = _lastDataReceived[droneId];

      if (!connection.isConnected) {
        health[droneId] = 'DISCONNECTED';
      } else if (lastData == null) {
        health[droneId] = 'NO_DATA';
      } else if (now.difference(lastData).inSeconds > 10) {
        health[droneId] = 'STALE_DATA';
      } else if (now.difference(lastData).inSeconds > 5) {
        health[droneId] = 'SLOW_DATA';
      } else {
        health[droneId] = 'HEALTHY';
      }
    }

    return health;
  }

  /// Dispose service with optimized cleanup
  void dispose() {
    disconnectAllOptimized();
    _connectionStateController.close();
    _telemetryDataController.close();
  }
}

/// Individual drone connection
class DroneConnection {
  final String droneId;
  final String port;
  final int baudRate;

  // Connection components
  late final DroneMAVLinkAPI _api;
  late final TelemetryDataManager _dataManager;

  // State
  bool _isConnected = false;
  bool _hasReceivedData = false;

  // Event streams
  final _connectionController = StreamController<bool>.broadcast();
  final _telemetryController =
      StreamController<Map<String, dynamic>>.broadcast();

  // Subscription
  StreamSubscription? _apiSubscription;

  DroneConnection({
    required this.droneId,
    required this.port,
    required this.baudRate,
  }) {
    _api = DroneMAVLinkAPI();
    _dataManager = TelemetryDataManager();
  }

  // Getters
  bool get isConnected => _isConnected;
  bool get hasReceivedData => _hasReceivedData;
  Map<String, dynamic> get currentTelemetry => _dataManager.currentTelemetry;
  String get currentMode => _dataManager.currentMode;
  bool get isArmed => _dataManager.isArmed;

  // Streams
  Stream<bool> get connectionStream => _connectionController.stream;
  Stream<Map<String, dynamic>> get telemetryStream =>
      _telemetryController.stream;

  /// Connect to drone
  Future<bool> connect() async {
    try {
      debugPrint('Connecting drone $droneId to port $port...');

      // Setup API listener first
      _setupApiListener();

      // Connect to port
      await _api.connect(port, baudRate: baudRate);
      _isConnected = _api.isConnected;

      if (_isConnected) {
        _connectionController.add(true);

        // Request data streams after connection
        Timer(const Duration(milliseconds: 1000), () {
          if (_isConnected) {
            _api.requestAllDataStreams();

            // Send again for reliability
            Timer(const Duration(milliseconds: 500), () {
              if (_isConnected) {
                _api.requestAllDataStreams();
              }
            });
          }
        });

        debugPrint('Drone $droneId connected successfully');
        return true;
      } else {
        debugPrint('Failed to connect drone $droneId');
        _connectionController.add(false);
        return false;
      }
    } catch (e) {
      debugPrint('Error connecting drone $droneId: $e');
      _isConnected = false;
      _connectionController.add(false);
      return false;
    }
  }

  /// Disconnect from drone
  Future<void> disconnect() async {
    try {
      debugPrint('Disconnecting drone $droneId...');

      // Cancel subscription
      _apiSubscription?.cancel();

      // Disconnect API
      _api.disconnect();

      // Reset state
      _isConnected = false;
      _hasReceivedData = false;

      // Clear data
      _dataManager.clearData();

      // Notify listeners
      _connectionController.add(false);

      debugPrint('Drone $droneId disconnected');
    } catch (e) {
      debugPrint('Error disconnecting drone $droneId: $e');
    }
  }

  /// Send command to drone
  Future<void> sendCommand(
    String command, [
    Map<String, dynamic>? params,
  ]) async {
    if (!_isConnected) {
      debugPrint('Cannot send command to disconnected drone $droneId');
      return;
    }

    try {
      switch (command) {
        case 'arm':
          _api.sendArmCommand(true);
          break;
        case 'disarm':
          _api.sendArmCommand(false);
          break;
        case 'setMode':
          if (params != null && params['mode'] is int) {
            _api.setFlightMode(params['mode']);
          }
          break;
        default:
          debugPrint('Unknown command: $command');
      }
    } catch (e) {
      debugPrint('Error sending command to drone $droneId: $e');
    }
  }

  /// Setup API event listener
  void _setupApiListener() {
    _apiSubscription?.cancel();
    _apiSubscription = _api.eventStream.listen((event) {
      switch (event.type) {
        case MAVLinkEventType.connectionStateChanged:
          _handleConnectionStateChange(event.data);
          break;
        case MAVLinkEventType.heartbeat:
          if (event.data is Map) {
            _dataManager.updateHeartbeatData(event.data as Map);
            _checkDataReceived();
          }
          break;
        case MAVLinkEventType.attitude:
          if (event.data is Map) {
            _dataManager.updateAttitudeData(event.data as Map);
            _checkDataReceived();
          }
          break;
        case MAVLinkEventType.vfrHud:
          if (event.data is Map) {
            _dataManager.updateVfrHudData(event.data as Map);
            _checkDataReceived();
          }
          break;
        case MAVLinkEventType.position:
          if (event.data is Map) {
            _dataManager.updatePositionData(event.data as Map);
            _checkDataReceived();
          }
          break;
        case MAVLinkEventType.gpsInfo:
          if (event.data is Map) {
            _dataManager.updateGpsInfoData(event.data as Map);
            _checkDataReceived();
          }
          break;
        case MAVLinkEventType.batteryStatus:
          if (event.data is Map) {
            _dataManager.updateBatteryStatusData(event.data as Map);
            _checkDataReceived();
          }
          break;
        default:
          break;
      }
    });
  }

  /// Handle connection state changes
  void _handleConnectionStateChange(dynamic state) {
    final connected = state == MAVLinkConnectionState.connected;

    if (_isConnected != connected) {
      _isConnected = connected;
      _connectionController.add(connected);

      if (!connected) {
        _dataManager.clearData();
        _hasReceivedData = false;
      }
    }
  }

  /// Check if meaningful data received
  void _checkDataReceived() {
    if (!_hasReceivedData) {
      final data = _dataManager.currentTelemetry;

      final hasPosition =
          ((data['gps_latitude'] ?? 0.0) != 0.0) ||
          ((data['gps_longitude'] ?? 0.0) != 0.0);
      final hasBattery = (data['battery'] ?? 0.0) > 0.0;
      final hasAttitude =
          (data['roll'] != null) ||
          (data['pitch'] != null) ||
          (data['yaw'] != null);
      final hasBasicData =
          (data['armed'] != null) ||
          (data['airspeed'] != null) ||
          (data['groundspeed'] != null);

      if (hasPosition || hasBattery || hasAttitude || hasBasicData) {
        _hasReceivedData = true;
      }
    }

    // Always emit telemetry data with additional info
    final telemetryData = Map<String, dynamic>.from(
      _dataManager.currentTelemetry,
    );
    telemetryData['flight_mode'] = _dataManager.currentMode;
    telemetryData['armed'] = _dataManager.isArmed ? 1.0 : 0.0;
    _telemetryController.add(telemetryData);
  }

  /// Dispose connection
  void dispose() {
    disconnect();
    _connectionController.close();
    _telemetryController.close();
    _dataManager.dispose();
  }
}

/// Wrapper class that connects PRIMARY drone from TelemetryService to MultiDroneService
class _PrimaryDroneConnection extends DroneConnection {
  final TelemetryService _telemetryService;
  late final StreamSubscription _telemetrySubscription;
  late final StreamSubscription _connectionSubscription;

  _PrimaryDroneConnection(this._telemetryService)
    : super(droneId: 'PRIMARY', port: 'TelemetryService', baudRate: 0) {
    // Forward telemetry data from TelemetryService
    _telemetrySubscription = _telemetryService.telemetryStream.listen((data) {
      // Convert Map<String, dynamic> to Map<String, double>
      final doubleData = <String, double>{};
      data.forEach((key, value) {
        if (value is num) {
          doubleData[key] = value.toDouble();
        }
      });
      _telemetryController.add(doubleData);
    });

    // Forward connection state from TelemetryService
    _connectionSubscription = _telemetryService.connectionStream.listen(
      (isConnected) => _connectionController.add(isConnected),
    );
  }

  // Override properties to use TelemetryService data
  @override
  bool get isConnected => _telemetryService.isConnected;

  @override
  Map<String, dynamic> get currentTelemetry {
    // Convert TelemetryService data to Map<String, dynamic>
    final dynamicData = <String, dynamic>{};
    _telemetryService.currentTelemetry.forEach((key, value) {
      dynamicData[key] = value;
    });

    // Add currentMode and armed status
    dynamicData['flight_mode'] = _telemetryService.currentMode;
    dynamicData['armed'] = _telemetryService.isArmed ? 1.0 : 0.0;

    return dynamicData;
  }

  @override
  Future<bool> connect() async {
    // PRIMARY is already connected via TelemetryService
    // This is just a wrapper, no need to connect again
    return isConnected;
  }

  @override
  Future<void> disconnect() async {
    // Don't disconnect TelemetryService - it's managed separately
    // Just clean up subscriptions
    await _telemetrySubscription.cancel();
    await _connectionSubscription.cancel();
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
