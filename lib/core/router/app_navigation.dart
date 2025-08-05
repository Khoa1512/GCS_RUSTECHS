import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:skylink/core/router/app_route.dart';
import 'package:skylink/presentation/view/file/file_page.dart';
import 'package:skylink/presentation/view/main/home/homepage.dart';
import 'package:skylink/presentation/view/main/map/map_page.dart';
import 'package:skylink/presentation/view/main/all_drone/all_drone_page.dart';
import 'package:skylink/presentation/view/main/route/route_page.dart';
import 'package:skylink/presentation/view/main_wrapper/main_wrapper.dart';

class AppNavigation {
  static final GlobalKey<NavigatorState> _rootNavigatorKey =
      GlobalKey<NavigatorState>();
  static final GlobalKey<NavigatorState> _homeNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'homeNavigator');
  static final GlobalKey<NavigatorState> _mapNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'mapNavigator');
  static final GlobalKey<NavigatorState> _allDroneNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'allDroneNavigator');
  static final GlobalKey<NavigatorState> _routeNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'routeNavigator');
  static final GlobalKey<NavigatorState> _fileNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'fileNavigator');

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
        _buildAllDroneBranch(),
        _buildRouteBranch(),
        _buildFileBranch()
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

  static StatefulShellBranch _buildAllDroneBranch() {
    return StatefulShellBranch(
      navigatorKey: _allDroneNavigatorKey,
      routes: [
        GoRoute(
          path: AppRoute.allDrone,
          name: AppRoute.allDrone,
          builder: (context, state) => const AllDronePage(),
        ),
      ],
    );
  }

  static StatefulShellBranch _buildRouteBranch() {
    return StatefulShellBranch(
      navigatorKey: _routeNavigatorKey,
      routes: [
        GoRoute(
          path: AppRoute.route,
          name: AppRoute.route,
          builder: (context, state) => const RoutePage(),
        ),
      ],
    );
  }

  static StatefulShellBranch _buildFileBranch() {
    return StatefulShellBranch(
      navigatorKey: _fileNavigatorKey,
      routes: [
        GoRoute(
          path: AppRoute.file,
          name: AppRoute.file,
          builder: (context, state) => const FilePage(),
        ),
      ],
    );
  }
}
