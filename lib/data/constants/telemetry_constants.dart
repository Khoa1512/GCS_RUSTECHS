import 'package:flutter/material.dart';
import '../telemetry_data.dart';
import '../../services/telemetry_service.dart';

class TelemetryConstants {
  static final TelemetryService _telemetryService = TelemetryService();

  // Available telemetry types that can be displayed (for selector dialog)
  static final List<TelemetryData> allTelemetryData = [
    // Basic flight data (real data will be populated)
    TelemetryData(
      label: 'Roll',
      value: '0.0',
      color: Colors.blue.shade300,
      unit: '°',
    ),
    TelemetryData(
      label: 'Pitch',
      value: '0.0',
      color: Colors.green.shade300,
      unit: '°',
    ),
    TelemetryData(
      label: 'Yaw',
      value: '0.0',
      color: Colors.purple.shade300,
      unit: '°',
    ),
    TelemetryData(
      label: 'Airspeed',
      value: '0.0',
      color: Colors.orange.shade300,
      unit: 'm/s',
    ),
    TelemetryData(
      label: 'Groundspeed',
      value: '0.0',
      color: Colors.cyan.shade300,
      unit: 'm/s',
    ),
    TelemetryData(
      label: 'Altitude MSL',
      value: '0.0',
      color: Colors.red.shade300,
      unit: 'm',
    ),
    TelemetryData(
      label: 'Altitude Rel',
      value: '0.0',
      color: Colors.pink.shade300,
      unit: 'm',
    ),
    TelemetryData(
      label: 'Satellites',
      value: '0',
      color: Colors.amber.shade300,
      unit: '',
    ),
    TelemetryData(
      label: 'Battery',
      value: '0%',
      color: Colors.teal.shade300,
      unit: '%',
    ),

    // Additional telemetry options for selection
    TelemetryData(
      label: 'GPS Fix',
      value: 'No GPS',
      color: Colors.indigo.shade300,
      unit: '',
    ),
    TelemetryData(
      label: 'Flight Mode',
      value: 'Unknown',
      color: Colors.lime.shade300,
      unit: '',
    ),
    TelemetryData(
      label: 'Armed Status',
      value: 'Disarmed',
      color: Colors.deepOrange.shade300,
      unit: '',
    ),

    // Legacy fake data for backwards compatibility with selector
    TelemetryData(
      label: 'RangeFinder1',
      value: '0.00',
      color: Colors.pink.shade300,
      unit: 'cm',
    ),
    TelemetryData(
      label: 'Dist to Home',
      value: '0.00',
      color: Colors.green.shade300,
      unit: 'm',
    ),
    TelemetryData(
      label: 'Battery Voltage',
      value: '0.0',
      color: Colors.green.shade400,
      unit: 'V',
    ),
    TelemetryData(
      label: 'Current',
      value: '0.0',
      color: Colors.amber.shade300,
      unit: 'A',
    ),
    TelemetryData(
      label: 'HDOP',
      value: '0.0',
      color: Colors.indigo.shade300,
      unit: '',
    ),
    TelemetryData(
      label: 'VDOP',
      value: '0.0',
      color: Colors.deepPurple.shade300,
      unit: '',
    ),
    TelemetryData(
      label: 'Wind Speed',
      value: '0.0',
      color: Colors.lightBlue.shade300,
      unit: 'm/s',
    ),
    TelemetryData(
      label: 'Wind Direction',
      value: '0',
      color: Colors.blueGrey.shade300,
      unit: '°',
    ),
    TelemetryData(
      label: 'Temperature',
      value: '0',
      color: Colors.orange.shade400,
      unit: '°C',
    ),
    TelemetryData(
      label: 'Humidity',
      value: '0',
      color: Colors.blue.shade400,
      unit: '%',
    ),
    TelemetryData(
      label: 'Pressure',
      value: '0',
      color: Colors.purple.shade400,
      unit: 'hPa',
    ),
    TelemetryData(
      label: 'Climb Rate',
      value: '0.0',
      color: Colors.green.shade600,
      unit: 'm/s',
    ),
    TelemetryData(
      label: 'Flight Time',
      value: '00:00',
      color: Colors.purple.shade500,
      unit: '',
    ),
    TelemetryData(
      label: 'Total Distance',
      value: '0.0',
      color: Colors.teal.shade500,
      unit: 'km',
    ),
  ];

