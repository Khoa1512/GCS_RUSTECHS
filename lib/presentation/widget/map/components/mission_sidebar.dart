import 'package:flutter/material.dart';
import 'package:skylink/data/models/route_point_model.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:skylink/api/telemetry/mavlink/mission/mission_models.dart';
import 'package:skylink/data/constants/mav_cmd_params.dart';

class MissionSidebar extends StatefulWidget {
  final List<RoutePoint> routePoints;
  final double? totalDistance;
  final Duration? estimatedTime;
  final double? batteryUsage;
  final String riskLevel;
  final VoidCallback onReadMission;
  final VoidCallback? onSendMission;
  final Function(List<RoutePoint>) onImportMission;
  final Function(List<RoutePoint>)? onReorderWaypoints;
  final Function(RoutePoint)? onEditWaypoint;
  final Function(String)? onDeleteWaypoint;
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
    this.onReorderWaypoints,
    this.onEditWaypoint,
    this.onDeleteWaypoint,
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

  // Convert PlanMissionItem to RoutePoint
  RoutePoint _missionItemToRoutePoint(PlanMissionItem item) {
    return RoutePoint(
      id: '${DateTime.now().millisecondsSinceEpoch}_${item.seq}',
      order: item.seq + 1, // Convert from 0-based
      latitude: item.x.toString(),
      longitude: item.y.toString(),
      altitude: item.z.toInt().toString(),
      command: item.command,
      commandParams: {
        'param1': item.param1,
        'param2': item.param2,
        'param3': item.param3,
        'param4': item.param4,
      },
    );
  }

