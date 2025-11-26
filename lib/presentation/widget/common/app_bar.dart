import 'package:flutter/material.dart';
import 'package:skylink/services/telemetry_service.dart';
import 'dart:async';

class QGCAppBar extends StatefulWidget implements PreferredSizeWidget {
  final Function(String)? onSettingsChanged;

  const QGCAppBar({super.key, this.onSettingsChanged});

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  State<QGCAppBar> createState() => _QGCAppBarState();
}

class _QGCAppBarState extends State<QGCAppBar> {
  bool _showConnectionDropdown = false;
  final GlobalKey _connectionButtonKey = GlobalKey();
  OverlayEntry? _connectionOverlayEntry;

  // Port selection overlay system with LayerLink for highest z-order
  final LayerLink _portLayerLink = LayerLink();
  OverlayEntry? _portOverlayEntry;

  // Connection related variables
  List<String> _availablePorts = [];
  String? _selectedPort;
  bool _isConnecting = false;
  bool _isWaitingForData = false;
  Timer? _progressTimer;
  double _progressValue = 0.0;
  StreamSubscription? _dataSubscription;
  StreamSubscription? _connectionSubscription;
  void Function(void Function())?
  _dropdownSetState; // Thêm reference cho dropdown state

  @override
  void initState() {
    super.initState();
    _loadAvailablePorts();

    // Listen to connection changes to rebuild dropdown if open
    _connectionSubscription = TelemetryService().connectionStream.listen((
      isConnected,
    ) {
      if (_showConnectionDropdown) {
        // Force rebuild dropdown by closing and reopening
        _hideConnectionDropdown();
        Future.delayed(const Duration(milliseconds: 50), () {
          if (mounted) {
            _showConnectionDropdownMenu();
          }
        });
      }
    });
  }

  void _loadAvailablePorts() {
    final telemetryService = TelemetryService();
    setState(() {
      final allPorts = telemetryService.getAvailablePorts();

      _availablePorts = allPorts.where((port) {
        // Keep USB serial ports (typically flight controllers)
        if (port.contains('usbserial') || port.contains('usbmodem')) {
          return true;
        }

        // Keep known flight controller port patterns
        if (port.contains('SLAB_') ||
            port.contains('CH340') ||
            port.contains('CP210') ||
            port.contains('FTDI')) {
          return true;
        }

        // Keep ttyUSB and ttyACM (Linux)
        if (port.contains('ttyUSB') || port.contains('ttyACM')) {
          return true;
        }

        // Keep COM ports (Windows) but exclude system ones
        if (port.startsWith('COM') &&
            !port.contains('COM1') &&
            !port.contains('COM2')) {
          return true;
        }

        // For development: keep any remaining /dev/cu. ports that might be FC
        if (!port.startsWith('/dev/cu.') &&
            !port.contains('Bluetooth') &&
            !port.contains('debug') &&
            !port.contains('console')) {
          return true;
        }

        return false;
      }).toList();

      // If no filtered ports and we had ports before, keep the previous selection
      if (_availablePorts.isEmpty &&
          _selectedPort != null &&
          allPorts.contains(_selectedPort)) {
        _availablePorts = [_selectedPort!];
      }

      // Auto-select first available port if none selected
      if (_availablePorts.isNotEmpty &&
          (_selectedPort == null || !_availablePorts.contains(_selectedPort))) {
        _selectedPort = _availablePorts.first;
      } else if (_availablePorts.isEmpty) {
        _selectedPort = null;
      }
    });
  }

