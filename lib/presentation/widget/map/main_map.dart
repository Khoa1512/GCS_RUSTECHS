import 'dart:ui';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:skylink/core/constant/map_type.dart';
import 'package:skylink/data/models/route_point_model.dart';

class MainMapSimple extends StatefulWidget {
  final MapController mapController;
  final MapType mapType;
  final List<RoutePoint> routePoints;
  final Function(LatLng latLng) onTap;
  final Function(int index, LatLng newPosition)? onWaypointDrag;
  final bool isConfigValid;
  final LatLng? homePoint;

  const MainMapSimple({
    super.key,
    required this.mapController,
    required this.mapType,
    required this.routePoints,
    required this.onTap,
    this.onWaypointDrag,
    required this.isConfigValid,
    this.homePoint,
  });

  @override
  State<MainMapSimple> createState() => _MainMapSimpleState();
}

// Waypoint interaction modes:
// 1. Tap + Pan: Tap trên waypoint và kéo ngay lập tức (chuột)
// 2. Long Press + Move: Nhấn giữ waypoint (~500ms) rồi kéo (trackpad/touch)
class _MainMapSimpleState extends State<MainMapSimple> {
  bool _hasZoomedToHome = false;
  int? _draggedWaypointIndex;
  LatLng? _draggedPosition;
  DateTime? _lastUpdateTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeMap();
    });
  }

  @override
  void didUpdateWidget(MainMapSimple oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.homePoint != null && widget.homePoint == null) {
      _hasZoomedToHome = false;
    }
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
      widget.mapController.move(const LatLng(10.7302, 106.6988), 16);
    }
  }

  void _zoomToHomePoint() {
    if (widget.homePoint != null) {
      widget.mapController.move(widget.homePoint!, 18);
      _hasZoomedToHome = true;
    }
  }

  void _onWaypointPanUpdate(int index, DragUpdateDetails details) {
    // Debouncing để tránh quá nhiều updates (chỉ update mỗi 16ms ~ 60fps)
    final now = DateTime.now();
    if (_lastUpdateTime != null &&
        now.difference(_lastUpdateTime!).inMilliseconds < 16) {
      return;
    }
    _lastUpdateTime = now;

    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    // Cải thiện độ chính xác của việc chuyển đổi tọa độ
    final localPosition = renderBox.globalToLocal(details.globalPosition);
    final camera = widget.mapController.camera;
    final bounds = camera.visibleBounds;
    final size = renderBox.size;

    // Kiểm tra bounds để tránh kéo ra ngoài màn hình
    final clampedX = localPosition.dx.clamp(0.0, size.width);
    final clampedY = localPosition.dy.clamp(0.0, size.height);

    final relativeX = clampedX / size.width;
    final relativeY = clampedY / size.height;

    final newLat = bounds.north - (bounds.north - bounds.south) * relativeY;
    final newLng = bounds.west + (bounds.east - bounds.west) * relativeX;

    final point = LatLng(newLat, newLng);

    setState(() {
      _draggedWaypointIndex = index;
      _draggedPosition = point;
    });

    // Haptic feedback nhẹ khi kéo (chỉ khi thực sự di chuyển)
    if (_draggedPosition != null &&
        (point.latitude != _draggedPosition!.latitude ||
            point.longitude != _draggedPosition!.longitude)) {
      HapticFeedback.selectionClick();
    }

    if (widget.onWaypointDrag != null) {
      widget.onWaypointDrag!(index, point);
    }
  }

  void _onWaypointPanEnd(int index, DragEndDetails details) {
    // Haptic feedback khi hoàn thành việc kéo
    HapticFeedback.mediumImpact();

    setState(() {
      _draggedWaypointIndex = null;
      _draggedPosition = null;
      _lastUpdateTime = null;
    });
  }

  // Phương thức xử lý long press move (cho trackpad)
  void _onWaypointLongPressMoveUpdate(
    int index,
    LongPressMoveUpdateDetails details,
  ) {
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final localPosition = renderBox.globalToLocal(details.globalPosition);
    final camera = widget.mapController.camera;
    final bounds = camera.visibleBounds;
    final size = renderBox.size;

    // Kiểm tra bounds để tránh kéo ra ngoài màn hình
    final clampedX = localPosition.dx.clamp(0.0, size.width);
    final clampedY = localPosition.dy.clamp(0.0, size.height);

    final relativeX = clampedX / size.width;
    final relativeY = clampedY / size.height;

    final newLat = bounds.north - (bounds.north - bounds.south) * relativeY;
    final newLng = bounds.west + (bounds.east - bounds.west) * relativeX;

    final point = LatLng(newLat, newLng);

    setState(() {
      _draggedWaypointIndex = index;
      _draggedPosition = point;
    });

    if (widget.onWaypointDrag != null) {
      widget.onWaypointDrag!(index, point);
    }
  }

  void _onWaypointLongPressEnd(int index, LongPressEndDetails details) {
    // Haptic feedback khi hoàn thành việc kéo
    HapticFeedback.mediumImpact();

    setState(() {
      _draggedWaypointIndex = null;
      _draggedPosition = null;
    });
  }

  @override
  Widget build(BuildContext context) {
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
            interactionOptions: InteractionOptions(
              flags: _draggedWaypointIndex != null
                  ? InteractiveFlag.doubleTapZoom | InteractiveFlag.pinchZoom
                  : InteractiveFlag.all,
            ),
            onTap: (tapPosition, latlng) {
              if (widget.isConfigValid) {
                widget.onTap(latlng);
              }
            },
          ),
          children: [
            TileLayer(
              urlTemplate: widget.mapType.urlTemplate,
              userAgentPackageName: "com.example.vtol_rustech",
            ),
            if (latLngPoints.isNotEmpty)
              PolylineLayer(
                polylines: [
                  if (widget.homePoint != null && latLngPoints.isNotEmpty)
                    Polyline(
                      points: [widget.homePoint!, latLngPoints.first],
                      color: Colors.cyan,
                      strokeWidth: 4,
                    ),
                  ...List.generate(latLngPoints.length - 1, (index) {
                    return Polyline(
                      points: [latLngPoints[index], latLngPoints[index + 1]],
                      color: Colors.cyan,
                      strokeWidth: 4,
                    );
                  }),
                ],
              ),
            MarkerLayer(
              markers: [
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
                ...latLngPoints.asMap().entries.map((entry) {
                  final index = entry.key;
                  final point = entry.value;
                  final isDragged = _draggedWaypointIndex == index;

                  return Marker(
                    point: point,
                    width: isDragged ? 45 : 35, // Kích thước vừa phải
                    height: isDragged ? 45 : 35,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      // Cải thiện độ nhạy cho trackpad
                      dragStartBehavior: DragStartBehavior.down,
                      onTapDown: (details) {
                        // Haptic feedback khi bắt đầu chạm
                        HapticFeedback.lightImpact();
                        // Chuẩn bị cho việc kéo
                        setState(() {
                          _draggedWaypointIndex = index;
                        });
                      },
                      onLongPressStart: (details) {
                        // Long press để bắt đầu drag (tốt cho trackpad)
                        setState(() {
                          _draggedWaypointIndex = index;
                          _draggedPosition = point;
                        });
                        HapticFeedback.mediumImpact();
                      },
                      onLongPressMoveUpdate: (details) =>
                          _onWaypointLongPressMoveUpdate(index, details),
                      onLongPressEnd: (details) =>
                          _onWaypointLongPressEnd(index, details),
                      onPanStart: (details) {
                        setState(() {
                          _draggedWaypointIndex = index;
                          _draggedPosition = point;
                        });
                      },
                      onPanUpdate: (details) =>
                          _onWaypointPanUpdate(index, details),
                      onPanEnd: (details) => _onWaypointPanEnd(index, details),
                      onTap: () {
                        // Reset khi chỉ tap không kéo
                        setState(() {
                          _draggedWaypointIndex = null;
                          _draggedPosition = null;
                        });
                      },
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (isDragged)
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.blue.withOpacity(0.6),
                                  width: 3,
                                ),
                              ),
                            ),
                          Icon(
                            Icons.location_on,
                            color: isDragged ? Colors.blue : Colors.red,
                            size: isDragged
                                ? 40
                                : 36, // Kích thước icon lớn hơn
                          ),
                          Positioned.fill(
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  fontSize: isDragged ? 16 : 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withOpacity(0.8),
                                      offset: const Offset(1, 1),
                                      blurRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ],
        ),
        if (_draggedWaypointIndex != null && _draggedPosition != null)
          Positioned(
            left: 20,
            top: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.8),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Waypoint ${_draggedWaypointIndex! + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Lat: ${_draggedPosition!.latitude.toStringAsFixed(7)}',
                    style: const TextStyle(
                      color: Colors.cyan,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                  Text(
                    'Lng: ${_draggedPosition!.longitude.toStringAsFixed(7)}',
                    style: const TextStyle(
                      color: Colors.cyan,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
