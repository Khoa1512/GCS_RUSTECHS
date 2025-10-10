import 'dart:async';
import 'package:flutter/material.dart';
import 'package:skylink/services/multi_drone_service.dart';
import 'package:skylink/services/telemetry_service.dart';
import 'package:skylink/presentation/widget/swarm/drone_detail_dialog.dart';

class SwarmControlPanel extends StatefulWidget {
  const SwarmControlPanel({super.key});

  @override
  State<SwarmControlPanel> createState() => _SwarmControlPanelState();
}

class _SwarmControlPanelState extends State<SwarmControlPanel> {
  final MultiDroneService _multiDroneService = MultiDroneService();
  final TelemetryService _telemetryService = TelemetryService();
  Map<String, bool> _connectionStates = {};
  Map<String, Map<String, dynamic>> _telemetryData = {};
  StreamSubscription? _connectionSubscription;
  StreamSubscription? _telemetrySubscription;
  StreamSubscription? _primaryDroneSubscription;

  @override
  void initState() {
    super.initState();
    _setupListeners();
  }

  void _setupListeners() {
    _connectionSubscription = _multiDroneService.connectionStateStream.listen((
      states,
    ) {
      if (mounted) {
        setState(() {
          _connectionStates = states;

          // Add primary drone if connected
          if (_telemetryService.isConnected) {
            _connectionStates['PRIMARY'] = true;
          }
        });
      }
    });

    _telemetrySubscription = _multiDroneService.telemetryDataStream.listen((
      data,
    ) {
      if (mounted) {
        setState(() {
          _telemetryData = data;
          // MultiDroneService now handles PRIMARY drone automatically
          // No need to manually add it here
        });
      }
    });

    // Primary drone is now handled automatically by MultiDroneService
    // No need for separate subscription
    //
    // _primaryDroneSubscription = _telemetryService.connectionStream.listen((isConnected) {
    //   // This logic is now handled in MultiDroneService.addPrimaryDroneFromTelemetryService()
    // });
  }

