import 'dart:convert';
import 'dart:developer';

/// Adapter to convert MQTT JSON data to TelemetryService compatible format
class MqttDataAdapter {
  /// Convert MQTT JSON string to telemetry data format (ULTRA-FAST 10ms)
  static Map<String, double> convertMqttToTelemetry(String jsonString) {
    try {
      final Map<String, dynamic> data = json.decode(jsonString);
      final Map<String, double> telemetryData = {};

      // Ultra-fast data extraction - no debug overhead
      Map<String, dynamic> actualData = data;
      if (data.containsKey('v') && data['v'] is Map) {
        actualData = data['v'] as Map<String, dynamic>;
      }

      // Optimized mapping order for 10ms performance
      _mapDirectValues(actualData, telemetryData);
      _mapPositionData(actualData, telemetryData);
      _mapVelocityData(actualData, telemetryData);
      _mapBatteryData(actualData, telemetryData);
      _mapGpsData(actualData, telemetryData);
      _calculateDerivedValues(actualData, telemetryData);

      return telemetryData;
    } catch (e) {
      return {};
    }
  }

  /// Map direct value fields
  static void _mapDirectValues(
    Map<String, dynamic> mqtt,
    Map<String, double> telemetry,
  ) {
    // Check for nested attitude object (correct field name)
    if (mqtt['attitude'] is Map) {
      final attitudeData = mqtt['attitude'] as Map<String, dynamic>;

      if (attitudeData['roll'] is num) {
        telemetry['roll'] = attitudeData['roll'].toDouble();
      }
      if (attitudeData['pitch'] is num) {
        telemetry['pitch'] = attitudeData['pitch'].toDouble();
      }
      if (attitudeData['yaw'] is num) {
        telemetry['yaw'] = attitudeData['yaw'].toDouble();
      }
    } else {
      print('   ❌ No attitude object found');
    }

    // Also check direct fields (flat structure)
    if (mqtt['roll'] is num) {
      telemetry['roll'] = mqtt['roll'].toDouble();
    }
    if (mqtt['pitch'] is num) {
      telemetry['pitch'] = mqtt['pitch'].toDouble();
    }
    if (mqtt['yaw'] is num) {
      telemetry['yaw'] = mqtt['yaw'].toDouble();
    }

    // Speed values
    if (mqtt['rollspeed'] is num) {
      telemetry['rollspeed'] = mqtt['rollspeed'].toDouble();
    }
    if (mqtt['pitchspeed'] is num) {
      telemetry['pitchspeed'] = mqtt['pitchspeed'].toDouble();
    }
    if (mqtt['yawspeed'] is num) {
      telemetry['yawspeed'] = mqtt['yawspeed'].toDouble();
    }

    // Ground and air speed
    if (mqtt['groundspeed'] is num) {
      telemetry['groundspeed'] = mqtt['groundspeed'].toDouble();
    }
    if (mqtt['airspeed'] is num) {
      telemetry['airspeed'] = mqtt['airspeed'].toDouble();
    }

    // Other navigation data
    if (mqtt['cog'] is num) {
      telemetry['cog'] = mqtt['cog'].toDouble();
    }
    if (mqtt['climb'] is num) {
      telemetry['climb'] = mqtt['climb'].toDouble();
    }
    // Add heading mapping for flat structure
    if (mqtt['hdg'] is num) {
      telemetry['heading'] = mqtt['hdg'].toDouble();
      // Also map to compass_heading for Primary Flight Display
      telemetry['compass_heading'] = mqtt['hdg'].toDouble();
    }

    // Also check for yaw as fallback heading
    if (mqtt['yaw'] is num && !telemetry.containsKey('compass_heading')) {
      telemetry['compass_heading'] = mqtt['yaw'].toDouble();
    }

    // Direct latitude/longitude (flat structure)
    if (mqtt['latitude'] is num) {
      telemetry['latitude'] = mqtt['latitude'].toDouble();
    }
    if (mqtt['longitude'] is num) {
      telemetry['longitude'] = mqtt['longitude'].toDouble();
    }

    // Altitude variations - handle both direct and nested
    if (mqtt['altitude'] is num) {
      telemetry['altitude_msl'] = mqtt['altitude'].toDouble();
    }
    if (mqtt['alt'] is num) {
      telemetry['altitude_msl'] = mqtt['alt'].toDouble();
    }
    if (mqtt['relative_alt'] is num) {
      telemetry['altitude_rel'] = mqtt['relative_alt'].toDouble();
    }

    // Connection status
    if (mqtt['connected'] is bool) {
      telemetry['connected'] = mqtt['connected'] ? 1.0 : 0.0;
    }
    if (mqtt['armed'] is bool) {
      telemetry['armed'] = mqtt['armed'] ? 1.0 : 0.0;
    }

    // Flight mode string to number
    if (mqtt['flight_mode'] is String) {
      telemetry['flight_mode'] = _flightModeToNumber(mqtt['flight_mode']);
    }
  }

