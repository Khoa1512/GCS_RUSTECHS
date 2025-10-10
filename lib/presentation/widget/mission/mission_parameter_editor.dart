import 'package:flutter/material.dart';
import 'package:skylink/data/models/route_point_model.dart';
import 'package:skylink/data/constants/mav_cmd.dart';
import 'package:skylink/data/constants/mav_cmd_params.dart';

/// Widget for editing waypoint command parameters with live preview
class MissionParameterEditor extends StatefulWidget {
  final RoutePoint waypoint;
  final Function(RoutePoint) onWaypointUpdated;

  const MissionParameterEditor({
    super.key,
    required this.waypoint,
    required this.onWaypointUpdated,
  });

  @override
  State<MissionParameterEditor> createState() => _MissionParameterEditorState();
}

class _MissionParameterEditorState extends State<MissionParameterEditor> {
  late Map<String, dynamic> _currentParams;
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _initializeParameters();
  }

  void _initializeParameters() {
    _currentParams = Map.from(widget.waypoint.commandParams ?? {});

    // Get parameter definitions for this command
    final paramDefs = getCommandParams(widget.waypoint.command);

    // Initialize controllers and default values
    for (int i = 0; i < paramDefs.length; i++) {
      final paramName = 'param${i + 1}';
      final paramDef = paramDefs[i];

      // Use existing value or default
      final currentValue = _currentParams[paramName] ?? paramDef.defaultValue;
      _currentParams[paramName] = currentValue;

      _controllers[paramName] = TextEditingController(
        text: currentValue.toString(),
      );

      // Add listener to update parameters in real-time
      _controllers[paramName]!.addListener(() {
        _updateParameter(paramName);
      });
    }
  }

  void _updateParameter(String paramName) {
    final controller = _controllers[paramName];
    if (controller == null) return;

    final value = double.tryParse(controller.text) ?? 0.0;

    setState(() {
      _currentParams[paramName] = value;
    });

    // Update waypoint with new parameters
    final updatedWaypoint = widget.waypoint.copyWith(
      commandParams: _currentParams,
    );

    widget.onWaypointUpdated(updatedWaypoint);
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final paramDefs = getCommandParams(widget.waypoint.command);
    final commandName =
        mavCmdNameMap[widget.waypoint.command] ?? 'Unknown Command';

    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Waypoint ${widget.waypoint.order}: $commandName',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Position info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Position',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text('Lat: ${widget.waypoint.latitude}'),
                  Text('Lng: ${widget.waypoint.longitude}'),
                  Text('Alt: ${widget.waypoint.altitude}m'),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Parameters
            if (paramDefs.isNotEmpty) ...[
              Text('Parameters', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),

              ...paramDefs.asMap().entries.map((entry) {
                final index = entry.key;
                final paramDef = entry.value;
                final paramName = 'param${index + 1}';
                final controller = _controllers[paramName]!;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildParameterField(paramDef, controller, paramName),
                );
              }),

              // Special highlight for radius parameters
              if (_isLoiterCommand(widget.waypoint.command)) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info, color: Colors.blue, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'Loiter Visualization',
                            style: TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'The radius parameter (Param 3) controls the loiter circle shown on the map. '
                        'Adjust the value to see the circle size change in real-time.',
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Current radius: ${_getCurrentRadius()}m',
                        style: TextStyle(
                          color: Colors.blue.shade800,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ] else ...[
              Text(
                'No parameters required for this command.',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildParameterField(
    MavCmdParam paramDef,
    TextEditingController controller,
    String paramName,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                paramDef.name,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            if (paramDef.unit.isNotEmpty)
              Text(
                paramDef.unit,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
          ],
        ),
        if (paramDef.description.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            paramDef.description,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
        ],
        const SizedBox(height: 4),

        // Parameter input field
        if (paramDef.enumValues != null) ...[
          // Dropdown for enum values
          DropdownButtonFormField<String>(
            initialValue: controller.text,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
            ),
            items: paramDef.enumValues!.map((enumValue) {
              final parts = enumValue.split(': ');
              final value = parts[0];
              final label = parts.length > 1 ? parts[1] : value;
              return DropdownMenuItem<String>(value: value, child: Text(label));
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                controller.text = value;
              }
            },
          ),
        ] else ...[
          // Text field for numeric values
          TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              hintText: _getHintText(paramDef),
            ),
          ),
        ],

        // Show min/max constraints if available
        if (paramDef.min != null || paramDef.max != null) ...[
          const SizedBox(height: 2),
          Text(
            'Range: ${paramDef.min ?? '∞'} - ${paramDef.max ?? '∞'}',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
          ),
        ],
      ],
    );
  }

  String _getHintText(MavCmdParam paramDef) {
    if (paramDef.min != null && paramDef.max != null) {
      return '${paramDef.min} - ${paramDef.max}';
    } else if (paramDef.min != null) {
      return 'Min: ${paramDef.min}';
    } else if (paramDef.max != null) {
      return 'Max: ${paramDef.max}';
    } else {
      return 'Enter value';
    }
  }

  bool _isLoiterCommand(int command) {
    return [
      MavCmd.loiterTurns,
      MavCmd.loiterTime,
      MavCmd.loiterUnlimited,
      MavCmd.loiterToAlt,
    ].contains(command);
  }

  String _getCurrentRadius() {
    final radius = _currentParams['param3'] ?? 0.0;
    return radius.toStringAsFixed(1);
  }
}
