import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:skylink/presentation/widget/app_bar/app_status_bar.dart';
import 'package:skylink/presentation/widget/navigation/app_navigation_bar.dart';
import 'package:skylink/responsive/demension.dart';
import 'package:skylink/responsive/responsive_scaffold.dart';

class DesktopAppBar extends StatefulWidget {
  const DesktopAppBar({super.key});

  @override
  State<DesktopAppBar> createState() => _DesktopAppBarState();
}

class _DesktopAppBarState extends State<DesktopAppBar> {
  bool _isHovered = false;

  // Desktop-specific constants
  static const double minWindowWidth = 1200.0;
  static const double minWindowHeight = 800.0;
  static const double defaultWindowWidth = 1400.0;
  static const double defaultWindowHeight = 900.0;

  @override
  void initState() {
    super.initState();
    _setInitialWindowSize();
  }

  void _setInitialWindowSize() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Set minimum window size constraints
      SystemChrome.setApplicationSwitcherDescription(
        ApplicationSwitcherDescription(
          label: 'VTOL Control System',
          primaryColor: 0xFF1E1E1E,
        ),
      );
      // Note: Window size constraints would typically be set at the main.dart level
      // or through platform-specific configurations
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Use defined constants for desktop sizing
        final screenWidth = MediaQuery.of(context).size.width;
        final effectiveWidth = screenWidth < minWindowWidth
            ? minWindowWidth
            : screenWidth;

        return ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: minWindowWidth,
            maxWidth: double.infinity,
            minHeight: 120.0,
            maxHeight: 120.0,
          ),
          child: Container(
            width: effectiveWidth,
            height: 120.0,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [const Color(0xFF1E1E1E), const Color(0xFF2A2A2A)],
              ),
              border: Border(
                bottom: BorderSide(
                  color: Colors.white.withOpacity(0.08),
                  width: 1,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: SafeSizedContainer(
              padding: EdgeInsets.symmetric(
                horizontal: 24.0, // Fixed desktop spacing
                vertical: 16.0, // Fixed desktop spacing
              ),
              child: _buildDesktopLayout(), // Only desktop layout
            ),
          ),
        );
      },
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        _buildAppName(),
        SizedBox(width: 32),
        // Navigation bar in the center for desktop
        Expanded(
          flex: 1,
          child: ConstrainedSizeWidget(
            minHeight: 40,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.02),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withOpacity(0.05),
                  width: 1,
                ),
              ),
              child: AppNavigationBar(),
            ),
          ),
        ),
        SizedBox(width: 24),
        // Status bar on the right
        ConstrainedSizeWidget(maxWidth: 450, child: AppStatusBar()),
      ],
    );
  }

  Widget _buildAppName() {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: EdgeInsets.symmetric(
          horizontal: 20.0, // Fixed desktop spacing
          vertical: 12.0, // Fixed desktop spacing
        ),
        decoration: BoxDecoration(
          gradient: _isHovered
              ? LinearGradient(
                  colors: [
                    const Color(0xFF00C896).withOpacity(0.1),
                    const Color(0xFF00A67E).withOpacity(0.1),
                  ],
                )
              : null,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isHovered
                ? const Color(0xFF00C896).withOpacity(0.3)
                : Colors.white.withOpacity(0.05),
            width: 1,
          ),
          boxShadow: _isHovered
              ? [
                  BoxShadow(
                    color: const Color(0xFF00C896).withOpacity(0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFF00C896), const Color(0xFF00A67E)],
                ),
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00C896).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.flight,
                color: Colors.white,
                size: context.responsiveSpacing(desktop: 22),
              ),
            ),
            SizedBox(width: context.responsiveSpacing(desktop: 12)),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Rustech',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.5,
                    fontSize: context.responsiveSpacing(desktop: 22),
                  ),
                ),
                if (context.isDesktop)
                  Text(
                    'Skylink Dashboard',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
