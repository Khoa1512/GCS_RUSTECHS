import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:skylink/core/router/app_route.dart';
// import 'package:skylink/presentation/view/main/home/homepage.dart';
import 'package:skylink/presentation/view/main/map/map_page.dart';
// import 'package:skylink/presentation/view/main_wrapper/main_wrapper.dart';

class AppNavigation {
  static final GlobalKey<NavigatorState> _rootNavigatorKey =
      GlobalKey<NavigatorState>();

  // QGroundControl-style: Direct to map without shell wrapper
  static final GoRouter router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoute.map,
    routes: [
      // Main map route (primary interface)
      GoRoute(
        path: AppRoute.map,
        name: AppRoute.map,
        builder: (context, state) => const MapPage(),
      ),
      // Legacy routes (commented for future use)
      // _buildMainShellRoute()
    ],
  );

  // Legacy shell route (commented but preserved)
  /*
  static final GoRouter router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    routes: [_buildMainShellRoute()],
  );

  static StatefulShellRoute _buildMainShellRoute() {
    return StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          MainWrapper(navigationShell: navigationShell),
      branches: [
        _buildHomeBranch(),
        _buildMapBranch(),
      ],
    );
  }

  static StatefulShellBranch _buildHomeBranch() {
    return StatefulShellBranch(
      navigatorKey: _homeNavigatorKey,
      routes: [
        GoRoute(
          path: AppRoute.home,
          name: AppRoute.home,
          builder: (context, state) => const Homepage(),
        ),
      ],
    );
  }

  static StatefulShellBranch _buildMapBranch() {
    return StatefulShellBranch(
      navigatorKey: _mapNavigatorKey,
      routes: [
        GoRoute(
          path: AppRoute.map,
          name: AppRoute.map,
          builder: (context, state) => const MapPage(),
        ),
      ],
    );
  }
  */
}