  /// Show port selection menu with highest z-order using root overlay
  void _showPortSelectionMenu() {
    // Không cho phép chọn cổng khác khi đã kết nối
    if (TelemetryService().isConnected) {
      return;
    }

    // remove nếu đã có
    _removePortOverlay();

    // lấy render box của trigger (nút chọn cổng)
    final renderBox =
        _connectionButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) {
      // fallback: show ở giữa màn hình nếu không lấy được vị trí
      final screen = MediaQuery.of(context).size;
      final fallbackLeft = (screen.width - 280) / 2;
      final fallbackTop = (screen.height - 200) / 2;

      _portOverlayEntry = OverlayEntry(
        builder: (_) {
          return Positioned(
            left: fallbackLeft,
            top: fallbackTop,
            child: Material(
              elevation: 25,
              borderRadius: BorderRadius.circular(12),
              color: Colors.grey.shade800,
              child: Container(
                width: 250,
                height: 200,
                padding: const EdgeInsets.all(16),
                child: const Text(
                  'Port Selection Menu',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          );
        },
      );
      Overlay.of(context, rootOverlay: true).insert(_portOverlayEntry!);
      return;
    }

    // thông số menu
    const double menuWidth = 220;
    const double menuMaxHeight = 300;
    const double margin = 8;

    // toạ độ toàn cục của trigger
    final targetGlobal = renderBox.localToGlobal(Offset.zero);
    final triggerSize = renderBox.size;

    double left = targetGlobal.dx + triggerSize.width - menuWidth - 40;

    // nếu left quá nhỏ (tràn trái) -> clamp
    if (left < margin) left = margin;

    final screenWidth = MediaQuery.of(context).size.width;
    // nếu menu tràn phải -> clamp sang trái
    if (left + menuWidth > screenWidth - margin) {
      left = screenWidth - menuWidth - margin;
      if (left < margin) left = margin; // extra safety
    }

    double top = targetGlobal.dy + triggerSize.height + 160;

    final screenHeight = MediaQuery.of(context).size.height;
    if (top + menuMaxHeight > screenHeight - margin) {
      // nếu đủ chỗ để show ở trên trigger:
      final aboveTop =
          targetGlobal.dy -
          menuMaxHeight -
          20; // Cũng tăng khoảng cách cho consistent
      if (aboveTop >= margin) {
        top = aboveTop;
      } else {
        // nếu không đủ chỗ cả trên lẫn dưới -> đặt top sao cho không tràn dưới
        top = (screenHeight - menuMaxHeight) - margin;
        if (top < margin) top = margin; // safety
      }
    }

    _portOverlayEntry = OverlayEntry(
      builder: (context) => Material(
        type: MaterialType.transparency,
        child: Stack(
          children: [
            // barrier để bắt tap ngoài
            Positioned.fill(
              child: GestureDetector(
                onTap: _removePortOverlay,
                behavior: HitTestBehavior.translucent,
                child: Container(color: Colors.transparent),
              ),
            ),

            // menu ở vị trí đã tính
            Positioned(
              left: left,
              top: top,
              child: Material(
                elevation: 25,
                borderRadius: BorderRadius.circular(12),
                color: Colors.transparent,
                child: Container(
                  width: menuWidth,
                  constraints: const BoxConstraints(maxHeight: menuMaxHeight),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade800,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.blue.withOpacity(0.3),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: _buildPortListContent(), // tách nhỏ phần UI để rõ ràng
                ),
              ),
            ),
          ],
        ),
      ),
    );

    Overlay.of(context, rootOverlay: true).insert(_portOverlayEntry!);
  }

  // Ví dụ helper: phần UI của menu (tách ra để code trên ngắn gọn)
  Widget _buildPortListContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.usb, color: Colors.blue.shade300, size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Chọn cổng Serial',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(color: Colors.grey, height: 1, indent: 12, endIndent: 12),
        if (_availablePorts.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Không tìm thấy cổng nào',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          )
        else
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _availablePorts.length,
              itemBuilder: (context, index) {
                final port = _availablePorts[index];
                final isSelected = port == _selectedPort;
                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedPort = port;
                    });
                    _removePortOverlay();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.blue.withOpacity(0.2) : null,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelected ? Icons.check_circle : Icons.usb,
                          color: isSelected
                              ? Colors.blue.shade300
                              : Colors.grey[400],
                          size: 16,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            port,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.grey[300],
                              fontSize: 13,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  /// Safely remove port overlay
  void _removePortOverlay() {
    _portOverlayEntry?.remove();
    _portOverlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.grey.shade900, Colors.grey.shade800],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: Border(
          bottom: BorderSide(
            color: Colors.blue.withValues(alpha: 0.4),
            width: 2,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // App Logo & Title - Rustech
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                // Logo Container with modern design
                Container(
                  width: 50,
                  height: 50,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade700, Colors.blue.shade900],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.blue.withValues(alpha: 0.5),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.4),
                        offset: const Offset(0, 4),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        offset: const Offset(0, 2),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      'assets/images/logo.png',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.precision_manufacturing_rounded,
                          size: 40,
                          color: Colors.white,
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Company Name & App Title
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Text(
                          'RUSTECH',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            shadows: [
                              Shadow(
                                color: Colors.blue.withOpacity(0.5),
                                offset: const Offset(0, 1),
                                blurRadius: 3,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.blue.shade400,
                                Colors.cyan.shade400,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'GCS',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    // Subtitle
                    Text(
                      'Ground Control Station ',
                      style: TextStyle(
                        color: Colors.cyan.shade300,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Spacer(),
          _buildConnectionButton(context),

          const SizedBox(width: 12),
          _buildSettingsButton(context),

          const SizedBox(width: 20),
        ],
      ),
    );
  }

  Widget _buildConnectionButton(BuildContext context) {
    return StreamBuilder<bool>(
      stream: TelemetryService().connectionStream,
      builder: (context, snapshot) {
        final isConnected = snapshot.data ?? false;

        return GestureDetector(
          key: _connectionButtonKey,
          onTap: () {
            _toggleConnectionDropdown();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isConnected
                    ? [Colors.green.shade600, Colors.green.shade700]
                    : [Colors.red.shade600, Colors.red.shade700],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(
                color: isConnected
                    ? Colors.green.withValues(alpha: 0.5)
                    : Colors.red.withValues(alpha: 0.5),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: isConnected
                      ? Colors.green.withValues(alpha: 0.3)
                      : Colors.red.withValues(alpha: 0.3),
                  offset: const Offset(0, 2),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  isConnected ? 'Đã kết nối' : 'Kết nối',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _toggleConnectionDropdown() {
    if (_showConnectionDropdown) {
      _hideConnectionDropdown();
    } else {
      _showConnectionDropdownMenu();
    }
  }

  void _showConnectionDropdownMenu() {
    final RenderBox? renderBox =
        _connectionButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    _connectionOverlayEntry = OverlayEntry(
      builder: (context) => Material(
        type: MaterialType.transparency,
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: _hideConnectionDropdown,
                child: Container(color: Colors.transparent),
              ),
            ),
            // Connection dropdown menu
            Positioned(
              top: offset.dy + size.height + 12,
              left: offset.dx - 140,
              child: Material(
                elevation: 20, // Lower than port selection (25)
                borderRadius: BorderRadius.circular(12),
                color: Colors.grey.shade900,
                shadowColor: Colors.black.withValues(alpha: 0.5),
                child: StatefulBuilder(
                  builder: (context, setDropdownState) {
                    // Lưu reference để có thể cập nhật UI từ timer
                    _dropdownSetState = setDropdownState;
                    return Container(
                      width: 300,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.blue.withValues(alpha: 0.3),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.settings_input_antenna,
                                  color: Colors.blue.shade300,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Kết nối Drone',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Port selection with CompositedTransformTarget
                          const Text(
                            'Cổng Serial:',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: StreamBuilder<bool>(
                                  stream: TelemetryService().connectionStream,
                                  builder: (context, snapshot) {
                                    final isConnected = snapshot.data ?? false;

                                    return CompositedTransformTarget(
                                      link: _portLayerLink,
                                      child: InkWell(
                                        onTap: isConnected
                                            ? null
                                            : _showPortSelectionMenu, // Vô hiệu hóa khi đã kết nối
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 12,
                                          ),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: isConnected
                                                  ? Colors.grey.shade700
                                                  : Colors.grey.shade600,
                                            ),
                                            color: isConnected
                                                ? Colors
                                                      .grey
                                                      .shade900 // Tối hơn khi disabled
                                                : Colors.grey.shade800,
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  _selectedPort ?? 'Chọn cổng',
                                                  style: TextStyle(
                                                    color: isConnected
                                                        ? Colors
                                                              .grey
                                                              .shade500 // Mờ hơn khi disabled
                                                        : _selectedPort != null
                                                        ? Colors.white
                                                        : Colors.grey,
                                                    fontSize: 14,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              Icon(
                                                Icons.arrow_drop_down,
                                                color: isConnected
                                                    ? Colors
                                                          .grey
                                                          .shade600 // Mờ hơn khi disabled
                                                    : Colors.grey.shade400,
                                                size: 20,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              StreamBuilder<bool>(
                                stream: TelemetryService().connectionStream,
                                builder: (context, snapshot) {
                                  final isConnected = snapshot.data ?? false;

                                  return IconButton(
                                    icon: Icon(
                                      Icons.refresh,
                                      color: isConnected
                                          ? Colors.grey.shade600
                                          : Colors.blue.shade300,
                                      size: 18,
                                    ),
                                    onPressed: isConnected
                                        ? null
                                        : _loadAvailablePorts,
                                    tooltip: isConnected
                                        ? null
                                        : 'Làm mới danh sách cổng',
                                    style: IconButton.styleFrom(
                                      backgroundColor: isConnected
                                          ? Colors.grey.shade900
                                          : Colors.grey.shade800,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        side: BorderSide(
                                          color: isConnected
                                              ? Colors.grey.shade700
                                              : Colors.grey.shade600,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Progress bar (show when waiting for data)
                          if (_isWaitingForData) ...[
                            Container(
                              width: double.infinity,
                              height: 8,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                                color: Colors.grey.shade700,
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: _progressValue,
                                  backgroundColor: Colors.transparent,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.green,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Đang chờ dữ liệu từ drone... ${(_progressValue * 100).toStringAsFixed(0)}%',
                              style: TextStyle(
                                color: Colors.green.shade300,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                          ],

                          // Connect/Disconnect button
                          StreamBuilder<bool>(
                            stream: TelemetryService().connectionStream,
                            initialData: TelemetryService()
                                .isConnected, // Force initial state
                            builder: (context, snapshot) {
                              final isConnected =
                                  snapshot.data ??
                                  TelemetryService().isConnected;

                              return SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _selectedPort == null
                                      ? null
                                      : isConnected
                                      ? _disconnectFromPort
                                      : (_isConnecting || _isWaitingForData)
                                      ? null
                                      : _connectToPort,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isConnected
                                        ? Colors.red.shade600
                                        : Colors.blue.shade600,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    elevation: 3,
                                  ),
                                  child: _isConnecting
                                      ? Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            const Text(
                                              'Đang kết nối...',
                                              style: TextStyle(fontSize: 14),
                                            ),
                                          ],
                                        )
                                      : Text(
                                          isConnected
                                              ? 'Ngắt kết nối'
                                              : _isWaitingForData
                                              ? 'Đang chờ dữ liệu...'
                                              : 'Kết nối',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );

    Overlay.of(context).insert(_connectionOverlayEntry!);
    setState(() {
      _showConnectionDropdown = true;
    });
  }

  void _hideConnectionDropdown() {
    _connectionOverlayEntry?.remove();
    _connectionOverlayEntry = null;
    _dropdownSetState = null; // Reset dropdown state function
    setState(() {
      _showConnectionDropdown = false;
    });
  }

  void _handleSettingsSelection(String setting) {
    widget.onSettingsChanged?.call(setting);
  }

  Future<void> _connectToPort() async {
    if (_selectedPort == null) return;

    setState(() {
      _isConnecting = true;
      _isWaitingForData = false;
      _progressValue = 0.0;
    });

    try {
      final telemetryService = TelemetryService();

      final availablePorts = telemetryService.getAvailablePorts();
      if (!availablePorts.contains(_selectedPort)) {
        throw Exception('Cổng không còn khả dụng');
      }

      bool success = await telemetryService.connect(
        _selectedPort!,
        baudRate: 115200,
      );

      if (success) {
        setState(() {
          _isConnecting = false;
          _isWaitingForData = true;
        });
        _showSnackBar(
          'Kết nối cổng thành công, đang chờ dữ liệu từ drone...',
          isError: false,
        );

        _startProgressBar();
      } else {
        setState(() {
          _isConnecting = false;
          _isWaitingForData = false;
        });
        _showSnackBar('Không thể kết nối tới $_selectedPort', isError: true);
      }
    } catch (e) {
      setState(() {
        _isConnecting = false;
        _isWaitingForData = false;
      });
      _showSnackBar('Lỗi kết nối: $e', isError: true);
    }
  }

  void _startProgressBar() {
    _progressTimer?.cancel();
    _dataSubscription?.cancel();

    bool hasReceivedData = false;

    setState(() {
      _progressValue = 0.0;
    });

    // Lắng nghe data stream
    final telemetryService = TelemetryService();
    _dataSubscription = telemetryService.dataReceiveStream.listen((hasData) {
      if (hasData) {
        hasReceivedData = true;
      }
    });

    _progressTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (mounted) {
        setState(() {
          _progressValue += 0.01;
          if (_progressValue > 1.0) _progressValue = 1.0;
        });

        if (_dropdownSetState != null) {
          _dropdownSetState!(() {});
        }

        if (_progressValue >= 1.0) {
          _progressTimer?.cancel();
          _dataSubscription?.cancel();

          setState(() {
            _isWaitingForData = false;
          });

          if (hasReceivedData) {
            telemetryService.setConnected(true);
            _showSnackBar('Kết nối thành công!', isError: false);
            _hideConnectionDropdown();
          } else {
            telemetryService.disconnect();
            _showSnackBar(
              'Timeout: Không nhận được dữ liệu từ drone',
              isError: true,
            );
          }
        }
      }
    });
  }

  Future<void> _disconnectFromPort() async {
    try {
      final telemetryService = TelemetryService();
      telemetryService.disconnect();
      telemetryService.setConnected(false);
      _progressTimer?.cancel();
      _dataSubscription?.cancel();

      setState(() {
        _isConnecting = false;
        _isWaitingForData = false;
        _progressValue = 0.0;
      });

      _showSnackBar('Đã ngắt kết nối', isError: false);
    } catch (e) {
      _showSnackBar('Lỗi ngắt kết nối: $e', isError: true);
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  void dispose() {
    _hideConnectionDropdown();
    _removePortOverlay();
    _progressTimer?.cancel();
    _dataSubscription?.cancel();
    _connectionSubscription?.cancel();
    super.dispose();
  }

  Widget _buildSettingsButton(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: _handleSettingsSelection,
      color: Colors.grey.shade800,
      offset: const Offset(0, 50),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.3), width: 1),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade700,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.grey.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: IconButton(
          icon: Icon(Icons.widgets, color: Colors.white, size: 18),
          onPressed: null,
          padding: const EdgeInsets.all(8),
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          tooltip: 'Tiện ích',
        ),
      ),
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'pdf',
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.dashboard,
                  color: Colors.blue.shade300,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Màn hình bay',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'camera',
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.videocam,
                  color: Colors.blue.shade300,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Xem camera',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'mission_planning',
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.flight_takeoff,
                  color: Colors.blue.shade300,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Kế hoạch bay',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'gimbal_control',
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.videocam_outlined,
                  color: Colors.purple.shade300,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Điều khiển Gimbal',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
