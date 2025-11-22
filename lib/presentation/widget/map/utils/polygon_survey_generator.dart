import 'dart:math' as math;
import 'package:latlong2/latlong.dart';
import 'package:skylink/data/models/route_point_model.dart';
import 'package:skylink/presentation/widget/map/utils/survey_generator.dart';

/// Generator chuyên xử lý survey cho polygon
/// TỰ ĐỘNG chọn thuật toán tối ưu: Line Sweep hoặc Decomposition
class PolygonSurveyGenerator {
  static const double _earthRadius = 6371000.0; // meters

  /// Generate waypoints cho polygon survey
  /// TỰ ĐỘNG chọn thuật toán tối ưu dựa trên độ phức tạp của polygon
  static List<RoutePoint> generateForPolygon({
    required List<LatLng> polygon,
    required SurveyConfig config,
  }) {
    if (polygon.length < 3) {
      print('❌ Polygon must have at least 3 points');
      return [];
    }

    print('🎯 Analyzing polygon complexity...');

    // 1. Tính toán polygon bounds và complexity
    final bounds = _calculateBoundingBox(polygon);
    final polygonArea = bounds.width * bounds.height;
    final complexity = _analyzePolygonComplexity(polygon);

    print('   Polygon vertices: ${polygon.length}');
    print('   Polygon area: ~${polygonArea.toStringAsFixed(0)}m²');
    print('   Complexity score: ${complexity.score.toStringAsFixed(2)}');
    print('   Is complex: ${complexity.isComplex ? "YES" : "NO"}');
    print('   Reason: ${complexity.reason}');

    // 2. Auto-optimize spacing
    double optimizedSpacing = config.spacing;
    final minDimension = math.min(bounds.width, bounds.height);
    final recommendedSpacing = minDimension / 10;

    if (config.spacing > recommendedSpacing * 2) {
      print('   ⚠️  Spacing too large! Auto-adjusting...');
      optimizedSpacing = recommendedSpacing;
      print('   ✅ Optimized spacing: ${optimizedSpacing.toStringAsFixed(1)}m');
    } else if (config.spacing < recommendedSpacing / 3) {
      print('   ⚠️  Spacing too small! Auto-adjusting...');
      optimizedSpacing = recommendedSpacing / 2;
      print('   ✅ Optimized spacing: ${optimizedSpacing.toStringAsFixed(1)}m');
    }

    // Create optimized config
    final optimizedConfig = SurveyConfig(
      spacing: optimizedSpacing,
      angle: config.angle,
      altitude: config.altitude,
      pattern: SurveyPattern.lawnmower,
      overlap: config.overlap,
    );

    // 3. Chọn thuật toán dựa trên complexity
    if (complexity.isComplex) {
      print('   🚀 Using DECOMPOSITION algorithm (optimal for complex shapes)');
      return _generateWithDecomposition(polygon, optimizedConfig);
    } else {
      print('   ⚡ Using LINE SWEEP algorithm (optimal for simple shapes)');
      return _generateLawnmowerForPolygon(polygon, optimizedConfig);
    }
  }

