import 'package:flutter/material.dart';

class MissionTooltip extends StatefulWidget {
  final Widget child;
  final String message;
  final String? description;
  final IconData? icon;
  final Color? color;
  final Duration showDuration;
  final bool showOnTap;

  const MissionTooltip({
    super.key,
    required this.child,
    required this.message,
    this.description,
    this.icon,
    this.color,
    this.showDuration = const Duration(seconds: 3),
    this.showOnTap = false,
  });

  @override
  State<MissionTooltip> createState() => _MissionTooltipState();
}

class _MissionTooltipState extends State<MissionTooltip>
    with SingleTickerProviderStateMixin {
  OverlayEntry? _overlayEntry;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0.0, 0.2), end: Offset.zero).animate(
          CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
        );
  }

  @override
  void dispose() {
    _hideTooltip();
    _animationController.dispose();
    super.dispose();
  }

  void _showTooltip() {
    _hideTooltip(); // Hide any existing tooltip

    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: offset.dx,
        top: offset.dy - 80, // Position above the widget
        child: SlideTransition(
          position: _slideAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Material(
              color: Colors.transparent,
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.8,
                  minWidth: 200,
                ),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: (widget.color ?? Colors.teal).withOpacity(0.3),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with icon and title
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.icon != null) ...[
                          Icon(
                            widget.icon!,
                            color: widget.color ?? Colors.teal,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                        ],
                        Flexible(
                          child: Text(
                            widget.message,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Description if provided
                    if (widget.description != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        widget.description!,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
    _animationController.forward();

    // Auto hide after duration
    Future.delayed(widget.showDuration, () {
      _hideTooltip();
    });
  }

  void _hideTooltip() {
    if (_overlayEntry != null) {
      _animationController.reverse().then((_) {
        _overlayEntry?.remove();
        _overlayEntry = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.showOnTap) {
      return GestureDetector(onTap: _showTooltip, child: widget.child);
    } else {
      return MouseRegion(
        onEnter: (_) => _showTooltip(),
        onExit: (_) => _hideTooltip(),
        child: widget.child,
      );
    }
  }
}

class MissionQuickHelp extends StatelessWidget {
  final VoidCallback? onShowFullGuide;

  const MissionQuickHelp({super.key, this.onShowFullGuide});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.teal.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline, color: Colors.yellow, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Mẹo nhanh',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (onShowFullGuide != null)
                TextButton(
                  onPressed: onShowFullGuide,
                  child: const Text(
                    'Xem toàn bộ',
                    style: TextStyle(color: Colors.teal, fontSize: 12),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          _buildQuickTip('Click trên bản đồ để thêm waypoint', Icons.touch_app),
          _buildQuickTip('Kéo thả để di chuyển waypoint', Icons.drag_indicator),
          _buildQuickTip(
            'Sử dụng Orbit/Survey cho mission phức tạp',
            Icons.auto_awesome,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickTip(String text, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, color: Colors.teal, size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
