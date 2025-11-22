import 'package:flutter/material.dart';
import 'package:skylink/presentation/widget/map/components/mission_tooltip.dart';

class FloatingMissionActions extends StatelessWidget {
  final VoidCallback? onAddWaypoint;
  final VoidCallback? onOrbitTemplate;
  final VoidCallback? onSurveyTemplate;
  final VoidCallback? onPolygonSurvey;
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
    this.onPolygonSurvey,
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
              MissionTooltip(
                message: 'Thêm Waypoint',
                description:
                    'Click để thêm điểm bay mới. Bạn cũng có thể click trực tiếp lên bản đồ.',
                icon: Icons.add_location,
                color: Colors.green,
                child: _buildActionButton(
                  icon: Icons.add_location,
                  label: 'Thêm Waypoint',
                  onPressed: onAddWaypoint,
                  color: Colors.green,
                ),
              ),
              const Divider(height: 1, color: Colors.grey),
              MissionTooltip(
                message: 'Orbit Template',
                description:
                    'Tạo đường bay vòng tròn quanh một điểm. Phù hợp cho quan sát, chụp ảnh 360°.',
                icon: Icons.track_changes,
                color: Colors.blue,
                child: _buildActionButton(
                  icon: Icons.track_changes,
                  label: 'Orbit',
                  onPressed: onOrbitTemplate,
                  color: Colors.blue,
                ),
              ),
              const Divider(height: 1, color: Colors.grey),
              _buildActionButton(
                icon: Icons.crop_square,
                label: 'Survey Box',
                onPressed: onSurveyTemplate,
                color: Colors.teal,
              ),
              const Divider(height: 1, color: Colors.grey),
              _buildActionButton(
                icon: Icons.polyline,
                label: 'Survey Polygon',
                onPressed: onPolygonSurvey,
                color: Colors.purple,
              ),
              const Divider(height: 1, color: Colors.grey),
              MissionTooltip(
                message: 'Xoá nhiệm vụ',
                description:
                    'Xóa toàn bộ điểm bay và bắt đầu mission mới. Sẽ có xác nhận trước khi xóa.',
                icon: Icons.delete_sweep,
                color: Colors.red,
                child: _buildActionButton(
                  icon: Icons.delete_sweep,
                  label: 'Xoá tất cả',
                  onPressed: onClearMission,
                  color: Colors.red,
                ),
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
                tooltip: 'Hoàn tác',
              ),
              const VerticalDivider(width: 1, color: Colors.grey),
              _buildIconButton(
                icon: Icons.redo,
                onPressed: canRedo ? onRedo : null,
                tooltip: 'Làm lại',
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
