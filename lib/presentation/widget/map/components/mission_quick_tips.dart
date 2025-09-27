import 'package:flutter/material.dart';

class MissionQuickTips extends StatefulWidget {
  final int waypointCount;
  final VoidCallback? onShowFullGuide;

  const MissionQuickTips({
    super.key,
    required this.waypointCount,
    this.onShowFullGuide,
  });

  @override
  State<MissionQuickTips> createState() => _MissionQuickTipsState();
}

class _MissionQuickTipsState extends State<MissionQuickTips> {
  bool isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.teal.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          // Header
          GestureDetector(
            onTap: () => setState(() => isExpanded = !isExpanded),
            child: Container(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.lightbulb_outline, color: Colors.yellow, size: 16),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Mẹo nhanh',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          // Expandable content
          if (isExpanded) ...[
            const Divider(height: 1, color: Colors.grey),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ..._getTipsForCurrentState(),
                  const SizedBox(height: 8),
                  if (widget.onShowFullGuide != null)
                    GestureDetector(
                      onTap: widget.onShowFullGuide,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.teal.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.help_outline,
                              color: Colors.teal,
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'Xem hướng dẫn đầy đủ',
                              style: TextStyle(
                                color: Colors.teal,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _getTipsForCurrentState() {
    if (widget.waypointCount == 0) {
      return [
        _buildTip(
          'Click trên bản đồ để thêm waypoint đầu tiên',
          Icons.touch_app,
        ),
        _buildTip('Dùng nút "Thêm waypoint" để thêm điểm bay', Icons.add_location),
        _buildTip(
          'Thử template Orbit/Survey cho mission phức tạp',
          Icons.auto_awesome,
        ),
      ];
    } else if (widget.waypointCount < 3) {
      return [
        _buildTip('Click vào waypoint để chỉnh sửa', Icons.edit),
        _buildTip('Kéo thả để di chuyển waypoint', Icons.drag_indicator),
        _buildTip('Thêm waypoint để tạo đường bay', Icons.add_location),
      ];
    } else {
      return [
        _buildTip('Kiểm tra độ cao và tốc độ các waypoint', Icons.speed),
        _buildTip('Xem tổng quan mission ở phần tổng quan', Icons.analytics),
        _buildTip('Nhấn "Gửi Mission" để gửi lên FC', Icons.upload),
      ];
    }
  }

  Widget _buildTip(String text, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.teal, size: 12),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MissionProgressTips extends StatelessWidget {
  final int waypointCount;
  final bool isConnected;
  final VoidCallback? onShowGuide;

  const MissionProgressTips({
    super.key,
    required this.waypointCount,
    required this.isConnected,
    this.onShowGuide,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.teal.withOpacity(0.1), Colors.teal.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.teal.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_getProgressIcon(), color: Colors.teal, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _getProgressTitle(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (onShowGuide != null)
                GestureDetector(
                  onTap: onShowGuide,
                  child: Icon(Icons.help_outline, color: Colors.teal, size: 16),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _getProgressMessage(),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          _buildProgressBar(),
        ],
      ),
    );
  }

  IconData _getProgressIcon() {
    if (waypointCount == 0) return Icons.flight_takeoff;
    if (waypointCount < 3) return Icons.route;
    if (!isConnected) return Icons.wifi_off;
    return Icons.check_circle;
  }

  String _getProgressTitle() {
    if (waypointCount == 0) return 'Bắt đầu tạo Mission';
    if (waypointCount < 3) return 'Đang xây dựng Mission';
    if (!isConnected) return 'Cần kết nối với máy bay';
    return 'Mission sẵn sàng!';
  }

  String _getProgressMessage() {
    if (waypointCount == 0) {
      return 'Thêm waypoint đầu tiên để bắt đầu mission của bạn.';
    }
    if (waypointCount < 3) {
      return 'Thêm waypoint và chỉnh sửa thông số để hoàn thiện mission.';
    }
    if (!isConnected) {
      return 'Kết nối với Flight Controller để gửi mission lên máy bay.';
    }
    return 'Mission đã hoàn tất! Có thể gửi lên Flight Controller.';
  }

  Widget _buildProgressBar() {
    double progress = 0.0;
    if (waypointCount > 0) progress = 0.3;
    if (waypointCount >= 3) progress = 0.7;
    if (waypointCount >= 3 && isConnected) progress = 1.0;

    return Container(
      height: 4,
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.3),
        borderRadius: BorderRadius.circular(2),
      ),
      child: FractionallySizedBox(
        widthFactor: progress,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.teal,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}