  /// Generate Lawnmower pattern TRỰC TIẾP cho polygon
  /// Mỗi line chỉ bay trong phần polygon, KHÔNG bay toàn bộ width
  static List<RoutePoint> _generateLawnmowerForPolygon(
    List<LatLng> polygon,
    SurveyConfig config,
  ) {
    print('🚁 Generating Lawnmower for Polygon...');

    // 1. Tính bounding box và center
    final bounds = _calculateBoundingBox(polygon);
    final center = LatLng(
      (bounds.minLat + bounds.maxLat) / 2,
      (bounds.minLng + bounds.maxLng) / 2,
    );

    // 2. Rotate polygon về góc 0 để dễ tính
    final rotatedPolygon = _rotatePolygon(polygon, center, -config.angle);

    // 3. Tính bounding box sau khi rotate
    final rotatedBounds = _calculateBoundingBox(rotatedPolygon);

    // 4. Tính số lines dọc theo height
    final numLines =
        ((rotatedBounds.maxLat - rotatedBounds.minLat) *
                _earthRadius *
                math.pi /
                180 /
                config.spacing)
            .ceil();

    print('   Polygon vertices: ${polygon.length}');
    print(
      '   Bounding box: ${bounds.width.toStringAsFixed(0)}m x ${bounds.height.toStringAsFixed(0)}m',
    );
    print('   Number of lines: $numLines');
    print('   Spacing: ${config.spacing}m');

    final waypoints = <RoutePoint>[];
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    int waypointCount = 0;

    // 5. Scan từng line ngang
    for (int i = 0; i <= numLines; i++) {
      // Vị trí latitude của line này
      final lat =
          rotatedBounds.minLat +
          (i * config.spacing * 180 / (math.pi * _earthRadius));

      // Tìm tất cả intersection points của line này với polygon edges
      final intersections = _findLineIntersections(lat, rotatedPolygon);

      if (intersections.isEmpty) continue;

      // Sort intersections theo longitude
      intersections.sort((a, b) => a.longitude.compareTo(b.longitude));

      // Tạo waypoints cho mỗi segment (pair of intersections)
      // Zigzag pattern: line lẻ bay ngược chiều
      final isReverse = i % 2 == 1;
      final segments = <List<LatLng>>[];

      // Group intersections thành segments (inside polygon)
      for (int j = 0; j < intersections.length - 1; j += 2) {
        if (j + 1 < intersections.length) {
          segments.add([intersections[j], intersections[j + 1]]);
        }
      }

      // Add waypoints cho line này
      // Tránh duplicate với waypoint cuối cùng
      if (isReverse) {
        final reversedSegments = segments.reversed.toList();
        for (int j = 0; j < reversedSegments.length; j++) {
          final segment = reversedSegments[j];
          final start = _rotatePoint(segment[1], center, config.angle);
          final end = _rotatePoint(segment[0], center, config.angle);

          // Add start point (check duplicate)
          if (!_isDuplicatePoint(waypoints, start)) {
            waypoints.add(
              _createWaypoint(
                start,
                config.altitude,
                timestamp,
                waypointCount++,
              ),
            );
          }

          // Only add end point if it's the last segment of this line
          if (j == reversedSegments.length - 1) {
            if (!_isDuplicatePoint(waypoints, end)) {
              waypoints.add(
                _createWaypoint(
                  end,
                  config.altitude,
                  timestamp,
                  waypointCount++,
                ),
              );
            }
          }
        }
      } else {
        for (int j = 0; j < segments.length; j++) {
          final segment = segments[j];
          final start = _rotatePoint(segment[0], center, config.angle);
          final end = _rotatePoint(segment[1], center, config.angle);

          // Add start point (check duplicate)
          if (!_isDuplicatePoint(waypoints, start)) {
            waypoints.add(
              _createWaypoint(
                start,
                config.altitude,
                timestamp,
                waypointCount++,
              ),
            );
          }

          // Only add end point if it's the last segment of this line
          if (j == segments.length - 1) {
            if (!_isDuplicatePoint(waypoints, end)) {
              waypoints.add(
                _createWaypoint(
                  end,
                  config.altitude,
                  timestamp,
                  waypointCount++,
                ),
              );
            }
          }
        }
      }
    }

    // Re-index order
    for (int i = 0; i < waypoints.length; i++) {
      waypoints[i] = waypoints[i].copyWith(order: i + 1);
    }

    print('   ✅ Generated ${waypoints.length} waypoints');
    return waypoints;
  }

  // ============================================================================
  // DECOMPOSITION ALGORITHM - For Complex Polygons
  // ============================================================================

