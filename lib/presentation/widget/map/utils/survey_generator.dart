import 'dart:math' as math;
import 'package:latlong2/latlong.dart';
import 'package:skylink/data/models/route_point_model.dart';

/// Survey pattern types
enum SurveyPattern { lawnmower, grid, perimeter }

class SurveyConfig {
  final double spacing;
  final double angle;
  final double altitude;
  final SurveyPattern pattern;
  final double overlap;

  const SurveyConfig({
    this.spacing = 20.0,
    this.angle = 0.0,
    this.altitude = 50.0,
    this.pattern = SurveyPattern.lawnmower,
    this.overlap = 70.0,
  });
}

/// Generator for survey mission waypoints
class SurveyGenerator {
  static const double _earthRadius = 6371000.0; // meters

  /// Generate waypoints for a bounding box survey
  static List<RoutePoint> generateSurvey({
    required LatLng topLeft,
    required LatLng bottomRight,
    required SurveyConfig config,
  }) {
    switch (config.pattern) {
      case SurveyPattern.lawnmower:
        return _generateLawnmower(topLeft, bottomRight, config);
      case SurveyPattern.grid:
        return _generateGrid(topLeft, bottomRight, config);
      case SurveyPattern.perimeter:
        return _generatePerimeter(topLeft, bottomRight, config);
    }
  }

  // NOTE: Polygon survey logic moved to polygon_survey_generator.dart

  /// Generate lawnmower (zigzag) pattern
  static List<RoutePoint> _generateLawnmower(
    LatLng topLeft,
    LatLng bottomRight,
    SurveyConfig config,
  ) {
    final waypoints = <RoutePoint>[];

    // Calculate bounding box dimensions
    final minLat = math.min(topLeft.latitude, bottomRight.latitude);
    final maxLat = math.max(topLeft.latitude, bottomRight.latitude);
    final minLng = math.min(topLeft.longitude, bottomRight.longitude);
    final maxLng = math.max(topLeft.longitude, bottomRight.longitude);

    // Calculate center point for rotation
    final centerLat = (minLat + maxLat) / 2;
    final centerLng = (minLng + maxLng) / 2;
    final center = LatLng(centerLat, centerLng);

    // Calculate box dimensions in meters
    final width = _calculateDistance(
      LatLng(centerLat, minLng),
      LatLng(centerLat, maxLng),
    );
    final height = _calculateDistance(
      LatLng(minLat, centerLng),
      LatLng(maxLat, centerLng),
    );

    // Determine which dimension to use based on angle
    // For 0° or 180°: lines go across width, spaced along height
    // For 90° or 270°: lines go across height, spaced along width
    final angleNormalized = config.angle % 180;
    final isVertical = angleNormalized > 45 && angleNormalized < 135;

    final lineLength = isVertical ? width : height;
    final spacingDimension = isVertical ? height : width;

    // Calculate number of lines based on spacing dimension
    final numLines = (spacingDimension / config.spacing).ceil();

    // Generate lines
    for (int i = 0; i <= numLines; i++) {
      // Calculate offset from center
      final offsetMeters = (i - numLines / 2) * config.spacing;

      // Start and end points of the line (before rotation)
      final startY = -lineLength / 2;
      final endY = lineLength / 2;

      // Alternate direction for zigzag
      final isReverse = i % 2 == 1;
      final actualStartY = isReverse ? endY : startY;
      final actualEndY = isReverse ? startY : endY;

      // Convert to lat/lng with rotation
      final startPoint = _offsetPoint(
        center,
        offsetMeters,
        actualStartY,
        config.angle,
      );
      final endPoint = _offsetPoint(
        center,
        offsetMeters,
        actualEndY,
        config.angle,
      );

      // Add waypoints
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      waypoints.add(
        RoutePoint(
          id: '${timestamp}_${waypoints.length}',
          order: waypoints.length + 1,
          latitude: startPoint.latitude.toString(),
          longitude: startPoint.longitude.toString(),
          altitude: config.altitude.toInt().toString(),
          command: 16, // MAV_CMD_NAV_WAYPOINT
        ),
      );

      waypoints.add(
        RoutePoint(
          id: '${timestamp}_${waypoints.length}',
          order: waypoints.length + 1,
          latitude: endPoint.latitude.toString(),
          longitude: endPoint.longitude.toString(),
          altitude: config.altitude.toInt().toString(),
          command: 16, // MAV_CMD_NAV_WAYPOINT
        ),
      );
    }

    return waypoints;
  }

