import 'package:flutter/material.dart';
import 'package:skylink/core/constant/app_color.dart';

class ControlPanelWidget extends StatefulWidget {
  const ControlPanelWidget({super.key});

  @override
  State<ControlPanelWidget> createState() => _ControlPanelWidgetState();
}

class _ControlPanelWidgetState extends State<ControlPanelWidget>
    with TickerProviderStateMixin {
  String selectedDirection = 'left';
  bool isAwbSelected = false;
  bool isDispSelected = false;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 200),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _buildControlPanel();
  }

  Widget _buildControlPanel() {
    return Container(
      height: double.infinity,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.grey.shade800,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.05),
            blurRadius: 1,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0), // Reduced from 20
        child: Column(
          children: [
            // Header với title - more compact
            Text(
              'Gimbal Control',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16, // Reduced from 18
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            SizedBox(height: 12), // Reduced from 16
            // AWB and DISP buttons - Modern design
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildTopButton('AWB', Icons.wb_auto, isAwbSelected, () {
                  setState(() {
                    isAwbSelected = !isAwbSelected;
                  });
                }),
                _buildTopButton(
                  'DISP',
                  Icons.display_settings,
                  isDispSelected,
                  () {
                    setState(() {
                      isDispSelected = !isDispSelected;
                    });
                  },
                ),
              ],
            ),
            SizedBox(height: 16), // Reduced from 24
            // Modern Circular directional control - more compact
            Expanded(
              child: Center(
                child: Container(
                  width: 200, // Reduced from 250
                  height: 200, // Reduced from 250
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      center: Alignment.topLeft,
                      radius: 1.2,
                      colors: [
                        Colors.grey.shade600,
                        Colors.grey.shade700,
                        Colors.grey.shade800,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 15,
                        offset: Offset(0, 8),
                      ),
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.08),
                        blurRadius: 1,
                        offset: Offset(-1, -1),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      // Inner circle với glassmorphism
                      Center(
                        child: Container(
                          width: 120, // Reduced from 150
                          height: 120, // Reduced from 150
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.grey.shade700.withValues(alpha: 0.8),
                                Colors.grey.shade800.withValues(alpha: 0.9),
                              ],
                            ),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Icon(
                              Icons.gps_fixed,
                              color: AppColors.primaryColor.withValues(
                                alpha: 0.6,
                              ),
                              size: 24, // Reduced from 32
                            ),
                          ),
                        ),
                      ),

                      // Direction buttons với hiệu ứng hiện đại
                      _buildDirectionButton(
                        'up',
                        Alignment.topCenter,
                        Icons.keyboard_arrow_up_rounded,
                      ),
                      _buildDirectionButton(
                        'right',
                        Alignment.centerRight,
                        Icons.keyboard_arrow_right_rounded,
                      ),
                      _buildDirectionButton(
                        'down',
                        Alignment.bottomCenter,
                        Icons.keyboard_arrow_down_rounded,
                      ),
                      _buildDirectionButton(
                        'left',
                        Alignment.centerLeft,
                        Icons.keyboard_arrow_left_rounded,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopButton(
    String text,
    IconData icon,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 10,
        ), // Reduced padding
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12), // Slightly smaller radius
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isSelected
                ? [
                    AppColors.primaryColor,
                    AppColors.primaryColor.withValues(alpha: 0.8),
                  ]
                : [Colors.grey.shade600, Colors.grey.shade700],
          ),
          border: Border.all(
            color: isSelected
                ? AppColors.primaryColor.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.1),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? AppColors.primaryColor.withValues(alpha: 0.3)
                  : Colors.black.withValues(alpha: 0.2),
              blurRadius: isSelected ? 8 : 6, // Reduced blur
              offset: Offset(0, 3), // Reduced offset
            ),
            if (isSelected)
              BoxShadow(
                color: AppColors.primaryColor.withValues(alpha: 0.2),
                blurRadius: 12, // Reduced blur
                offset: Offset(0, 0),
              ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : AppColors.primaryColor,
              size: 16, // Reduced from 18
            ),
            SizedBox(width: 6), // Reduced from 8
            Text(
              text,
              style: TextStyle(
                color: Colors.white,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                fontSize: 12, // Reduced from 14
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDirectionButton(
    String direction,
    Alignment alignment,
    IconData icon,
  ) {
    bool isSelected = selectedDirection == direction;

    return Align(
      alignment: alignment,
      child: GestureDetector(
        onTap: () {
          setState(() {
            selectedDirection = direction;
          });
          _animationController.forward().then((_) {
            _animationController.reverse();
          });
          _onDirectionSelected(direction);
        },
        child: AnimatedContainer(
          duration: Duration(milliseconds: 200),
          width: 48, // Reduced from 64
          height: 48, // Reduced from 64
          margin: EdgeInsets.all(6), // Reduced from 8
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: isSelected
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primaryColor,
                      AppColors.primaryColor.withValues(alpha: 0.8),
                    ],
                  )
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.grey.shade600, Colors.grey.shade700],
                  ),
            border: Border.all(
              color: isSelected
                  ? AppColors.primaryColor.withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.1),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? AppColors.primaryColor.withValues(alpha: 0.3)
                    : Colors.black.withValues(alpha: 0.3),
                blurRadius: isSelected ? 10 : 5, // Reduced blur
                offset: Offset(0, isSelected ? 4 : 2), // Reduced offset
              ),
              if (isSelected)
                BoxShadow(
                  color: AppColors.primaryColor.withValues(alpha: 0.2),
                  blurRadius: 16,
                  offset: Offset(0, 0),
                ),
            ],
          ),
          child: Icon(
            icon,
            color: isSelected
                ? Colors.white
                : Colors.white.withValues(alpha: 0.8),
            size: 20, // Reduced from 28
          ),
        ),
      ),
    );
  }

  void _onDirectionSelected(String direction) {
    print('Direction selected: $direction');
    // Haptic feedback
    // HapticFeedback.lightImpact();
  }
}
