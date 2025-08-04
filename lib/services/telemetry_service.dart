import 'dart:async';
import 'package:skylink/api/telemetry/mavlink_api.dart';
import 'package:skylink/data/telemetry_data.dart';
import 'package:flutter/material.dart';

/// Service for managing telemetry data from MAVLink API
class TelemetryService {
  static final TelemetryService _instance = TelemetryService._internal();
  factory TelemetryService() => _instance;
  TelemetryService._internal();

  final DroneMAVLinkAPI _api = DroneMAVLinkAPI();
  StreamSubscription? _apiSubscription;

  // Stream controllers for real-time data
  final _telemetryController =
      StreamController<Map<String, double>>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();

  // Current telemetry data
  Map<String, double> _currentTelemetry = {};
  bool _isConnected = false;

  // Public getters
  Stream<Map<String, double>> get telemetryStream =>
      _telemetryController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;
  bool get isConnected => _isConnected;
  Map<String, double> get currentTelemetry => Map.from(_currentTelemetry);

  // Expose MAVLink API for accessing other event types (like statusText)
  DroneMAVLinkAPI get mavlinkAPI => _api;

  /// Initialize the service
  void initialize() {
    _setupApiListener();
  }

  /// Connect to drone via specified port
  Future<bool> connect(String port, {int baudRate = 115200}) async {
    try {
      bool success = await _api.connect(port, baudRate: baudRate);
      if (success) {
        _isConnected = true;
        _connectionController.add(true);
        // Request all data streams for real-time telemetry
        _api.requestAllDataStreams();
      }
      return success;
    } catch (e) {
      print('TelemetryService connect error: $e');
      return false;
    }
  }

  /// Disconnect from drone
  void disconnect() {
    _api.disconnect();
    _isConnected = false;
    _connectionController.add(false);
    _currentTelemetry.clear();
    _telemetryController.add(_currentTelemetry);
  }

  /// Get available serial ports
  List<String> getAvailablePorts() {
    return _api.getAvailablePorts();
  }

