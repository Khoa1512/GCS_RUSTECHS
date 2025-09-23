import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:skylink/api/telemetry/mavlink_api.dart';
import 'package:skylink/data/telemetry_data_manager.dart';

/// Simple multi-drone connection manager
class MultiDroneService {
  static final MultiDroneService _instance = MultiDroneService._internal();
  factory MultiDroneService() => _instance;
  MultiDroneService._internal();

  // Map to store multiple drone connections
  final Map<String, DroneConnection> _connections = {};

  // Event streams
  final _connectionStateController =
      StreamController<Map<String, bool>>.broadcast();
  final _telemetryDataController =
      StreamController<Map<String, Map<String, dynamic>>>.broadcast();

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

  /// Add and connect a new drone
  Future<bool> addDrone(
    String droneId,
    String port, {
    int baudRate = 115200,
  }) async {
    try {
      debugPrint('Adding drone $droneId on port $port...');

      // Check if drone already exists
      if (_connections.containsKey(droneId)) {
        debugPrint('Drone $droneId already exists');
        return false;
      }

      // Create new drone connection
      final connection = DroneConnection(
        droneId: droneId,
        port: port,
        baudRate: baudRate,
      );

      // Setup listeners for this drone
      _setupDroneListeners(connection);

      // Attempt to connect
      final success = await connection.connect();
      if (success) {
        _connections[droneId] = connection;
        _emitConnectionState();
        debugPrint('Drone $droneId connected successfully');
        return true;
      } else {
        debugPrint('Failed to connect drone $droneId');
        return false;
      }
    } catch (e) {
      debugPrint('Error adding drone $droneId: $e');
      return false;
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

  /// Send command to all connected drones
  Future<void> sendCommandToAll(
    String command, [
    Map<String, dynamic>? params,
  ]) async {
    final futures = <Future>[];

    for (final connection in _connections.values) {
      if (connection.isConnected) {
        futures.add(connection.sendCommand(command, params));
      }
    }

    await Future.wait(futures);
  }

  /// Disconnect all drones
  Future<void> disconnectAll() async {
    debugPrint('Disconnecting all drones...');

    final futures = _connections.values.map((conn) => conn.disconnect());
    await Future.wait(futures);

    _connections.clear();
    _emitConnectionState();
    _emitTelemetryData();

    debugPrint('All drones disconnected');
  }

  /// Setup listeners for a drone connection
  void _setupDroneListeners(DroneConnection connection) {
    // Listen to connection state changes
    connection.connectionStream.listen((connected) {
      _emitConnectionState();
    });

    // Listen to telemetry data
    connection.telemetryStream.listen((data) {
      _emitTelemetryData();
    });
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

  /// Dispose service
  void dispose() {
    disconnectAll();
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

    // Always emit telemetry data
    _telemetryController.add(_dataManager.currentTelemetry);
  }

  /// Dispose connection
  void dispose() {
    disconnect();
    _connectionController.close();
    _telemetryController.close();
    _dataManager.dispose();
  }
}
