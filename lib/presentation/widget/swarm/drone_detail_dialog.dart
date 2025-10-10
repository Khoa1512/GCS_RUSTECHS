import 'package:flutter/material.dart';
import 'dart:async';
import 'package:skylink/services/multi_drone_service.dart';
import 'package:skylink/services/telemetry_service.dart';

/// Detailed drone information dialog
class DroneDetailDialog extends StatefulWidget {
  final String droneId;
  final Map<String, dynamic> initialData;

  const DroneDetailDialog({
    super.key,
    required this.droneId,
    required this.initialData,
  });

  static Future<void> show(
    BuildContext context,
    String droneId,
    Map<String, dynamic> telemetryData,
  ) async {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) =>
          DroneDetailDialog(droneId: droneId, initialData: telemetryData),
    );
  }

  @override
  State<DroneDetailDialog> createState() => _DroneDetailDialogState();
}

class _DroneDetailDialogState extends State<DroneDetailDialog> {
  final MultiDroneService _multiDroneService = MultiDroneService();
  final TelemetryService _telemetryService = TelemetryService();

  late Map<String, dynamic> _currentData;
  StreamSubscription? _dataSubscription;

  @override
  void initState() {
    super.initState();
    _currentData = Map.from(widget.initialData);
    _startDataSubscription();
  }

  void _startDataSubscription() {
    _dataSubscription = _multiDroneService.telemetryDataStream.listen((
      allData,
    ) {
      if (mounted && allData.containsKey(widget.droneId)) {
        setState(() {
          _currentData = Map.from(allData[widget.droneId]!);
        });
      }
    });
  }

