import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:skylink/core/constant/map_type.dart';
import 'package:skylink/data/models/route_point_model.dart';
import 'package:skylink/presentation/widget/map/components/undo_redo_manager.dart';
import 'package:skylink/presentation/widget/map/main_map.dart';

/// Centralized state management for MapPage
/// Contains all state variables and computed properties
class MapPageState {
  // Map configuration
  MapType? selectedMapType;
  final MapController mapController = MapController();
  final GlobalKey<MainMapSimpleState> mapKey = GlobalKey<MainMapSimpleState>();

  // Mission data
  List<RoutePoint> routePoints = [];
  final Map<String, LayerLink> waypointLayerLinks = {};
  final UndoRedoManager undoRedoManager = UndoRedoManager();

  // GPS/Home point
  LatLng? homePoint;
  bool hasSetHomePoint = false;
  bool isHomePointManuallySet = false; // Track if user manually dragged home point

  // Stream subscriptions
  StreamSubscription? mavSub;
  StreamSubscription? telemetrySub;

  // Mission operations state
  bool isReadingMission = false;

  // Edit mode state
  RoutePoint? selectedWaypoint;
  bool isEditMode = false;
  bool isSimpleMode = true;

  // Multi-select state
  Set<String> selectedWaypointIds = <String>{};
  bool get isBatchEditMode => selectedWaypointIds.isNotEmpty;

  // Template selection state
  bool isSelectingOrbitCenter = false;
  bool isDragging = false;

  // Survey area drawing state
  bool isDrawingBoundingBox = false;
  LatLng? boundingBoxStart;
  LatLng? boundingBoxEnd;

  // Polygon drawing state
  bool isDrawingPolygon = false;
  List<LatLng> polygonPoints = [];

  // Mission statistics
  double? totalDistance;
  Duration? estimatedTime;
  double? batteryUsage;

  // UI state
  bool showTutorial = false;
  final GlobalKey helpButtonKey = GlobalKey();
  bool showMissionSidebar = false;
  bool showCameraView = false;
  bool isCameraSwapped = false;
  bool isMissionPlanningMode = false;
  bool showPdfCompass = false;
  bool showGimbalControl = false;
  double cameraOverlayWidth =
      450; // Track camera overlay width for gimbal control positioning

  /// Initialize state with default values
  void initialize() {
    selectedMapType = mapTypes.firstWhere(
      (mapType) => mapType.name == 'Google Hybrid',
      orElse: () => mapTypes.first,
    );
  }

  /// Clean up resources
  void dispose() {
    mavSub?.cancel();
    telemetrySub?.cancel();
    mapController.dispose();
  }

  /// Ensure layer links exist for all waypoints
  void ensureLayerLinksForWaypoints() {
    for (final waypoint in routePoints) {
      if (!waypointLayerLinks.containsKey(waypoint.id)) {
        waypointLayerLinks[waypoint.id] = LayerLink();
      }
    }
    // Remove layer links for waypoints that no longer exist
    waypointLayerLinks.removeWhere(
      (id, link) => !routePoints.any((wp) => wp.id == id),
    );
  }

  /// Clear all edit states
  void clearEditStates() {
    isEditMode = false;
    selectedWaypoint = null;
    isDragging = false;
    isSelectingOrbitCenter = false;
    isDrawingBoundingBox = false;
    boundingBoxStart = null;
    boundingBoxEnd = null;
    isDrawingPolygon = false;
    polygonPoints.clear();
  }

  /// Clear selection states
  void clearSelectionStates() {
    selectedWaypoint = null;
    selectedWaypointIds.clear();
    isEditMode = false;
  }

  /// Reorder waypoints sequentially
  void reorderWaypoints() {
    for (int i = 0; i < routePoints.length; i++) {
      routePoints[i] = routePoints[i].copyWith(order: i + 1);
    }
  }

  /// Get current waypoint index
  int? getCurrentWaypointIndex() {
    if (selectedWaypoint == null || routePoints.isEmpty) return null;
    return routePoints.indexWhere((wp) => wp.order == selectedWaypoint!.order);
  }
}
