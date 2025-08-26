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
  final Function(LatLng latLng) onTap;
  final bool isConfigValid;
  final LatLng? homePoint; // Home point từ GPS

  const MainMap({
    super.key,
    required this.mapController,
    required this.mapType,
    required this.routePoints,
    required this.onTap,
    required this.isConfigValid,
    this.homePoint,
  });

  @override
  State<MainMap> createState() => _MainMapState();
}

class _MainMapState extends State<MainMap> {
  bool isRouteSelectionMode = false;
  bool _hasZoomedToHome = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeMap();
    });
  }

  @override
  void didUpdateWidget(MainMap oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Reset zoom flag nếu homePoint bị set về null (GPS mất)
    if (oldWidget.homePoint != null && widget.homePoint == null) {
      _hasZoomedToHome = false;
    }

    // Nếu có home point mới và chưa zoom thì zoom đến home point
    if (widget.homePoint != null &&
        oldWidget.homePoint != widget.homePoint &&
        !_hasZoomedToHome) {
      _zoomToHomePoint();
    }
  }

  void _initializeMap() {
    if (widget.homePoint != null && !_hasZoomedToHome) {
      _zoomToHomePoint();
    } else {
      // Zoom mặc định đến ĐH Tôn Đức Thắng
      widget.mapController.move(const LatLng(10.7302, 106.6988), 16);
    }
  }

  void _zoomToHomePoint() {
    if (widget.homePoint != null) {
      widget.mapController.move(widget.homePoint!, 18);
      _hasZoomedToHome = true;
      print('Map zoomed to home point: ${widget.homePoint}');
    }
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
              if (isRouteSelectionMode && widget.isConfigValid) {
                widget.onTap(latlng);
              } else if (isRouteSelectionMode) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Please set command and altitude before adding waypoints',
                    ),
                    backgroundColor: Colors.orange,
                  ),
                );
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
            if (latLngPoints.isNotEmpty)
              PolylineLayer(
                polylines: [
                  // Route từ home point đến waypoint đầu tiên (nếu có home point)
                  if (widget.homePoint != null && latLngPoints.isNotEmpty)
                    Polyline(
                      points: [widget.homePoint!, latLngPoints.first],
                      color: Colors.tealAccent,
                      strokeWidth: 4,
                    ),
                  // Route giữa các waypoints
                  if (latLngPoints.length > 1)
                    Polyline(
                      points: latLngPoints,
                      color: Colors.tealAccent,
                      strokeWidth: 4,
                    ),
                ],
              ),

            // Route point markers với home marker
            MarkerLayer(
              markers: [
                // Home marker (nếu có)
                if (widget.homePoint != null)
                  Marker(
                    point: widget.homePoint!,
                    width: 40,
                    height: 40,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          'H',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                // Route point markers
                ...latLngPoints.asMap().entries.map((entry) {
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
                }),
              ],
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
