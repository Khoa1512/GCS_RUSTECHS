import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:skylink/presentation/widget/app_bar/desktop_app_bar.dart';
import 'package:skylink/responsive/demension.dart';
import 'package:skylink/responsive/responsive_scaffold.dart';
import 'package:skylink/core/router/app_route.dart';

class MainWrapper extends StatefulWidget {
  final StatefulNavigationShell navigationShell;

  const MainWrapper({super.key, required this.navigationShell});

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper>
    with SingleTickerProviderStateMixin {
  final List<NavigationItem> _navigationItems = [
    NavigationItem(
      label: 'Home',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
      route: AppRoute.home,
    ),
    NavigationItem(
      label: 'Map',
      icon: Icons.map_outlined,
      selectedIcon: Icons.map,
      route: AppRoute.map,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    if (context.isMobile) {
      return _buildMobileLayout();
    } else {
      return _buildDesktopLayout();
    }
  }

  Widget _buildMobileLayout() {
    return ResponsiveScaffold(
      body: SafeSizedContainer(child: widget.navigationShell),
      bottomNavigationBar: NavigationBar(
        selectedIndex: widget.navigationShell.currentIndex,
        onDestinationSelected: (index) => _onTap(index),
        destinations: _navigationItems.map((item) {
          return NavigationDestination(
            icon: Icon(item.icon),
            selectedIcon: Icon(item.selectedIcon),
            label: item.label,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return ResponsiveScaffold(
      body: SafeSizedContainer(
        child: Column(
          children: [
            ConstrainedSizeWidget(
              minHeight: kToolbarHeight,
              child: DesktopAppBar(),
            ),
            Expanded(child: SafeSizedContainer(child: widget.navigationShell)),
          ],
        ),
      ),
    );
  }

  void _onTap(int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }
}

class NavigationItem {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String route;

  const NavigationItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.route,
  });
}
