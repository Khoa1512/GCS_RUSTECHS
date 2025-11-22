import 'package:flutter/material.dart';
import 'package:skylink/data/models/route_point_model.dart';

class WaypointTooltip extends StatelessWidget {
  final RoutePoint waypoint;
  final Offset position;
  final bool isVisible;

  const WaypointTooltip({
    super.key,
    required this.waypoint,
    required this.position,
    required this.isVisible,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 280,
        constraints: const BoxConstraints(maxHeight: 200, maxWidth: 280),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.teal.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.teal,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      waypoint.order.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Waypoint ${waypoint.order}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Command Type
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.settings_applications,
                  color: Colors.white60,
                  size: 14,
                ),
                const SizedBox(width: 6),
                Text(
                  _getCommandName(waypoint.command),
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),

            const SizedBox(height: 4),

            // Altitude
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.height, color: Colors.white60, size: 14),
                const SizedBox(width: 6),
                Text(
                  '${waypoint.altitude}m',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),

            // Position
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.location_on, color: Colors.white60, size: 14),
                const SizedBox(width: 6),
                Text(
                  '${double.parse(waypoint.latitude).toStringAsFixed(6)}, ${double.parse(waypoint.longitude).toStringAsFixed(6)}',
                  style: const TextStyle(color: Colors.white60, fontSize: 10),
                ),
              ],
            ),

            // Advanced parameters if available
            if (waypoint.commandParams != null &&
                waypoint.commandParams!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                height: 1,
                color: Colors.white10,
              ),
              const SizedBox(height: 6),
              ..._buildAdvancedParams(),
            ],
          ],
        ),
      ),
    );
  }

  String _getCommandName(int command) {
    switch (command) {
      case 16:
        return 'Waypoint';
      case 19:
        return 'Loiter Time';
      case 20:
        return 'Return to Launch';
      case 21:
        return 'Land';
      case 22:
        return 'Takeoff';
      case 82:
        return 'Spline Waypoint';
      case 178:
        return 'Change Speed';
      case 183:
        return 'Set Servo';
      case 184:
        return 'Repeat Servo';
      case 201:
        return 'Set ROI';
      default:
        return 'Command $command';
    }
  }

  List<Widget> _buildAdvancedParams() {
    final params = waypoint.commandParams ?? {};
    final widgets = <Widget>[];

    // Show only non-zero parameters to keep tooltip clean
    final relevantParams = <String, dynamic>{};

    switch (waypoint.command) {
      case 16: // Waypoint
        if (params['param1'] != null && params['param1'] != 0.0) {
          relevantParams['Hold Time'] = '${params['param1']}s';
        }
        if (params['param2'] != null && params['param2'] != 0.0) {
          relevantParams['Accept Radius'] = '${params['param2']}m';
        }
        if (params['param4'] != null && params['param4'] != 0.0) {
          relevantParams['Yaw'] = '${params['param4']}°';
        }
        break;
      case 19: // Loiter Time
        if (params['param1'] != null && params['param1'] != 0.0) {
          relevantParams['Loiter Time'] = '${params['param1']}s';
        }
        if (params['param3'] != null && params['param3'] != 0.0) {
          relevantParams['Radius'] = '${params['param3']}m';
        }
        break;
      case 21: // Land
        if (params['param1'] != null && params['param1'] != 0.0) {
          relevantParams['Abort Alt'] = '${params['param1']}m';
        }
        if (params['param4'] != null && params['param4'] != 0.0) {
          relevantParams['Yaw'] = '${params['param4']}°';
        }
        break;
      case 183: // Set Servo
        if (params['param1'] != null && params['param1'] != 0.0) {
          relevantParams['Servo #'] = params['param1'].toInt().toString();
        }
        if (params['param2'] != null && params['param2'] != 0.0) {
          relevantParams['PWM'] = '${params['param2'].toInt()}us';
        }
        break;
      case 184: // Repeat Servo
        if (params['param1'] != null && params['param1'] != 0.0) {
          relevantParams['Servo #'] = params['param1'].toInt().toString();
        }
        if (params['param2'] != null && params['param2'] != 0.0) {
          relevantParams['PWM'] = '${params['param2'].toInt()}us';
        }
        if (params['param3'] != null && params['param3'] != 0.0) {
          relevantParams['Count'] = params['param3'].toInt().toString();
        }
        if (params['param4'] != null && params['param4'] != 0.0) {
          relevantParams['Cycle Time'] = '${params['param4']}s';
        }
        break;
    }

    for (final entry in relevantParams.entries) {
      widgets.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '• ${entry.key}:',
              style: const TextStyle(color: Colors.white38, fontSize: 10),
            ),
            const SizedBox(width: 4),
            Text(
              entry.value.toString(),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return widgets;
  }
}
