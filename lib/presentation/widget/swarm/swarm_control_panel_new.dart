import 'dart:async';
import 'package:flutter/material.dart';
import 'package:skylink/services/multi_drone_service.dart';

class SwarmControlPanel extends StatefulWidget {
  const SwarmControlPanel({super.key});

  @override
  State<SwarmControlPanel> createState() => _SwarmControlPanelState();
}

class _SwarmControlPanelState extends State<SwarmControlPanel> {
  final MultiDroneService _multiDroneService = MultiDroneService();

  Map<String, bool> _connectionStates = {};
  Map<String, Map<String, dynamic>> _telemetryData = {};

  StreamSubscription? _connectionSubscription;
  StreamSubscription? _telemetrySubscription;

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
        });
      }
    });

    _telemetrySubscription = _multiDroneService.telemetryDataStream.listen((
      data,
    ) {
      if (mounted) {
        setState(() {
          _telemetryData = data;
        });
      }
    });
  }

  @override
  void dispose() {
    _connectionSubscription?.cancel();
    _telemetrySubscription?.cancel();
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
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: droneCount > 0 ? Colors.green : Colors.grey,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$droneCount',
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
              'Use connection button in app bar to connect drones',
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

        return _buildDroneCard(droneId, telemetryData, index + 1);
      },
    );
  }

  Widget _buildDroneCard(
    String droneId,
    Map<String, dynamic> telemetryData,
    int droneNumber,
  ) {
    // Get telemetry values with defaults
    final battery = telemetryData['battery']?.toDouble() ?? 0.0;
    final voltage = telemetryData['voltage']?.toDouble() ?? 0.0;
    final armed = telemetryData['armed']?.toInt() == 1;
    final altitude = telemetryData['gps_altitude']?.toDouble() ?? 0.0;
    final speed = telemetryData['groundspeed']?.toDouble() ?? 0.0;
    final mode = telemetryData['mode']?.toString() ?? 'UNKNOWN';

    // Determine status color based on mode
    Color statusColor = Colors.grey;
    String statusText = mode;

    if (armed) {
      if (mode.contains('MANUAL')) {
        statusColor = Colors.green;
        statusText = 'SWARM_MANUAL';
      } else if (mode.contains('AUTO') || mode.contains('GUIDED')) {
        statusColor = Colors.blue;
        statusText = 'SWARM_GUIDED';
      } else {
        statusColor = Colors.orange;
        statusText = 'SWARM_$mode';
      }
    } else {
      statusColor = Colors.purple;
      statusText = 'SWARM_MANUAL';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor, width: 2),
      ),
      child: Column(
        children: [
          // Header Row
          Row(
            children: [
              // Drone Number
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Center(
                  child: Text(
                    '$droneNumber',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Status
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      armed ? 'Armed' : 'TakeOff',
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ],
                ),
              ),

              // Battery and Voltage
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'VOL ${voltage.toStringAsFixed(2)}V',
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                  ),
                  Text(
                    'ASL ${altitude.toStringAsFixed(1)}m',
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                  ),
                  Text(
                    'ALT ${altitude.toStringAsFixed(1)}m',
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                  ),
                  Text(
                    'SPD ${speed.toStringAsFixed(1)}m/s',
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ],
              ),

              // Status Icons
              Column(
                children: [
                  if (battery > 70)
                    Icon(Icons.battery_full, color: Colors.green, size: 16)
                  else if (battery > 30)
                    Icon(Icons.battery_3_bar, color: Colors.orange, size: 16)
                  else
                    Icon(Icons.battery_1_bar, color: Colors.red, size: 16),

                  if (armed)
                    Icon(Icons.lock_open, color: Colors.red, size: 12)
                  else
                    Icon(Icons.lock, color: Colors.green, size: 12),
                ],
              ),
            ],
          ),

          // Signal Status Bar
          const SizedBox(height: 4),
          Container(
            height: 2,
            width: double.infinity,
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ],
      ),
    );
  }
}