  /// Generate grid pattern (cross-hatch / double coverage)
  /// Bay tất cả đường NGANG trước, sau đó bay tất cả đường DỌC
  /// Tạo pattern chéo nhau (╬) - mỗi điểm được phủ 2 lần
  static List<RoutePoint> _generateGrid(
    LatLng topLeft,
    LatLng bottomRight,
    SurveyConfig config,
  ) {
    final waypoints = <RoutePoint>[];

    // Calculate bounding box dimensions
    final minLat = math.min(topLeft.latitude, bottomRight.latitude);
    final maxLat = math.max(topLeft.latitude, bottomRight.latitude);
    final minLng = math.min(topLeft.longitude, bottomRight.longitude);
    final maxLng = math.max(topLeft.longitude, bottomRight.longitude);

    // Calculate center point
    final centerLat = (minLat + maxLat) / 2;
    final centerLng = (minLng + maxLng) / 2;
    final center = LatLng(centerLat, centerLng);

    // Calculate box dimensions in meters
    final width = _calculateDistance(
      LatLng(centerLat, minLng),
      LatLng(centerLat, maxLng),
    );
    final height = _calculateDistance(
      LatLng(minLat, centerLng),
      LatLng(maxLat, centerLng),
    );

    // Calculate number of lines
    final numHorizontalLines = (height / config.spacing).ceil() + 1;
    final numVerticalLines = (width / config.spacing).ceil() + 1;

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    int waypointCount = 0;

    // ═══════════════════════════════════════════════════════
    // PASS 1: Bay tất cả đường NGANG (Horizontal lines)
    // ═══════════════════════════════════════════════════════
    for (int row = 0; row < numHorizontalLines; row++) {
      final yOffset = -height / 2 + (row * config.spacing);

      // Zigzag: hàng lẻ bay ngược lại
      final isReverse = row % 2 == 1;
      final startX = isReverse ? width / 2 : -width / 2;
      final endX = isReverse ? -width / 2 : width / 2;

      final startPoint = _offsetPoint(center, startX, yOffset, config.angle);
      final endPoint = _offsetPoint(center, endX, yOffset, config.angle);

      waypoints.add(
        RoutePoint(
          id: '${timestamp}_${waypointCount++}',
          order: waypoints.length + 1,
          latitude: startPoint.latitude.toString(),
          longitude: startPoint.longitude.toString(),
          altitude: config.altitude.toInt().toString(),
          command: 16, // MAV_CMD_NAV_WAYPOINT
        ),
      );

      waypoints.add(
        RoutePoint(
          id: '${timestamp}_${waypointCount++}',
          order: waypoints.length + 1,
          latitude: endPoint.latitude.toString(),
          longitude: endPoint.longitude.toString(),
          altitude: config.altitude.toInt().toString(),
          command: 16, // MAV_CMD_NAV_WAYPOINT
        ),
      );
    }

    // ║║║║║║║║║║║║║║║║║║║║║║║║║║║║║║║║║║║║║║║║║║║║║║║║║║║
    // PASS 2: Bay tất cả đường DỌC (Vertical lines)
    // ║║║║║║║║║║║║║║║║║║║║║║║║║║║║║║║║║║║║║║║║║║║║║║║║║║║
    for (int col = 0; col < numVerticalLines; col++) {
      final xOffset = -width / 2 + (col * config.spacing);

      // Zigzag: cột lẻ bay ngược lại
      final isReverse = col % 2 == 1;
      final startY = isReverse ? height / 2 : -height / 2;
      final endY = isReverse ? -height / 2 : height / 2;

      final startPoint = _offsetPoint(center, xOffset, startY, config.angle);
      final endPoint = _offsetPoint(center, xOffset, endY, config.angle);

      waypoints.add(
        RoutePoint(
          id: '${timestamp}_${waypointCount++}',
          order: waypoints.length + 1,
          latitude: startPoint.latitude.toString(),
          longitude: startPoint.longitude.toString(),
          altitude: config.altitude.toInt().toString(),
          command: 16, // MAV_CMD_NAV_WAYPOINT
        ),
      );

      waypoints.add(
        RoutePoint(
          id: '${timestamp}_${waypointCount++}',
          order: waypoints.length + 1,
          latitude: endPoint.latitude.toString(),
          longitude: endPoint.longitude.toString(),
          altitude: config.altitude.toInt().toString(),
          command: 16, // MAV_CMD_NAV_WAYPOINT
        ),
      );
    }

    return waypoints;
  }

  /// Generate perimeter pattern
  static List<RoutePoint> _generatePerimeter(
    LatLng topLeft,
    LatLng bottomRight,
    SurveyConfig config,
  ) {
    final waypoints = <RoutePoint>[];
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    // Calculate corners
    final minLat = math.min(topLeft.latitude, bottomRight.latitude);
    final maxLat = math.max(topLeft.latitude, bottomRight.latitude);
    final minLng = math.min(topLeft.longitude, bottomRight.longitude);
    final maxLng = math.max(topLeft.longitude, bottomRight.longitude);

    final corners = [
      LatLng(maxLat, minLng), // Top-left
      LatLng(maxLat, maxLng), // Top-right
      LatLng(minLat, maxLng), // Bottom-right
      LatLng(minLat, minLng), // Bottom-left
      LatLng(maxLat, minLng), // Back to start
    ];

    for (int i = 0; i < corners.length; i++) {
      waypoints.add(
        RoutePoint(
          id: '${timestamp}_$i',
          order: i + 1,
          latitude: corners[i].latitude.toString(),
          longitude: corners[i].longitude.toString(),
          altitude: config.altitude.toInt().toString(),
          command: 16, // MAV_CMD_NAV_WAYPOINT
        ),
      );
    }

    return waypoints;
  }

  /// Calculate distance between two points using Haversine formula
  static double _calculateDistance(LatLng point1, LatLng point2) {
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

    return _earthRadius * c;
  }

  /// Offset a point by x,y meters with rotation
  static LatLng _offsetPoint(
    LatLng center,
    double offsetX,
    double offsetY,
    double angleDegrees,
  ) {
    // Convert angle to radians
    final angleRad = angleDegrees * math.pi / 180;

    // Rotate the offset
    final rotatedX =
        offsetX * math.cos(angleRad) - offsetY * math.sin(angleRad);
    final rotatedY =
        offsetX * math.sin(angleRad) + offsetY * math.cos(angleRad);

    // Convert meters to degrees (approximate)
    final latOffset = rotatedY / _earthRadius * (180 / math.pi);
    final lngOffset =
        rotatedX /
        (_earthRadius * math.cos(center.latitude * math.pi / 180)) *
        (180 / math.pi);

    return LatLng(center.latitude + latOffset, center.longitude + lngOffset);
  }
}
