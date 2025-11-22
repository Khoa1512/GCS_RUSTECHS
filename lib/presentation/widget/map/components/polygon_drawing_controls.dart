import 'package:flutter/material.dart';
import 'dart:ui';

class PolygonDrawingControls extends StatefulWidget {
  final int pointCount;
  final VoidCallback? onUndo;
  final VoidCallback? onFinish;
  final VoidCallback onCancel;
  final bool canFinish;

  const PolygonDrawingControls({
    super.key,
    required this.pointCount,
    this.onUndo,
    this.onFinish,
    required this.onCancel,
    this.canFinish = false,
  });

  @override
  State<PolygonDrawingControls> createState() => _PolygonDrawingControlsState();
}

class _PolygonDrawingControlsState extends State<PolygonDrawingControls>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 4),
              spreadRadius: 0,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.95),
                    Colors.white.withOpacity(0.85),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withOpacity(0.5),
                  width: 1.5,
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header with point count
                  _buildHeader(),

                  const SizedBox(height: 12),

                  // Action buttons
                  _buildActionButtons(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Animated icon
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 500),
          builder: (context, value, child) {
            return Transform.rotate(
              angle: value * 3.14159 * 2,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.purple.shade400, Colors.purple.shade600],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.purple.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.polyline_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            );
          },
        ),

        const SizedBox(width: 12),

        // Text info
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Vẽ Polygon Survey',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${widget.pointCount} điểm',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.purple.shade700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  widget.canFinish ? '✓ Sẵn sàng' : 'Cần ≥3 điểm',
                  style: TextStyle(
                    fontSize: 11,
                    color: widget.canFinish
                        ? Colors.green.shade700
                        : Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Undo button
        if (widget.onUndo != null)
          _ModernButton(
            onPressed: widget.onUndo,
            icon: Icons.undo_rounded,
            label: 'Hoàn tác',
            color: Colors.orange.shade600,
            backgroundColor: Colors.orange.shade50,
          ),

        if (widget.onUndo != null) const SizedBox(width: 8),

        // Finish button
        _ModernButton(
          onPressed: widget.canFinish ? widget.onFinish : null,
          icon: Icons.check_circle_rounded,
          label: 'Hoàn thành',
          color: Colors.green.shade600,
          backgroundColor: Colors.green.shade50,
          isPrimary: true,
        ),

        const SizedBox(width: 8),

        // Cancel button
        _ModernButton(
          onPressed: widget.onCancel,
          icon: Icons.close_rounded,
          label: 'Hủy',
          color: Colors.red.shade600,
          backgroundColor: Colors.red.shade50,
        ),
      ],
    );
  }
}

/// Modern button component with hover effects
class _ModernButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final IconData icon;
  final String label;
  final Color color;
  final Color backgroundColor;
  final bool isPrimary;

  const _ModernButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    required this.color,
    required this.backgroundColor,
    this.isPrimary = false,
  });

  @override
  State<_ModernButton> createState() => _ModernButtonState();
}

class _ModernButtonState extends State<_ModernButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.onPressed == null;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: EdgeInsets.symmetric(
            horizontal: widget.isPrimary ? 16 : 14,
            vertical: widget.isPrimary ? 12 : 10,
          ),
          decoration: BoxDecoration(
            gradient: isDisabled
                ? null
                : widget.isPrimary
                ? LinearGradient(
                    colors: [widget.color, widget.color.withOpacity(0.8)],
                  )
                : null,
            color: isDisabled
                ? Colors.grey.shade200
                : widget.isPrimary
                ? null
                : _isPressed
                ? widget.color.withOpacity(0.2)
                : _isHovered
                ? widget.backgroundColor.withOpacity(0.8)
                : widget.backgroundColor,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isDisabled
                ? null
                : [
                    if (_isHovered && !_isPressed)
                      BoxShadow(
                        color: widget.color.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                  ],
          ),
          transform: Matrix4.identity()..scale(_isPressed ? 0.95 : 1.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: widget.isPrimary ? 16 : 15,
                color: isDisabled
                    ? Colors.grey.shade400
                    : widget.isPrimary
                    ? Colors.white
                    : widget.color,
              ),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: widget.isPrimary ? 13 : 12,
                  fontWeight: widget.isPrimary
                      ? FontWeight.bold
                      : FontWeight.w600,
                  color: isDisabled
                      ? Colors.grey.shade400
                      : widget.isPrimary
                      ? Colors.white
                      : widget.color,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
