import 'dart:math' as math;
import 'package:latlong2/latlong.dart';
import 'package:skylink/data/models/route_point_model.dart';

class MissionTemplates {
  // Create orbit mission around a center point
  static List<RoutePoint> createOrbitMission({
    required LatLng center,
    required double radius, // meters
    required double altitude,
    int points = 8,
  }) {
    final waypoints = <RoutePoint>[];

    // Convert radius from meters to degrees (approximate)
    final radiusLat = radius / 111320; // 1 degree lat ≈ 111320 meters
    final radiusLng =
        radius / (111320 * math.cos(center.latitude * math.pi / 180));

    for (int i = 0; i < points; i++) {
      final angle = (i * 2 * math.pi) / points;
      final lat = center.latitude + radiusLat * math.cos(angle);
      final lng = center.longitude + radiusLng * math.sin(angle);

      waypoints.add(
        RoutePoint(
          id: '${DateTime.now().millisecondsSinceEpoch}_orbit_$i',
          order: i + 1,
          latitude: lat.toString(),
          longitude: lng.toString(),
          altitude: altitude.toInt().toString(),
          command: 16, // MAV_CMD_NAV_WAYPOINT
          commandParams: {
            'param1': 5.0, // Hold time 5 seconds
            'param2': 10.0, // Acceptance radius 10m
            'param3': 0.0, // Pass radius
            'param4': 0.0, // Yaw
          },
        ),
      );
    }

    return waypoints;
  }

  // Create survey grid mission for a rectangular area
  static List<RoutePoint> createSurveyMission({
    required LatLng topLeft,
    required LatLng bottomRight,
    required double altitude,
    required double spacing, // meters between lanes
    bool alternating = true, // zigzag pattern
  }) {
    final waypoints = <RoutePoint>[];

    // Calculate grid dimensions
    final lngDiff = bottomRight.longitude - topLeft.longitude;

    // Convert spacing from meters to degrees
    final spacingLng =
        spacing / (111320 * math.cos(topLeft.latitude * math.pi / 180));

    // Calculate number of lanes
    final numLanes = (lngDiff / spacingLng).ceil();

    int waypointIndex = 0;

    for (int lane = 0; lane <= numLanes; lane++) {
      final lngOffset = lane * spacingLng;
      final currentLng = topLeft.longitude + lngOffset;

      if (currentLng > bottomRight.longitude) break;

      if (alternating && lane % 2 == 0) {
        // Top to bottom
        waypoints.add(
          _createSurveyWaypoint(
            LatLng(topLeft.latitude, currentLng),
            altitude,
            waypointIndex++,
          ),
        );
        waypoints.add(
          _createSurveyWaypoint(
            LatLng(bottomRight.latitude, currentLng),
            altitude,
            waypointIndex++,
          ),
        );
      } else {
        // Bottom to top
        waypoints.add(
          _createSurveyWaypoint(
            LatLng(bottomRight.latitude, currentLng),
            altitude,
            waypointIndex++,
          ),
        );
        waypoints.add(
          _createSurveyWaypoint(
            LatLng(topLeft.latitude, currentLng),
            altitude,
            waypointIndex++,
          ),
        );
      }
    }

    return waypoints;
  }

  static RoutePoint _createSurveyWaypoint(
    LatLng position,
    double altitude,
    int index,
  ) {
    return RoutePoint(
      id: '${DateTime.now().millisecondsSinceEpoch}_survey_$index',
      order: index + 1,
      latitude: position.latitude.toString(),
      longitude: position.longitude.toString(),
      altitude: altitude.toInt().toString(),
      command: 16, // MAV_CMD_NAV_WAYPOINT
      commandParams: {
        'param1': 0.0, // No hold time for survey
        'param2': 5.0, // Acceptance radius 5m
        'param3': 0.0, // Pass radius
        'param4': 0.0, // Yaw
      },
    );
  }

  // Create simple path mission between two points
  static List<RoutePoint> createSimplePath({
    required LatLng start,
    required LatLng end,
    required double altitude,
    int intermediatePoints = 0,
  }) {
    final waypoints = <RoutePoint>[];

    // Add takeoff point
    waypoints.add(
      RoutePoint(
        id: '${DateTime.now().millisecondsSinceEpoch}_takeoff',
        order: 1,
        latitude: start.latitude.toString(),
        longitude: start.longitude.toString(),
        altitude: altitude.toInt().toString(),
        command: 22, // MAV_CMD_NAV_TAKEOFF
      ),
    );

    // Add intermediate points if requested
    if (intermediatePoints > 0) {
      final latStep =
          (end.latitude - start.latitude) / (intermediatePoints + 1);
      final lngStep =
          (end.longitude - start.longitude) / (intermediatePoints + 1);

      for (int i = 1; i <= intermediatePoints; i++) {
        waypoints.add(
          RoutePoint(
            id: '${DateTime.now().millisecondsSinceEpoch}_path_$i',
            order: i + 1,
            latitude: (start.latitude + latStep * i).toString(),
            longitude: (start.longitude + lngStep * i).toString(),
            altitude: altitude.toInt().toString(),
            command: 16, // MAV_CMD_NAV_WAYPOINT
          ),
        );
      }
    }

    // Add destination
    waypoints.add(
      RoutePoint(
        id: '${DateTime.now().millisecondsSinceEpoch}_destination',
        order: waypoints.length + 1,
        latitude: end.latitude.toString(),
        longitude: end.longitude.toString(),
        altitude: altitude.toInt().toString(),
        command: 16, // MAV_CMD_NAV_WAYPOINT
      ),
    );

    // Add landing point
    waypoints.add(
      RoutePoint(
        id: '${DateTime.now().millisecondsSinceEpoch}_land',
        order: waypoints.length + 1,
        latitude: end.latitude.toString(),
        longitude: end.longitude.toString(),
        altitude: "0",
        command: 21, // MAV_CMD_NAV_LAND
      ),
    );

    return waypoints;
  }

  // Create return-to-launch mission
  static List<RoutePoint> createRTLMission({
    required LatLng homePoint,
    required double altitude,
  }) {
    return [
      RoutePoint(
        id: '${DateTime.now().millisecondsSinceEpoch}_rtl',
        order: 1,
        latitude: homePoint.latitude.toString(),
        longitude: homePoint.longitude.toString(),
        altitude: altitude.toInt().toString(),
        command: 20, // MAV_CMD_NAV_RETURN_TO_LAUNCH
      ),
    ];
  }
}
