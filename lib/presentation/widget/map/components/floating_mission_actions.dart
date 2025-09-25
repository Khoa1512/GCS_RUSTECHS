import 'package:flutter/material.dart';

class FloatingMissionActions extends StatelessWidget {
  final VoidCallback? onAddWaypoint;
  final VoidCallback? onOrbitTemplate;
  final VoidCallback? onSurveyTemplate;
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
  final VoidCallback? onClearMission;
  final bool canUndo;
  final bool canRedo;

  const FloatingMissionActions({
    super.key,
    this.onAddWaypoint,
    this.onOrbitTemplate,
    this.onSurveyTemplate,
    this.onUndo,
    this.onRedo,
    this.onClearMission,
    this.canUndo = false,
    this.canRedo = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Action buttons group
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF2D2D2D),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildActionButton(
                icon: Icons.add_location,
                label: 'Add WP',
                onPressed: onAddWaypoint,
                color: Colors.green,
              ),
              const Divider(height: 1, color: Colors.grey),
              _buildActionButton(
                icon: Icons.track_changes,
                label: 'Orbit',
                onPressed: onOrbitTemplate,
                color: Colors.blue,
              ),
              const Divider(height: 1, color: Colors.grey),
              _buildActionButton(
                icon: Icons.grid_on,
                label: 'Survey',
                onPressed: onSurveyTemplate,
                color: Colors.purple,
              ),
              const Divider(height: 1, color: Colors.grey),
              _buildActionButton(
                icon: Icons.delete_sweep,
                label: 'Clear',
                onPressed: onClearMission,
                color: Colors.red,
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Undo/Redo buttons
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF2D2D2D),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildIconButton(
                icon: Icons.undo,
                onPressed: canUndo ? onUndo : null,
                tooltip: 'Undo',
              ),
              const VerticalDivider(width: 1, color: Colors.grey),
              _buildIconButton(
                icon: Icons.redo,
                onPressed: canRedo ? onRedo : null,
                tooltip: 'Redo',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    required Color color,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: onPressed != null ? color : Colors.grey,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: onPressed != null ? Colors.white : Colors.grey,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(12),
            child: Icon(
              icon,
              color: onPressed != null ? Colors.white : Colors.grey,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}
