import 'dart:async';
import 'package:flutter/material.dart';
import 'package:skylink/data/telemetry_data.dart';

/// Manages telemetry data storage, processing and access
class TelemetryDataManager {
  // Current telemetry data
  final Map<String, double> _currentTelemetry = {};
  bool _armed = false;
  String _lastGpsFixType = 'No GPS';
  String _vehicleType = 'Unknown'; // Vehicle type from heartbeat
  String _currentMode = 'Unknown';

  // Heading stabilization - Optimized for ATTITUDE.yaw (more stable than VFR_HUD)
  double _lastStableHeading = 0.0;
  DateTime _lastHeadingUpdate = DateTime.now();
  static const double _headingStabilityThreshold = 3.0; // degrees
  static const Duration _headingUpdateInterval = Duration(milliseconds: 500);

  // Moving average filter for heading (reduce magnetometer noise)
  final List<double> _headingBuffer = [];
  static const int _headingBufferSize =
      8; // increased from 5 for stronger filtering

  // Stream controller for real-time data
  final _telemetryController =
      StreamController<Map<String, double>>.broadcast();

  // Public getters
  Stream<Map<String, double>> get telemetryStream =>
      _telemetryController.stream;
  Map<String, double> get currentTelemetry => Map.from(_currentTelemetry);
  String get vehicleType => _vehicleType;
  String get currentMode => _currentMode;
  bool get isArmed => _armed;

  // GPS data getters
  double get gpsLatitude => _currentTelemetry['gps_latitude'] ?? 0.0;
  double get gpsLongitude => _currentTelemetry['gps_longitude'] ?? 0.0;
  double get gpsAltitude => _currentTelemetry['gps_altitude'] ?? 0.0;
  double get gpsSpeed => _currentTelemetry['gps_speed'] ?? 0.0;
  double get gpsCourse => _currentTelemetry['gps_course'] ?? 0.0;
  double get gpsHorizontalAccuracy =>
      _currentTelemetry['gps_horizontal_accuracy'] ?? 0.0;
  double get gpsVerticalAccuracy =>
      _currentTelemetry['gps_vertical_accuracy'] ?? 0.0;
  String get gpsFixType => _lastGpsFixType;
  int get gpsFixValue => _getGpsFixValue(_lastGpsFixType).toInt();

  /// Check if GPS has a valid fix
  bool get hasValidGpsFix {
    // Only accept valid GPS fixes that can provide accurate position
    return _lastGpsFixType == '2D Fix' ||
        _lastGpsFixType == '3D Fix' ||
        _lastGpsFixType == 'DGPS' ||
        _lastGpsFixType == 'RTK Float' ||
        _lastGpsFixType == 'RTK Fixed' ||
        _lastGpsFixType == 'Static' ||
        _lastGpsFixType == 'PPP';
  }

  /// Get GPS accuracy in human readable format
  String get gpsAccuracyString {
    if (!hasValidGpsFix) {
      return _lastGpsFixType; // Show actual fix type for debugging
    }
    return '±${gpsHorizontalAccuracy.toStringAsFixed(1)}m';
  }

  /// Clear all telemetry data
  void clearData() {
    _currentTelemetry.clear();
    _armed = false;
    _lastGpsFixType = 'No GPS';
    _vehicleType = 'Unknown';
    _currentMode = 'Unknown';
    _lastStableHeading = 0.0;
    _headingBuffer.clear();
    _emitTelemetry();
  }

  /// Update heartbeat data
  void updateHeartbeatData(Map data) {
    final newMode = (data['mode'] as String?) ?? _currentMode;
    if (newMode != _currentMode) {
      _currentMode = newMode;
    }
    _armed = (data['armed'] as bool?) ?? _armed;
    _vehicleType = (data['type'] as String?) ?? _vehicleType;
    _currentTelemetry['armed'] = _armed ? 1.0 : 0.0;
    _emitTelemetry();
  }

