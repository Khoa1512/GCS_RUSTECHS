import 'package:flutter/material.dart';
import 'package:skylink/data/models/route_point_model.dart';

class WaypointMiniInspector extends StatefulWidget {
  final RoutePoint waypoint;
  final Function(RoutePoint) onUpdate;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Offset markerScreenPosition;

  const WaypointMiniInspector({
    super.key,
    required this.waypoint,
    required this.onUpdate,
    required this.onEdit,
    required this.onDelete,
    required this.markerScreenPosition,
  });

  @override
  State<WaypointMiniInspector> createState() => _WaypointMiniInspectorState();
}

class _WaypointMiniInspectorState extends State<WaypointMiniInspector> {
  late double _altitude;
  late double _speed;

  @override
  void initState() {
    super.initState();
    _altitude = double.tryParse(widget.waypoint.altitude) ?? 100.0;
    _speed = widget.waypoint.commandParams?['speed'] ?? 10.0;
  }

  @override
  void didUpdateWidget(WaypointMiniInspector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.waypoint.id != widget.waypoint.id) {
      _altitude = double.tryParse(widget.waypoint.altitude) ?? 100.0;
      _speed = widget.waypoint.commandParams?['speed'] ?? 10.0;
    }
  }

  void _updateAltitude(double value) {
    setState(() {
      _altitude = value;
    });
    _updateWaypoint();
  }

  void _updateSpeed(double value) {
    setState(() {
      _speed = value;
    });
    _updateWaypoint();
  }

  void _updateWaypoint() {
    final updatedWaypoint = widget.waypoint.copyWith(
      altitude: _altitude.toInt().toString(),
      commandParams: {...widget.waypoint.commandParams ?? {}, 'speed': _speed},
    );
    widget.onUpdate(updatedWaypoint);
  }

  @override
  Widget build(BuildContext context) {
    // Calculate position relative to marker
    final left =
        widget.markerScreenPosition.dx - 140; // Center the 280px wide panel
    final top = widget.markerScreenPosition.dy + 40; // Place below marker

    return Positioned(
      top: top.clamp(0.0, MediaQuery.of(context).size.height - 200),
      left: left.clamp(0.0, MediaQuery.of(context).size.width - 280),
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFF2D2D2D),
        child: Container(
          width: 280,
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with waypoint info
              Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.teal,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        '${widget.waypoint.order}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _getCommandName(widget.waypoint.command),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  // Edit button
                  IconButton(
                    onPressed: widget.onEdit,
                    icon: const Icon(Icons.more_horiz),
                    color: Colors.grey.shade400,
                    iconSize: 20,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    padding: EdgeInsets.zero,
                  ),
                  // Delete button
                  IconButton(
                    onPressed: widget.onDelete,
                    icon: const Icon(Icons.delete_outline),
                    color: Colors.red.shade400,
                    iconSize: 18,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Altitude control
              Row(
                children: [
                  const Icon(Icons.height, color: Colors.grey, size: 16),
                  const SizedBox(width: 8),
                  const Text(
                    'Alt:',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(width: 8),
                  // Decrease button
                  GestureDetector(
                    onTap: () => _updateAltitude(_altitude - 10),
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade700,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(
                        Icons.remove,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Altitude value
                  SizedBox(
                    width: 60,
                    child: Text(
                      '${_altitude.toInt()}m',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Increase button
                  GestureDetector(
                    onTap: () => _updateAltitude(_altitude + 10),
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.teal,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Speed control
              Row(
                children: [
                  const Icon(Icons.speed, color: Colors.grey, size: 16),
                  const SizedBox(width: 8),
                  const Text(
                    'Speed:',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: Colors.teal,
                        inactiveTrackColor: Colors.grey.shade700,
                        thumbColor: Colors.teal,
                        overlayColor: Colors.teal.withOpacity(0.2),
                        trackHeight: 2,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 6,
                        ),
                      ),
                      child: Slider(
                        value: _speed.clamp(1.0, 30.0),
                        min: 1.0,
                        max: 30.0,
                        divisions: 29,
                        onChanged: _updateSpeed,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 40,
                    child: Text(
                      '${_speed.toInt()}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getCommandName(int command) {
    switch (command) {
      case 16:
        return 'Waypoint';
      case 201:
        return 'Do Set ROI';
      case 19:
        return 'Loiter Time';
      case 21:
        return 'Land';
      case 22:
        return 'Takeoff';
      case 183:
        return 'Set Servo';
      case 184:
        return 'Repeat Servo';
      default:
        return 'Command $command';
    }
  }
}