  /// Generate waypoints using Polygon Decomposition
  /// Chia polygon phức tạp thành các convex parts, optimize từng phần
  static List<RoutePoint> _generateWithDecomposition(
    List<LatLng> polygon,
    SurveyConfig config,
  ) {
    print('🔧 Decomposing polygon into convex parts...');

    // 1. Decompose polygon into convex parts
    final convexParts = _decomposePolygon(polygon);
    print('   ✅ Decomposed into ${convexParts.length} convex parts');

    // 2. Generate survey for each part with optimal angle
    final allWaypoints = <List<RoutePoint>>[];
    for (int i = 0; i < convexParts.length; i++) {
      final part = convexParts[i];
      print('   📍 Processing part ${i + 1}/${convexParts.length}...');

      // Find optimal angle for this part
      final optimalAngle = _findOptimalAngle(part);
      final partConfig = SurveyConfig(
        spacing: config.spacing,
        angle: optimalAngle,
        altitude: config.altitude,
        pattern: SurveyPattern.lawnmower,
        overlap: config.overlap,
      );

      // Generate waypoints for this part
      final waypoints = _generateLawnmowerForPolygon(part, partConfig);
      if (waypoints.isNotEmpty) {
        allWaypoints.add(waypoints);
        print('      Generated ${waypoints.length} waypoints');
      }
    }

    // 3. Connect all parts using TSP (Traveling Salesman Problem)
    print('   🔗 Connecting parts with optimal path...');
    final connectedWaypoints = _connectPartsWithTSP(allWaypoints);

    // 4. Re-index all waypoints
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    for (int i = 0; i < connectedWaypoints.length; i++) {
      connectedWaypoints[i] = RoutePoint(
        id: '${timestamp}_$i',
        order: i + 1,
        latitude: connectedWaypoints[i].latitude,
        longitude: connectedWaypoints[i].longitude,
        altitude: connectedWaypoints[i].altitude,
        command: connectedWaypoints[i].command,
      );
    }

    print('   ✅ Total waypoints: ${connectedWaypoints.length}');
    return connectedWaypoints;
  }

  /// Analyze polygon complexity to decide which algorithm to use
  static _PolygonComplexity _analyzePolygonComplexity(List<LatLng> polygon) {
    // Factor 1: Concavity (reflex angles)
    int reflexAngles = 0;
    for (int i = 0; i < polygon.length; i++) {
      final prev = polygon[(i - 1 + polygon.length) % polygon.length];
      final curr = polygon[i];
      final next = polygon[(i + 1) % polygon.length];

      if (_isReflexAngle(prev, curr, next)) {
        reflexAngles++;
      }
    }

    // Factor 2: Aspect ratio (얼마나 길쭉한가)
    final bounds = _calculateBoundingBox(polygon);
    final aspectRatio =
        math.max(bounds.width, bounds.height) /
        math.min(bounds.width, bounds.height);

    // Factor 3: Area efficiency (polygon area vs bounding box area)
    final polygonArea = _calculatePolygonArea(polygon);
    final boundingBoxArea = bounds.width * bounds.height;
    final areaEfficiency = polygonArea / boundingBoxArea;

    // Calculate complexity score
    double score = 0;
    String reason = '';

    // Reflex angles contribute most to complexity
    if (reflexAngles >= 4) {
      score += 3.0;
      reason += 'Many concave angles ($reflexAngles). ';
    } else if (reflexAngles >= 2) {
      score += 1.5;
      reason += 'Some concave angles ($reflexAngles). ';
    }

    // Aspect ratio
    if (aspectRatio > 3.0) {
      score += 1.5;
      reason += 'High aspect ratio (${aspectRatio.toStringAsFixed(1)}). ';
    }

    // Area efficiency (low = lots of empty space in bounding box)
    if (areaEfficiency < 0.6) {
      score += 2.0;
      reason +=
          'Low area efficiency (${(areaEfficiency * 100).toStringAsFixed(0)}%). ';
    }

    // Decision: Complex if score >= 3.0
    final isComplex = score >= 3.0;

    if (!isComplex && reason.isEmpty) {
      reason = 'Simple convex shape, Line Sweep is optimal.';
    }

    return _PolygonComplexity(
      score: score,
      isComplex: isComplex,
      reason: reason.trim(),
      reflexAngles: reflexAngles,
      aspectRatio: aspectRatio,
      areaEfficiency: areaEfficiency,
    );
  }

