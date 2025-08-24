import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:skylink/data/models/route_point_model.dart';
import 'package:skylink/data/constants/mav_cmd.dart';

class RoutePointTable extends StatefulWidget {
  final List<RoutePoint> routePoints;
  final Function(LatLng latLng) onSearchLocation;
  final Function() onClearTap;
  final Function(List<RoutePoint>) onSendConfigs;
  final Function(RoutePoint point, int command, String altitude) onEditPoint;

  const RoutePointTable({
    super.key,
    required this.routePoints,
    required this.onSearchLocation,
    required this.onClearTap,
    required this.onSendConfigs,
    required this.onEditPoint,
  });

  @override
  State<RoutePointTable> createState() => _RoutePointTableState();
}

class _RoutePointTableState extends State<RoutePointTable> {
  final TextEditingController searchController = TextEditingController();
  bool isExpanded = false;
  final Map<String, String> _altitudeEdits = {};
  final Map<String, String> _commandEdits = {};

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

  void _savePointChanges(RoutePoint point) {
    final newAltitude = _altitudeEdits[point.id];
    final newCommand = _commandEdits[point.id];

    if (newAltitude != null || newCommand != null) {
      widget.onEditPoint(
        point,
        newCommand != null ? mavCmdMap[newCommand]! : point.command,
        newAltitude ?? point.altitude,
      );

      setState(() {
        _altitudeEdits.remove(point.id);
        _commandEdits.remove(point.id);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade800, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF2D2D2D),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(8),
              ),
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade800, width: 1),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.flight_takeoff, color: Colors.teal, size: 20),
                const SizedBox(width: 8),
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
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.teal.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
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
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Search Bar
          Container(
            height: 64,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF2D2D2D),
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade800, width: 1),
              ),
            ),
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.grey.shade800, width: 1),
              ),
              child: Row(
                children: [
                  Icon(Icons.search, color: Colors.grey.shade400, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: searchController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Search location: 10.842087, 106.7077925',
                        hintStyle: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
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
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Action Buttons
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF2D2D2D),
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade800, width: 1),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _ActionButton(
                  icon: Icons.file_download,
                  label: 'Read Mission',
                  onTap: () {
                    // TODO: Implement Read Mission
                  },
                ),
                const SizedBox(width: 8),
                _ActionButton(
                  icon: Icons.file_upload,
                  label: 'Write Mission',
                  onTap: () {
                    // TODO: Implement Write Mission
                  },
                ),
                const SizedBox(width: 8),
                _ActionButton(
                  icon: Icons.save,
                  label: 'Save Plan',
                  onTap: () {
                    // TODO: Implement Save Plan
                  },
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
                  width: 40,
                  child: Text(
                    '',
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 5,
                  child: Text(
                    'Latitude',
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 5,
                  child: Text(
                    'Longitude',
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 4,
                  child: Text(
                    'Command',
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 80,
                  child: Text(
                    'Alt (m)',
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 13,
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
                      SizedBox(
                        width: 40,
                        child: Container(
                          width: 24,
                          height: 24,
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
                      Expanded(
                        flex: 5,
                        child: Text(
                          point.latitude,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 5,
                        child: Text(
                          point.longitude,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 4,
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
                                fontSize: 13,
                              ),
                              icon: Icon(
                                Icons.arrow_drop_down,
                                color: Colors.grey.shade400,
                              ),
                              items: mavCmdMap.keys.map((String cmd) {
                                return DropdownMenuItem<String>(
                                  value: cmd,
                                  child: Text(cmd),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                if (newValue != null) {
                                  setState(() {
                                    _commandEdits[point.id] = newValue;
                                  });
                                  _savePointChanges(point);
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 80,
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
                              controller: TextEditingController(
                                text:
                                    _altitudeEdits[point.id] ?? point.altitude,
                              ),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              onChanged: (value) {
                                _altitudeEdits[point.id] = value;
                              },
                              onSubmitted: (value) {
                                _savePointChanges(point);
                              },
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

          // Footer
          Container(
            height: 56,
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color(0xFF2D2D2D),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(8)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _ActionButton(
                  icon: Icons.clear_all,
                  label: 'Clear Points',
                  onTap: widget.onClearTap,
                  color: Colors.red.shade400,
                ),
                const SizedBox(width: 8),
                _ActionButton(
                  icon: Icons.send,
                  label: 'Send Configs',
                  onTap: () => widget.onSendConfigs(widget.routePoints),
                  color: Colors.teal,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _ActionButton({
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: buttonColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: buttonColor.withOpacity(0.3), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: buttonColor, size: 16),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: buttonColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
