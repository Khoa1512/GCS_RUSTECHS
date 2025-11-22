import 'package:flutter/material.dart';
import 'package:skylink/data/models/route_point_model.dart';

/// Helper functions for waypoint operations and visualization
class MissionWaypointHelpers {
  /// Check if a waypoint is a ROI (Region of Interest) point
  /// ROI points are used for camera focus, drone doesn't fly to these points
  static bool isROIPoint(RoutePoint waypoint) {
    return waypoint.command == 201; // MAV_CMD_DO_SET_ROI
  }

  /// Get the appropriate icon for a waypoint based on its command type
  static IconData getWaypointIcon(RoutePoint waypoint) {
    if (isROIPoint(waypoint)) {
      return Icons.center_focus_strong; // Camera focus icon for ROI
    }
    return Icons.location_on; // Default waypoint icon
  }

  /// Get the appropriate color for a waypoint based on its command type
  static Color getWaypointColor(
    RoutePoint waypoint, {
    bool isSelected = false,
    bool isMultiSelected = false,
  }) {
    if (isMultiSelected) return Colors.orange;
    if (isSelected) return Colors.blue;

    if (isROIPoint(waypoint)) {
      return Colors.purple; // Purple for ROI points
    }
    return Colors.red; // Default red for regular waypoints
  }

  /// Filter out ROI points from a list of waypoints
  /// Used for polyline generation (flight path)
  static List<RoutePoint> getFlightPathPoints(List<RoutePoint> waypoints) {
    return waypoints.where((wp) => !isROIPoint(wp)).toList();
  }

  /// Get waypoint description for UI display
  static String getWaypointDescription(RoutePoint waypoint) {
    if (isROIPoint(waypoint)) {
      return 'Điểm focus camera';
    }

    switch (waypoint.command) {
      case 16:
        return 'Điểm định hướng';
      case 19:
        return 'Lượn tại chỗ';
      case 20:
        return 'Quay về điểm xuất phát';
      case 21:
        return 'Hạ cánh';
      case 183:
        return 'Đặt Servo';
      case 184:
        return 'Lặp Servo';
      default:
        return 'Điểm định hướng';
    }
  }

  /// Get tooltip text for waypoint markers
  static String getWaypointTooltip(RoutePoint waypoint) {
    final description = getWaypointDescription(waypoint);
    if (isROIPoint(waypoint)) {
      return '$description\n(Drone sẽ hướng camera về điểm này)';
    }
    return '$description\n(Drone sẽ bay đến điểm này)';
  }
}