  /// Map position object data
  static void _mapPositionData(
    Map<String, dynamic> mqtt,
    Map<String, double> telemetry,
  ) {
    if (mqtt['position'] is Map<String, dynamic>) {
      final position = mqtt['position'] as Map<String, dynamic>;

      if (position['lat'] is num) {
        telemetry['latitude'] = position['lat'].toDouble();
      }
      if (position['lon'] is num) {
        telemetry['longitude'] = position['lon'].toDouble();
      }
      if (position['alt'] is num) {
        telemetry['altitude_msl'] = position['alt'].toDouble();
      }
      if (position['relative_alt'] is num) {
        telemetry['altitude_rel'] = position['relative_alt'].toDouble();
      }
      // Add heading mapping from position object
      if (position['hdg'] is num) {
        telemetry['heading'] = position['hdg'].toDouble();
        // Also map to compass_heading for Primary Flight Display
        telemetry['compass_heading'] = position['hdg'].toDouble();
      }
    } else {
      print('   ⚠️ No position object found');
    }
  }

  /// Map velocity object data
  static void _mapVelocityData(
    Map<String, dynamic> mqtt,
    Map<String, double> telemetry,
  ) {
    if (mqtt['velocity'] is Map<String, dynamic>) {
      final velocity = mqtt['velocity'] as Map<String, dynamic>;

      if (velocity['vx'] is num) {
        telemetry['velocity_x'] = velocity['vx'].toDouble();
      }
      if (velocity['vy'] is num) {
        telemetry['velocity_y'] = velocity['vy'].toDouble();
      }
      if (velocity['vz'] is num) {
        telemetry['velocity_z'] = velocity['vz'].toDouble();
      }
    }
  }

  /// Map battery object data
  static void _mapBatteryData(
    Map<String, dynamic> mqtt,
    Map<String, double> telemetry,
  ) {
    // Handle nested battery object structure
    if (mqtt['battery'] is Map<String, dynamic>) {
      final battery = mqtt['battery'] as Map<String, dynamic>;

      if (battery['voltage'] is num) {
        telemetry['voltageBattery'] = battery['voltage'].toDouble();
      }
      if (battery['current'] is num) {
        telemetry['battery_current'] = battery['current'].toDouble();
      }
      if (battery['remaining'] is num) {
        telemetry['battery'] = battery['remaining'].toDouble();
      }
    }

    // Handle flat structure - direct voltage field
    if (mqtt['voltage'] is num) {
      telemetry['voltageBattery'] = mqtt['voltage'].toDouble();
    }

    // Handle other flat battery fields
    if (mqtt['battery_current'] is num) {
      telemetry['battery_current'] = mqtt['battery_current'].toDouble();
    }
    if (mqtt['battery_remaining'] is num) {
      telemetry['battery'] = mqtt['battery_remaining'].toDouble();
    }
    if (mqtt['battery_percent'] is num) {
      telemetry['battery'] = mqtt['battery_percent'].toDouble();
    }
  }

