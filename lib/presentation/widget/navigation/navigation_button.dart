import 'package:flutter/material.dart';
import 'package:skylink/core/constant/app_color.dart';
import 'package:skylink/responsive/demension.dart';

class NavigationButton extends StatefulWidget {
  final String text;
  final IconData icon;
  final bool isSelected;
  final VoidCallback? onTap;
  final bool isCompact;
  final bool showBackground;

  const NavigationButton({
    super.key,
    required this.text,
    required this.icon,
    this.isSelected = false,
    this.onTap,
    this.isCompact = false,
    this.showBackground = true,
  });

  @override
  State<NavigationButton> createState() => _NavigationButtonState();
}

class _NavigationButtonState extends State<NavigationButton>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shouldShowCompact = widget.isCompact;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => _animationController.forward(),
        onTapUp: (_) => _animationController.reverse(),
        onTapCancel: () => _animationController.reverse(),
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                padding: EdgeInsets.symmetric(
                  horizontal: shouldShowCompact ? 12 : 20,
                  vertical: shouldShowCompact ? 8 : 14,
                ),
                decoration: widget.showBackground
                    ? BoxDecoration(
                        color: widget.isSelected
                            ? AppColors.primaryColor
                            : _isHovered
                            ? AppColors.primaryColor.withOpacity(0.15)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(
                          shouldShowCompact ? 12 : 16,
                        ),
                        boxShadow: widget.isSelected
                            ? [
                                BoxShadow(
                                  color: AppColors.primaryColor.withOpacity(
                                    0.3,
                                  ),
                                  blurRadius: shouldShowCompact ? 4 : 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                        border: _isHovered && !widget.isSelected
                            ? Border.all(
                                color: AppColors.primaryColor.withOpacity(0.3),
                                width: 1,
                              )
                            : null,
                      )
                    : null,
                child: shouldShowCompact
                    ? _buildCompactLayout()
                    : _buildFullLayout(),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCompactLayout() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          widget.icon,
          color: widget.isSelected
              ? Colors.white
              : _isHovered
              ? (widget.showBackground ? AppColors.primaryColor : Colors.white)
              : Colors.white.withOpacity(0.7),
          size: 18,
        ),
        SizedBox(height: ResponsiveDimensions.spacingXS),
        Text(
          widget.text,
          style: Theme.of(context).textTheme.bodySmall!.copyWith(
            color: widget.isSelected
                ? Colors.white
                : _isHovered
                ? (widget.showBackground
                      ? AppColors.primaryColor
                      : Colors.white)
                : Colors.white.withOpacity(0.8),
            fontWeight: widget.isSelected
                ? FontWeight.w600
                : _isHovered
                ? FontWeight.w500
                : FontWeight.normal,
            fontSize: 10,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildFullLayout() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          child: Icon(
            widget.icon,
            color: widget.isSelected
                ? Colors.white
                : _isHovered
                ? (widget.showBackground
                      ? AppColors.primaryColor
                      : Colors.white)
                : Colors.white.withOpacity(0.7),
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: Theme.of(context).textTheme.bodyMedium!.copyWith(
            color: widget.isSelected
                ? Colors.white
                : _isHovered
                ? (widget.showBackground
                      ? AppColors.primaryColor
                      : Colors.white)
                : Colors.white.withOpacity(0.8),
            fontWeight: widget.isSelected
                ? FontWeight.w600
                : _isHovered
                ? FontWeight.w500
                : FontWeight.normal,
            letterSpacing: 0.5,
          ),
          child: Text(widget.text),
        ),
      ],
    );
  }
}
