import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth != double.infinity
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;

        return ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: availableWidth,
            minHeight: context.isMobile ? 110 : 120,
            maxHeight: context.isMobile ? 110 : 120,
          ),
          child: Container(
            width: double.infinity,
            height: context.isMobile ? 110 : 120,
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
                horizontal: context.responsiveSpacing(
                  mobile: 12,
                  tablet: 20,
                  desktop: 24,
                ),
                vertical: context.responsiveSpacing(
                  mobile: 8,
                  tablet: 12,
                  desktop: 16,
                ),
              ),
              child: context.isMobile
                  ? _buildMobileLayout()
                  : _buildDesktopLayout(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // App name and status in a row for mobile
        SizedBox(
          height: 40,
          child: Row(
            children: [
              Expanded(child: _buildAppName()),
              const Spacer(),
              ConstrainedSizeWidget(maxWidth: 200, child: AppStatusBar()),
            ],
          ),
        ),
        SizedBox(height: 8),
        // Navigation bar below for mobile
        Expanded(
          child: ConstrainedSizeWidget(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.02),
                borderRadius: BorderRadius.circular(8),
              ),
              child: AppNavigationBar(),
            ),
          ),
        ),
      ],
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
          horizontal: context.responsiveSpacing(
            mobile: 12,
            tablet: 16,
            desktop: 20,
          ),
          vertical: context.responsiveSpacing(
            mobile: 8,
            tablet: 10,
            desktop: 12,
          ),
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
                size: context.responsiveSpacing(
                  mobile: 18,
                  tablet: 20,
                  desktop: 22,
                ),
              ),
            ),
            SizedBox(
              width: context.responsiveSpacing(
                mobile: 8,
                tablet: 10,
                desktop: 12,
              ),
            ),
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
                    fontSize: context.responsiveSpacing(
                      mobile: 18,
                      tablet: 20,
                      desktop: 22,
                    ),
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
