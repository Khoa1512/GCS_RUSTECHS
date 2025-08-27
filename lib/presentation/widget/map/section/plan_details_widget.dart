import 'package:flutter/material.dart';
import 'package:skylink/data/models/mission_plan_model.dart';

class PlanDetailsWidget extends StatelessWidget {
  final UserMissionPlan? plan;

  const PlanDetailsWidget({super.key, this.plan});

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(2)} km';
    } else {
      return '${meters.toStringAsFixed(1)} m';
    }
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: Colors.teal, size: 16),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 11),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (plan == null) {
      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          border: Border(
            top: BorderSide(color: Colors.grey.shade800, width: 1),
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.info_outline, color: Colors.grey, size: 32),
              SizedBox(height: 8),
              Text(
                'Select a plan to view details',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    final altStats = plan!.altitudeStats;
    final bounds = plan!.missionBounds;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        border: Border(top: BorderSide(color: Colors.grey.shade800, width: 1)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF2D2D2D),
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade800, width: 1),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.info, color: Colors.teal, size: 18),
                const SizedBox(width: 8),
                const Text(
                  'Plan Details',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: plan!.waypointCount > 0
                        ? Colors.green.withOpacity(0.2)
                        : Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    plan!.waypointCount > 0 ? 'Ready' : 'Empty',
                    style: TextStyle(
                      color: plan!.waypointCount > 0
                          ? Colors.green
                          : Colors.orange,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Plan Basic Info
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2D2D2D),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade800, width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plan!.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (plan!.description.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            plan!.description,
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 11,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          'Created: ${plan!.createdAt.day}/${plan!.createdAt.month}/${plan!.createdAt.year}',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Mission Statistics
                  const Text(
                    'Mission Statistics',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2D2D2D),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade800, width: 1),
                    ),
                    child: Column(
                      children: [
                        _buildInfoRow(
                          'Waypoints',
                          '${plan!.waypointCount}',
                          Icons.place,
                        ),
                        _buildInfoRow(
                          'Total Distance',
                          _formatDistance(plan!.totalDistance),
                          Icons.straighten,
                        ),
                        _buildInfoRow(
                          'Est. Flight Time',
                          _formatDuration(plan!.estimatedFlightTime),
                          Icons.access_time,
                        ),
                        if (plan!.waypointCount > 0) ...[
                          _buildInfoRow(
                            'Min Altitude',
                            '${altStats['min']!.toStringAsFixed(1)} m',
                            Icons.expand_more,
                          ),
                          _buildInfoRow(
                            'Max Altitude',
                            '${altStats['max']!.toStringAsFixed(1)} m',
                            Icons.expand_less,
                          ),
                          _buildInfoRow(
                            'Avg Altitude',
                            '${altStats['avg']!.toStringAsFixed(1)} m',
                            Icons.height,
                          ),
                        ],
                      ],
                    ),
                  ),

                  if (bounds != null) ...[
                    const SizedBox(height: 16),

                    // Mission Area
                    const Text(
                      'Mission Area',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2D2D2D),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.grey.shade800,
                          width: 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          _buildInfoRow(
                            'North Bound',
                            '${bounds['north']!.toStringAsFixed(6)}°',
                            Icons.keyboard_arrow_up,
                          ),
                          _buildInfoRow(
                            'South Bound',
                            '${bounds['south']!.toStringAsFixed(6)}°',
                            Icons.keyboard_arrow_down,
                          ),
                          _buildInfoRow(
                            'East Bound',
                            '${bounds['east']!.toStringAsFixed(6)}°',
                            Icons.keyboard_arrow_right,
                          ),
                          _buildInfoRow(
                            'West Bound',
                            '${bounds['west']!.toStringAsFixed(6)}°',
                            Icons.keyboard_arrow_left,
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Performance Estimates
                  const Text(
                    'Performance Estimates',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2D2D2D),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade800, width: 1),
                    ),
                    child: Column(
                      children: [
                        _buildInfoRow(
                          'Battery Usage',
                          '~${(plan!.estimatedFlightTime.inMinutes * 2.5).toStringAsFixed(0)}%',
                          Icons.battery_std,
                        ),
                        _buildInfoRow('Avg Speed', '15.0 m/s', Icons.speed),
                        _buildInfoRow(
                          'Risk Level',
                          plan!.waypointCount > 10 ? 'Medium' : 'Low',
                          Icons.warning_amber,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
