import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:skylink/core/constant/map_type.dart';
import 'package:skylink/data/models/route_point_model.dart';
import 'package:skylink/presentation/widget/mission/mission_visualization_helpers.dart';
import 'package:skylink/presentation/widget/mission/mission_waypoint_helpers.dart';
import 'package:skylink/presentation/widget/map/components/bounding_box_drawer.dart';
import 'package:skylink/presentation/widget/map/components/polygon_drawer.dart';

class MainMapSimple extends StatefulWidget {
  final MapController mapController;
  final MapType mapType;
  final List<RoutePoint> routePoints;
  final Function(LatLng latLng)? onTap;
  final Function(int index, LatLng newPosition)? onWaypointDrag;
  final Function(int index, Offset globalPosition, {bool isCtrlPressed})?
  onWaypointTap;
  final VoidCallback? onWaypointDragStart;
  final VoidCallback? onWaypointDragEnd;
  final Function(LatLng latLng)? onPointerHover;
  final bool isConfigValid;
  final LatLng? homePoint;
  final Map<String, LayerLink>? waypointLayerLinks;
  final RoutePoint? selectedWaypoint;
  final Set<String>? selectedWaypointIds;

  // Bounding box drawing state
  final bool isDrawingBoundingBox;
  final LatLng? boundingBoxStart;
  final LatLng? boundingBoxEnd;

  // Polygon drawing state
  final bool isDrawingPolygon;
  final List<LatLng> polygonPoints;

  const MainMapSimple({
    super.key,
    required this.mapController,
    required this.mapType,
    required this.routePoints,
    this.onTap,
    this.onWaypointDrag,
    this.onWaypointTap,
    this.onWaypointDragStart,
    this.onWaypointDragEnd,
    this.onPointerHover,
    required this.isConfigValid,
    this.homePoint,
    this.waypointLayerLinks,
    this.selectedWaypoint,
    this.selectedWaypointIds,
    this.isDrawingBoundingBox = false,
    this.boundingBoxStart,
    this.boundingBoxEnd,
    this.isDrawingPolygon = false,
    this.polygonPoints = const [],
  });

  @override
  State<MainMapSimple> createState() => MainMapSimpleState();
}

class MainMapSimpleState extends State<MainMapSimple> {
  bool _hasZoomedToHome = false;
  int? _draggedWaypointIndex;
  LatLng? _draggedPosition;

  void clearDragState() {
    setState(() {
      _draggedWaypointIndex = null;
      _draggedPosition = null;
    });
  }

  // Public method to clear drag state from outside
  void clearMapDragState() {
    clearDragState();
  }

