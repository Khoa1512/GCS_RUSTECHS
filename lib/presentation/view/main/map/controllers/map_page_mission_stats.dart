import 'dart:math' as math;
import 'package:latlong2/latlong.dart';
import 'package:skylink/data/models/route_point_model.dart';
import 'package:skylink/presentation/widget/mission/mission_waypoint_helpers.dart';

/// Mission statistics calculator
/// Handles distance, time, and battery calculations
class MissionStatsCalculator {
  /// Calculate mission statistics
  static MissionStats calculate(List<RoutePoint> routePoints) {
    if (routePoints.isEmpty) {
      return const MissionStats(
        totalDistance: null,
        estimatedTime: null,
        batteryUsage: null,
      );
    }

    // Calculate total distance using only flight path points (excluding ROI)
    final flightPathPoints = MissionWaypointHelpers.getFlightPathPoints(
      routePoints,
    );

    double distance = 0;
    for (int i = 1; i < flightPathPoints.length; i++) {
      final prev = LatLng(
        double.parse(flightPathPoints[i - 1].latitude),
        double.parse(flightPathPoints[i - 1].longitude),
      );
      final curr = LatLng(
        double.parse(flightPathPoints[i].latitude),
        double.parse(flightPathPoints[i].longitude),
      );
      distance += _calculateDistance(prev, curr);
    }

    // Estimate flight time (assuming 10 m/s average speed)
    const avgSpeed = 10.0; // m/s
    final timeInSeconds = distance / avgSpeed;

    // Estimate battery usage (rough calculation)
    final batteryPercent = math.min(
      100,
      (timeInSeconds / 60) * 2,
    ); // 2% per minute

    return MissionStats(
      totalDistance: distance,
      estimatedTime: Duration(seconds: timeInSeconds.round()),
      batteryUsage: batteryPercent.toDouble(),
    );
  }

  /// Calculate distance between two points using Haversine formula
  static double _calculateDistance(LatLng point1, LatLng point2) {
    const earthRadius = 6371000; // meters
    final lat1Rad = point1.latitude * math.pi / 180;
    final lat2Rad = point2.latitude * math.pi / 180;
    final deltaLat = (point2.latitude - point1.latitude) * math.pi / 180;
    final deltaLng = (point2.longitude - point1.longitude) * math.pi / 180;

    final a =
        math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
        math.cos(lat1Rad) *
            math.cos(lat2Rad) *
            math.sin(deltaLng / 2) *
            math.sin(deltaLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }
}

/// Mission statistics data class
class MissionStats {
  final double? totalDistance;
  final Duration? estimatedTime;
  final double? batteryUsage;

  const MissionStats({
    this.totalDistance,
    this.estimatedTime,
    this.batteryUsage,
  });
}
