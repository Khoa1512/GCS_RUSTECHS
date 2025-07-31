import 'package:flutter/material.dart';
import '../telemetry_data.dart';

class TelemetryConstants {
  static final List<TelemetryData> allTelemetryData = [
    // Basic flight data
    TelemetryData(
      label: 'Altitude',
      value: '0.00',
      color: Colors.purple.shade300,
      unit: 'm',
    ),
    TelemetryData(
      label: 'GroundSpeed',
      value: '0.00',
      color: Colors.orange.shade300,
      unit: 'm/s',
    ),
    TelemetryData(
      label: 'Yaw',
      value: '0.00',
      color: Colors.blue.shade300,
      unit: 'deg',
    ),
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
      label: 'Pitch',
      value: '0.00',
      color: Colors.red.shade300,
      unit: 'deg',
    ),
    TelemetryData(
      label: 'ahrs2_alt',
      value: '0.00',
      color: Colors.yellow.shade300,
      unit: '',
    ),
    TelemetryData(
      label: 'Dist Traveled',
      value: '0.00',
      color: Colors.cyan.shade300,
      unit: 'm',
    ),
    TelemetryData(
      label: 'Roll',
      value: '0.00',
      color: Colors.lightBlue.shade300,
      unit: 'deg',
    ),

    // Power & Battery
    TelemetryData(
      label: 'Battery Voltage',
      value: '12.6',
      color: Colors.green.shade400,
      unit: 'V',
    ),
    TelemetryData(
      label: 'Current',
      value: '2.5',
      color: Colors.amber.shade300,
      unit: 'A',
    ),
    TelemetryData(
      label: 'Battery %',
      value: '85',
      color: Colors.lime.shade300,
      unit: '%',
    ),
    TelemetryData(
      label: 'Power Consumption',
      value: '31.5',
      color: Colors.teal.shade400,
      unit: 'W',
    ),

    // GPS & Navigation
    TelemetryData(
      label: 'GPS Satellites',
      value: '12',
      color: Colors.teal.shade300,
      unit: '',
    ),
    TelemetryData(
      label: 'HDOP',
      value: '1.2',
      color: Colors.indigo.shade300,
      unit: '',
    ),
    TelemetryData(
      label: 'GPS Fix Type',
      value: '3D',
      color: Colors.green.shade500,
      unit: '',
    ),
    TelemetryData(
      label: 'Course',
      value: '180',
      color: Colors.purple.shade400,
      unit: 'deg',
    ),

    // Vibration & Sensors
    TelemetryData(
      label: 'Vibration X',
      value: '0.05',
      color: Colors.deepOrange.shade300,
      unit: 'm/s²',
    ),
    TelemetryData(
      label: 'Vibration Y',
      value: '0.03',
      color: Colors.deepPurple.shade300,
      unit: 'm/s²',
    ),
    TelemetryData(
      label: 'Vibration Z',
      value: '0.08',
      color: Colors.brown.shade300,
      unit: 'm/s²',
    ),
    TelemetryData(
      label: 'Accelerometer X',
      value: '0.12',
      color: Colors.orange.shade600,
      unit: 'm/s²',
    ),
    TelemetryData(
      label: 'Accelerometer Y',
      value: '-0.08',
      color: Colors.red.shade400,
      unit: 'm/s²',
    ),
    TelemetryData(
      label: 'Accelerometer Z',
      value: '9.81',
      color: Colors.blue.shade400,
      unit: 'm/s²',
    ),

    // Environmental
    TelemetryData(
      label: 'Wind Speed',
      value: '5.2',
      color: Colors.blueGrey.shade300,
      unit: 'm/s',
    ),
    TelemetryData(
      label: 'Wind Direction',
      value: '45',
      color: Colors.grey.shade300,
      unit: 'deg',
    ),
    TelemetryData(
      label: 'Temperature',
      value: '25.3',
      color: Colors.red.shade200,
      unit: '°C',
    ),
    TelemetryData(
      label: 'Humidity',
      value: '65',
      color: Colors.blue.shade200,
      unit: '%',
    ),
    TelemetryData(
      label: 'Pressure',
      value: '1013.2',
      color: Colors.purple.shade200,
      unit: 'hPa',
    ),
    TelemetryData(
      label: 'Air Density',
      value: '1.225',
      color: Colors.cyan.shade400,
      unit: 'kg/m³',
    ),

    // Motors & Performance
    TelemetryData(
      label: 'Motor RPM 1',
      value: '1500',
      color: Colors.orange.shade400,
      unit: 'rpm',
    ),
    TelemetryData(
      label: 'Motor RPM 2',
      value: '1520',
      color: Colors.orange.shade500,
      unit: 'rpm',
    ),
    TelemetryData(
      label: 'Motor RPM 3',
      value: '1480',
      color: Colors.orange.shade600,
      unit: 'rpm',
    ),
    TelemetryData(
      label: 'Motor RPM 4',
      value: '1510',
      color: Colors.orange.shade700,
      unit: 'rpm',
    ),
    TelemetryData(
      label: 'Throttle %',
      value: '45',
      color: Colors.red.shade500,
      unit: '%',
    ),
    TelemetryData(
      label: 'ESC Temperature',
      value: '42',
      color: Colors.deepOrange.shade400,
      unit: '°C',
    ),

    // Flight Performance
    TelemetryData(
      label: 'Climb Rate',
      value: '2.1',
      color: Colors.green.shade600,
      unit: 'm/s',
    ),
    TelemetryData(
      label: 'Air Speed',
      value: '12.5',
      color: Colors.blue.shade600,
      unit: 'm/s',
    ),
    TelemetryData(
      label: 'Flight Time',
      value: '15:42',
      color: Colors.purple.shade500,
      unit: '',
    ),
    TelemetryData(
      label: 'Max Altitude',
      value: '120',
      color: Colors.indigo.shade400,
      unit: 'm',
    ),
    TelemetryData(
      label: 'Total Distance',
      value: '2.3',
      color: Colors.teal.shade500,
      unit: 'km',
    ),
  ];

  static List<TelemetryData> getDefaultTelemetry() {
    return allTelemetryData.take(9).toList();
  }
}
