import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:skylink/core/constant/map_type.dart';
import 'package:skylink/data/models/route_point_model.dart';

class MainMap extends StatefulWidget {
  final MapController mapController;
  final MapType mapType;
  final List<RoutePoint> routePoints;
  final Function(LatLng) onTap;

  const MainMap({
    super.key,
    required this.mapController,
    required this.mapType,
    required this.routePoints,
    required this.onTap,
  });

  @override
  State<MainMap> createState() => _MainMapState();
}

class _MainMapState extends State<MainMap> {
  bool isRouteSelectionMode = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.mapController.move(const LatLng(10.8231, 106.6297), 16);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Convert RoutePoints to LatLng
    final latLngPoints = widget.routePoints
        .map(
          (point) => LatLng(
            double.parse(point.latitude),
            double.parse(point.longitude),
          ),
        )
        .toList();

    return Stack(
      children: [
        FlutterMap(
          mapController: widget.mapController,
          options: MapOptions(
            initialZoom: 5,
            onTap: (tapPosition, latlng) {
              if (isRouteSelectionMode) {
                widget.onTap(latlng);
              }
            },
          ),
          children: [
            // Base map tiles
            TileLayer(
              urlTemplate: widget.mapType.urlTemplate,
              userAgentPackageName: "com.example.vtol_rustech",
            ),

            // Route polyline layer
            if (latLngPoints.length > 1)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: latLngPoints,
                    color: Colors.tealAccent,
                    strokeWidth: 4,
                  ),
                ],
              ),

            // Route point markers with order number
            MarkerLayer(
              markers: latLngPoints.asMap().entries.map((entry) {
                final index = entry.key;
                final point = entry.value;

                return Marker(
                  point: point,
                  width: 40,
                  height: 40,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 40,
                      ),
                      Positioned(
                        top: 8,
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                offset: Offset(0, 0),
                                blurRadius: 2,
                                color: Colors.black,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),

        // Route selection toggle button
        Positioned(
          bottom: 20,
          left: 20,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: isRouteSelectionMode
                      ? Colors.teal.withOpacity(0.2)
                      : Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isRouteSelectionMode
                        ? Colors.teal.withOpacity(0.3)
                        : Colors.white.withOpacity(0.2),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      setState(() {
                        isRouteSelectionMode = !isRouteSelectionMode;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isRouteSelectionMode
                                ? Icons.edit_location_alt
                                : Icons.add_location_alt,
                            color: isRouteSelectionMode
                                ? Colors.teal
                                : Colors.white.withOpacity(0.9),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isRouteSelectionMode
                                ? 'Route Mode ON'
                                : 'Choose Route',
                            style: TextStyle(
                              color: isRouteSelectionMode
                                  ? Colors.teal
                                  : Colors.white.withOpacity(0.9),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