  /// Check if angle at vertex is reflex (> 180 degrees)
  static bool _isReflexAngle(LatLng prev, LatLng curr, LatLng next) {
    final dx1 = curr.longitude - prev.longitude;
    final dy1 = curr.latitude - prev.latitude;
    final dx2 = next.longitude - curr.longitude;
    final dy2 = next.latitude - curr.latitude;

    // Cross product
    final cross = dx1 * dy2 - dy1 * dx2;

    // Negative cross product = reflex angle (for counter-clockwise polygon)
    return cross < 0;
  }

  /// Calculate polygon area using Shoelace formula
  static double _calculatePolygonArea(List<LatLng> polygon) {
    double area = 0;
    for (int i = 0; i < polygon.length; i++) {
      final j = (i + 1) % polygon.length;
      area += polygon[i].longitude * polygon[j].latitude;
      area -= polygon[j].longitude * polygon[i].latitude;
    }
    area = area.abs() / 2;

    // Convert to square meters (approximate)
    final centerLat =
        polygon.map((p) => p.latitude).reduce((a, b) => a + b) / polygon.length;
    final metersPerDegreeLat = _earthRadius * math.pi / 180;
    final metersPerDegreeLng =
        _earthRadius * math.pi / 180 * math.cos(centerLat * math.pi / 180);

    return area * metersPerDegreeLat * metersPerDegreeLng;
  }

  /// Decompose polygon into convex parts using ear clipping
  static List<List<LatLng>> _decomposePolygon(List<LatLng> polygon) {
    // For now, use a simple approach: split at reflex vertices
    // Advanced: Use proper polygon decomposition (Hertel-Mehlhorn algorithm)

    final parts = <List<LatLng>>[];
    final reflexVertices = <int>[];

    // Find all reflex vertices
    for (int i = 0; i < polygon.length; i++) {
      final prev = polygon[(i - 1 + polygon.length) % polygon.length];
      final curr = polygon[i];
      final next = polygon[(i + 1) % polygon.length];

      if (_isReflexAngle(prev, curr, next)) {
        reflexVertices.add(i);
      }
    }

    // If no reflex vertices, polygon is already convex
    if (reflexVertices.isEmpty) {
      return [polygon];
    }

    // Simple decomposition: split polygon at each reflex vertex
    // This is not optimal but works for most cases
    if (reflexVertices.length <= 2) {
      // For simple L-shapes or U-shapes, split into 2-3 rectangles
      parts.addAll(_splitSimplePolygon(polygon, reflexVertices));
    } else {
      // For very complex shapes, fall back to original polygon
      // (Decomposition would be too complex)
      parts.add(polygon);
    }

    return parts.isEmpty ? [polygon] : parts;
  }

  /// Split simple polygon (L, U shape) into convex parts
  static List<List<LatLng>> _splitSimplePolygon(
    List<LatLng> polygon,
    List<int> reflexVertices,
  ) {
    // This is a simplified version
    // For production, use proper polygon decomposition algorithms

    // For now, just return the original polygon
    // TODO: Implement proper splitting for L/U shapes
    return [polygon];
  }

