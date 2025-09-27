import 'package:flutter/material.dart';
import 'package:skylink/data/constants/mav_cmd_params.dart';
import 'package:skylink/data/models/route_point_model.dart';

class BatchEditPanel extends StatefulWidget {
  final List<RoutePoint> selectedWaypoints;
  final Function(Map<String, dynamic> batchChanges) onSave;
  final VoidCallback onCancel;
  final VoidCallback? onDelete;
  final bool isSimpleMode;
  final Function(bool) onModeToggle;

  const BatchEditPanel({
    super.key,
    required this.selectedWaypoints,
    required this.onSave,
    required this.onCancel,
    this.onDelete,
    this.isSimpleMode = true,
    required this.onModeToggle,
  });

  @override
  State<BatchEditPanel> createState() => _BatchEditPanelState();
}

class _BatchEditPanelState extends State<BatchEditPanel> {
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
    // Initialize with first waypoint values or defaults
    final firstWaypoint = widget.selectedWaypoints.isNotEmpty
        ? widget.selectedWaypoints.first
        : null;

    _selectedCommand = firstWaypoint?.command ?? 16;
    _altitudeController = TextEditingController(
      text: firstWaypoint?.altitude ?? '100',
    );

    final params = firstWaypoint?.commandParams ?? {};
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
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
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
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.max,
              children: [
                Expanded(
                  child: Text(
                    'Chỉnh sửa hàng loạt (${widget.selectedWaypoints.length} điểm định hướng)',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                IconButton(
                  onPressed: widget.onCancel,
                  icon: const Icon(Icons.close, color: Colors.white70),
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
                                    ? Colors.orange
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
                                    ? Colors.orange
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
                // Delete all selected waypoints button
                IconButton(
                  onPressed: widget.onDelete != null
                      ? _showDeleteConfirmation
                      : null,
                  icon: Icon(
                    Icons.delete_outline,
                    color: widget.onDelete != null
                        ? Colors.red
                        : Colors.red.withValues(alpha: 0.3),
                  ),
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
                  onPressed: _saveBatchChanges,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
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
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
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
          : 'Tham số $paramNumber cho lệnh này';
    }
    return 'Tham số $paramNumber';
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
    return 'Tham số $paramNumber';
  }

  void _saveBatchChanges() {
    // Create batch changes map
    final batchChanges = <String, dynamic>{};

    // Validate and include altitude (required field)
    if (_altitudeController.text.isNotEmpty) {
      final altitude = double.tryParse(_altitudeController.text);
      if (altitude != null && altitude >= 0) {
        batchChanges['altitude'] = _altitudeController.text;
      } else {
        // Show error for invalid altitude
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Giá trị độ cao không hợp lệ. Phải là số dương.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    // Always include command
    batchChanges['command'] = _selectedCommand;

    // Validate and include parameters
    final params = <String, double>{};

    if (_param1Controller.text.isNotEmpty) {
      final value = double.tryParse(_param1Controller.text);
      if (value != null) {
        params['param1'] = value;
      }
    }

    if (_param2Controller.text.isNotEmpty) {
      final value = double.tryParse(_param2Controller.text);
      if (value != null) {
        params['param2'] = value;
      }
    }

    if (_param3Controller.text.isNotEmpty) {
      final value = double.tryParse(_param3Controller.text);
      if (value != null) {
        params['param3'] = value;
      }
    }

    if (_param4Controller.text.isNotEmpty) {
      final value = double.tryParse(_param4Controller.text);
      if (value != null) {
        params['param4'] = value;
      }
    }

    if (params.isNotEmpty) {
      batchChanges['commandParams'] = params;
    }

    widget.onSave(batchChanges);
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2A2A2A),
          title: const Text(
            'Xóa waypoints',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            'Bạn có chắc chắn muốn xóa ${widget.selectedWaypoints.length} waypoints đã chọn?\n\nHành động này không thể hoàn tác.',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Hủy', style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                widget.onDelete?.call();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Xoá'),
            ),
          ],
        );
      },
    );
  }
}