  DateTime? _lastUpdateTime;

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
    // Force rebuild if mapType changes
    if (oldWidget.mapType != widget.mapType) {
      setState(() {});
    }
  }

  void _initializeMap() {
    if (widget.homePoint != null && !_hasZoomedToHome) {
      _zoomToHomePoint();
    }
  }

  void _zoomToHomePoint() {
    if (widget.homePoint != null) {
      widget.mapController.move(widget.homePoint!, 20);
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
    // Check if this is a drag operation or a static long press
    if (_draggedWaypointIndex == index && _draggedPosition != null) {
      // This was a drag operation - apply final position
      HapticFeedback.mediumImpact();
      setState(() {
        _draggedWaypointIndex = null;
        _draggedPosition = null;
      });
    } else {
      // This was a static long press - show context menu
      if (widget.onWaypointTap != null) {
        widget.onWaypointTap!(index, details.globalPosition);
      }
    }
  }

  void _onWaypointLongPressStart(int index, LongPressStartDetails details) {
    // Start timing - if user starts moving, it becomes drag, otherwise context menu
    HapticFeedback.lightImpact();

    if (widget.onWaypointDrag != null) {
      setState(() {
        _draggedWaypointIndex = index;
        _draggedPosition = LatLng(
          double.parse(widget.routePoints[index].latitude),
          double.parse(widget.routePoints[index].longitude),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // All waypoints for rendering markers
    final latLngPoints = widget.routePoints
        .map(
          (point) => LatLng(
            double.parse(point.latitude),
            double.parse(point.longitude),
          ),
        )
        .toList();

    // Flight path points (excluding ROI points)
    final flightPathPoints =
        MissionWaypointHelpers.getFlightPathPoints(widget.routePoints)
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
            initialCenter:
                widget.homePoint ??
                const LatLng(10.7302, 106.6988), // Đại học Tôn Đức Thắng
            initialZoom: widget.homePoint != null ? 18.0 : 16.0,
            minZoom: 3.0,
            maxZoom: 20.0,
            interactionOptions: InteractionOptions(
              flags: _draggedWaypointIndex != null
                  ? InteractiveFlag.doubleTapZoom |
                        InteractiveFlag.pinchZoom |
                        InteractiveFlag.drag
                  : InteractiveFlag.all,
            ),
            onTap: (tapPosition, latlng) {
              if (widget.isConfigValid && widget.onTap != null) {
                widget.onTap!(latlng);
              }
            },
            onPointerHover: (event, latlng) {
              if (widget.isDrawingBoundingBox &&
                  widget.boundingBoxStart != null &&
                  widget.onPointerHover != null) {
                widget.onPointerHover!(latlng);
              }
            },
          ),
          children: [
            TileLayer(
              urlTemplate: widget.mapType.urlTemplate,
              userAgentPackageName: "com.example.vtol_rustech",
              tileProvider: NetworkTileProvider(),
            ),

            // Bounding box drawer layer
            BoundingBoxDrawer(
              isDrawing: widget.isDrawingBoundingBox,
              startPoint: widget.boundingBoxStart,
              endPoint: widget.boundingBoxEnd,
            ),

            // Polygon drawer layer
            if (widget.isDrawingPolygon)
              PolygonDrawer(points: widget.polygonPoints),

            if (flightPathPoints.isNotEmpty)
              PolylineLayer(
                polylines: [
                  if (widget.homePoint != null && flightPathPoints.isNotEmpty)
                    Polyline(
                      points: [widget.homePoint!, flightPathPoints.first],
                      color: Colors.cyan,
                      strokeWidth: 4,
                    ),
                  ...List.generate(flightPathPoints.length - 1, (index) {
                    return Polyline(
                      points: [
                        flightPathPoints[index],
                        flightPathPoints[index + 1],
                      ],
                      color: Colors.cyan,
                      strokeWidth: 4,
                    );
                  }),
                  // Add loiter circles visualization
                  ...MissionVisualizationHelpers.generateLoiterPolylines(
                    widget.routePoints,
                    mapZoom: widget.mapController.camera.zoom,
                  ),
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
                  final routePoint = widget.routePoints[index];
                  final isSingleSelected =
                      widget.selectedWaypoint?.id == routePoint.id;
                  final isMultiSelected =
                      widget.selectedWaypointIds?.contains(routePoint.id) ??
                      false;
                  final isHighlighted = isSingleSelected || isMultiSelected;

                  return Marker(
                    point: point,
                    width: isHighlighted ? 45 : 35, // Kích thước vừa phải
                    height: isHighlighted ? 45 : 35,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      // Cải thiện độ nhạy cho trackpad
                      dragStartBehavior: DragStartBehavior.down,
                      onTapDown: widget.onWaypointDrag != null
                          ? (details) {
                              // Haptic feedback khi bắt đầu chạm
                              HapticFeedback.lightImpact();
                              // Chuẩn bị cho việc kéo
                              setState(() {
                                _draggedWaypointIndex = index;
                              });
                            }
                          : null,
                      onLongPressStart: (details) {
                        // Start timing for long press
                        _onWaypointLongPressStart(index, details);
                        widget.onWaypointDragStart?.call();
                      },
                      onLongPressMoveUpdate: widget.onWaypointDrag != null
                          ? (details) =>
                                _onWaypointLongPressMoveUpdate(index, details)
                          : null,
                      onLongPressEnd: (details) {
                        _onWaypointLongPressEnd(index, details);
                        widget.onWaypointDragEnd?.call();
                      },
                      onPanStart: widget.onWaypointDrag != null
                          ? (details) {
                              setState(() {
                                _draggedWaypointIndex = index;
                                _draggedPosition = point;
                              });
                              widget.onWaypointDragStart?.call();
                            }
                          : null,
                      onPanUpdate: widget.onWaypointDrag != null
                          ? (details) => _onWaypointPanUpdate(index, details)
                          : null,
                      onPanEnd: widget.onWaypointDrag != null
                          ? (details) {
                              _onWaypointPanEnd(index, details);
                              widget.onWaypointDragEnd?.call();
                            }
                          : null,
                      onTap: () {
                        // Show context menu when clicking on waypoint marker
                        if (widget.onWaypointTap != null) {
                          final RenderBox? renderBox =
                              context.findRenderObject() as RenderBox?;
                          if (renderBox != null) {
                            final globalPosition = renderBox.localToGlobal(
                              const Offset(30, 30), // Offset from marker center
                            );
                            // Check for Ctrl/Cmd key
                            final isCtrlPressed =
                                HardwareKeyboard.instance.isControlPressed ||
                                HardwareKeyboard.instance.isMetaPressed;
                            widget.onWaypointTap!(
                              index,
                              globalPosition,
                              isCtrlPressed: isCtrlPressed,
                            );
                          }
                        }
                      },
                      child: CompositedTransformTarget(
                        link:
                            widget.waypointLayerLinks?[widget
                                .routePoints[index]
                                .id] ??
                            LayerLink(),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            if (isHighlighted)
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isMultiSelected
                                        ? Colors.orange.withOpacity(0.8)
                                        : Colors.blue.withOpacity(0.6),
                                    width: 3,
                                  ),
                                ),
                              ),
                            Icon(
                              MissionWaypointHelpers.getWaypointIcon(
                                routePoint,
                              ),
                              color: MissionWaypointHelpers.getWaypointColor(
                                routePoint,
                                isSelected: isSingleSelected,
                                isMultiSelected: isMultiSelected,
                              ),
                              size: isHighlighted
                                  ? 40
                                  : 36, // Kích thước icon lớn hơn
                            ),
                            if (!MissionWaypointHelpers.isROIPoint(routePoint))
                              Positioned.fill(
                                child: Center(
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 4.0),
                                    child: Text(
                                      '${index + 1}',
                                      style: TextStyle(
                                        fontSize: isHighlighted ? 16 : 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        shadows: [
                                          Shadow(
                                            color: Colors.black.withOpacity(
                                              0.8,
                                            ),
                                            offset: const Offset(1, 1),
                                            blurRadius: 2,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            // ROI indicator - show "ROI" text instead of number
                            if (MissionWaypointHelpers.isROIPoint(routePoint))
                              Positioned.fill(
                                child: Center(
                                  child: Text(
                                    'ROI',
                                    style: TextStyle(
                                      fontSize: isHighlighted ? 10 : 8,
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
                    ),
                  );
                }),
                // Remove loiter radius markers - no more label boxes
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
                    "Vĩ Độ: ${_draggedPosition!.latitude.toStringAsFixed(7)}",
                    style: const TextStyle(
                      color: Colors.cyan,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                  Text(
                    'Kinh Độ: ${_draggedPosition!.longitude.toStringAsFixed(7)}',
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
