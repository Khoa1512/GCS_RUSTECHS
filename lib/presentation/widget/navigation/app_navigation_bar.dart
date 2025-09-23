import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:skylink/core/router/app_route.dart';
import 'package:skylink/presentation/widget/navigation/navigation_button.dart';
import 'package:skylink/responsive/demension.dart';

class AppNavigationBar extends StatefulWidget {
  const AppNavigationBar({super.key});

  @override
  State<AppNavigationBar> createState() => _AppNavigationBarState();
}

class _AppNavigationBarState extends State<AppNavigationBar>
    with TickerProviderStateMixin {
  final List<GlobalKey> _buttonKeys = [
    GlobalKey(),
    GlobalKey(),
    GlobalKey(),
    GlobalKey(),
    GlobalKey(),
  ];

  int _selectedIndex = 0;
  double _indicatorLeft = 0;
  double _indicatorWidth = 100;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
  }

  void _updateIndicatorPosition(String currentRoute) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final routes = [
        AppRoute.home,
        AppRoute.map,
        AppRoute.swarm,
        AppRoute.file,
        AppRoute.params,
      ];
      final newIndex = routes.indexOf(currentRoute);

      if (newIndex != -1 && newIndex != _selectedIndex) {
        _moveIndicatorToIndex(newIndex);
      } else if (!_isInitialized && newIndex != -1) {
        _initializeIndicatorPosition(newIndex);
      }
    });
  }

  void _initializeIndicatorPosition(int index) {
    final key = _buttonKeys[index];
    final RenderBox? renderBox =
        key.currentContext?.findRenderObject() as RenderBox?;
    final RenderBox? containerBox = context.findRenderObject() as RenderBox?;

    if (renderBox != null && containerBox != null) {
      final buttonPosition = renderBox.localToGlobal(Offset.zero);
      final containerPosition = containerBox.localToGlobal(Offset.zero);
      final size = renderBox.size;

      // Calculate relative position within the container
      final relativeLeft = buttonPosition.dx - containerPosition.dx;

      setState(() {
        _selectedIndex = index;
        _indicatorLeft = relativeLeft;
        _indicatorWidth = size.width;
        _isInitialized = true;
      });
    }
  }

  void _moveIndicatorToIndex(int newIndex) {
    final key = _buttonKeys[newIndex];
    final RenderBox? renderBox =
        key.currentContext?.findRenderObject() as RenderBox?;
    final RenderBox? containerBox = context.findRenderObject() as RenderBox?;

    if (renderBox != null && containerBox != null) {
      final buttonPosition = renderBox.localToGlobal(Offset.zero);
      final containerPosition = containerBox.localToGlobal(Offset.zero);
      final size = renderBox.size;

      // Calculate relative position within the container
      final relativeLeft = buttonPosition.dx - containerPosition.dx;

      setState(() {
        _selectedIndex = newIndex;
        _indicatorLeft = relativeLeft;
        _indicatorWidth = size.width;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentRoute = GoRouterState.of(context).matchedLocation;
    _updateIndicatorPosition(currentRoute);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Ensure we have valid constraints
        final maxWidth = constraints.maxWidth != double.infinity
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;
        final maxHeight = constraints.maxHeight != double.infinity
            ? constraints.maxHeight
            : 60.0;

        return ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: maxWidth,
            maxHeight: maxHeight,
            minHeight: 40,
          ),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: context.responsiveSpacing(desktop: 16),
              vertical: context.responsiveSpacing(desktop: 10),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Animated selection indicator (render first so buttons appear on top)
                if (_isInitialized)
                  AnimatedPositioned(
                    key: ValueKey(
                      'nav_indicator_$_selectedIndex',
                    ), // Add key to prevent conflicts
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeInOutCubic,
                    left: _indicatorLeft,
                    top: 0,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeInOutCubic,
                      width: _indicatorWidth,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF00C896),
                            const Color(0xFF00A67E),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00C896).withOpacity(0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                          BoxShadow(
                            color: const Color(0xFF00C896).withOpacity(0.2),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                // Navigation buttons (render second so they appear on top of indicator)
                _buildDesktopLayout(currentRoute),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDesktopLayout(String currentRoute) {
    return Row(children: _buildNavigationButtons(currentRoute));
  }

  List<Widget> _buildNavigationButtons(
    String currentRoute, {
    bool isCompact = false,
  }) {
    final routes = [
      AppRoute.home,
      AppRoute.map,
      AppRoute.swarm,
      // AppRoute.route,
      AppRoute.file,
      AppRoute.params,
    ];
    final labels = ['Home', 'Mission', 'Swarm', 'File', 'Params'];

    final icons = [
      Icons.home,
      Icons.map,
      Icons.flight,
      // Icons.route,
      Icons.file_copy,
      Icons.settings,
    ];
    final buttons = <Widget>[];

    for (int i = 0; i < routes.length; i++) {
      buttons.add(
        NavigationButton(
          key: _buttonKeys[i],
          text: labels[i],
          icon: icons[i],
          isSelected: currentRoute == routes[i],
          onTap: () => context.go(routes[i]),
          isCompact: isCompact,
          showBackground: false, // Don't show individual button backgrounds
        ),
      );

      if (i < routes.length - 1) {
        buttons.add(SizedBox(width: ResponsiveDimensions.spacingS));
      }
    }

    return buttons;
  }
}
