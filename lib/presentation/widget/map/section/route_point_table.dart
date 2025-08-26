import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:skylink/data/models/route_point_model.dart';
import 'package:skylink/data/constants/mav_cmd.dart';
import 'package:skylink/data/constants/mav_cmd_params.dart';

class RoutePointTable extends StatefulWidget {
  final List<RoutePoint> routePoints;
  final Function(LatLng latLng) onSearchLocation;
  final Function() onClearTap;
  final Function(List<RoutePoint>) onSendConfigs;
  final Function(
    RoutePoint point,
    int command,
    String altitude,
    Map<String, double> params,
  )
  onEditPoint;
  final Function()? onReadMission;
  final Function(RoutePoint)? onDeletePoint;

  const RoutePointTable({
    super.key,
    required this.routePoints,
    required this.onSearchLocation,
    required this.onClearTap,
    required this.onSendConfigs,
    required this.onEditPoint,
    this.onReadMission,
    this.onDeletePoint,
  });

  @override
  State<RoutePointTable> createState() => _RoutePointTableState();
}

class _RoutePointTableState extends State<RoutePointTable> {
  final TextEditingController searchController = TextEditingController();
  bool isExpanded = false;
  final Map<String, String> _altitudeEdits = {};
  final Map<String, String> _commandEdits = {};
  final Map<String, Map<String, double>> _paramEdits =
      {}; // pointId -> param -> value
  final Map<String, Map<String, String>> _paramTextEdits =
      {}; // pointId -> param -> text display