  @override
  void dispose() {
    _connectionSubscription?.cancel();
    _telemetrySubscription?.cancel();
    _primaryDroneSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connectedDrones = _connectionStates.entries
        .where((entry) => entry.value)
        .toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade800, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(connectedDrones.length),
          const SizedBox(height: 16),
          Expanded(child: _buildDroneList(connectedDrones)),
        ],
      ),
    );
  }

  Widget _buildHeader(int droneCount) {
    return Row(
      children: [
        Icon(Icons.group_work, color: Colors.teal, size: 20),
        const SizedBox(width: 8),
        Text(
          'Swarm Status',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: droneCount > 0 ? Colors.green : Colors.grey,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$droneCount Connected',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDroneList(List<MapEntry<String, bool>> connectedDrones) {
    if (connectedDrones.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.flight_takeoff, size: 48, color: Colors.grey.shade600),
            const SizedBox(height: 16),
            Text(
              'No Drones Connected',
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Use connection dialog to connect via MultiDroneService',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: connectedDrones.length,
      itemBuilder: (context, index) {
        final droneEntry = connectedDrones[index];
        final droneId = droneEntry.key;
        final telemetryData = _telemetryData[droneId] ?? {};
        return _buildDroneCard(droneId, telemetryData);
      },
    );
  }

  Widget _buildDroneCard(String droneId, Map<String, dynamic> telemetryData) {
    // Safe value extraction for attitude data
    double roll = 0.0;
    double pitch = 0.0;
    double yaw = 0.0;

    try {
      roll = double.tryParse(telemetryData['roll']?.toString() ?? '0') ?? 0.0;
      pitch = double.tryParse(telemetryData['pitch']?.toString() ?? '0') ?? 0.0;
      yaw = double.tryParse(telemetryData['yaw']?.toString() ?? '0') ?? 0.0;

      // Convert radians to degrees if needed
      roll = _radiansToDegrees(roll);
      pitch = _radiansToDegrees(pitch);
      yaw = _radiansToDegrees(yaw);
    } catch (e) {
      print('SwarmControlPanel: Error parsing attitude for $droneId: $e');
    }

    // Get drone-specific colors
    final colors = _getDroneColors(droneId);

    return GestureDetector(
      onTap: () => _showDroneDetails(droneId, telemetryData),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              colors['primary']!.withOpacity(0.8),
              colors['secondary']!.withOpacity(0.6),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors['accent']!, width: 2),
          boxShadow: [
            BoxShadow(
              color: colors['primary']!.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colors['accent']!.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: colors['accent']!, width: 1),
                    ),
                    child: Icon(
                      Icons.flight,
                      size: 18,
                      color: colors['accent']!,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          droneId.toUpperCase(),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        Text(
                          _getDroneSubtitle(droneId),
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withOpacity(0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.wifi, color: Colors.white, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          'LIVE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Column(
                children: [
                  _buildValueRow(
                    'Roll',
                    '${roll.toStringAsFixed(1)}°',
                    colors['accent']!,
                  ),
                  _buildValueRow(
                    'Pitch',
                    '${pitch.toStringAsFixed(1)}°',
                    colors['accent']!,
                  ),
                  _buildValueRow(
                    'Yaw',
                    '${yaw.toStringAsFixed(1)}°',
                    colors['accent']!,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDroneDetails(String droneId, Map<String, dynamic> telemetryData) {
    DroneDetailDialog.show(context, droneId, telemetryData);
  }

  /// Convert radians to degrees
  double _radiansToDegrees(double radians) {
    // Check if value is already in degrees (typically range -180 to 180 or 0 to 360)
    if (radians.abs() > 10) {
      return radians; // Already in degrees
    }
    return radians * 180.0 / 3.14159265359; // Convert from radians
  }

  /// Get drone-specific color scheme
  Map<String, Color> _getDroneColors(String droneId) {
    switch (droneId) {
      case 'PRIMARY':
        return {
          'primary': const Color(0xFF1E3A8A), // Deep blue
          'secondary': const Color(0xFF3B82F6), // Light blue
          'accent': const Color(0xFF60A5FA), // Accent blue
        };
      case 'DRONE_2':
        return {
          'primary': const Color(0xFF059669), // Deep green
          'secondary': const Color(0xFF10B981), // Light green
          'accent': const Color(0xFF34D399), // Accent green
        };
      case 'DRONE_3':
        return {
          'primary': const Color(0xFFDC2626), // Deep red
          'secondary': const Color(0xFFEF4444), // Light red
          'accent': const Color(0xFFF87171), // Accent red
        };
      case 'DRONE_4':
        return {
          'primary': const Color(0xFF7C2D92), // Deep purple
          'secondary': const Color(0xFF9333EA), // Light purple
          'accent': const Color(0xFFA855F7), // Accent purple
        };
      case 'DRONE_5':
        return {
          'primary': const Color(0xFFEA580C), // Deep orange
          'secondary': const Color(0xFFF97316), // Light orange
          'accent': const Color(0xFFFB923C), // Accent orange
        };
      default:
        return {
          'primary': const Color(0xFF374151), // Deep gray
          'secondary': const Color(0xFF6B7280), // Light gray
          'accent': const Color(0xFF9CA3AF), // Accent gray
        };
    }
  }

  /// Get drone subtitle text
  String _getDroneSubtitle(String droneId) {
    switch (droneId) {
      case 'PRIMARY':
        return 'Master Drone';
      case 'DRONE_2':
        return 'Wing Drone Alpha';
      case 'DRONE_3':
        return 'Wing Drone Beta';
      case 'DRONE_4':
        return 'Wing Drone Gamma';
      case 'DRONE_5':
        return 'Wing Drone Delta';
      default:
        return 'Additional Drone';
    }
  }

  Widget _buildValueRow(String label, String value, [Color? accentColor]) {
    final color = accentColor ?? Colors.white;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withOpacity(0.5), width: 1),
            ),
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
