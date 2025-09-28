import 'package:flutter/material.dart';
import 'package:skylink/data/models/route_point_model.dart';
import 'package:skylink/data/constants/mav_cmd_params.dart';
import 'package:skylink/presentation/widget/mission/mission_waypoint_helpers.dart';

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
    16: 'Điểm định hướng',
    19: 'Lượn tại chỗ',
    201: 'Điểm quan sát (ROI)',
    20: 'Quay về điểm xuất phát',
    21: 'Hạ cánh',
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
                  child: Column(
                    children: [
                      Text(
                        MissionWaypointHelpers.isROIPoint(widget.waypoint)
                            ? 'Điểm ROI ${widget.waypoint.order}'
                            : 'Waypoint ${widget.waypoint.order}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (MissionWaypointHelpers.isROIPoint(widget.waypoint))
                        Text(
                          'Camera sẽ hướng về điểm này',
                          style: TextStyle(
                            color: Colors.purple.shade200,
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                          textAlign: TextAlign.center,
                        ),
                    ],
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
                                  'Cơ bản',
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
                                  'Chi tiết',
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

                  // ROI Information Box
                  if (MissionWaypointHelpers.isROIPoint(widget.waypoint))
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.purple.withOpacity(0.1),
                        border: Border.all(
                          color: Colors.purple.withOpacity(0.3),
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.center_focus_strong,
                            color: Colors.purple.shade300,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Điểm ROI (Region of Interest)',
                                  style: TextStyle(
                                    color: Colors.purple.shade200,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Drone sẽ không bay đến điểm này, chỉ hướng camera/gimbal về vị trí này',
                                  style: TextStyle(
                                    color: Colors.purple.shade100,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Command Type
                  DropdownButtonFormField<int>(
                    value: _selectedCommand,
                    decoration: InputDecoration(
                      labelText: 'Lệnh bay',
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
                          labelText: 'Độ cao (m)',
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
                      'Tham số',
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
                        _buildParameterFieldWithTooltip(
                          controller: _param1Controller,
                          paramNumber: 1,
                        ),
                        const SizedBox(height: 8),
                        _buildParameterFieldWithTooltip(
                          controller: _param2Controller,
                          paramNumber: 2,
                        ),
                        const SizedBox(height: 8),
                        _buildParameterFieldWithTooltip(
                          controller: _param3Controller,
                          paramNumber: 3,
                        ),
                        const SizedBox(height: 8),
                        _buildParameterFieldWithTooltip(
                          controller: _param4Controller,
                          paramNumber: 4,
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
                    'Huỷ',
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
                  child: const Text('Lưu'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParameterFieldWithTooltip({
    required TextEditingController controller,
    required int paramNumber,
  }) {
    final paramDescription = _getParamDescription(paramNumber);
    final paramLabel = _getParamLabel(paramNumber);

    return Tooltip(
      message: paramDescription,
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.teal.withValues(alpha: 0.3)),
      ),
      textStyle: const TextStyle(color: Colors.white, fontSize: 12),
      preferBelow: false,
      verticalOffset: 10,
      child: TextFormField(
        controller: controller,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: paramLabel,
          labelStyle: const TextStyle(color: Colors.white60, fontSize: 12),
          suffixIcon: Icon(
            Icons.help_outline,
            color: Colors.white.withValues(alpha: 0.5),
            size: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
        ),
      ),
    );
  }

  String _getParamDescription(int paramNumber) {
    // Get parameter definitions for the selected command
    final params = mavCmdParams[_selectedCommand];
    if (params != null && paramNumber >= 1 && paramNumber <= params.length) {
      final param = params[paramNumber - 1]; // Convert to 0-based index
      return param.description.isNotEmpty
          ? param.description
          : 'Parameter $paramNumber for this command';
    }
    return 'Parameter $paramNumber';
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