  void handleSearchLocation() {
    final input = searchController.text.trim();
    final parts = input.split(',');
    if (parts.length == 2) {
      final lat = double.tryParse(parts[0]);
      final lng = double.tryParse(parts[1]);
      if (lat != null && lng != null) {
        widget.onSearchLocation(LatLng(lat, lng));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid latitude or longitude.')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter coordinates as: lat, lng')),
      );
    }
  }

  void _saveAllChanges() {
    // Kiểm tra xem có route points nào không
    if (widget.routePoints.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No waypoints to save'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Lưu tất cả thay đổi cho tất cả points
    for (final point in widget.routePoints) {
      final newAltitude = _altitudeEdits[point.id];
      final newCommand = _commandEdits[point.id];
      final newParams = _paramEdits[point.id] ?? {};

      if (newAltitude != null || newCommand != null || newParams.isNotEmpty) {
        // Convert param names to param indices
        final paramsByIndex = <String, double>{};
        final params = getCommandParams(
          newCommand != null ? mavCmdMap[newCommand]! : point.command,
        );
        for (int i = 0; i < params.length; i++) {
          if (newParams.containsKey(params[i].name)) {
            paramsByIndex['param${i + 1}'] = newParams[params[i].name]!;
          }
        }

        widget.onEditPoint(
          point,
          newCommand != null ? mavCmdMap[newCommand]! : point.command,
          newAltitude ?? point.altitude,
          paramsByIndex,
        );
      }
    }

    // Clear edits sau khi save
    setState(() {
      _altitudeEdits.clear();
      _commandEdits.clear();
      _paramEdits.clear();
      _paramTextEdits.clear();
    });

    // Send mission to FC after saving changes
    // Note: Không hiện snackbar ở đây vì map_page.dart sẽ xử lý thông báo
    widget.onSendConfigs(widget.routePoints);
  }

  double _getParamValue(RoutePoint point, int paramIndex) {
    // Get current command (including edits)
    final currentCommand = _commandEdits[point.id] != null
        ? mavCmdMap[_commandEdits[point.id]]!
        : point.command;

    final params = getCommandParams(currentCommand);
    if (paramIndex < params.length) {
      // Check if there's an edit in progress
      final editedParams = _paramEdits[point.id];
      if (editedParams != null &&
          editedParams.containsKey(params[paramIndex].name)) {
        return editedParams[params[paramIndex].name]!;
      }

      // Check commandParams from the point
      if (point.commandParams != null) {
        final key = 'param${paramIndex + 1}';
        if (point.commandParams!.containsKey(key)) {
          return (point.commandParams![key] as num).toDouble();
        }
      }

      // Return default value
      return params[paramIndex].defaultValue;
    }
    return 0.0;
  }

  void _updateParamValue(RoutePoint point, int paramIndex, double value) {
    // Get current command (including edits)
    final currentCommand = _commandEdits[point.id] != null
        ? mavCmdMap[_commandEdits[point.id]]!
        : point.command;

    final params = getCommandParams(currentCommand);
    if (paramIndex < params.length) {
      setState(() {
        _paramEdits[point.id] ??= {};
        _paramEdits[point.id]![params[paramIndex].name] = value;
      });
    }
  }

  void _updateParamText(RoutePoint point, int paramIndex, String text) {
    // Get current command (including edits)
    final currentCommand = _commandEdits[point.id] != null
        ? mavCmdMap[_commandEdits[point.id]]!
        : point.command;

    final params = getCommandParams(currentCommand);
    if (paramIndex < params.length) {
      setState(() {
        _paramTextEdits[point.id] ??= {};
        _paramTextEdits[point.id]![params[paramIndex].name] = text;
      });
    }
  }

  String _getParamText(RoutePoint point, int paramIndex) {
    // Get current command (including edits)
    final currentCommand = _commandEdits[point.id] != null
        ? mavCmdMap[_commandEdits[point.id]]!
        : point.command;

    final params = getCommandParams(currentCommand);
    if (paramIndex < params.length) {
      // Check if there's a text edit in progress
      final editedTexts = _paramTextEdits[point.id];
      if (editedTexts != null &&
          editedTexts.containsKey(params[paramIndex].name)) {
        return editedTexts[params[paramIndex].name]!;
      }
    }

    // Fallback to the numeric value
    return _getParamValue(point, paramIndex).toString();
  }

  void _showDeleteConfirmation(BuildContext context, RoutePoint point) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2D2D2D),
          title: const Text(
            'Delete Waypoint',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            'Are you sure you want to delete waypoint ${point.order}?',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                widget.onDeletePoint?.call(point);
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildParamCellExpanded(RoutePoint point, int paramIndex) {
    // Get command for this specific point (including any edits)
    final currentCommand = _commandEdits[point.id] != null
        ? mavCmdMap[_commandEdits[point.id]]!
        : point.command;

    final params = getCommandParams(currentCommand);
    if (paramIndex >= params.length) {
      return Container(
        height: 32,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.grey.shade800, width: 1),
        ),
        child: Center(
          child: Text(
            'N/A',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 10),
          ),
        ),
      );
    }

    final param = params[paramIndex];
    final value = _getParamValue(point, paramIndex);

    // Get command name for tooltip
    final commandName = mavCmdMap.entries
        .firstWhere((entry) => entry.value == currentCommand)
        .key;

    return Tooltip(
      message:
          'Command: $commandName\n'
          'Parameter: ${param.name}\n'
          '${param.description}\n'
          '${param.unit.isNotEmpty ? 'Unit: ${param.unit}' : ''}'
          '${param.min != null ? '\nMin: ${param.min}' : ''}'
          '${param.max != null ? '\nMax: ${param.max}' : ''}',
      preferBelow: false,
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF2D2D2D),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.grey.shade700, width: 1),
        ),
        child: Center(
          child: param.enumValues != null
              ? _buildEnumDropdown(point, paramIndex, param, value)
              : _buildNumberInput(point, paramIndex, param, value),
        ),
      ),
    );
  }

  Widget _buildEnumDropdown(
    RoutePoint point,
    int paramIndex,
    MavCmdParam param,
    double value,
  ) {
    final key = '${point.id}_param_enum_$paramIndex';
    return DropdownButtonHideUnderline(
      child: DropdownButton<double>(
        key: ValueKey(key),
        value: value,
        isExpanded: true,
        dropdownColor: const Color(0xFF2D2D2D),
        style: const TextStyle(color: Colors.white, fontSize: 11),
        icon: Icon(
          Icons.arrow_drop_down,
          color: Colors.grey.shade400,
          size: 16,
        ),
        items: param.enumValues!.asMap().entries.map((entry) {
          return DropdownMenuItem<double>(
            value: entry.key.toDouble(),
            child: Text(
              entry.value,
              style: const TextStyle(fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          );
        }).toList(),
        onChanged: (newValue) {
          if (newValue != null) {
            _updateParamValue(point, paramIndex, newValue);
          }
        },
      ),
    );
  }

  Widget _buildNumberInput(
    RoutePoint point,
    int paramIndex,
    MavCmdParam param,
    double value,
  ) {
    final key = '${point.id}_param_$paramIndex';
    final displayText = _getParamText(point, paramIndex);

    return TextField(
      key: ValueKey(key),
      controller: TextEditingController(text: displayText)
        ..selection = TextSelection.fromPosition(
          TextPosition(offset: displayText.length),
        ),
      style: const TextStyle(color: Colors.white, fontSize: 11),
      decoration: const InputDecoration(
        border: InputBorder.none,
        isDense: true,
        contentPadding: EdgeInsets.zero,
      ),
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      onChanged: (newValue) {
        // Always update the text display
        _updateParamText(point, paramIndex, newValue);

        // Try to parse as number for validation
        final parsed = double.tryParse(newValue);
        if (parsed != null) {
          // Validate range
          if (param.min != null && parsed < param.min!) return;
          if (param.max != null && parsed > param.max!) return;
          _updateParamValue(point, paramIndex, parsed);
        } else if (newValue.isEmpty) {
          // Allow empty string, set to 0
          _updateParamValue(point, paramIndex, 0.0);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        border: Border(top: BorderSide(color: Colors.grey.shade800, width: 1)),
      ),
      child: Column(
        children: [
          // Header - Compact để tiết kiệm không gian
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
                const Icon(Icons.flight_takeoff, color: Colors.teal, size: 22),
                const SizedBox(width: 10),
                const Text(
                  'Mission Plan',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
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
                    color: Colors.teal.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        color: Colors.teal,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${widget.routePoints.length} waypoints',
                        style: const TextStyle(
                          color: Colors.teal,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Control Row - Search + Action Buttons
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF2D2D2D),
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade800, width: 1),
              ),
            ),
            child: Row(
              children: [
                // Search section
                Expanded(
                  flex: 3,
                  child: Container(
                    height: 34,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.grey.shade800, width: 1),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.search,
                          color: Colors.grey.shade400,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: searchController,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                            decoration: InputDecoration(
                              hintText:
                                  'Search location: 10.842087, 106.7077925',
                              hintStyle: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 13,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: handleSearchLocation,
                            borderRadius: BorderRadius.circular(4),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.teal.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Icon(
                                Icons.search,
                                color: Colors.teal,
                                size: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 16),

                // Action buttons
                Expanded(
                  flex: 2,
                  child: Row(
                    children: [
                      Expanded(
                        child: _CompactActionButton(
                          icon: Icons.download,
                          label: 'Read',
                          onTap: widget.onReadMission ?? () {},
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _CompactActionButton(
                          icon: Icons.upload,
                          label: 'Write',
                          onTap: _saveAllChanges,
                          color: Colors.teal,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _CompactActionButton(
                          icon: Icons.save,
                          label: 'Save',
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Save Plan functionality coming soon',
                                ),
                                backgroundColor: Colors.orange,
                              ),
                            );
                          },
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _CompactActionButton(
                          icon: Icons.clear_all,
                          label: 'Clear',
                          onTap: widget.onClearTap,
                          color: Colors.red.shade400,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Table Header
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF2D2D2D),
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade800, width: 1),
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 50,
                  child: Text(
                    'Seq',
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: Text(
                    'Latitude',
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: Text(
                    'Longitude',
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Command',
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 12),
                // Parameter headers
                for (int i = 0; i < 4; i++) ...[
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Param${i + 1}',
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  if (i < 3) const SizedBox(width: 8),
                ],
                const SizedBox(width: 12),
                SizedBox(
                  width: 85,
                  child: Text(
                    'Alt (m)',
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 60,
                  child: Text(
                    'Actions',
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),

          // Table Body
          Expanded(
            child: ListView.builder(
              itemCount: widget.routePoints.length,
              itemBuilder: (context, index) {
                final point = widget.routePoints[index];
                return Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: index.isEven
                        ? const Color(0xFF1E1E1E)
                        : const Color(0xFF252525),
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade800, width: 1),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Sequence number
                      SizedBox(
                        width: 50,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: Colors.teal.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              point.order.toString(),
                              style: const TextStyle(
                                color: Colors.teal,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Latitude
                      Expanded(
                        flex: 3,
                        child: Container(
                          alignment: Alignment.center,
                          child: Text(
                            point.latitude,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Longitude
                      Expanded(
                        flex: 3,
                        child: Container(
                          alignment: Alignment.center,
                          child: Text(
                            point.longitude,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Command dropdown
                      Expanded(
                        flex: 2,
                        child: Container(
                          height: 32,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2D2D2D),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: Colors.grey.shade700,
                              width: 1,
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value:
                                  _commandEdits[point.id] ??
                                  mavCmdNameMap[point.command],
                              isExpanded: true,
                              dropdownColor: const Color(0xFF2D2D2D),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                              icon: Icon(
                                Icons.arrow_drop_down,
                                color: Colors.grey.shade400,
                                size: 16,
                              ),
                              items: mavCmdMap.keys.map((String cmd) {
                                return DropdownMenuItem<String>(
                                  value: cmd,
                                  child: Text(
                                    cmd,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                if (newValue != null) {
                                  setState(() {
                                    _commandEdits[point.id] = newValue;
                                    // Clear param edits when command changes
                                    _paramEdits.remove(point.id);
                                    _paramTextEdits.remove(point.id);
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Parameter columns (dynamic based on command)
                      for (int i = 0; i < 4; i++) ...[
                        Expanded(
                          flex: 2,
                          child: _buildParamCellExpanded(point, i),
                        ),
                        if (i < 3) const SizedBox(width: 8),
                      ],

                      const SizedBox(width: 12),

                      // Altitude
                      SizedBox(
                        width: 85,
                        child: Container(
                          height: 32,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2D2D2D),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: Colors.grey.shade700,
                              width: 1,
                            ),
                          ),
                          child: Center(
                            child: TextField(
                              key: ValueKey('${point.id}_altitude'),
                              controller:
                                  TextEditingController(
                                      text:
                                          _altitudeEdits[point.id] ??
                                          point.altitude,
                                    )
                                    ..selection = TextSelection.fromPosition(
                                      TextPosition(
                                        offset:
                                            (_altitudeEdits[point.id] ??
                                                    point.altitude)
                                                .length,
                                      ),
                                    ),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              onChanged: (value) {
                                setState(() {
                                  _altitudeEdits[point.id] = value;
                                });
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Actions column
                      SizedBox(
                        width: 60,
                        child: Center(
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: widget.onDeletePoint != null
                                  ? () =>
                                        _showDeleteConfirmation(context, point)
                                  : null,
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.red.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Icon(
                                  Icons.delete_outline,
                                  color: widget.onDeletePoint != null
                                      ? Colors.red.shade300
                                      : Colors.grey.shade600,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _CompactActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final buttonColor = color ?? Colors.teal;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: buttonColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: buttonColor.withOpacity(0.4), width: 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: buttonColor, size: 14),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: buttonColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