  /// Update attitude data
  void updateAttitudeData(Map data) {
    _currentTelemetry['roll'] =
        (data['roll'] as num?)?.toDouble() ??
        (_currentTelemetry['roll'] ?? 0.0);
    _currentTelemetry['pitch'] =
        (data['pitch'] as num?)?.toDouble() ??
        (_currentTelemetry['pitch'] ?? 0.0);

    final rawYaw =
        (data['yaw'] as num?)?.toDouble() ?? (_currentTelemetry['yaw'] ?? 0.0);

    // Convert yaw from radians to degrees if needed
    double yawDegrees = rawYaw;
    if (rawYaw.abs() <= 6.28) {
      // likely radians (-π to π)
      yawDegrees = rawYaw * 180.0 / 3.14159;
      if (yawDegrees < 0) yawDegrees += 360; // normalize 0-360
    }
    _currentTelemetry['yaw'] = yawDegrees;
    _updateCompassHeading(yawDegrees);
    _emitTelemetry();
  }

  /// Update VFR HUD data
  void updateVfrHudData(Map data) {
    _currentTelemetry['airspeed'] =
        (data['airspeed'] as num?)?.toDouble() ??
        (_currentTelemetry['airspeed'] ?? 0.0);
    _currentTelemetry['groundspeed'] =
        (data['groundspeed'] as num?)?.toDouble() ??
        (_currentTelemetry['groundspeed'] ?? 0.0);

    // vfrhud.alt can serve as MSL if GLOBAL_POSITION not yet arrived
    final alt = (data['alt'] as num?)?.toDouble();
    if (alt != null) {
      _currentTelemetry['altitude_msl'] = alt;
    }
    _emitTelemetry();
  }

  /// Update position data
  void updatePositionData(Map data) {
    _currentTelemetry['altitude_msl'] =
        (data['altMSL'] as num?)?.toDouble() ??
        (_currentTelemetry['altitude_msl'] ?? 0.0);
    _currentTelemetry['altitude_rel'] =
        (data['altRelative'] as num?)?.toDouble() ??
        (_currentTelemetry['altitude_rel'] ?? 0.0);
    _currentTelemetry['groundspeed'] =
        (data['groundSpeed'] as num?)?.toDouble() ??
        (_currentTelemetry['groundspeed'] ?? 0.0);
    _emitTelemetry();
  }

  /// Update GPS info data
  void updateGpsInfoData(Map data) {
    final fixType = (data['fixType'] as String?) ?? 'No GPS';
    _currentTelemetry['satellites'] =
        ((data['satellites'] as num?)?.toDouble() ?? 0.0);
    _currentTelemetry['gps_fix'] = _getGpsFixValue(fixType);

    _currentTelemetry['gps_latitude'] =
        (data['lat'] as num?)?.toDouble() ??
        (_currentTelemetry['gps_latitude'] ?? 0.0);
    _currentTelemetry['gps_longitude'] =
        (data['lon'] as num?)?.toDouble() ??
        (_currentTelemetry['gps_longitude'] ?? 0.0);
    _currentTelemetry['gps_altitude'] =
        (data['alt'] as num?)?.toDouble() ??
        (_currentTelemetry['gps_altitude'] ?? 0.0);
    _currentTelemetry['gps_speed'] =
        (data['vel'] as num?)?.toDouble() ??
        (_currentTelemetry['gps_speed'] ?? 0.0);
    _currentTelemetry['gps_course'] =
        (data['cog'] as num?)?.toDouble() ??
        (_currentTelemetry['gps_course'] ?? 0.0);
    _currentTelemetry['gps_horizontal_accuracy'] =
        (data['eph'] as num?)?.toDouble() ??
        (_currentTelemetry['gps_horizontal_accuracy'] ?? 0.0);
    _currentTelemetry['gps_vertical_accuracy'] =
        (data['epv'] as num?)?.toDouble() ??
        (_currentTelemetry['gps_vertical_accuracy'] ?? 0.0);

    // Cache last fix type string in a field for getters
    _lastGpsFixType = fixType;
    _emitTelemetry();
  }

  /// Update battery status data
  void updateBatteryStatusData(Map data) {
    final bp = (data['batteryPercent'] as num?)?.toDouble();
    final vb = (data['voltageBattery'] as num?)?.toDouble();
    if (bp != null) {
      _currentTelemetry['battery'] = bp;
    }
    if (vb != null) {
      _currentTelemetry['voltageBattery'] = vb;
    }
    _emitTelemetry();
  }

