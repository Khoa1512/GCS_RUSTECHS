import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../services/http_gimbal_service.dart';

/// Ultra-compact Gimbal Control để overlay lên camera
class GimbalControlCompact extends StatefulWidget {
  final VoidCallback? onClose;

  const GimbalControlCompact({super.key, this.onClose});

  @override
  State<GimbalControlCompact> createState() => _GimbalControlCompactState();
}

class _GimbalControlCompactState extends State<GimbalControlCompact>
    with SingleTickerProviderStateMixin {
  final _httpService = HttpGimbalService();
  late AnimationController _animController;
  String? _currentMode; // Track current mode
  bool _isGimbalConnected = false; // Track gimbal connection status
  bool _isOSDEnabled = false; // Track OSD show/hide status

  @override
  void initState() {
    super.initState();

    // Listen to HTTP service
    _httpService.addListener(_onServiceUpdate);
    // Auto-test connection
    _httpService.testConnection();

    _animController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _animController.forward(); // Auto mở ngay
  }

  @override
  void dispose() {
    _animController.dispose();

    // Remove listener
    _httpService.removeListener(_onServiceUpdate);

    super.dispose();
  }

  void _onServiceUpdate() {
    if (mounted) setState(() {});
  }

  // Không cần toggle nữa - luôn mở rộng

  @override
  Widget build(BuildContext context) {
    // Panel compact, professional
    return Container(
      width: 220,
      constraints: const BoxConstraints(
        maxHeight: 420, // Compact hơn nhờ layout mới
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors: [
            Colors.black.withOpacity(0.95),
            Colors.black.withOpacity(0.90),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.blue.withOpacity(0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.7),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.blue.withOpacity(0.1),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(10),
            child: _buildExpandedView(),
          ),
        ),
      ),
    );
  }

  // Không cần collapsed view nữa - luôn hiện full panel

  Widget _buildExpandedView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with connection
        _buildHeaderWithConnection(),
        const SizedBox(height: 8),

        // Demo Data với labels
        _buildDemoData(),
        const SizedBox(height: 8),

        // Mode selection với label
        _buildSectionLabel('Chế độ:'),
        Row(
          children: [
            Expanded(child: _buildModeButton('Khóa', Icons.lock, false)),
            const SizedBox(width: 5),
            Expanded(
              child: _buildModeButton('Theo dõi', Icons.gps_fixed, false),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Aim & OSD - 2 bên
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSmallActionButton(
              'Aim',
              Icons.my_location,
              false,
              Colors.orange,
            ),
            _buildSmallActionButton(
              'OSD',
              Icons.text_fields,
              _isOSDEnabled,
              Colors.cyan,
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Quick Controls riêng
        _buildSectionLabel('Điều khiển:'),
        _buildQuickControls(),
        const SizedBox(height: 8),

        // PIP với label và mô tả (5 modes: 0-4)
        _buildSectionLabel('PIP:'),
        Row(
          children: [
            Expanded(child: _buildPIPButton(0, 'Tắt')),
            const SizedBox(width: 2),
            Expanded(child: _buildPIPButton(1, 'TR')),
            const SizedBox(width: 2),
            Expanded(child: _buildPIPButton(2, 'TL')),
            const SizedBox(width: 2),
            Expanded(child: _buildPIPButton(3, 'BR')),
            const SizedBox(width: 2),
            Expanded(child: _buildPIPButton(4, 'BL')),
          ],
        ),
      ],
    );
  }

  Widget _buildHeaderWithConnection() {
    final isConnected = _httpService.isConnected;
    const connectionType = 'HTTP';

    return Column(
      children: [
        // Header row
        Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: isConnected ? Colors.green : Colors.orange,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (isConnected ? Colors.green : Colors.orange)
                        .withOpacity(0.5),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Gimbal',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  connectionType,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 8,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const Spacer(),
            // Connect/Disconnect button
            InkWell(
              onTap: () async {
                if (_isGimbalConnected) {
                  // Disconnect from gimbal
                  final success = await _httpService.sendDisconnectCommand();
                  if (success) {
                    setState(() => _isGimbalConnected = false);
                    _showSnackBar('✅ Đã ngắt kết nối gimbal');
                  } else {
                    _showSnackBar('❌ Ngắt kết nối thất bại');
                  }
                } else {
                  final success = await _httpService.sendConnectCommand(
                    ip: '192.168.144.108',
                    port: 2332,
                  );
                  if (success) {
                    setState(() => _isGimbalConnected = true);
                    _showSnackBar('✅ Đã gửi lệnh kết nối gimbal');
                  } else {
                    _showSnackBar('❌ Kết nối thất bại');
                  }
                }
              },
              borderRadius: BorderRadius.circular(4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: (_isGimbalConnected ? Colors.red : Colors.green)
                      .withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: (_isGimbalConnected ? Colors.red : Colors.green)
                        .withOpacity(0.5),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _isGimbalConnected ? 'Ngắt' : 'Kết nối',
                      style: TextStyle(
                        color: _isGimbalConnected ? Colors.red : Colors.green,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
            InkWell(
              onTap: widget.onClose,
              borderRadius: BorderRadius.circular(4),
              child: Container(
                padding: const EdgeInsets.all(2),
                child: const Icon(Icons.close, color: Colors.white60, size: 14),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDemoData() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildDataItem('Pitch:', '-30°'),
          Container(width: 1, height: 20, color: Colors.white.withOpacity(0.2)),
          _buildDataItem('Yaw:', '45°'),
        ],
      ),
    );
  }

  Widget _buildDataItem(String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildModeButton(String label, IconData icon, bool isActive) {
    final isCurrentMode = _currentMode == (label == 'Khóa' ? 'lock' : 'follow');

    return InkWell(
      onTap: () async {
        final mode = label == 'Khóa' ? 'lock' : 'follow';
        debugPrint('🎮 Mode $label');

        final success = mode == 'lock'
            ? await _httpService.sendLockCommand()
            : await _httpService.sendFollowCommand();

        if (success) {
          setState(() => _currentMode = mode);
          // _showSnackBar('✅ Đã gửi lệnh $label');
        } else {
          // _showSnackBar('❌ Gửi lệnh thất bại');
        }
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isCurrentMode
              ? Colors.green.withOpacity(0.25)
              : Colors.grey.withOpacity(0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isCurrentMode
                ? Colors.green.withOpacity(0.6)
                : Colors.grey.withOpacity(0.4),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isCurrentMode ? Colors.green : Colors.grey.shade300,
              size: 13,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isCurrentMode ? Colors.green : Colors.grey.shade300,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildQuickControls() {
    return Column(
      children: [
        // Row 1: Up
        Center(child: _buildControlButton(Icons.arrow_upward, 'Lên')),
        const SizedBox(height: 3),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildControlButton(Icons.arrow_back, 'Trái'),
            const SizedBox(width: 3),
            _buildControlButton(Icons.stop, 'Dừng'),
            const SizedBox(width: 3),
            _buildControlButton(Icons.arrow_forward, 'Phải'),
          ],
        ),
        const SizedBox(height: 3),
        // Row 3: Down
        Center(child: _buildControlButton(Icons.arrow_downward, 'Xuống')),
      ],
    );
  }

  Widget _buildControlButton(IconData icon, String label) {
    return InkWell(
      onTap: () async {
        if (_currentMode == null) {
          _showSnackBar('⚠️ Chọn chế độ Khóa/Theo dõi trước');
          return;
        }

        double pitch = 0, yaw = 0;

        switch (label) {
          case 'Lên':
            pitch = 5.0;
            break;
          case 'Xuống':
            pitch = -5.0;
            break;
          case 'Trái':
            yaw = -10.0;
            break;
          case 'Phải':
            yaw = 10.0;
            break;
          case 'Dừng':
            pitch = 0;
            yaw = 0;
            break;
        }

        await _httpService.sendVelocityCommand(
          mode: _currentMode ?? 'lock',
          pitch: pitch,
          yaw: yaw,
        );

        debugPrint('🎮 Control $label: p=$pitch, y=$yaw');
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 46,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.2),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.blue.withOpacity(0.4), width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.blue.shade300, size: 14),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: Colors.blue.shade300,
                fontSize: 7,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPIPButton(int mode, String label) {
    return InkWell(
      onTap: () async {
        await _httpService.sendPIPCommand(mode: mode);
        debugPrint('🎮 PIP $mode - $label');
      },
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 5),
        decoration: BoxDecoration(
          color: Colors.purple.withOpacity(0.25),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.purple.withOpacity(0.5), width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$mode',
              style: TextStyle(
                color: Colors.purple.shade200,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (label != 'Tắt')
              Text(
                label,
                style: TextStyle(
                  color: Colors.purple.shade300,
                  fontSize: 7,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white60,
          fontSize: 9,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSmallActionButton(
    String label,
    IconData icon,
    bool isActive,
    Color baseColor,
  ) {
    return InkWell(
      onTap: () async {
        if (label == 'OSD') {
          // Toggle OSD state
          final newOSDState = !_isOSDEnabled;
          final success = await _httpService.sendOSDCommand(show: newOSDState);
          if (success) {
            setState(() => _isOSDEnabled = newOSDState);
            _showSnackBar('✅ OSD ${newOSDState ? "hiện" : "ẩn"}');
          } else {
            _showSnackBar('❌ Gửi lệnh OSD thất bại');
          }
        } else if (label == 'Aim') {
          // Click to aim - center of screen (5000, 5000)
          await _httpService.sendClickToAimCommand(x: 5000, y: 5000);
        }
        debugPrint('🎮 $label toggle');
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 90, // Rộng hơn để chứa text dễ đọc
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: BoxDecoration(
          color: isActive
              ? baseColor.withOpacity(0.25)
              : Colors.grey.withOpacity(0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isActive
                ? baseColor.withOpacity(0.6)
                : Colors.grey.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isActive ? baseColor : Colors.grey.shade500,
              size: 13,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isActive ? baseColor : Colors.grey.shade500,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