  Future<void> _handleImportMission() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['plan', 'waypoints'],
        dialogTitle: 'Select Mission File',
      );

      if (result != null && result.files.single.path != null) {
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

  Future<void> _handleExportMission() async {
    try {
      if (widget.routePoints.isEmpty) {
        _showSnackbar('No waypoints to export', isError: true);
        return;
      }

      // Convert RoutePoint to PlanMissionItem
      final missionItems = widget.routePoints
          .map((rp) => _routePointToMissionItem(rp))
          .toList();

      final missionPlan = MissionPlan(items: missionItems);
      final jsonContent = missionPlan.toQgcPlanJson();

      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Mission File',
        fileName: 'mission_${DateTime.now().millisecondsSinceEpoch}.plan',
        type: FileType.custom,
        allowedExtensions: ['plan'],
      );

      if (outputFile != null) {
        final file = File(outputFile);
        await file.writeAsString(jsonContent);
        _showSnackbar('Mission exported successfully');
      }
    } catch (e) {
      // Fallback for macOS
      try {
        final directory = await getApplicationDocumentsDirectory();
        final fileName =
            'mission_${DateTime.now().millisecondsSinceEpoch}.plan';
        final file = File('${directory.path}/$fileName');

        final missionItems = widget.routePoints
            .map((rp) => _routePointToMissionItem(rp))
            .toList();

        final missionPlan = MissionPlan(items: missionItems);

        final jsonContent = missionPlan.toQgcPlanJson();
        await file.writeAsString(jsonContent);

        _showSnackbar('Mission exported to Documents/$fileName');
      } catch (fallbackError) {
        _showSnackbar('Export failed: $fallbackError', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1A1A1A),
      child: Column(
        children: [
          // Header
          _buildHeader(),

          // Summary Section
          _buildSummarySection(),

          // Waypoint List Section
          Expanded(child: _buildWaypointListSection()),

          // Controls Section
          _buildControlsSection(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        border: Border.all(color: Colors.teal.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.teal.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.flight_takeoff, color: Colors.teal, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mission Plan',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
    );
  }

  Widget _buildSummarySection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF252525),
        border: Border.symmetric(
          horizontal: BorderSide(color: Colors.teal.withValues(alpha: 0.1)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics_outlined, color: Colors.teal, size: 16),
              const SizedBox(width: 8),
              Text(
                'Mission Overview',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.location_on,
                  label: 'Waypoints',
                  value: '${widget.routePoints.length}',
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 8),
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
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.access_time,
                  label: 'Time',
                  value: widget.estimatedTime != null
                      ? '${widget.estimatedTime!.inMinutes}m ${widget.estimatedTime!.inSeconds % 60}s'
                      : 'N/A',
                  color: Colors.orange,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.battery_charging_full,
                  label: 'Battery',
                  value: widget.batteryUsage != null
                      ? '${widget.batteryUsage!.toStringAsFixed(0)}%'
                      : 'N/A',
                  color: Colors.red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWaypointListSection() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        border: Border.symmetric(
          horizontal: BorderSide(color: Colors.teal.withValues(alpha: 0.1)),
        ),
      ),
      child: Column(
        children: [
          // Waypoint List Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF252525),
              border: Border(
                bottom: BorderSide(color: Colors.teal.withValues(alpha: 0.1)),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.list_alt, color: Colors.teal, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Waypoint Details',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (widget.routePoints.isNotEmpty)
                  Text(
                    'Long press to reorder',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),

          // Waypoint List
          Expanded(
            child: widget.routePoints.isEmpty
                ? _buildEmptyState()
                : _buildReorderableWaypointList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.location_off, size: 48, color: Colors.white24),
          const SizedBox(height: 16),
          Text(
            'No waypoints added',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add waypoints to start planning\nyour mission',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildReorderableWaypointList() {
    return ReorderableListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: widget.routePoints.length,
      buildDefaultDragHandles: false, // Bỏ drag handles mặc định
      onReorder: (oldIndex, newIndex) {
        if (widget.onReorderWaypoints != null) {
          final items = List<RoutePoint>.from(widget.routePoints);
          if (newIndex > oldIndex) newIndex--;
          final item = items.removeAt(oldIndex);
          items.insert(newIndex, item);

          // Update order numbers
          for (int i = 0; i < items.length; i++) {
            items[i] = items[i].copyWith(order: i + 1);
          }

          widget.onReorderWaypoints!(items);
        }
      },
      itemBuilder: (context, index) {
        final waypoint = widget.routePoints[index];
        return ReorderableDragStartListener(
          index: index,
          key: ValueKey(waypoint.id),
          child: _buildWaypointCard(waypoint, index),
        );
      },
    );
  }

  Widget _buildWaypointCard(RoutePoint waypoint, int index) {
    final commandName = _getCommandName(waypoint.command);
    final commandIcon = _getCommandIcon(waypoint.command);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _getCommandColor(waypoint.command).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  commandIcon,
                  color: _getCommandColor(waypoint.command),
                  size: 16,
                ),
                Text(
                  '${waypoint.order}',
                  style: TextStyle(
                    color: _getCommandColor(waypoint.command),
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          title: Text(
            commandName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                'Lat: ${double.parse(waypoint.latitude).toStringAsFixed(6)}',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
              Text(
                'Lng: ${double.parse(waypoint.longitude).toStringAsFixed(6)}',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
              if (waypoint.commandParams?.isNotEmpty == true) ...[
                const SizedBox(height: 4),
                _buildParameterChips(waypoint),
              ],
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Center(
                  child: Text(
                    '${waypoint.altitude}m',
                    style: const TextStyle(
                      color: Colors.blue,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (widget.onEditWaypoint != null)
                IconButton(
                  icon: Icon(Icons.edit, color: Colors.white54, size: 16),
                  onPressed: () => widget.onEditWaypoint!(waypoint),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
              if (widget.onDeleteWaypoint != null)
                IconButton(
                  icon: Icon(Icons.delete_outline, color: Colors.red, size: 16),
                  onPressed: () => widget.onDeleteWaypoint!(waypoint.id),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildParameterChips(RoutePoint waypoint) {
    final params = waypoint.commandParams!;
    final commandParams = mavCmdParams[waypoint.command];

    return Wrap(
      spacing: 4,
      runSpacing: 2,
      children: params.entries.take(3).map((entry) {
        // Try to find matching parameter info
        String label = entry.key;
        String unit = '';

        if (commandParams != null) {
          // Try to match by parameter name
          for (final param in commandParams) {
            if (param.name.toLowerCase().contains(entry.key.toLowerCase()) ||
                entry.key.toLowerCase().contains(param.name.toLowerCase())) {
              label = param.name;
              unit = param.unit;
              break;
            }
          }
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: Colors.teal.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Text(
            '$label: ${entry.value}$unit',
            style: const TextStyle(
              color: Colors.teal,
              fontSize: 9,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildControlsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF252525),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
        border: Border.all(color: Colors.teal.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.control_camera, color: Colors.teal, size: 16),
              const SizedBox(width: 8),
              Text(
                'Mission Controls',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Flight Controller Controls
          _buildControlGroup(
            title: 'Flight Controller',
            icon: Icons.flight,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildControlButton(
                      label: 'Read Mission',
                      icon: Icons.download,
                      color: Colors.blue,
                      onPressed: widget.onReadMission,
                      enabled: widget.isConnected,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildControlButton(
                      label: 'Send Mission',
                      icon: Icons.send,
                      color: Colors.green,
                      onPressed: widget.onSendMission,
                      enabled:
                          widget.onSendMission != null && widget.isConnected,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          // File Operations
          _buildControlGroup(
            title: 'File Operations',
            icon: Icons.folder,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildControlButton(
                      label: 'Import',
                      icon: Icons.file_open,
                      color: Colors.orange,
                      onPressed: _handleImportMission,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildControlButton(
                      label: 'Export',
                      icon: Icons.save_alt,
                      color: Colors.purple,
                      onPressed: widget.routePoints.isNotEmpty
                          ? _handleExportMission
                          : null,
                      enabled: widget.routePoints.isNotEmpty,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControlGroup({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.white54, size: 14),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                color: Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  Widget _buildControlButton({
    required String label,
    required IconData icon,
    required Color color,
    VoidCallback? onPressed,
    bool enabled = true,
  }) {
    return ElevatedButton.icon(
      onPressed: enabled ? onPressed : null,
      icon: Icon(icon, size: 16),
      label: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: enabled && onPressed != null
            ? color
            : Colors.grey.shade700,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 0,
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
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white60,
              fontSize: 9,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getCommandIcon(int command) {
    switch (command) {
      case 16:
        return Icons.location_on; // Waypoint
      case 19:
        return Icons.loop; // Loiter Time
      case 20:
        return Icons.home; // RTL
      case 21:
        return Icons.flight_land; // Land
      case 201:
        return Icons.camera_alt; // Do Set ROI
      case 22:
        return Icons.flight_takeoff; // Takeoff
      default:
        return Icons.place;
    }
  }

  Color _getCommandColor(int command) {
    switch (command) {
      case 16:
        return Colors.blue; // Waypoint
      case 19:
        return Colors.orange; // Loiter Time
      case 20:
        return Colors.green; // RTL
      case 21:
        return Colors.red; // Land
      case 201:
        return Colors.purple; // Do Set ROI
      case 22:
        return Colors.cyan; // Takeoff
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
        return 'Return to Launch';
      case 21:
        return 'Land';
      case 201:
        return 'Set ROI';
      default:
        return 'Command $command';
    }
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

  void _showSnackbar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: Duration(seconds: isError ? 3 : 2),
      ),
    );
  }
}