  /// Apply moving average filter to reduce magnetometer noise
  double _filterHeading(double newHeading) {
    // Add to buffer
    _headingBuffer.add(newHeading);

    // Keep buffer size limited
    if (_headingBuffer.length > _headingBufferSize) {
      _headingBuffer.removeAt(0);
    }

    // Return simple average if buffer not full
    if (_headingBuffer.length < 3) {
      return newHeading;
    }

    // Calculate weighted average (recent values have more weight)
    double sum = 0.0;
    double weightSum = 0.0;

    for (int i = 0; i < _headingBuffer.length; i++) {
      double weight = (i + 1).toDouble(); // Recent values get higher weight
      sum += _headingBuffer[i] * weight;
      weightSum += weight;
    }

    return sum / weightSum;
  }

  /// Update compass heading with stability filtering
  void _updateCompassHeading(double newHeading) {
    final now = DateTime.now();

    // Skip update if too frequent (reduce noise)
    if (now.difference(_lastHeadingUpdate) < _headingUpdateInterval) {
      return;
    }

    // Normalize heading to 0-360
    newHeading = newHeading % 360;
    if (newHeading < 0) newHeading += 360;

    // Apply moving average filter to smooth out noise
    final filteredHeading = _filterHeading(newHeading);

    // Calculate heading difference handling 360/0 wraparound
    double headingDiff = (filteredHeading - _lastStableHeading).abs();
    if (headingDiff > 180) {
      headingDiff = 360 - headingDiff;
    }

    // Only update if change is significant enough to be meaningful
    if (headingDiff > _headingStabilityThreshold ||
        now.difference(_lastHeadingUpdate) > Duration(seconds: 2)) {
      _currentTelemetry['compass_heading'] = filteredHeading;
      _lastStableHeading = filteredHeading;
      _lastHeadingUpdate = now;
    }
  }