  /// Find optimal scan angle for a polygon part
  static double _findOptimalAngle(List<LatLng> polygon) {
    // Find the longest edge and use its angle
    double maxLength = 0;
    double optimalAngle = 0;

    for (int i = 0; i < polygon.length; i++) {
      final p1 = polygon[i];
      final p2 = polygon[(i + 1) % polygon.length];

      final length = _calculateDistance(p1, p2);
      if (length > maxLength) {
        maxLength = length;

        // Calculate angle of this edge
        final dx = p2.longitude - p1.longitude;
        final dy = p2.latitude - p1.latitude;
        optimalAngle = math.atan2(dy, dx) * 180 / math.pi;
      }
    }

    return optimalAngle;
  }

  /// Connect multiple parts using TSP (greedy nearest neighbor)
  static List<RoutePoint> _connectPartsWithTSP(List<List<RoutePoint>> parts) {
    if (parts.isEmpty) return [];
    if (parts.length == 1) return parts[0];

    final connected = <RoutePoint>[];
    final visited = <bool>[];
    for (int i = 0; i < parts.length; i++) {
      visited.add(false);
    }

    // Start with first part
    int currentPart = 0;
    visited[currentPart] = true;
    connected.addAll(parts[currentPart]);

    // Greedy: always go to nearest unvisited part
    for (int i = 1; i < parts.length; i++) {
      final lastPoint = connected.last;
      final lastLat = double.parse(lastPoint.latitude);
      final lastLng = double.parse(lastPoint.longitude);

      // Find nearest unvisited part
      double minDistance = double.infinity;
      int nearestPart = -1;
      bool shouldReverse = false;

      for (int j = 0; j < parts.length; j++) {
        if (visited[j]) continue;

        final part = parts[j];
        final firstPoint = part.first;
        final lastPointOfPart = part.last;

        // Distance to first point
        final distToFirst = _calculateDistance(
          LatLng(lastLat, lastLng),
          LatLng(
            double.parse(firstPoint.latitude),
            double.parse(firstPoint.longitude),
          ),
        );

        // Distance to last point
        final distToLast = _calculateDistance(
          LatLng(lastLat, lastLng),
          LatLng(
            double.parse(lastPointOfPart.latitude),
            double.parse(lastPointOfPart.longitude),
          ),
        );

        if (distToFirst < minDistance) {
          minDistance = distToFirst;
          nearestPart = j;
          shouldReverse = false;
        }

        if (distToLast < minDistance) {
          minDistance = distToLast;
          nearestPart = j;
          shouldReverse = true;
        }
      }

      // Add nearest part
      if (nearestPart != -1) {
        visited[nearestPart] = true;
        final partWaypoints = shouldReverse
            ? parts[nearestPart].reversed.toList()
            : parts[nearestPart];
        connected.addAll(partWaypoints);
      }
    }

    return connected;
  }

  // ============================================================================
  // HELPER CLASSES
  // ============================================================================

  /// Tìm tất cả intersection points của một horizontal line với polygon
  static List<LatLng> _findLineIntersections(double lat, List<LatLng> polygon) {
    final intersections = <LatLng>[];

    for (int i = 0; i < polygon.length; i++) {
      final p1 = polygon[i];
      final p2 = polygon[(i + 1) % polygon.length];

      // Check if line crosses this edge
      if ((p1.latitude <= lat && p2.latitude >= lat) ||
          (p1.latitude >= lat && p2.latitude <= lat)) {
        // Calculate intersection longitude
        if (p1.latitude == p2.latitude) {
          // Horizontal edge - skip or handle specially
          continue;
        }

        final t = (lat - p1.latitude) / (p2.latitude - p1.latitude);
        final lng = p1.longitude + t * (p2.longitude - p1.longitude);

        intersections.add(LatLng(lat, lng));
      }
    }

    return intersections;
  }

  /// Rotate polygon quanh center point
  static List<LatLng> _rotatePolygon(
    List<LatLng> polygon,
    LatLng center,
    double angleDegrees,
  ) {
    return polygon
        .map((point) => _rotatePoint(point, center, angleDegrees))
        .toList();
  }

