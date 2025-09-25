import 'package:flutter/material.dart';
import 'package:skylink/data/models/route_point_model.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:skylink/api/telemetry/mavlink/mission/mission_models.dart';
import 'package:flutter/foundation.dart';

class MissionSidebar extends StatefulWidget {
  final List<RoutePoint> routePoints;
  final double? totalDistance;
  final Duration? estimatedTime;
  final double? batteryUsage;
  final String riskLevel;
  final VoidCallback onReadMission;
  final VoidCallback? onSendMission;
  final Function(List<RoutePoint>) onImportMission;
  final bool isConnected;

  const MissionSidebar({
    super.key,
    required this.routePoints,
    this.totalDistance,
    this.estimatedTime,
    this.batteryUsage,
    required this.riskLevel,
    required this.onReadMission,
    this.onSendMission,
    required this.onImportMission,
    required this.isConnected,
  });

  @override
  State<MissionSidebar> createState() => _MissionSidebarState();
}

class _MissionSidebarState extends State<MissionSidebar> {
  // Convert RoutePoint to PlanMissionItem
  PlanMissionItem _routePointToMissionItem(RoutePoint routePoint) {
    return PlanMissionItem(
      seq: routePoint.order - 1, // Convert to 0-based
      command: routePoint.command,
      frame: 3, // MAV_FRAME_GLOBAL_RELATIVE_ALT
      param1: routePoint.commandParams?['param1'] ?? 0,
      param2: routePoint.commandParams?['param2'] ?? 0,
      param3: routePoint.commandParams?['param3'] ?? 0,
      param4: routePoint.commandParams?['param4'] ?? 0,
      x: double.parse(routePoint.latitude),
      y: double.parse(routePoint.longitude),
      z: double.parse(routePoint.altitude),
    );
  }