  @override
  void dispose() {
    _dataSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 500,
        height: 600,
        decoration: BoxDecoration(
          color: Colors.grey.shade900,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: widget.droneId == 'PRIMARY' ? Colors.blue : Colors.green,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            // Header
            _buildHeader(),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildFlightModeSection(),
                    const SizedBox(height: 16),
                    _buildAttitudeSection(),
                    const SizedBox(height: 16),
                    _buildPositionSection(),
                    const SizedBox(height: 16),
                    _buildSystemSection(),
                    const SizedBox(height: 16),
                    // _buildVelocitySection(),
                  ],
                ),
              ),
            ),

            // Footer
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final isConnected = _getConnectionStatus();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: widget.droneId == 'PRIMARY'
            ? Colors.blue.withOpacity(0.1)
            : Colors.green.withOpacity(0.1),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(18),
          topRight: Radius.circular(18),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.flight,
            color: widget.droneId == 'PRIMARY' ? Colors.blue : Colors.green,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.droneId,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  widget.droneId == 'PRIMARY'
                      ? 'Master Drone'
                      : 'Additional Drone',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildFlightModeSection() {
    return _buildSection(
      title: 'Flight Status',
      icon: Icons.flight_takeoff,
      color: Colors.blue,
      children: [
        _buildInfoRow('Mode', _getValue('flight_mode', 'Unknown').toString()),
        _buildInfoRow('Armed', _getArmedStatus()),
        _buildInfoRow(
          'GPS Fix',
          _getValue('gps_fix_type', 'No GPS').toString(),
        ),
        _buildInfoRow(
          'Satellites',
          '${_getValue('gps_satellites_visible', 0)}',
        ),
      ],
    );
  }

  Widget _buildAttitudeSection() {
    return _buildSection(
      title: 'Attitude & Orientation',
      icon: Icons.threed_rotation,
      color: Colors.orange,
      children: [
        _buildInfoRow('Roll', '${_getValue('roll', 0.0).toStringAsFixed(2)}°'),
        _buildInfoRow(
          'Pitch',
          '${_getValue('pitch', 0.0).toStringAsFixed(2)}°',
        ),
        _buildInfoRow('Yaw', '${_getValue('yaw', 0.0).toStringAsFixed(2)}°'),
        _buildInfoRow(
          'Heading',
          '${_getValue('heading', 0.0).toStringAsFixed(1)}°',
        ),
        _buildInfoRow(
          'Roll Rate',
          '${_getValue('rollspeed', 0.0).toStringAsFixed(2)} rad/s',
        ),
        _buildInfoRow(
          'Pitch Rate',
          '${_getValue('pitchspeed', 0.0).toStringAsFixed(2)} rad/s',
        ),
        _buildInfoRow(
          'Yaw Rate',
          '${_getValue('yawspeed', 0.0).toStringAsFixed(2)} rad/s',
        ),
      ],
    );
  }

  Widget _buildPositionSection() {
    return _buildSection(
      title: 'Position & Navigation',
      icon: Icons.location_on,
      color: Colors.green,
      children: [
        _buildInfoRow(
          'Latitude',
          '${_getValue('gps_latitude', 0.0).toStringAsFixed(7)}°',
        ),
        _buildInfoRow(
          'Longitude',
          '${_getValue('gps_longitude', 0.0).toStringAsFixed(7)}°',
        ),
        _buildInfoRow(
          'Altitude (MSL)',
          '${_getValue('gps_altitude', 0.0).toStringAsFixed(1)} m',
        ),
        _buildInfoRow(
          'Altitude (AGL)',
          '${_getValue('relative_alt', 0.0).toStringAsFixed(1)} m',
        ),
        _buildInfoRow(
          'Ground Speed',
          '${_getValue('groundspeed', 0.0).toStringAsFixed(1)} m/s',
        ),
        _buildInfoRow(
          'Climb Rate',
          '${_getValue('climb', 0.0).toStringAsFixed(1)} m/s',
        ),
        _buildInfoRow(
          'GPS HDOP',
          '${_getValue('eph', 0.0).toStringAsFixed(2)}',
        ),
        _buildInfoRow(
          'GPS VDOP',
          '${_getValue('epv', 0.0).toStringAsFixed(2)}',
        ),
      ],
    );
  }

  Widget _buildSystemSection() {
    return _buildSection(
      title: 'System Status',
      icon: Icons.settings,
      color: Colors.purple,
      children: [
        _buildInfoRow(
          'Battery',
          '${_getValue('battery', 0.0).toStringAsFixed(1)}%',
        ),
        _buildInfoRow(
          'Voltage',
          '${_getValue('voltageBattery', 0.0).toStringAsFixed(2)} V',
        ),
        _buildInfoRow(
          'Throttle',
          '${_getValue('throttle', 0.0).toStringAsFixed(1)}%',
        ),
        _buildInfoRow(
          'RC RSSI',
          '${_getValue('rssi', 0.0).toStringAsFixed(0)}',
        ),
        _buildInfoRow('Vehicle Type', _getVehicleType()),
        _buildInfoRow('Firmware', _getValue('autopilot', 'Unknown').toString()),
      ],
    );
  }

  // Widget _buildVelocitySection() {
  //   return _buildSection(
  //     title: 'Velocity & Motion',
  //     icon: Icons.speed,
  //     color: Colors.red,
  //     children: [
  //       _buildInfoRow('Vel X', '${_getValue('vx', 0.0).toStringAsFixed(2)} m/s'),
  //       _buildInfoRow('Vel Y', '${_getValue('vy', 0.0).toStringAsFixed(2)} m/s'),
  //       _buildInfoRow('Vel Z', '${_getValue('vz', 0.0).toStringAsFixed(2)} m/s'),
  //       _buildInfoRow('Airspeed', '${_getValue('airspeed', 0.0).toStringAsFixed(1)} m/s'),
  //     ],
  //   );
  // }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade800,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade800,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(18),
          bottomRight: Radius.circular(18),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.update, color: Colors.white70, size: 16),
          const SizedBox(width: 8),
          Text(
            'Real-time telemetry data',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const Spacer(),
          Text(
            'Last update: ${DateTime.now().toLocal().toString().substring(11, 19)}',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  bool _getConnectionStatus() {
    if (widget.droneId == 'PRIMARY') {
      return _telemetryService.isConnected;
    } else {
      // For other drones, check if we have recent telemetry data
      return _currentData.isNotEmpty;
    }
  }

  dynamic _getValue(String key, dynamic defaultValue) {
    return _currentData[key] ?? defaultValue;
  }

  String _getVehicleType() {
    final vehicleType = _getValue('type', 0);
    switch (vehicleType) {
      case 1:
        return 'Fixed Wing';
      case 2:
        return 'Quadrotor';
      case 3:
        return 'Coaxial';
      case 4:
        return 'Helicopter';
      case 13:
        return 'Hexarotor';
      case 14:
        return 'Octorotor';
      case 15:
        return 'Tricopter';
      case 21:
        return 'VTOL Duo Rotor';
      case 22:
        return 'VTOL Quad Rotor';
      case 23:
        return 'VTOL Tiltrotor';
      default:
        return 'Unknown ($vehicleType)';
    }
  }

  String _getArmedStatus() {
    final armed = _getValue('armed', 0);
    // Armed can be bool, int, or double
    if (armed is bool) {
      return armed ? 'YES' : 'NO';
    } else if (armed is num) {
      return armed > 0 ? 'YES' : 'NO';
    } else {
      return 'UNKNOWN';
    }
  }
}
