import 'package:flutter/material.dart';

class MissionHelpDialog extends StatefulWidget {
  final VoidCallback? onReadyToSend;

  const MissionHelpDialog({super.key, this.onReadyToSend});

  @override
  State<MissionHelpDialog> createState() => _MissionHelpDialogState();
}

class _MissionHelpDialogState extends State<MissionHelpDialog>
    with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.85,
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.teal.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF252525),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.teal.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.help_outline,
                      color: Colors.teal,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Hướng dẫn thiết lập kế hoạch bay',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.grey),
                  ),
                ],
              ),
            ),

            // Tab bar
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                border: Border(
                  bottom: BorderSide(color: Colors.teal.withOpacity(0.3)),
                ),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorColor: Colors.teal,
                labelColor: Colors.teal,
                unselectedLabelColor: Colors.grey,
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(
                    icon: Icon(Icons.rocket_launch, size: 20),
                    text: 'Cơ bản',
                  ),
                  Tab(icon: Icon(Icons.settings, size: 20), text: 'Nâng cao'),
                  Tab(
                    icon: Icon(Icons.checklist, size: 20),
                    text: 'Trước khi bay',
                  ),
                ],
              ),
            ),

            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildBasicTab(),
                  _buildAdvancedTab(),
                  _buildPreFlightTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Tab "Cơ bản" - 5 bước step-by-step
  Widget _buildBasicTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('5 bước tạo Mission cơ bản'),
          const SizedBox(height: 24),

          // 5 steps
          _buildStep(
            Icons.connect_without_contact,
            'Kết nối Flight Controller',
            'Đảm bảo kết nối ổn định với máy bay',
            Colors.blue,
          ),
          const SizedBox(height: 16),
          _buildStep(
            Icons.add_location,
            'Thêm điểm bay',
            '• Click trực tiếp trên bản đồ để thêm waypoint\n• Hoặc dùng nút "Thêm waypoint" để nhập tọa độ chính xác',
            Colors.green,
          ),
          const SizedBox(height: 16),
          _buildStep(
            Icons.tune,
            'Chỉnh sửa thông số',
            '• Chỉnh sửa từng điểm: Click vào 1 waypoint\n• Chỉnh sửa nhiều điểm: Giữ Ctrl/Cmd + click để chọn nhiều waypoint\n• Có thể thay đổi: Loại lệnh bay, độ cao, tốc độ, thời gian dừng, và các thông số khác tùy theo loại lệnh',
            Colors.orange,
          ),
          const SizedBox(height: 16),
          _buildStep(
            Icons.preview,
            'Xem trước kế hoạch bay',
            'Kiểm tra đường bay và tổng quan kế hoạch bay',
            Colors.purple,
          ),
          const SizedBox(height: 16),
          _buildStep(
            Icons.send,
            'Gửi lên máy bay',
            'Upload kế hoạch bay và sẵn sàng thực hiện',
            Colors.teal,
          ),

          const SizedBox(height: 32),

          // Map illustration placeholder
          _buildMapIllustration(),
        ],
      ),
    );
  }

  Widget _buildMapIllustration() {
    return Container(
      height: 550,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF252525),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.teal.withOpacity(0.3)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            Expanded(
              child: Image.asset(
                'assets/images/mission_demo.png',
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.map, color: Colors.teal, size: 48),
                        SizedBox(height: 8),
                        Text(
                          'Minh họa bản đồ kế hoạch bay',
                          style: TextStyle(color: Colors.white60, fontSize: 14),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.black.withOpacity(0.7)),
              child: const Center(
                child: Text(
                  'Ví dụ: Kế hoạch bay với waypoints và đường bay',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Tính năng nâng cao'),
          const SizedBox(height: 16),
          _buildInfoCard(
            icon: Icons.rotate_right,
            title: 'Orbit - Bay vòng tròn',
            description:
                '• Click nút "Orbit"\n• Chọn điểm trung tâm trên bản đồ\n• Thiết lập bán kính và số vòng\n• Phù hợp cho: quan sát, chụp ảnh góc',
            color: Colors.blue,
          ),
          const SizedBox(height: 16),
          _buildInfoCard(
            icon: Icons.grid_on,
            title: 'Survey - Khảo sát khu vực',
            description:
                '• Click nút "Survey"\n• Chọn điểm trung tâm khu vực\n• Thiết lập kích thước và độ phủ\n• Tạo đường bay zigzag tự động\n• Phù hợp cho: chụp ảnh mapping, khảo sát',
            color: Colors.green,
          ),
          const SizedBox(height: 16),
          _buildInfoCard(
            icon: Icons.camera_alt,
            title: 'Do Set ROI - Điểm quan sát',
            description:
                '• Chọn loại lệnh "Do Set ROI"\n• Đặt điểm mà camera sẽ hướng về\n• Máy bay sẽ điều chỉnh gimbal tự động\n• Phù hợp cho: theo dõi mục tiêu, chụp ảnh định hướng',
            color: Colors.purple,
          ),
          const SizedBox(height: 16),
          _buildInfoCard(
            icon: Icons.settings,
            title: 'Lệnh MAVLink tùy chỉnh',
            description:
                '• WAYPOINT: Bay đến điểm và tiếp tục\n• LOITER_TIME: Bay đến và dừng lại\n• LAND: Hạ cánh tại điểm này\n• RETURN_TO_LAUNCH: Quay về điểm xuất phát\n• DO_SET_ROI: Hướng camera về điểm',
            color: Colors.orange,
          ),
          const SizedBox(height: 24),
          _buildTemplateDetailsSection(),
        ],
      ),
    );
  }

  Widget _buildPreFlightTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Checklist trước khi bay'),
          const SizedBox(height: 16),
          _buildPreFlightSection(),
          const SizedBox(height: 24),
          _buildSafetySection(),
          const SizedBox(height: 24),
          _buildMissionValidationSection(),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String description,
    Color color = Colors.teal,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF252525),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreFlightSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF252525),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.checklist, color: Colors.green, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Checklist thiết bị',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildChecklistItem('Pin máy bay đầy đủ', false),
          _buildChecklistItem('Kết nối telemetry ổn định', false),
          _buildChecklistItem('GPS lock tối thiểu 8 vệ tinh', false),
          _buildChecklistItem('Compass calibrated', false),
          _buildChecklistItem('Prop không bị hỏng', false),
          _buildChecklistItem('Camera/gimbal hoạt động', false),
        ],
      ),
    );
  }

  Widget _buildSafetySection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF252525),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning, color: Colors.orange, size: 20),
              const SizedBox(width: 8),
              const Text(
                'An toàn bay',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildChecklistItem('Kiểm tra vùng cấm bay', false),
          _buildChecklistItem('Thời tiết phù hợp (<10m/s gió)', false),
          _buildChecklistItem('Có người quan sát VLOS', false),
          _buildChecklistItem('Thiết lập Return-to-Home', false),
          _buildChecklistItem('Khu vực hạ cánh an toàn', false),
        ],
      ),
    );
  }

  Widget _buildMissionValidationSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF252525),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.rule, color: Colors.blue, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Kiểm tra Mission',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildChecklistItem('Mission có ít nhất 1 waypoint', false),
          _buildChecklistItem('Độ cao phù hợp (>5m, <120m)', false),
          _buildChecklistItem('Tốc độ hợp lý (<15m/s)', false),
          _buildChecklistItem('Khoảng cách giữa WP phù hợp', false),
          _buildChecklistItem('Pin đủ cho toàn mission + 20%', false),
        ],
      ),
    );
  }

  Widget _buildStep(
    IconData icon,
    String title,
    String description,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF252525),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Center(child: Icon(icon, color: color, size: 20)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateDetailsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF252525),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tips_and_updates, color: Colors.purple, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Mẹo sử dụng Templates',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildTip(
            'Orbit Template',
            'Phù hợp để quan sát một điểm cố định, chụp ảnh 360°',
          ),
          _buildTip(
            'Survey Template',
            'Tốt nhất cho mapping, chụp ảnh diện rộng',
          ),
          _buildTip(
            'Kết hợp Templates',
            'Có thể dùng nhiều template trong cùng một mission',
          ),
          _buildTip(
            'Tùy chỉnh sau khi tạo',
            'Có thể chỉnh sửa waypoint sau khi tạo từ template',
          ),
        ],
      ),
    );
  }

  Widget _buildTip(String title, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_outline, color: Colors.yellow, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  description,
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChecklistItem(String text, [bool isChecked = false]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            isChecked ? Icons.check_box : Icons.check_box_outline_blank,
            color: isChecked ? Colors.green : Colors.grey,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: isChecked ? Colors.white : Colors.white70,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