  Future<void> _handleImportMission() async {
    try {
      print('DEBUG: Starting import mission...');
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['plan', 'waypoints'],
        dialogTitle: 'Select Mission File',
      );

      print('DEBUG: File picker result: $result');
      if (result != null && result.files.single.path != null) {
        print('DEBUG: Selected file: ${result.files.single.path}');
        final file = File(result.files.single.path!);
        final content = await file.readAsString();
        final extension = result.files.single.extension?.toLowerCase();

        MissionPlan missionPlan;

        if (extension == 'plan') {
          // QGroundControl .plan format
          missionPlan = MissionPlan.fromQgcPlanJson(content);
        } else if (extension == 'waypoints') {
          // ArduPilot .waypoints format
          missionPlan = MissionPlan.fromArduPilotWaypoints(content);
        } else {
          _showSnackbar('Unsupported file format', isError: true);
          return;
        }

        // Convert PlanMissionItem to RoutePoint
        final routePoints = missionPlan.items
            .map((item) => _missionItemToRoutePoint(item))
            .toList();

        // Call the callback to update the mission
        widget.onImportMission(routePoints);

        _showSnackbar(
          'Mission imported successfully (${routePoints.length} waypoints)',
        );
      }
    } catch (e) {
      _showSnackbar('Import failed: $e', isError: true);
    }
  }

  void _showSnackbar(String message, {bool isError = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // Convert PlanMissionItem to RoutePoint
  RoutePoint _missionItemToRoutePoint(PlanMissionItem item) {
    return RoutePoint(
      id: 'imported_${item.seq}',
      order: item.seq + 1, // Convert to 1-based
      latitude: item.x.toString(),
      longitude: item.y.toString(),
      altitude: item.z.toString(),
      command: item.command,
      commandParams: {
        'param1': item.param1,
        'param2': item.param2,
        'param3': item.param3,
        'param4': item.param4,
      },
    );
  }

  // Handle export mission
  Future<void> _handleExportMission() async {
    if (widget.routePoints.isEmpty) {
      _showSnackbar('No mission to export', isError: true);
      return;
    }

    try {
      // Convert RoutePoint to PlanMissionItem
      final planItems = widget.routePoints.map((rp) {
        return PlanMissionItem(
          seq: rp.order - 1, // Convert to 0-based
          command: rp.command,
          frame: 3, // MAV_FRAME_GLOBAL_RELATIVE_ALT
          param1: rp.commandParams?['param1'] ?? 0,
          param2: rp.commandParams?['param2'] ?? 0,
          param3: rp.commandParams?['param3'] ?? 0,
          param4: rp.commandParams?['param4'] ?? 0,
          x: double.parse(rp.latitude),
          y: double.parse(rp.longitude),
          z: double.parse(rp.altitude),
        );
      }).toList();

      final mission = MissionPlan(items: planItems);

      // Create filename with timestamp
      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')[0];
      final filename = 'mission_$timestamp';

      // Let user choose save location
      String? outputFile;

      if (Platform.isMacOS) {
        // For macOS, try using getDownloadsDirectory as fallback
        try {
          outputFile = await FilePicker.platform.saveFile(
            dialogTitle: 'Save Mission File',
            fileName: filename,
            type: FileType.custom,
            allowedExtensions: ['plan'],
          );
        } catch (e) {
          // Fallback to Documents directory
          final documentsDir = await getApplicationDocumentsDirectory();
          outputFile = '${documentsDir.path}/$filename';
        }
      } else {
        outputFile = await FilePicker.platform.saveFile(
          dialogTitle: 'Save Mission File',
          fileName: filename,
          type: FileType.custom,
          allowedExtensions: ['plan'],
        );
      }

      if (outputFile == null) {
        return;
      }

      // Write file
      final file = File(outputFile);
      await file.writeAsString(mission.toQgcPlanJson());

      _showSnackbar('Mission exported to: $outputFile');
    } catch (e) {
      _showSnackbar('Export failed: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1A1A1A),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.teal.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.flight_takeoff, color: Colors.teal, size: 24),
                const SizedBox(width: 12),
                Text(
                  'Mission Control',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Mission Summary
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.teal.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Summary Header
                  Row(
                    children: [
                      Icon(Icons.assignment, color: Colors.teal, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Mission Summary',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getRiskColor(),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          widget.riskLevel.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Stats Grid
                  Expanded(
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                icon: Icons.location_on,
                                label: 'Waypoints',
                                value: '${routePoints.length}',
                                color: Colors.blue,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildStatCard(
                                icon: Icons.straighten,
                                label: 'Distance',
                                value: widget.totalDistance != null
                                    ? '${(widget.totalDistance! / 1000).toStringAsFixed(1)}km'
                                    : 'N/A',
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                icon: Icons.schedule,
                                label: 'ETA',
                                value: widget.estimatedTime != null
                                    ? '${widget.estimatedTime!.inMinutes}m ${widget.estimatedTime!.inSeconds % 60}s'
                                    : 'N/A',
                                color: Colors.orange,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildStatCard(
                                icon: Icons.battery_std,
                                label: 'Battery',
                                value: widget.batteryUsage != null
                                    ? '${widget.batteryUsage!.toStringAsFixed(0)}%'
                                    : 'N/A',
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Waypoint List
                        if (routePoints.isNotEmpty) ...[
                          Text(
                            'Waypoint List',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: ListView.builder(
                              itemCount: routePoints.length,
                              itemBuilder: (context, index) {
                                final wp = routePoints[index];
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 4),
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.black12,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 20,
                                        height: 20,
                                        decoration: BoxDecoration(
                                          color: Colors.teal,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            '${wp.order}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _getCommandName(wp.command),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            Text(
                                              '${wp.altitude}m',
                                              style: const TextStyle(
                                                color: Colors.white60,
                                                fontSize: 10,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Action Buttons
          Column(
            children: [
              // Flight Controller Section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Flight Controller',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: widget.onReadMission,
                            icon: const Icon(Icons.download, size: 16),
                            label: const Text(
                              'Read',
                              style: TextStyle(fontSize: 12),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: widget.onSendMission,
                            icon: const Icon(Icons.send, size: 16),
                            label: const Text(
                              'Send',
                              style: TextStyle(fontSize: 12),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: widget.onSendMission != null
                                  ? Colors.green
                                  : Colors.grey,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // File Operations
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'File Operations',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _handleImportMission,
                            icon: const Icon(Icons.file_open, size: 16),
                            label: const Text(
                              'Import',
                              style: TextStyle(fontSize: 12),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _handleExportMission,
                            icon: const Icon(Icons.save_alt, size: 16),
                            label: const Text(
                              'Export',
                              style: TextStyle(fontSize: 12),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: widget.routePoints.isNotEmpty
                                  ? Colors.purple
                                  : Colors.grey,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(label, style: TextStyle(color: Colors.white60, fontSize: 10)),
        ],
      ),
    );
  }

  Color _getRiskColor() {
    switch (widget.riskLevel.toLowerCase()) {
      case 'low':
        return Colors.green;
      case 'medium':
        return Colors.orange;
      case 'high':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getCommandName(int command) {
    switch (command) {
      case 16:
        return 'Waypoint';
      case 19:
        return 'Loiter Time';
      case 20:
        return 'RTL';
      case 21:
        return 'Land';
      case 201:
        return 'Do Set ROI';
      default:
        return 'Command $command';
    }
  }
}
