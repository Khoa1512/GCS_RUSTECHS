import 'package:flutter/material.dart';

class DroneInfoPanel extends StatelessWidget {
  final Map<String, bool> connectionStates;
  final Map<String, Map<String, dynamic>> telemetryData;

  const DroneInfoPanel({
    super.key,
    required this.connectionStates,
    required this.telemetryData,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(color: Color(0xFF2A2A2A)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          Expanded(child: _buildDroneList()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final connectedCount = connectionStates.values
        .where((connected) => connected)
        .length;
    final totalCount = connectionStates.length;

    return Row(
      children: [
        const Icon(Icons.info_outline, color: Colors.teal, size: 20),
        const SizedBox(width: 8),
        const Text(
          'Drone Status',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: connectedCount > 0
                ? Colors.green.shade800
                : Colors.grey.shade700,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$connectedCount/$totalCount',
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

  Widget _buildDroneList() {
    if (connectionStates.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.flight, color: Colors.grey.shade600, size: 48),
            const SizedBox(height: 16),
            Text(
              'No Drones Added',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add drones using the control panel above',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: connectionStates.length,
      itemBuilder: (context, index) {
        final droneId = connectionStates.keys.elementAt(index);
        return _buildDroneCard(droneId);
      },
    );
  }

  Widget _buildDroneCard(String droneId) {
    final isConnected = connectionStates[droneId] ?? false;
    final telemetry = telemetryData[droneId] ?? {};
    final droneNumber = droneId.replaceAll('drone_', '');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isConnected ? Colors.green : Colors.grey.shade700,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDroneHeader(droneNumber, isConnected),
          const SizedBox(height: 8),
          if (isConnected) _buildTelemetryData(telemetry),
          if (!isConnected) _buildDisconnectedState(),
        ],
      ),
    );
  }

  Widget _buildDroneHeader(String droneNumber, bool isConnected) {
    return Row(
      children: [
        Icon(
          Icons.memory,
          color: isConnected ? Colors.green : Colors.grey,
          size: 16,
        ),
        const SizedBox(width: 8),
        Text(
          'Drone $droneNumber',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: isConnected ? Colors.green.shade800 : Colors.red.shade800,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            isConnected ? 'ONLINE' : 'OFFLINE',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTelemetryData(Map<String, dynamic> data) {
    return Column(
      children: [
        _buildTelemetryRow([
          _buildTelemetryItem(
            'BAT',
            '${(data['battery'] ?? 0.0).toStringAsFixed(1)}%',
          ),
          _buildTelemetryItem(
            'ALT',
            '${(data['gps_altitude'] ?? 0.0).toStringAsFixed(1)}m',
          ),
          _buildTelemetryItem(
            'SPD',
            '${(data['groundspeed'] ?? 0.0).toStringAsFixed(1)}',
          ),
        ]),
        const SizedBox(height: 8),
        _buildTelemetryRow([
          _buildTelemetryItem(
            'YAW',
            '${(data['yaw'] ?? 0.0).toStringAsFixed(0)}°',
          ),
          _buildTelemetryItem(
            'ROLL',
            '${(data['roll'] ?? 0.0).toStringAsFixed(0)}°',
          ),
          _buildTelemetryItem(
            'PITCH',
            '${(data['pitch'] ?? 0.0).toStringAsFixed(0)}°',
          ),
        ]),
        const SizedBox(height: 8),
        _buildStatusRow(data),
      ],
    );
  }

  Widget _buildTelemetryRow(List<Widget> items) {
    return Row(
      children: items
          .expand((item) => [item, const SizedBox(width: 8)])
          .take(items.length * 2 - 1)
          .toList(),
    );
  }

  Widget _buildTelemetryItem(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey.shade800,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.grey.shade600, width: 0.5),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 9,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(Map<String, dynamic> data) {
    final isArmed = data['armed'] == 1.0;

    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isArmed ? Colors.red.shade800 : Colors.green.shade800,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              isArmed ? 'ARMED' : 'DISARMED',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDisconnectedState() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade800,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey.shade600, width: 0.5),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber, color: Colors.orange.shade400, size: 16),
          const SizedBox(width: 8),
          Text(
            'No telemetry data available',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