  /// Emit current telemetry map
  void _emitTelemetry() {
    _telemetryController.add(Map.from(_currentTelemetry));
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
      return _getDefaultTelemetryDataList();
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
        label: 'Voltage',
        value: (_currentTelemetry['voltageBattery'] ?? 0.00).toStringAsFixed(2),
        unit: 'V',
        color: Colors.redAccent,
      ),
      TelemetryData(
        label: 'GPS Lat',
        value: (_currentTelemetry['gps_latitude'] ?? 0.0).toStringAsFixed(6),
        unit: '°',
        color: Colors.deepOrange,
      ),
      TelemetryData(
        label: 'GPS Lon',
        value: (_currentTelemetry['gps_longitude'] ?? 0.0).toStringAsFixed(6),
        unit: '°',
        color: Colors.deepPurple,
      ),
      TelemetryData(
        label: 'GPS Alt',
        value: (_currentTelemetry['gps_altitude'] ?? 0.0).toStringAsFixed(1),
        unit: 'm',
        color: Colors.indigo,
      ),
      TelemetryData(
        label: 'GPS Speed',
        value: (_currentTelemetry['gps_speed'] ?? 0.0).toStringAsFixed(1),
        unit: 'm/s',
        color: Colors.lime,
      ),
      TelemetryData(
        label: 'GPS Course',
        value: (_currentTelemetry['gps_course'] ?? 0.0).toStringAsFixed(1),
        unit: '°',
        color: Colors.brown,
      ),
      TelemetryData(
        label: 'GPS H.Acc',
        value: (_currentTelemetry['gps_horizontal_accuracy'] ?? 0.0)
            .toStringAsFixed(2),
        unit: 'm',
        color: Colors.grey,
      ),
      TelemetryData(
        label: 'Battery',
        value: (_currentTelemetry['battery'] ?? 0.0).toInt().toString(),
        unit: '%',
        color: Colors.teal,
      ),
    ];
  }

  /// Get default telemetry data list when no connection
  List<TelemetryData> _getDefaultTelemetryDataList() {
    return [
      TelemetryData(label: 'Roll', value: '0.0', unit: '°', color: Colors.blue),
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
        label: 'Voltage',
        value: '0.00',
        unit: 'V',
        color: Colors.green,
      ),
      TelemetryData(
        label: 'GPS Lat',
        value: '0.0',
        unit: '°',
        color: Colors.deepOrange,
      ),
      TelemetryData(
        label: 'GPS Lon',
        value: '0.0',
        unit: '°',
        color: Colors.deepPurple,
      ),
      TelemetryData(
        label: 'GPS Alt',
        value: '0.0',
        unit: 'm',
        color: Colors.indigo,
      ),
      TelemetryData(
        label: 'GPS Speed',
        value: '0.0',
        unit: 'm/s',
        color: Colors.lime,
      ),
      TelemetryData(
        label: 'GPS Course',
        value: '0.0',
        unit: '°',
        color: Colors.brown,
      ),
      TelemetryData(
        label: 'GPS H.Acc',
        value: '0.0',
        unit: 'm',
        color: Colors.grey,
      ),
      TelemetryData(
        label: 'Battery',
        value: '0',
        unit: '%',
        color: Colors.teal,
      ),
    ];
  }

  /// Get all available telemetry data items for selector dialog
  List<TelemetryData> getAllAvailableTelemetryData() {
    return [
      // Flight Attitude
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

      // Speed Data
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

      // Altitude Data
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

      // GPS Data
      TelemetryData(
        label: 'GPS Latitude',
        value: (_currentTelemetry['gps_latitude'] ?? 0.0).toStringAsFixed(6),
        unit: '°',
        color: Colors.deepOrange,
      ),
      TelemetryData(
        label: 'GPS Longitude',
        value: (_currentTelemetry['gps_longitude'] ?? 0.0).toStringAsFixed(6),
        unit: '°',
        color: Colors.deepPurple,
      ),
      TelemetryData(
        label: 'GPS Altitude',
        value: (_currentTelemetry['gps_altitude'] ?? 0.0).toStringAsFixed(1),
        unit: 'm',
        color: Colors.indigo,
      ),
      TelemetryData(
        label: 'GPS Speed',
        value: (_currentTelemetry['gps_speed'] ?? 0.0).toStringAsFixed(1),
        unit: 'm/s',
        color: Colors.lime,
      ),
      TelemetryData(
        label: 'GPS Course',
        value: (_currentTelemetry['gps_course'] ?? 0.0).toStringAsFixed(1),
        unit: '°',
        color: Colors.brown,
      ),
      TelemetryData(
        label: 'GPS H.Accuracy',
        value: (_currentTelemetry['gps_horizontal_accuracy'] ?? 0.0)
            .toStringAsFixed(2),
        unit: 'm',
        color: Colors.grey,
      ),
      TelemetryData(
        label: 'GPS V.Accuracy',
        value: (_currentTelemetry['gps_vertical_accuracy'] ?? 0.0)
            .toStringAsFixed(2),
        unit: 'm',
        color: Colors.blueGrey,
      ),
      TelemetryData(
        label: 'GPS Fix Type',
        value: gpsFixType,
        unit: '',
        color: Colors.lightGreen,
      ),
      TelemetryData(
        label: 'Satellites',
        value: (_currentTelemetry['satellites'] ?? 0.0).toInt().toString(),
        unit: '',
        color: Colors.amber,
      ),

      // Battery & Power
      TelemetryData(
        label: 'Battery',
        value: (_currentTelemetry['battery'] ?? 0.0).toInt().toString(),
        unit: '%',
        color: Colors.teal,
      ),
      TelemetryData(
        label: 'Voltage',
        value: (_currentTelemetry['voltageBattery'] ?? 0.00).toStringAsFixed(2),
        unit: 'V',
        color: Colors.teal,
      ),

      // Flight Status
      TelemetryData(
        label: 'Flight Mode',
        value: _currentMode,
        unit: '',
        color: Colors.deepOrangeAccent,
      ),
    ];
  }

  /// Dispose resources
  void dispose() {
    _telemetryController.close();
  }
}
