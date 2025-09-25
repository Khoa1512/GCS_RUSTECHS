import 'package:flutter/material.dart';
import 'package:skylink/data/models/route_point_model.dart';

class MissionSummaryPanel extends StatelessWidget {
  final List<RoutePoint> waypoints;
  final double? totalDistance;
  final Duration? estimatedTime;
  final double? batteryUsage;
  final String riskLevel;

  const MissionSummaryPanel({
    super.key,
    required this.waypoints,
    this.totalDistance,
    this.estimatedTime,
    this.batteryUsage,
    this.riskLevel = 'Low',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.teal.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.flight_takeoff, color: Colors.teal, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Mission Summary',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _buildRiskBadge(),
            ],
          ),

          const SizedBox(height: 16),

          // Stats Grid
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Waypoints',
                  waypoints.length.toString(),
                  Icons.place,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard(
                  'Distance',
                  totalDistance != null
                      ? '${(totalDistance! / 1000).toStringAsFixed(1)}km'
                      : 'N/A',
                  Icons.straighten,
                  Colors.green,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'ETA',
                  estimatedTime != null
                      ? '${estimatedTime!.inMinutes}m ${estimatedTime!.inSeconds % 60}s'
                      : 'N/A',
                  Icons.schedule,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard(
                  'Battery',
                  batteryUsage != null
                      ? '${batteryUsage!.toStringAsFixed(0)}%'
                      : 'N/A',
                  Icons.battery_std,
                  _getBatteryColor(),
                ),
              ),
            ],
          ),

          if (batteryUsage != null) ...[
            const SizedBox(height: 12),
            _buildBatteryProgressBar(),
          ],
        ],
      ),
    );
  }

  Widget _buildRiskBadge() {
    Color color;
    switch (riskLevel.toLowerCase()) {
      case 'high':
        color = Colors.red;
        break;
      case 'medium':
        color = Colors.orange;
        break;
      default:
        color = Colors.green;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        riskLevel.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBatteryProgressBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Battery Usage',
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Container(
          height: 8,
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(4),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: (batteryUsage ?? 0) / 100,
            child: Container(
              decoration: BoxDecoration(
                color: _getBatteryColor(),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Color _getBatteryColor() {
    if (batteryUsage == null) return Colors.grey;
    if (batteryUsage! > 80) return Colors.red;
    if (batteryUsage! > 50) return Colors.orange;
    return Colors.green;
  }

  IconData _getRiskIcon() {
    switch (riskLevel.toLowerCase()) {
      case 'low':
        return Icons.check_circle_outline;
      case 'medium':
        return Icons.warning_amber_outlined;
      case 'high':
        return Icons.error_outline;
      default:
        return Icons.help_outline;
    }
  }
}
