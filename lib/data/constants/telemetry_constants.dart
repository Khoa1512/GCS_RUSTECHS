import 'package:flutter/material.dart';
import 'package:skylink/data/telemetry_data.dart';

/// Constants for telemetry data definitions
class TelemetryConstants {
  /// Get default/empty telemetry data when no connection
  static List<TelemetryData> getDefaultTelemetryData() {
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
        color: Colors.teal,
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

  /// Build telemetry data list from current telemetry map
  static List<TelemetryData> buildTelemetryDataList(
    Map<String, double> currentTelemetry,
  ) {
    return [
      TelemetryData(
        label: 'Roll',
        value: (currentTelemetry['roll'] ?? 0.0).toStringAsFixed(1),
        unit: '°',
        color: Colors.blue,
      ),
      TelemetryData(
        label: 'Pitch',
        value: (currentTelemetry['pitch'] ?? 0.0).toStringAsFixed(1),
        unit: '°',
        color: Colors.green,
      ),
      TelemetryData(
        label: 'Yaw',
        value: (currentTelemetry['yaw'] ?? 0.0).toStringAsFixed(1),
        unit: '°',
        color: Colors.purple,
      ),
      TelemetryData(
        label: 'Airspeed',
        value: (currentTelemetry['airspeed'] ?? 0.0).toStringAsFixed(1),
        unit: 'm/s',
        color: Colors.orange,
      ),
      TelemetryData(
        label: 'Groundspeed',
        value: (currentTelemetry['groundspeed'] ?? 0.0).toStringAsFixed(1),
        unit: 'm/s',
        color: Colors.cyan,
      ),
      TelemetryData(
        label: 'Altitude MSL',
        value: (currentTelemetry['altitude_msl'] ?? 0.0).toStringAsFixed(1),
        unit: 'm',
        color: Colors.red,
      ),
      TelemetryData(
        label: 'Altitude Rel',
        value: (currentTelemetry['altitude_rel'] ?? 0.0).toStringAsFixed(1),
        unit: 'm',
        color: Colors.pink,
      ),
      TelemetryData(
        label: 'Satellites',
        value: (currentTelemetry['satellites'] ?? 0.0).toInt().toString(),
        unit: '',
        color: Colors.amber,
      ),
      TelemetryData(
        label: 'Voltage',
        value: (currentTelemetry['voltageBattery'] ?? 0.00).toStringAsFixed(2),
        unit: 'V',
        color: Colors.teal,
      ),
      TelemetryData(
        label: 'GPS Lat',
        value: (currentTelemetry['gps_latitude'] ?? 0.0).toStringAsFixed(6),
        unit: '°',
        color: Colors.deepOrange,
      ),
      TelemetryData(
        label: 'GPS Lon',
        value: (currentTelemetry['gps_longitude'] ?? 0.0).toStringAsFixed(6),
        unit: '°',
        color: Colors.deepPurple,
      ),
      TelemetryData(
        label: 'GPS Alt',
        value: (currentTelemetry['gps_altitude'] ?? 0.0).toStringAsFixed(1),
        unit: 'm',
        color: Colors.indigo,
      ),
      TelemetryData(
        label: 'GPS Speed',
        value: (currentTelemetry['gps_speed'] ?? 0.0).toStringAsFixed(1),
        unit: 'm/s',
        color: Colors.lime,
      ),
      TelemetryData(
        label: 'GPS Course',
        value: (currentTelemetry['gps_course'] ?? 0.0).toStringAsFixed(1),
        unit: '°',
        color: Colors.brown,
      ),
      TelemetryData(
        label: 'GPS H.Acc',
        value: (currentTelemetry['gps_horizontal_accuracy'] ?? 0.0)
            .toStringAsFixed(2),
        unit: 'm',
        color: Colors.grey,
      ),
      TelemetryData(
        label: 'Battery',
        value: (currentTelemetry['battery'] ?? 0.0).toInt().toString(),
        unit: '%',
        color: Colors.teal,
      ),
    ];
  }

  /// Get all available telemetry data items for selector dialog
  static List<TelemetryData> buildAllAvailableTelemetryData(
    Map<String, double> currentTelemetry,
    String gpsFixType,
  ) {
    return [
      // Flight Attitude
      TelemetryData(
        label: 'Roll',
        value: (currentTelemetry['roll'] ?? 0.0).toStringAsFixed(1),
        unit: '°',
        color: Colors.blue,
      ),
      TelemetryData(
        label: 'Pitch',
        value: (currentTelemetry['pitch'] ?? 0.0).toStringAsFixed(1),
        unit: '°',
        color: Colors.green,
      ),
      TelemetryData(
        label: 'Yaw',
        value: (currentTelemetry['yaw'] ?? 0.0).toStringAsFixed(1),
        unit: '°',
        color: Colors.purple,
      ),

      // Speed Data
      TelemetryData(
        label: 'Airspeed',
        value: (currentTelemetry['airspeed'] ?? 0.0).toStringAsFixed(1),
        unit: 'm/s',
        color: Colors.orange,
      ),
      TelemetryData(
        label: 'Groundspeed',
        value: (currentTelemetry['groundspeed'] ?? 0.0).toStringAsFixed(1),
        unit: 'm/s',
        color: Colors.cyan,
      ),

      // Altitude Data
      TelemetryData(
        label: 'Altitude MSL',
        value: (currentTelemetry['altitude_msl'] ?? 0.0).toStringAsFixed(1),
        unit: 'm',
        color: Colors.red,
      ),
      TelemetryData(
        label: 'Altitude Rel',
        value: (currentTelemetry['altitude_rel'] ?? 0.0).toStringAsFixed(1),
        unit: 'm',
        color: Colors.pink,
      ),

      // GPS Data
      TelemetryData(
        label: 'GPS Latitude',
        value: (currentTelemetry['gps_latitude'] ?? 0.0).toStringAsFixed(6),
        unit: '°',
        color: Colors.deepOrange,
      ),
      TelemetryData(
        label: 'GPS Longitude',
        value: (currentTelemetry['gps_longitude'] ?? 0.0).toStringAsFixed(6),
        unit: '°',
        color: Colors.deepPurple,
      ),
      TelemetryData(
        label: 'GPS Altitude',
        value: (currentTelemetry['gps_altitude'] ?? 0.0).toStringAsFixed(1),
        unit: 'm',
        color: Colors.indigo,
      ),
      TelemetryData(
        label: 'GPS Speed',
        value: (currentTelemetry['gps_speed'] ?? 0.0).toStringAsFixed(1),
        unit: 'm/s',
        color: Colors.lime,
      ),
      TelemetryData(
        label: 'GPS Course',
        value: (currentTelemetry['gps_course'] ?? 0.0).toStringAsFixed(1),
        unit: '°',
        color: Colors.brown,
      ),
      TelemetryData(
        label: 'GPS H.Accuracy',
        value: (currentTelemetry['gps_horizontal_accuracy'] ?? 0.0)
            .toStringAsFixed(2),
        unit: 'm',
        color: Colors.grey,
      ),
      TelemetryData(
        label: 'GPS V.Accuracy',
        value: (currentTelemetry['gps_vertical_accuracy'] ?? 0.0)
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
        value: (currentTelemetry['satellites'] ?? 0.0).toInt().toString(),
        unit: '',
        color: Colors.amber,
      ),

      // Battery & Power
      TelemetryData(
        label: 'Battery',
        value: (currentTelemetry['battery'] ?? 0.0).toInt().toString(),
        unit: '%',
        color: Colors.teal,
      ),
      TelemetryData(
        label: 'Voltage',
        value: (currentTelemetry['voltageBattery'] ?? 0.00).toStringAsFixed(2),
        unit: 'V',
        color: Colors.teal,
      ),

      // Flight Status
      TelemetryData(
        label: 'Flight Mode',
        value: currentTelemetry['mode']?.toString() ?? 'Unknown',
        unit: '',
        color: Colors.deepOrangeAccent,
      ),
    ];
  }
}
