import 'package:flutter/material.dart';
import 'package:skylink/data/models/route_point_model.dart';
import 'package:skylink/data/constants/mav_cmd_params.dart';

class WaypointEditPanel extends StatefulWidget {
  final RoutePoint waypoint;
  final Function(RoutePoint updatedWaypoint) onSave;
  final VoidCallback onCancel;
  final VoidCallback? onDelete;
  final Function(int commandType)? onConvertType;
  final bool isSimpleMode;
  final Function(bool) onModeToggle;
  final VoidCallback? onPrevWaypoint;
  final VoidCallback? onNextWaypoint;
  final int? totalWaypoints;
  final int? currentIndex;

  const WaypointEditPanel({
    super.key,
    required this.waypoint,
    required this.onSave,
    required this.onCancel,
    this.onDelete,
    this.onConvertType,
    this.isSimpleMode = true,
    required this.onModeToggle,
    this.onPrevWaypoint,
    this.onNextWaypoint,
    this.totalWaypoints,
    this.currentIndex,
  });

  @override
  State<WaypointEditPanel> createState() => _WaypointEditPanelState();
}

class _WaypointEditPanelState extends State<WaypointEditPanel> {
  late TextEditingController _altitudeController;
  late int _selectedCommand;

  // Advanced parameters
  late TextEditingController _param1Controller;
  late TextEditingController _param2Controller;
  late TextEditingController _param3Controller;
  late TextEditingController _param4Controller;

  final Map<int, String> _commandTypes = {
    16: 'Waypoint',
    19: 'Loiter Time',
    201: 'Do Set ROI',
    20: 'RTL',
    21: 'Land',
  };

  @override
  void initState() {
    super.initState();
    _selectedCommand = widget.waypoint.command;
    _altitudeController = TextEditingController(text: widget.waypoint.altitude);

    final params = widget.waypoint.commandParams ?? {};
    _param1Controller = TextEditingController(
      text: params['param1']?.toString() ?? '0',
    );
    _param2Controller = TextEditingController(
      text: params['param2']?.toString() ?? '0',
    );
    _param3Controller = TextEditingController(
      text: params['param3']?.toString() ?? '0',
    );
    _param4Controller = TextEditingController(
      text: params['param4']?.toString() ?? '0',
    );
  }

  @override
  void dispose() {
    _altitudeController.dispose();
    _param1Controller.dispose();
    _param2Controller.dispose();
    _param3Controller.dispose();
    _param4Controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = widget.isSimpleMode ? 400.0 : 600.0;

    return Container(
      width: 300,
      constraints: BoxConstraints(maxHeight: maxHeight),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.teal.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.teal.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.max,
              children: [
                if (widget.onPrevWaypoint != null)
                  IconButton(
                    onPressed: widget.onPrevWaypoint,
                    icon: const Icon(Icons.chevron_left, color: Colors.white70),
                    iconSize: 20,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                Expanded(
                  child: Text(
                    'Waypoint ${widget.waypoint.order}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                if (widget.onNextWaypoint != null)
                  IconButton(
                    onPressed: widget.onNextWaypoint,
                    icon: const Icon(
                      Icons.chevron_right,
                      color: Colors.white70,
                    ),
                    iconSize: 20,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
              ],
            ),
          ),

          // Content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Mode Toggle
                  Container(
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2A2A),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => widget.onModeToggle(true),
                            child: Container(
                              decoration: BoxDecoration(
                                color: widget.isSimpleMode
                                    ? Colors.teal
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Center(
                                child: Text(
                                  'Simple',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => widget.onModeToggle(false),
                            child: Container(
                              decoration: BoxDecoration(
                                color: !widget.isSimpleMode
                                    ? Colors.teal
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Center(
                                child: Text(
                                  'Advanced',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Command Type
                  DropdownButtonFormField<int>(
                    value: _selectedCommand,
                    decoration: InputDecoration(
                      labelText: 'Command Type',
                      labelStyle: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    dropdownColor: const Color(0xFF2A2A2A),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    items: _commandTypes.entries.map((entry) {
                      return DropdownMenuItem<int>(
                        value: entry.key,
                        child: Text(entry.value),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedCommand = value;
                        });
                      }
                    },
                  ),

                  const SizedBox(height: 12),

                  // Basic Parameters
                  Column(
                    children: [
                      TextFormField(
                        controller: _altitudeController,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Altitude (m)',
                          labelStyle: const TextStyle(
                            color: Colors.white60,
                            fontSize: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                      ),
                    ],
                  ),

                  if (!widget.isSimpleMode) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Advanced Parameters',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Advanced Parameters
                    Column(
                      children: [
                        TextFormField(
                          controller: _param1Controller,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: _getParamLabel(1),
                            labelStyle: const TextStyle(
                              color: Colors.white60,
                              fontSize: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: Colors.white.withValues(alpha: 0.2),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: Colors.white.withValues(alpha: 0.2),
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _param2Controller,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: _getParamLabel(2),
                            labelStyle: const TextStyle(
                              color: Colors.white60,
                              fontSize: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: Colors.white.withValues(alpha: 0.2),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: Colors.white.withValues(alpha: 0.2),
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _param3Controller,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: _getParamLabel(3),
                            labelStyle: const TextStyle(
                              color: Colors.white60,
                              fontSize: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: Colors.white.withValues(alpha: 0.2),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: Colors.white.withValues(alpha: 0.2),
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _param4Controller,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: _getParamLabel(4),
                            labelStyle: const TextStyle(
                              color: Colors.white60,
                              fontSize: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: Colors.white.withValues(alpha: 0.2),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: Colors.white.withValues(alpha: 0.2),
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Action Bar
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.max,
              children: [
                if (widget.onDelete != null)
                  IconButton(
                    onPressed: widget.onDelete,
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    iconSize: 20,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                const Spacer(),
                TextButton(
                  onPressed: widget.onCancel,
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.white60),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _saveWaypoint,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                  child: const Text('Save'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getParamLabel(int paramNumber) {
    // Get parameter definitions for the selected command
    final params = mavCmdParams[_selectedCommand];
    if (params != null && paramNumber >= 1 && paramNumber <= params.length) {
      final param = params[paramNumber - 1]; // Convert to 0-based index
      if (param.unit.isNotEmpty) {
        return '${param.name} (${param.unit})';
      } else {
        return param.name;
      }
    }
    return 'Param $paramNumber';
  }

  void _saveWaypoint() {
    final updatedWaypoint = widget.waypoint.copyWith(
      altitude: _altitudeController.text,
      command: _selectedCommand,
      commandParams: {
        'param1': double.tryParse(_param1Controller.text) ?? 0.0,
        'param2': double.tryParse(_param2Controller.text) ?? 0.0,
        'param3': double.tryParse(_param3Controller.text) ?? 0.0,
        'param4': double.tryParse(_param4Controller.text) ?? 0.0,
      },
    );

    widget.onSave(updatedWaypoint);
  }
}