  /// Setup listener for MAVLink API events
  void _setupApiListener() {
    _apiSubscription = _api.eventStream.listen((event) {
      switch (event.type) {
        case MAVLinkEventType.connectionStateChanged:
          _handleConnectionStateChange(event.data);
          break;
        case MAVLinkEventType.attitude:
          _updateAttitudeData();
          break;
        case MAVLinkEventType.vfrHud:
          _updateVfrHudData();
          break;
        case MAVLinkEventType.gpsInfo:
          _updateGpsData();
          break;
        case MAVLinkEventType.batteryStatus:
          _updateBatteryData();
          break;
        default:
          // Update all data on any telemetry event
          _updateAllTelemetryData();
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
        _currentTelemetry.clear();
        _telemetryController.add(_currentTelemetry);
      }
    }
  }

  /// Update attitude data (roll, pitch, yaw)
  void _updateAttitudeData() {
    _currentTelemetry.addAll({
      'roll': _api.roll,
      'pitch': _api.pitch,
      'yaw': _api.yaw,
      'compass_heading': _api.yaw, // Use yaw as compass heading for now
    });
    _telemetryController.add(_currentTelemetry);
  }

  /// Update VFR HUD data (speed, altitude)
  void _updateVfrHudData() {
    _currentTelemetry.addAll({
      'airspeed': _api.airSpeed,
      'groundspeed': _api.groundSpeed,
      'altitude_msl': _api.altitudeMSL,
      'altitude_rel': _api.altitudeRelative,
    });
    _telemetryController.add(_currentTelemetry);
  }

  /// Update GPS data
  void _updateGpsData() {
    _currentTelemetry.addAll({
      'satellites': _api.satellites.toDouble(),
      'gps_fix': _getGpsFixValue(_api.gpsFixType),
    });
    _telemetryController.add(_currentTelemetry);
  }

  /// Update battery data
  void _updateBatteryData() {
    _currentTelemetry['battery'] = _api.batteryPercent.toDouble();
    _telemetryController.add(_currentTelemetry);
  }

  /// Update all telemetry data at once
  void _updateAllTelemetryData() {
    _currentTelemetry = {
      // Attitude
      'roll': _api.roll,
      'pitch': _api.pitch,
      'yaw': _api.yaw,

      // Heading/Compass - use yaw for compass until GPS heading is available
      'compass_heading': _api.yaw,

      // Speed
      'airspeed': _api.airSpeed,
      'groundspeed': _api.groundSpeed,

      // Altitude
      'altitude_msl': _api.altitudeMSL,
      'altitude_rel': _api.altitudeRelative,

      // GPS
      'satellites': _api.satellites.toDouble(),
      'gps_fix': _getGpsFixValue(_api.gpsFixType),

      // Battery
      'battery': _api.batteryPercent.toDouble(),

      // System status
      'armed': _api.isArmed ? 1.0 : 0.0,
    };
    _telemetryController.add(_currentTelemetry);
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

  /// Get telemetry data as TelemetryData objects for UI
  List<TelemetryData> getTelemetryDataList() {
    if (_currentTelemetry.isEmpty) {
      // Return default/empty telemetry data when no connection
      return [
        TelemetryData(
          label: 'Roll',
          value: '0.0',
          unit: '°',
          color: Colors.blue,
        ),
        TelemetryData(
          label: 'Pitch',
          value: '0.0',
          unit: '°',
          color: Colors.green,
        ),
        TelemetryData(
          label: 'Yaw',
          value: '0.0',
          unit: '°',
          color: Colors.purple,
        ),
        TelemetryData(
          label: 'Airspeed',
          value: '0.0',
          unit: 'm/s',
          color: Colors.orange,
        ),
        TelemetryData(
          label: 'Groundspeed',
          value: '0.0',
          unit: 'm/s',
          color: Colors.cyan,
        ),
        TelemetryData(
          label: 'Altitude MSL',
          value: '0.0',
          unit: 'm',
          color: Colors.red,
        ),
        TelemetryData(
          label: 'Altitude Rel',
          value: '0.0',
          unit: 'm',
          color: Colors.pink,
        ),
        TelemetryData(
          label: 'Satellites',
          value: '0',
          unit: '',
          color: Colors.amber,
        ),
        TelemetryData(
          label: 'Battery',
          value: '0',
          unit: '%',
          color: Colors.teal,
        ),
      ];
    }

    return [
      TelemetryData(
        label: 'Roll',
        value: (_currentTelemetry['roll'] ?? 0.0).toStringAsFixed(1),
        unit: '°',
        color: Colors.blue,
      ),
      TelemetryData(
        label: 'Pitch',
        value: (_currentTelemetry['pitch'] ?? 0.0).toStringAsFixed(1),
        unit: '°',
        color: Colors.green,
      ),
      TelemetryData(
        label: 'Yaw',
        value: (_currentTelemetry['yaw'] ?? 0.0).toStringAsFixed(1),
        unit: '°',
        color: Colors.purple,
      ),
      TelemetryData(
        label: 'Airspeed',
        value: (_currentTelemetry['airspeed'] ?? 0.0).toStringAsFixed(1),
        unit: 'm/s',
        color: Colors.orange,
      ),
      TelemetryData(
        label: 'Groundspeed',
        value: (_currentTelemetry['groundspeed'] ?? 0.0).toStringAsFixed(1),
        unit: 'm/s',
        color: Colors.cyan,
      ),
      TelemetryData(
        label: 'Altitude MSL',
        value: (_currentTelemetry['altitude_msl'] ?? 0.0).toStringAsFixed(1),
        unit: 'm',
        color: Colors.red,
      ),
      TelemetryData(
        label: 'Altitude Rel',
        value: (_currentTelemetry['altitude_rel'] ?? 0.0).toStringAsFixed(1),
        unit: 'm',
        color: Colors.pink,
      ),
      TelemetryData(
        label: 'Satellites',
        value: (_currentTelemetry['satellites'] ?? 0.0).toInt().toString(),
        unit: '',
        color: Colors.amber,
      ),
      TelemetryData(
        label: 'Battery',
        value: (_currentTelemetry['battery'] ?? 0.0).toInt().toString(),
        unit: '%',
        color: Colors.teal,
      ),
    ];
  }

  /// Send arm/disarm command
  void sendArmCommand(bool arm) {
    _api.sendArmCommand(arm);
  }

  /// Set flight mode
  void setFlightMode(int mode) {
    _api.setFlightMode(mode);
  }

  /// Get current flight mode
  String get currentMode => _api.currentMode;

  /// Check if drone is armed
  bool get isArmed => _api.isArmed;

  /// Dispose service and cleanup resources
  void dispose() {
    _apiSubscription?.cancel();
    _api.dispose();
    _telemetryController.close();
    _connectionController.close();
  }
}
