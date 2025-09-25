import 'package:flutter/material.dart';
import 'package:skylink/data/models/route_point_model.dart';

class WaypointContextMenu extends StatelessWidget {
  final RoutePoint waypoint;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Function(int commandType) onConvertType;
  final Offset position;

  const WaypointContextMenu({
    super.key,
    required this.waypoint,
    required this.onEdit,
    required this.onDelete,
    required this.onConvertType,
    required this.position,
  });

  @override
  Widget build(BuildContext context) {
    // Ensure menu doesn't go off screen
    final screenSize = MediaQuery.of(context).size;
    double left = position.dx;
    double top = position.dy;

    const menuWidth = 180.0;
    const menuHeight = 250.0; // Approximate height

    // Adjust horizontal position
    if (left + menuWidth > screenSize.width) {
      left = screenSize.width - menuWidth - 16;
    }
    if (left < 16) {
      left = 16;
    }

    // Adjust vertical position
    if (top + menuHeight > screenSize.height) {
      top = top - menuHeight - 20; // Show above
    }
    if (top < 16) {
      top = 16;
    }

    return Positioned(
      left: left,
      top: top,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(8),
        color: const Color(0xFF2D2D2D),
        child: Container(
          width: menuWidth,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Icon(Icons.place, color: Colors.teal, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Waypoint ${waypoint.order}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(color: Colors.grey, height: 1),

              // Edit option
              _buildMenuItem(icon: Icons.edit, label: 'Edit', onTap: onEdit),

              // Convert type submenu
              _buildSubmenuItem(
                icon: Icons.transform,
                label: 'Convert Type',
                children: [
                  _buildMenuItem(
                    icon: Icons.place,
                    label: 'Waypoint',
                    onTap: () => onConvertType(16),
                    isSubItem: true,
                  ),
                  _buildMenuItem(
                    icon: Icons.camera_alt,
                    label: 'Do Set ROI',
                    onTap: () => onConvertType(201),
                    isSubItem: true,
                  ),
                  _buildMenuItem(
                    icon: Icons.access_time,
                    label: 'Loiter Time',
                    onTap: () => onConvertType(19),
                    isSubItem: true,
                  ),
                  _buildMenuItem(
                    icon: Icons.flight_land,
                    label: 'Land',
                    onTap: () => onConvertType(21),
                    isSubItem: true,
                  ),
                ],
              ),

              const Divider(color: Colors.grey, height: 1),

              // Delete option
              _buildMenuItem(
                icon: Icons.delete,
                label: 'Delete',
                onTap: onDelete,
                color: Colors.red,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = Colors.white,
    bool isSubItem = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isSubItem ? 32 : 16,
          vertical: 12,
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(color: color, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmenuItem({
    required IconData icon,
    required String label,
    required List<Widget> children,
  }) {
    return ExpansionTile(
      leading: Icon(icon, color: Colors.white, size: 16),
      title: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 14),
      ),
      iconColor: Colors.white,
      collapsedIconColor: Colors.white,
      childrenPadding: EdgeInsets.zero,
      children: children,
    );
  }
}
