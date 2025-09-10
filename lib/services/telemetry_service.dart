import 'dart:async';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:skylink/api/telemetry/mavlink_api.dart';
import 'package:skylink/data/telemetry_data.dart';
import 'package:skylink/data/telemetry_data_manager.dart';

/// Service for managing telemetry data from MAVLink API
class TelemetryService {
  // Singleton instance
  static final TelemetryService _instance = TelemetryService._internal();
  factory TelemetryService() => _instance;

  // Event streams
  final _connectionController = StreamController<bool>.broadcast();
  final _dataReceiveController = StreamController<bool>.broadcast();

  // MAVLink API instance
  final DroneMAVLinkAPI _api = DroneMAVLinkAPI();

  // Data management
  final TelemetryDataManager _dataManager = TelemetryDataManager();
  StreamSubscription? _apiSubscription;

  // State tracking
  bool _isConnected = false;
  bool _hasReceivedData = false;

  // Constructor
  TelemetryService._internal();

  // Public API access
  DroneMAVLinkAPI get mavlinkAPI => _api;

  // Public streams
  Stream<Map<String, dynamic>> get telemetryStream =>
      _dataManager.telemetryStream;
  Stream<bool> get connectionStream => _connectionController.stream;
  Stream<bool> get dataReceiveStream => _dataReceiveController.stream;

  // Public state access
  bool get isConnected => _isConnected;
  bool get hasReceivedData => _hasReceivedData;
  Map<String, dynamic> get currentTelemetry => _dataManager.currentTelemetry;

  // Vehicle state
  String get vehicleType => _dataManager.vehicleType;
  String get currentMode => _dataManager.currentMode;
  bool get isArmed => _dataManager.isArmed;

  // GPS data access
  double get gpsLatitude => _dataManager.gpsLatitude;
  double get gpsLongitude => _dataManager.gpsLongitude;
  double get gpsAltitude => _dataManager.gpsAltitude;
  double get gpsSpeed => _dataManager.gpsSpeed;
  double get gpsCourse => _dataManager.gpsCourse;
  double get gpsHorizontalAccuracy => _dataManager.gpsHorizontalAccuracy;
  double get gpsVerticalAccuracy => _dataManager.gpsVerticalAccuracy;
  String get gpsFixType => _dataManager.gpsFixType;
  int get gpsFixValue => _dataManager.gpsFixValue;
  bool get hasValidGpsFix => _dataManager.hasValidGpsFix;
  String get gpsAccuracyString => _dataManager.gpsAccuracyString;

  /// Initialize the service
  void initialize() {
    _apiSubscription?.cancel();
    _setupApiListener();
  }

  /// Get available serial ports
  List<String> getAvailablePorts() {
    try {
      return SerialPort.availablePorts;
    } catch (e) {
      return [];
    }
  }

  /// Connect to drone via specified port
  Future<bool> connect(String port, {int baudRate = 115200}) async {
    try {
      // Check if port is available
      final availablePorts = getAvailablePorts();
      if (!availablePorts.contains(port)) {
        return false;
      }

      await _api.connect(port, baudRate: baudRate);

      final success = _api.isConnected;
      if (success) {
        _hasReceivedData = false;

        // Setup API listener
        _apiSubscription?.cancel();
        _setupApiListener();

        // Update connection state
        _connectionController.add(false);
        _dataReceiveController.add(false);

        // Request all data streams for real-time telemetry with delay
        Timer(const Duration(milliseconds: 1000), () {
          if (_isConnected) {
            _api.requestAllDataStreams();

            // Send again after delay to ensure FC receives
            Timer(const Duration(milliseconds: 500), () {
              if (_isConnected) {
                _api.requestAllDataStreams();
              }
            });
          }
        });
      }

      return success;
    } catch (e) {
      _isConnected = false;
      _connectionController.add(false);
      return false;
    }
  }

  /// Disconnect from drone
  void disconnect() {
    try {
      // Cancel subscription
      _apiSubscription?.cancel();

      // Disconnect from API
      _api.disconnect();

      // Reset states
      _isConnected = false;
      _hasReceivedData = false;

      // Notify listeners
      _connectionController.add(false);
      _dataReceiveController.add(false);

      // Clear telemetry data
      _dataManager.clearData();
    } catch (e) {
      _isConnected = false;
      _hasReceivedData = false;
      _connectionController.add(false);
      _dataReceiveController.add(false);
    }
  }

  /// Setup API event listener
  void _setupApiListener() {
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
          // no-op for other events
          break;
      }
    });
  }

  /// Handle connection state changes
  void _handleConnectionStateChange(MAVLinkConnectionState state) {
    bool connected = state == MAVLinkConnectionState.connected;

    if (_isConnected != connected) {
      _isConnected = connected;
      _connectionController.add(connected);

      if (!connected) {
        _dataManager.clearData();
      }
    } else {
      print('  - No change needed, _isConnected already: $_isConnected');
    }
  }

  /// Check if we've received meaningful data and notify listeners
  void _checkDataReceived() {
    if (!_hasReceivedData) {
      // Get current telemetry data
      final data = _dataManager.currentTelemetry;

      // Relaxed meaningful data detection - accept basic telemetry
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

      // Accept data if we have any meaningful telemetry
      if (hasPosition || hasBattery || hasAttitude || hasBasicData) {
        _hasReceivedData = true;
        _dataReceiveController.add(true);
      }
    }
  }

  /// Get telemetry data as TelemetryData objects for UI
  List<TelemetryData> getTelemetryDataList() {
    return _dataManager.getTelemetryDataList();
  }

  /// Get all available telemetry data items for selector dialog
  List<TelemetryData> getAllAvailableTelemetryData() {
    return _dataManager.getAllAvailableTelemetryData();
  }

  /// Send arm/disarm command
  void sendArmCommand(bool arm) {
    _api.sendArmCommand(arm);
  }

  /// Set flight mode
  void setFlightMode(int mode) {
    _api.setFlightMode(mode);
  }

  /// Convert GPS fix type string to numeric value
  double _getGpsFixValue(String fixType) {
    switch (fixType) {
      case 'No GPS':
        return 0.0;
      case 'No Fix':
        return 1.0;
      case '2D Fix':
        return 2.0;
      case '3D Fix':
        return 3.0;
      case 'DGPS':
        return 4.0;
      case 'RTK Float':
        return 5.0;
      case 'RTK Fixed':
        return 6.0;
      default:
        return 0.0;
    }
  }

  /// Dispose service and cleanup resources
  void dispose() {
    // Cancel subscription
    _apiSubscription?.cancel();

    // Dispose API
    _api.dispose();

    // Close stream controllers
    _connectionController.close();
    _dataReceiveController.close();

    // Dispose data manager
    _dataManager.dispose();
  }
}