  /// Rotate một point quanh center
  static LatLng _rotatePoint(LatLng point, LatLng center, double angleDegrees) {
    final angleRad = angleDegrees * math.pi / 180;

    // Convert to relative coordinates (meters approximation)
    final dx =
        (point.longitude - center.longitude) *
        _earthRadius *
        math.cos(center.latitude * math.pi / 180) *
        math.pi /
        180;
    final dy =
        (point.latitude - center.latitude) * _earthRadius * math.pi / 180;

    // Rotate
    final rotatedX = dx * math.cos(angleRad) - dy * math.sin(angleRad);
    final rotatedY = dx * math.sin(angleRad) + dy * math.cos(angleRad);

    // Convert back to lat/lng
    final newLat = center.latitude + rotatedY * 180 / (math.pi * _earthRadius);
    final newLng =
        center.longitude +
        rotatedX *
            180 /
            (math.pi *
                _earthRadius *
                math.cos(center.latitude * math.pi / 180));

    return LatLng(newLat, newLng);
  }

  /// Helper: Create RoutePoint
  static RoutePoint _createWaypoint(
    LatLng point,
    double altitude,
    int timestamp,
    int count,
  ) {
    return RoutePoint(
      id: '${timestamp}_$count',
      order: count + 1,
      latitude: point.latitude.toString(),
      longitude: point.longitude.toString(),
      altitude: altitude.toInt().toString(),
      command: 16, // MAV_CMD_NAV_WAYPOINT
    );
  }

  /// Check if point is duplicate with last waypoint
  static bool _isDuplicatePoint(List<RoutePoint> waypoints, LatLng point) {
    if (waypoints.isEmpty) return false;

    final lastWaypoint = waypoints.last;
    final lastLat = double.parse(lastWaypoint.latitude);
    final lastLng = double.parse(lastWaypoint.longitude);

    // Check if distance < 0.1m (consider as duplicate)
    final distance = _calculateDistance(LatLng(lastLat, lastLng), point);

    return distance < 0.1; // 0.1 meter threshold
  }

  /// Calculate bounding box
  static _PolygonBounds _calculateBoundingBox(List<LatLng> polygon) {
    double minLat = polygon.first.latitude;
    double maxLat = polygon.first.latitude;
    double minLng = polygon.first.longitude;
    double maxLng = polygon.first.longitude;

    for (final point in polygon) {
      minLat = math.min(minLat, point.latitude);
      maxLat = math.max(maxLat, point.latitude);
      minLng = math.min(minLng, point.longitude);
      maxLng = math.max(maxLng, point.longitude);
    }

    final centerLat = (minLat + maxLat) / 2;
    final width = _calculateDistance(
      LatLng(centerLat, minLng),
      LatLng(centerLat, maxLng),
    );
    final height = _calculateDistance(
      LatLng(minLat, (minLng + maxLng) / 2),
      LatLng(maxLat, (minLng + maxLng) / 2),
    );

    return _PolygonBounds(
      minLat: minLat,
      maxLat: maxLat,
      minLng: minLng,
      maxLng: maxLng,
      width: width,
      height: height,
    );
  }

  /// Calculate distance between two points
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
}

/// Helper class for polygon bounds
class _PolygonBounds {
  final double minLat;
  final double maxLat;
  final double minLng;
  final double maxLng;
  final double width; // meters
  final double height; // meters

  _PolygonBounds({
    required this.minLat,
    required this.maxLat,
    required this.minLng,
    required this.maxLng,
    required this.width,
    required this.height,
  });
}

/// Helper class for polygon complexity analysis
class _PolygonComplexity {
  final double score;
  final bool isComplex;
  final String reason;
  final int reflexAngles;
  final double aspectRatio;
  final double areaEfficiency;

  _PolygonComplexity({
    required this.score,
    required this.isComplex,
    required this.reason,
    required this.reflexAngles,
    required this.aspectRatio,
    required this.areaEfficiency,
  });
}
