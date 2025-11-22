import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Widget to draw and display a bounding box on the map
class BoundingBoxDrawer extends StatelessWidget {
  final LatLng? startPoint;
  final LatLng? endPoint;
  final bool isDrawing;

  const BoundingBoxDrawer({
    super.key,
    this.startPoint,
    this.endPoint,
    this.isDrawing = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!isDrawing || startPoint == null) {
      return const SizedBox.shrink();
    }

    // If we have both points, create the bounding box
    if (endPoint != null) {
      final bounds = _createBoundingBox(startPoint!, endPoint!);

      return PolygonLayer(
        polygons: [
          Polygon(
            points: bounds,
            color: Colors.teal.withOpacity(0.2),
            borderColor: Colors.teal,
            borderStrokeWidth: 3,
          ),
        ],
      );
    }

    // Just show the start point
    return MarkerLayer(
      markers: [
        Marker(
          point: startPoint!,
          width: 20,
          height: 20,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.teal,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  /// Create bounding box corners from two diagonal points
  List<LatLng> _createBoundingBox(LatLng point1, LatLng point2) {
    final minLat = point1.latitude < point2.latitude
        ? point1.latitude
        : point2.latitude;
    final maxLat = point1.latitude > point2.latitude
        ? point1.latitude
        : point2.latitude;
    final minLng = point1.longitude < point2.longitude
        ? point1.longitude
        : point2.longitude;
    final maxLng = point1.longitude > point2.longitude
        ? point1.longitude
        : point2.longitude;

    return [
      LatLng(minLat, minLng), // Bottom-left
      LatLng(minLat, maxLng), // Bottom-right
      LatLng(maxLat, maxLng), // Top-right
      LatLng(maxLat, minLng), // Top-left
      LatLng(minLat, minLng), // Close the box
    ];
  }
}
