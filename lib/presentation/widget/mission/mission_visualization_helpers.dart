import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:skylink/data/models/route_point_model.dart';
import 'package:skylink/data/constants/mav_cmd.dart';

/// Helper class for visualizing mission elements on the map
class MissionVisualizationHelpers {
  /// Generate circle points for loiter commands
  static List<LatLng> generateCirclePoints(
    LatLng center,
    double radiusMeters, {
    int points = 64,
  }) {
    final List<LatLng> circlePoints = [];

    // Earth radius in meters
    const double earthRadius = 6371000;

    // Convert center to radians
    final double centerLatRad = center.latitude * math.pi / 180;
    final double centerLngRad = center.longitude * math.pi / 180;

    for (int i = 0; i <= points; i++) {
      final double angle = (2 * math.pi * i) / points;

      // Calculate the point on the circle
      final double lat = math.asin(
        math.sin(centerLatRad) * math.cos(radiusMeters / earthRadius) +
            math.cos(centerLatRad) *
                math.sin(radiusMeters / earthRadius) *
                math.cos(angle),
      );

      final double lng =
          centerLngRad +
          math.atan2(
            math.sin(angle) *
                math.sin(radiusMeters / earthRadius) *
                math.cos(centerLatRad),
            math.cos(radiusMeters / earthRadius) -
                math.sin(centerLatRad) * math.sin(lat),
          );

      circlePoints.add(LatLng(lat * 180 / math.pi, lng * 180 / math.pi));
    }

    return circlePoints;
  }

  /// Get loiter radius from waypoint parameters
  static double? getLoiterRadius(RoutePoint waypoint) {
    if (waypoint.commandParams == null) return null;

    switch (waypoint.command) {
      case MavCmd.loiterTurns: // MAV_CMD_NAV_LOITER_TURNS (18)
        return waypoint.commandParams!['param3']
            ?.toDouble(); // Radius parameter

      case MavCmd.loiterTime: // MAV_CMD_NAV_LOITER_TIME (19)
        return waypoint.commandParams!['param3']
            ?.toDouble(); // Radius parameter

      case MavCmd.loiterUnlimited: // MAV_CMD_NAV_LOITER_UNLIM (17)
        return waypoint.commandParams!['param3']
            ?.toDouble(); // Radius parameter

      case MavCmd.loiterToAlt: // MAV_CMD_NAV_LOITER_TO_ALT (31)
        return waypoint.commandParams!['param2']
            ?.toDouble(); // Radius parameter

      default:
        return null;
    }
  }

  /// Check if waypoint has loiter command
  static bool isLoiterCommand(int command) {
    return [
      MavCmd.loiterTurns,
      MavCmd.loiterTime,
      MavCmd.loiterUnlimited,
      MavCmd.loiterToAlt,
    ].contains(command);
  }

  /// Get loiter direction from parameters (for visual indication)
  static int getLoiterDirection(RoutePoint waypoint) {
    if (waypoint.commandParams == null) return 1; // Default clockwise

    // For some loiter commands, direction might be in param4
    // This depends on the specific command implementation
    return 1; // Clockwise by default
  }

  /// Generate polylines for loiter visualization with zoom-aware scaling
  static List<Polyline> generateLoiterPolylines(
    List<RoutePoint> waypoints, {
    double? mapZoom,
  }) {
    final List<Polyline> polylines = [];

    for (final waypoint in waypoints) {
      if (!isLoiterCommand(waypoint.command)) continue;

      final radius = getLoiterRadius(waypoint);
      if (radius == null || radius <= 0) continue;

      // Calculate minimum visible radius based on zoom level
      double minVisibleRadius = 30.0; // Increase default minimum to 30m
      if (mapZoom != null) {
        // At zoom 15: min 60m, at zoom 18: min 15m, at zoom 20: min 8m
        minVisibleRadius = math.max(8.0, 300.0 / math.pow(2, mapZoom - 12));
      }

      // Use minimum radius for visibility
      final displayRadius = radius < minVisibleRadius
          ? minVisibleRadius
          : radius;

      final center = LatLng(
        double.parse(waypoint.latitude),
        double.parse(waypoint.longitude),
      );

      final circlePoints = generateCirclePoints(center, displayRadius);

      // Create the main circle
      polylines.add(
        Polyline(
          points: circlePoints,
          strokeWidth: 3.0,
          color: _getLoiterColor(waypoint.command),
        ),
      );

      // Add radius line
      if (circlePoints.isNotEmpty) {
        polylines.add(
          Polyline(
            points: [center, circlePoints.first],
            strokeWidth: 2.0,
            color: _getLoiterColor(waypoint.command),
          ),
        );
      }
    }

    return polylines;
  }

  /// Get color for different loiter commands
  static Color _getLoiterColor(int command) {
    switch (command) {
      case MavCmd.loiterTurns:
        return Colors.orange;
      case MavCmd.loiterTime:
        return Colors.blue;
      case MavCmd.loiterUnlimited:
        return Colors.purple;
      case MavCmd.loiterToAlt:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  /// Get loiter command name for display
  static String getLoiterCommandName(int command) {
    switch (command) {
      case MavCmd.loiterTurns:
        return 'Loiter Turns';
      case MavCmd.loiterTime:
        return 'Loiter Time';
      case MavCmd.loiterUnlimited:
        return 'Loiter Unlimited';
      case MavCmd.loiterToAlt:
        return 'Loiter to Alt';
      default:
        return 'Loiter';
    }
  }
}