  /// Map GPS object data
  static void _mapGpsData(
    Map<String, dynamic> mqtt,
    Map<String, double> telemetry,
  ) {
    if (mqtt['gps'] is Map<String, dynamic>) {
      final gps = mqtt['gps'] as Map<String, dynamic>;

      if (gps['fix_type'] is num) {
        telemetry['gps_fix'] = gps['fix_type'].toDouble();
      }
      if (gps['satellites_visible'] is num) {
        telemetry['satellites'] = gps['satellites_visible'].toDouble();
      }
    }
  }

  /// Calculate derived values from MQTT data
  static void _calculateDerivedValues(
    Map<String, dynamic> mqtt,
    Map<String, double> telemetry,
  ) {
    // Calculate total speed from velocity components
    if (telemetry.containsKey('velocity_x') &&
        telemetry.containsKey('velocity_y') &&
        telemetry.containsKey('velocity_z')) {
      final vx = telemetry['velocity_x']!;
      final vy = telemetry['velocity_y']!;
      final vz = telemetry['velocity_z']!;
      telemetry['speed_3d'] = (vx * vx + vy * vy + vz * vz).abs();
    }

    // Map flight mode string to number
    if (mqtt['flight_mode'] is String) {
      telemetry['flight_mode'] = _flightModeToNumber(mqtt['flight_mode']);
    }
  }

  /// Convert flight mode string to numeric value
  static double _flightModeToNumber(String mode) {
    switch (mode.toUpperCase()) {
      case 'MANUAL':
        return 0.0;
      case 'ACRO':
        return 1.0;
      case 'STABILIZE':
        return 2.0;
      case 'ALT_HOLD':
        return 3.0;
      case 'AUTO':
        return 4.0;
      case 'GUIDED':
        return 5.0;
      case 'LOITER':
        return 6.0;
      case 'RTL':
        return 7.0;
      case 'CIRCLE':
        return 8.0;
      case 'LAND':
        return 9.0;
      default:
        return -1.0;
    }
  }

  /// Create a sample telemetry data for testing
  static Map<String, double> createSampleTelemetry() {
    return {
      'roll': 0.0,
      'pitch': 0.0,
      'yaw': 0.0,
      'rollspeed': 0.0,
      'pitchspeed': 0.0,
      'yawspeed': 0.0,
      'groundspeed': 0.0,
      'airspeed': 0.0,
      'altitude_msl': 0.0,
      'altitude_rel': 0.0,
      'latitude': 0.0,
      'longitude': 0.0,
      'velocity_x': 0.0,
      'velocity_y': 0.0,
      'velocity_z': 0.0,
      'battery': 100.0,
      'battery_voltage': 12.6,
      'battery_current': 0.0,
      'satellites': 0.0,
      'gps_fix': 0.0,
      'armed': 0.0,
      'connected': 1.0,
      'flight_mode': 0.0,
      'cog': 0.0,
      'climb': 0.0,
      'heading': 0.0, // Add heading field
    };
  }

  /// Validate if MQTT data contains required fields
  static bool isValidMqttData(String payload) {
    try {
      final data = jsonDecode(payload);
      if (data is! Map<String, dynamic>) return false;

      // Check for some essential fields
      return data.containsKey('connected') ||
          data.containsKey('latitude') ||
          data.containsKey('pitch') ||
          data.containsKey('yaw');
    } catch (e) {
      return false;
    }
  }

  /// Get list of available fields from MQTT data
  static List<String> getAvailableFields(String payload) {
    try {
      final data = jsonDecode(payload);
      if (data is Map<String, dynamic>) {
        final fields = <String>[];
        _collectFields(data, fields, '');
        return fields;
      }
    } catch (e) {
      log('Error parsing MQTT fields: $e');
    }
    return [];
  }

  /// Recursively collect all field names from nested objects
  static void _collectFields(
    Map<String, dynamic> data,
    List<String> fields,
    String prefix,
  ) {
    data.forEach((key, value) {
      final fieldName = prefix.isEmpty ? key : '$prefix.$key';

      if (value is Map<String, dynamic>) {
        _collectFields(value, fields, fieldName);
      } else if (value is num || value is bool) {
        fields.add(fieldName);
      }
    });
  }
}
