import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:clipper2/clipper2.dart';

class GeoUtils {
  /// Checks if a polygon's bounding box intersects with the map's visible bounds.
  /// This is a fast preliminary check before doing more expensive intersection tests.
  static bool isPolygonVisible(
    List<LatLng> polygon,
    LatLngBounds visibleBounds,
  ) {
    if (polygon.isEmpty) return false;

    // Calculate polygon bounds
    double minLat = 90.0;
    double maxLat = -90.0;
    double minLon = 180.0;
    double maxLon = -180.0;

    for (var point in polygon) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLon) minLon = point.longitude;
      if (point.longitude > maxLon) maxLon = point.longitude;
    }

    // Check for intersection with visible bounds
    // Two rectangles intersect if they overlap on both axes

    // Visible bounds
    final double visSouth = visibleBounds.south;
    final double visNorth = visibleBounds.north;
    final double visWest = visibleBounds.west;
    final double visEast = visibleBounds.east;

    // Check latitude overlap
    bool latOverlap = (maxLat >= visSouth) && (minLat <= visNorth);

    // Check longitude overlap
    bool lonOverlap = (maxLon >= visWest) && (minLon <= visEast);

    return latOverlap && lonOverlap;
  }

  /// Simplifies a polygon using the Ramer-Douglas-Peucker algorithm.
  /// [tolerance] is the epsilon value (distance threshold).
  static List<LatLng> simplifyPolygon(List<LatLng> points, double tolerance) {
    if (points.length < 3) return points;

    // Find the point with the maximum distance
    double dmax = 0.0;
    int index = 0;
    int end = points.length - 1;

    for (int i = 1; i < end; i++) {
      double d = _perpendicularDistance(points[i], points[0], points[end]);
      if (d > dmax) {
        index = i;
        dmax = d;
      }
    }

    // If max distance is greater than epsilon, recursively simplify
    if (dmax > tolerance) {
      List<LatLng> recResults1 = simplifyPolygon(
        points.sublist(0, index + 1),
        tolerance,
      );
      List<LatLng> recResults2 = simplifyPolygon(
        points.sublist(index, end + 1),
        tolerance,
      );

      // Build the result list
      return [
        ...recResults1.sublist(0, recResults1.length - 1),
        ...recResults2,
      ];
    } else {
      return [points[0], points[end]];
    }
  }

  static double _perpendicularDistance(
    LatLng point,
    LatLng lineStart,
    LatLng lineEnd,
  ) {
    double dx = lineEnd.longitude - lineStart.longitude;
    double dy = lineEnd.latitude - lineStart.latitude;

    // Normalize
    double mag = dx * dx + dy * dy;
    if (mag > 0.0) {
      mag = 1.0 / mag; // Precompute inverse
    } else {
      // Line start and end are the same
      double dpx = point.longitude - lineStart.longitude;
      double dpy = point.latitude - lineStart.latitude;
      return dpx * dpx + dpy * dpy; // Squared distance
    }

    double u =
        ((point.longitude - lineStart.longitude) * dx +
            (point.latitude - lineStart.latitude) * dy) *
        mag;

    double x, y;
    if (u < 0.0) {
      x = lineStart.longitude;
      y = lineStart.latitude;
    } else if (u > 1.0) {
      x = lineEnd.longitude;
      y = lineEnd.latitude;
    } else {
      x = lineStart.longitude + u * dx;
      y = lineStart.latitude + u * dy;
    }

    double dpx = point.longitude - x;
    double dpy = point.latitude - y;
    return dpx * dpx + dpy * dpy; // Squared distance
  }

  /// Merges a list of polygons into a unified set of polygons (Union operation).
  /// Uses Clipper2 library.
  static List<List<LatLng>> mergePolygons(List<List<LatLng>> polygons) {
    if (polygons.isEmpty) return [];

    // 1. Convert LatLng to Path64 (Integer coordinates)
    // We scale by 1e7 to preserve precision (approx 1cm resolution)
    const double scale = 10000000.0;

    final Paths64 subject = [];

    for (final polygon in polygons) {
      final Path64 path = [];
      for (final point in polygon) {
        path.add(
          Point64(
            (point.latitude * scale).round(),
            (point.longitude * scale).round(),
          ),
        );
      }
      subject.add(path);
    }

    // 2. Execute Union Operation
    // Use named argument 'subject' as per error message
    final Paths64 solution = Clipper.union(
      subject: subject,
      fillRule: FillRule.nonZero,
    );

    // 3. Convert back to LatLng
    final List<List<LatLng>> result = [];

    for (final path in solution) {
      final List<LatLng> convertedPath = [];
      for (final point in path) {
        convertedPath.add(LatLng(point.x / scale, point.y / scale));
      }
      if (convertedPath.isNotEmpty) {
        result.add(convertedPath);
      }
    }

    return result;
  }
}
