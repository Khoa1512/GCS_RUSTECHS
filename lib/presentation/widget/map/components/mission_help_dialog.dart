import 'package:flutter/material.dart';

class MissionHelpDialog extends StatefulWidget {
  const MissionHelpDialog({super.key});

  @override
  State<MissionHelpDialog> createState() => _MissionHelpDialogState();
}

class _MissionHelpDialogState extends State<MissionHelpDialog>
    with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
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
                    child: Icon(
                      Icons.help_outline,
                      color: Colors.teal,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Hướng dẫn Mission Planning',
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
                tabs: const [
                  Tab(text: 'Bắt đầu'),
                  Tab(text: 'Waypoints'),
                  Tab(text: 'Templates'),
                  Tab(text: 'Gửi Mission'),
                ],
              ),
            ),

            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildGettingStartedTab(),
                  _buildWaypointsTab(),
                  _buildTemplatesTab(),
                  _buildUploadTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGettingStartedTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Chào mừng đến với Mission Planning!'),
          const SizedBox(height: 16),
          _buildInfoCard(
            icon: Icons.flight_takeoff,
            title: 'Mission là gì?',
            description:
                'Mission là một tập hợp các waypoint (điểm bay) được lập trình sẵn để máy bay tự động thực hiện theo đúng thứ tự.',
          ),
          const SizedBox(height: 16),
          _buildInfoCard(
            icon: Icons.map,
            title: 'Cách tạo Mission cơ bản',
            description:
                'Bạn có thể tạo mission bằng cách:\n• Click trực tiếp lên bản đồ\n• Sử dụng nút "Thêm Waypoint"\n• Sử dụng các template có sẵn',
          ),
          const SizedBox(height: 16),
          _buildInfoCard(
            icon: Icons.security,
            title: 'An toàn bay',
            description:
                'Luôn kiểm tra:\n• Độ cao tối thiểu\n• Vùng cấm bay\n• Thời tiết\n• Pin và nhiên liệu',
            color: Colors.orange,
          ),
          const SizedBox(height: 24),
          _buildStepByStepGuide(),
        ],
      ),
    );
  }

  Widget _buildWaypointsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Quản lý Waypoints'),
          const SizedBox(height: 16),
          _buildInfoCard(
            icon: Icons.add_location,
            title: 'Thêm Waypoint',
            description:
                '• Click vào nút "Add WP"\n• Hoặc click trực tiếp lên bản đồ\n• Waypoint sẽ được đánh số tự động',
          ),
          const SizedBox(height: 16),
          _buildInfoCard(
            icon: Icons.edit_location,
            title: 'Chỉnh sửa Waypoint',
            description:
                '• Click vào waypoint trên bản đồ\n• Panel chỉnh sửa sẽ hiện ra\n• Có thể thay đổi:\n  - Độ cao (Altitude)\n  - Tốc độ (Speed)\n  - Thời gian dừng (Delay)\n  - Loại waypoint',
          ),
          const SizedBox(height: 16),
          _buildInfoCard(
            icon: Icons.drag_indicator,
            title: 'Di chuyển Waypoint',
            description:
                '• Kéo thả waypoint trên bản đồ\n• Hoặc nhập tọa độ chính xác',
          ),
          const SizedBox(height: 16),
          _buildInfoCard(
            icon: Icons.delete,
            title: 'Xóa Waypoint',
            description:
                '• Click nút xoá trong panel\n• Có thể chọn nhiều waypoint để xóa',
            color: Colors.red,
          ),
          const SizedBox(height: 16),
          _buildWaypointTypesSection(),
          const SizedBox(height: 16),
          _buildEditPanelSection(),
          const SizedBox(height: 16),
          _buildBatchEditSection(),
        ],
      ),
    );
  }

  Widget _buildTemplatesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Mission Templates'),
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
            icon: Icons.clear_all,
            title: 'Clear All - Xóa tất cả',
            description:
                '• Xóa toàn bộ waypoint\n• Bắt đầu mission mới\n• Có xác nhận để tránh xóa nhầm',
            color: Colors.red,
          ),
          const SizedBox(height: 24),
          _buildTemplateDetailsSection(),
        ],
      ),
    );
  }

  Widget _buildUploadTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Gửi Mission lên Flight Controller'),
          const SizedBox(height: 16),
          _buildInfoCard(
            icon: Icons.upload,
            title: 'Gửi Mission',
            description:
                '• Kiểm tra kết nối với máy bay\n• Nhấn nút "Gửi Mission"\n• Mission sẽ được tải lên Flight Controller\n• Đợi xác nhận thành công',
            color: Colors.teal,
          ),
          const SizedBox(height: 16),
          _buildInfoCard(
            icon: Icons.check_circle,
            title: 'Xác nhận Mission',
            description:
                '• Flight Controller sẽ phản hồi kết quả\n• Kiểm tra thông báo thành công\n• Mission đã sẵn sàng để thực hiện',
            color: Colors.green,
          ),
          const SizedBox(height: 16),
          _buildInfoCard(
            icon: Icons.warning,
            title: 'Xử lý lỗi',
            description:
                '• Nếu upload thất bại:\n  - Kiểm tra kết nối\n  - Thử lại sau vài giây\n  - Kiểm tra mission có hợp lệ\n• Nếu FC từ chối:\n  - Kiểm tra waypoint có hợp lệ\n  - Kiểm tra độ cao, tốc độ',
            color: Colors.orange,
          ),
          const SizedBox(height: 24),
          _buildUploadChecklist(),
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

  Widget _buildStepByStepGuide() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF252525),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.teal.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.list_alt, color: Colors.teal, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Quy trình tạo Mission từng bước',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildStep(1, 'Kết nối với máy bay', 'Đảm bảo kết nối ổn định'),
          _buildStep(
            2,
            'Thêm waypoint',
            'Click trên bản đồ hoặc dùng nút Thêm Waypoint',
          ),
          _buildStep(
            3,
            'Chỉnh sửa thông số',
            'Độ cao, tốc độ cho từng waypoint',
          ),
          _buildStep(4, 'Kiểm tra mission', 'Xem tổng quan và risk level'),
          _buildStep(5, 'Gửi lên FC', 'Nhấn Gửi Mission để upload'),
          _buildStep(6, 'Xác nhận', 'Đợi Flight Controller xác nhận mission'),
        ],
      ),
    );
  }

  Widget _buildStep(int number, String title, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.teal,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$number',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
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

  Widget _buildWaypointTypesSection() {
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
              Icon(Icons.category, color: Colors.blue, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Các loại Waypoint',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildWaypointType(
            'WAYPOINT',
            'Bay đến điểm và tiếp tục',
            Colors.blue,
          ),
          _buildWaypointType(
            'LOITER_TIME',
            'Bay đến và dừng lại',
            Colors.orange,
          ),
          _buildWaypointType('LAND', 'Hạ cánh tại điểm này', Colors.red),
          _buildWaypointType(
            'DO_SET_ROI',
            'Hướng camera về điểm này',
            Colors.purple,
          ),
          _buildWaypointType('RTL', 'Quay về điểm xuất phát', Colors.cyan),
        ],
      ),
    );
  }

  Widget _buildWaypointType(String type, String description, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  type,
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

  Widget _buildUploadChecklist() {
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
                'Checklist trước khi upload',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildChecklistItem('Kết nối ổn định với FC'),
          _buildChecklistItem('Mission có ít nhất 1 waypoint'),
          _buildChecklistItem('Tất cả waypoint có độ cao hợp lý'),
          _buildChecklistItem('Không có waypoint trong vùng cấm bay'),
          _buildChecklistItem('Battery đủ cho toàn bộ mission'),
          _buildChecklistItem('Thời tiết phù hợp để bay'),
        ],
      ),
    );
  }

  Widget _buildChecklistItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(Icons.check_box_outline_blank, color: Colors.green, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditPanelSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF252525),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.indigo.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.edit, color: Colors.indigo, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Edit Panel - Chỉnh sửa Waypoint',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildEditPanelTip(
            'Mở Edit Panel',
            'Click vào bất kỳ waypoint nào trên bản đồ để mở panel chỉnh sửa',
          ),
          _buildEditPanelTip(
            'Thay đổi loại Waypoint',
            'Sử dụng dropdown "Waypoint Type" để chọn loại khác (WAYPOINT, LOITER_TIME, LAND, v.v.)',
          ),
          _buildEditPanelTip(
            'Chỉnh sửa Altitude',
            'Nhập độ cao mong muốn trong trường "Altitude (m)"',
          ),
          _buildEditPanelTip(
            'Điều chỉnh tọa độ',
            'Có thể thay đổi Latitude và Longitude để di chuyển waypoint chính xác',
          ),
          _buildEditPanelTip(
            'Các nút điều khiển',
            '• Cancel: Hủy thay đổi\n• Save: Lưu thay đổi\n• Delete: Xóa waypoint này',
          ),
        ],
      ),
    );
  }

  Widget _buildBatchEditSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF252525),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.deepOrange.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.select_all, color: Colors.deepOrange, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Batch Edit - Chỉnh sửa hàng loạt',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildEditPanelTip(
            'Chọn nhiều Waypoint',
            'Giữ Ctrl (Cmd trên Mac) và click vào các waypoint để chọn nhiều điểm',
          ),
          _buildEditPanelTip(
            'Thay đổi Altitude hàng loạt',
            'Khi đã chọn nhiều waypoint, thay đổi altitude sẽ áp dụng cho tất cả',
          ),
          _buildEditPanelTip(
            'Thay đổi loại hàng loạt',
            'Có thể thay đổi loại waypoint cho tất cả các điểm đã chọn cùng lúc',
          ),
          _buildEditPanelTip(
            'Xóa hàng loạt',
            'Chọn nhiều waypoint và nhấn Delete để xóa tất cả cùng lúc',
          ),
          _buildEditPanelTip(
            'Sắp xếp lại thứ tự',
            'Kéo thả waypoint trong danh sách để thay đổi thứ tự bay',
          ),
        ],
      ),
    );
  }

  Widget _buildEditPanelTip(String title, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_outline, color: Colors.amber, size: 16),
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
}