  /// Get default telemetry data - now returns real data from TelemetryService
  static List<TelemetryData> getDefaultTelemetry() {
    if (_telemetryService.isConnected) {
      // Return real telemetry data when connected
      return _telemetryService.getTelemetryDataList();
    } else {
      // Return default empty data when not connected
      return [
        TelemetryData(
          label: 'Roll',
          value: '0.0',
          color: Colors.blue.shade300,
          unit: '°',
        ),
        TelemetryData(
          label: 'Pitch',
          value: '0.0',
          color: Colors.green.shade300,
          unit: '°',
        ),
        TelemetryData(
          label: 'Yaw',
          value: '0.0',
          color: Colors.purple.shade300,
          unit: '°',
        ),
        TelemetryData(
          label: 'Airspeed',
          value: '0.0',
          color: Colors.orange.shade300,
          unit: 'm/s',
        ),
        TelemetryData(
          label: 'Groundspeed',
          value: '0.0',
          color: Colors.cyan.shade300,
          unit: 'm/s',
        ),
        TelemetryData(
          label: 'Altitude MSL',
          value: '0.0',
          color: Colors.red.shade300,
          unit: 'm',
        ),
        TelemetryData(
          label: 'Altitude Rel',
          value: '0.0',
          color: Colors.pink.shade300,
          unit: 'm',
        ),
        TelemetryData(
          label: 'Satellites',
          value: '0',
          color: Colors.amber.shade300,
          unit: '',
        ),
        TelemetryData(
          label: 'Battery',
          value: '0',
          color: Colors.teal.shade300,
          unit: '%',
        ),
      ];
    }
  }

  /// Get real-time telemetry data (always returns live data when available)
  static List<TelemetryData> getRealTimeTelemetry() {
    return _telemetryService.getTelemetryDataList();
  }

  /// Check if telemetry service is connected
  static bool get isConnected => _telemetryService.isConnected;

  /// Get current telemetry raw data
  static Map<String, double> get currentTelemetryData =>
      _telemetryService.currentTelemetry;

  /// Convert telemetry name to real data value
  static TelemetryData getUpdatedTelemetryItem(TelemetryData item) {
    if (!_telemetryService.isConnected) {
      return item; // Return original if not connected
    }

    final telemetryData = _telemetryService.currentTelemetry;

    switch (item.label.toLowerCase()) {
      case 'roll':
        return item.copyWith(
          value: (telemetryData['roll'] ?? 0.0).toStringAsFixed(1),
        );
      case 'pitch':
        return item.copyWith(
          value: (telemetryData['pitch'] ?? 0.0).toStringAsFixed(1),
        );
      case 'yaw':
        return item.copyWith(
          value: (telemetryData['yaw'] ?? 0.0).toStringAsFixed(1),
        );
      case 'airspeed':
        return item.copyWith(
          value: (telemetryData['airspeed'] ?? 0.0).toStringAsFixed(1),
        );
      case 'groundspeed':
        return item.copyWith(
          value: (telemetryData['groundspeed'] ?? 0.0).toStringAsFixed(1),
        );
      case 'altitude msl':
        return item.copyWith(
          value: (telemetryData['altitude_msl'] ?? 0.0).toStringAsFixed(1),
        );
      case 'altitude rel':
        return item.copyWith(
          value: (telemetryData['altitude_rel'] ?? 0.0).toStringAsFixed(1),
        );
      case 'satellites':
        return item.copyWith(
          value: (telemetryData['satellites'] ?? 0.0).toInt().toString(),
        );
      case 'battery':
        return item.copyWith(
          value: (telemetryData['battery'] ?? 0.0).toInt().toString(),
        );
      case 'gps fix':
        final gpsFixValue = telemetryData['gps_fix'] ?? 0.0;
        String fixText = 'No GPS';
        switch (gpsFixValue.toInt()) {
          case 0:
            fixText = 'No GPS';
            break;
          case 1:
            fixText = 'No Fix';
            break;
          case 2:
            fixText = '2D Fix';
            break;
          case 3:
            fixText = '3D Fix';
            break;
          case 4:
            fixText = 'DGPS';
            break;
          case 5:
            fixText = 'RTK Float';
            break;
          case 6:
            fixText = 'RTK Fixed';
            break;
        }
        return item.copyWith(value: fixText);
      case 'flight mode':
        return item.copyWith(value: _telemetryService.currentMode);
      case 'armed status':
        return item.copyWith(
          value: _telemetryService.isArmed ? 'Armed' : 'Disarmed',
        );
      default:
        return item; // Return original for unmapped items
    }
  }
}
