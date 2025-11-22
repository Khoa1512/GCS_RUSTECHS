import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Widget to draw polygon on map during survey area selection with animated dashed lines
class PolygonDrawer extends StatefulWidget {
  final List<LatLng> points;
  final Color color;
  final double strokeWidth;

  const PolygonDrawer({
    super.key,
    required this.points,
    this.color = Colors.teal,
    this.strokeWidth = 2.5,
  });

  @override
  State<PolygonDrawer> createState() => _PolygonDrawerState();
}

class _PolygonDrawerState extends State<PolygonDrawer>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.points.isEmpty) {
      return const SizedBox.shrink();
    }

    return Stack(
      children: [
        // Polygon fill (when >= 3 points)
        if (widget.points.length >= 3)
          PolygonLayer(
            polygons: [
              Polygon(
                points: widget.points,
                color: widget.color.withOpacity(0.5),
                borderColor: Colors.transparent,
                borderStrokeWidth: 0,
              ),
            ],
          ),

        // Animated dashed lines
        AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return PolylineLayer(polylines: _buildAnimatedDashedLines());
          },
        ),

        // Vertex markers (small dots)
        MarkerLayer(
          markers: widget.points.map((point) {
            return Marker(
              point: point,
              width: 12,
              height: 12,
              child: Container(
                decoration: BoxDecoration(
                  color: widget.color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  List<Polyline> _buildAnimatedDashedLines() {
    if (widget.points.length < 2) return [];

    final polylines = <Polyline>[];
    const dashLength = 0.0001; // ~10m in degrees (ngắn hơn)
    const gapLength = 0.00008; // ~8m in degrees
    final animationOffset =
        _animationController.value * (dashLength + gapLength);

    // Draw dashed lines between points
    for (int i = 0; i < widget.points.length; i++) {
      final start = widget.points[i];
      final end = widget.points[(i + 1) % widget.points.length];

      // Don't draw closing line if less than 3 points
      if (widget.points.length < 3 && i == widget.points.length - 1) break;

      // Calculate distance between points
      final latDiff = end.latitude - start.latitude;
      final lngDiff = end.longitude - start.longitude;
      final distance = math.sqrt(latDiff * latDiff + lngDiff * lngDiff);

      // Create dashes along the line
      double currentDist = -animationOffset % (dashLength + gapLength);

      while (currentDist < distance) {
        final startFraction = (currentDist / distance).clamp(0.0, 1.0);
        final endFraction = ((currentDist + dashLength) / distance).clamp(
          0.0,
          1.0,
        );

        if (startFraction < 1.0 && endFraction > 0.0) {
          final dashStart = LatLng(
            start.latitude + latDiff * startFraction,
            start.longitude + lngDiff * startFraction,
          );
          final dashEnd = LatLng(
            start.latitude + latDiff * endFraction,
            start.longitude + lngDiff * endFraction,
          );

          polylines.add(
            Polyline(
              points: [dashStart, dashEnd],
              color: Colors.white,
              strokeWidth: widget.strokeWidth,
            ),
          );
        }

        currentDist += dashLength + gapLength;
      }
    }

    return polylines;
  }
}
