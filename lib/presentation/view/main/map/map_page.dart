import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:skylink/core/constant/map_type.dart';
import 'package:skylink/data/models/route_point_model.dart';
import 'package:skylink/presentation/widget/map/main_map.dart';
import 'package:skylink/presentation/widget/map/components/floating_mission_actions.dart';

import 'package:skylink/presentation/widget/map/components/waypoint_edit_panel.dart';
import 'package:skylink/presentation/widget/map/components/batch_edit_panel.dart';
import 'package:skylink/presentation/widget/map/components/mission_sidebar.dart';
import 'package:skylink/presentation/widget/map/components/add_waypoint_dialog.dart';
import 'package:skylink/presentation/widget/common/confirm_dialog.dart';

import 'package:skylink/presentation/widget/map/components/undo_redo_manager.dart';
import 'package:skylink/presentation/widget/map/components/template_dialogs.dart';
import 'package:skylink/presentation/widget/map/utils/mission_templates.dart';
import 'package:skylink/presentation/widget/mission/mission_waypoint_helpers.dart';
import 'package:skylink/services/telemetry_service.dart';
import 'package:skylink/services/mission_service.dart';
import 'package:skylink/api/telemetry/mavlink/mission/mission_models.dart';
import 'package:skylink/api/telemetry/mavlink/events.dart';
import 'package:skylink/presentation/widget/map/components/mission_tutorial_overlay.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  MapType? selectedMapType;
  List<RoutePoint> routePoints = [];
  final MapController mapController = MapController();
  final GlobalKey<MainMapSimpleState> _mapKey = GlobalKey<MainMapSimpleState>();
  StreamSubscription? _mavSub;
  StreamSubscription? _telemetrySub;
  LatLng? homePoint;
  bool hasSetHomePoint = false;
  bool _isReadingMission = false;

  // New UI state
  RoutePoint? selectedWaypoint;
  bool isEditMode = false;
  bool isSimpleMode = true;
  final Map<String, LayerLink> _waypointLayerLinks = {};
  final UndoRedoManager undoRedoManager = UndoRedoManager();

  // Template selection state
  bool isSelectingOrbitCenter = false;
  bool isSelectingSurveyCenter = false;
  bool isDragging = false;

  // Multi-select state
  Set<String> selectedWaypointIds = <String>{};
  bool get isBatchEditMode => selectedWaypointIds.isNotEmpty;

  // Mission statistics
  double? totalDistance;
  Duration? estimatedTime;
  double? batteryUsage;
  String riskLevel = 'Low';

  // Tutorial state
  bool showTutorial = false;
  final GlobalKey _helpButtonKey = GlobalKey();

  void _ensureLayerLinksForWaypoints() {
    for (final waypoint in routePoints) {
      if (!_waypointLayerLinks.containsKey(waypoint.id)) {
        _waypointLayerLinks[waypoint.id] = LayerLink();
      }
    }
    // Remove layer links for waypoints that no longer exist
    _waypointLayerLinks.removeWhere(
      (id, link) => !routePoints.any((wp) => wp.id == id),
    );
  }

  @override
  void initState() {
    super.initState();
    selectedMapType = mapTypes.first;
    _setupMavlinkListener();
    _setupGpsListener();
    _setupConnectionListener();

    // Ensure layer links for existing waypoints
    _ensureLayerLinksForWaypoints();
  }

  void _setupConnectionListener() {
    TelemetryService().connectionStream.listen((isConnected) {
      if (!isConnected) {
        setState(() {
          homePoint = null;
          hasSetHomePoint = false;
        });
      }
    });
  }

  void _setupGpsListener() {
    _telemetrySub = TelemetryService().telemetryStream.listen(
      _onTelemetryUpdate,
    );
  }

  void _onTelemetryUpdate(Map<String, double> telemetry) {
    final hasValidGps = TelemetryService().hasValidGpsFix;
    final isConnected = TelemetryService().isConnected;

    if (!hasValidGps || !isConnected) {
      if (homePoint != null) {
        setState(() {
          homePoint = null;
          hasSetHomePoint = false;
        });
      }
      return;
    }

    if (!hasSetHomePoint && hasValidGps) {
      final lat = TelemetryService().gpsLatitude;
      final lng = TelemetryService().gpsLongitude;
      if (lat != 0.0 && lng != 0.0) {
        setState(() {
          homePoint = LatLng(lat, lng);
          hasSetHomePoint = true;
        });
      }
    }
  }

  void _setupMavlinkListener() {
    _mavSub?.cancel();
    _mavSub = TelemetryService().mavlinkAPI.eventStream.listen((event) {
      switch (event.type) {
        case MAVLinkEventType.missionDownloadComplete:
          if (_isReadingMission) {
            final missionItems = event.data as List<PlanMissionItem>;
            _convertMissionToRoutePoints(missionItems);
            _isReadingMission = false;
            _hideProgress();
          }
          break;
        default:
          break;
      }
    });
  }

  void _convertMissionToRoutePoints(List<PlanMissionItem> missionItems) {
    final newRoutePoints = <RoutePoint>[];

    for (int i = 0; i < missionItems.length; i++) {
      final item = missionItems[i];

      if (item.seq == 0 || !_isGlobalCoordinate(item.x, item.y)) continue;

      Map<String, dynamic>? commandParams;
      if (item.param1 != 0 ||
          item.param2 != 0 ||
          item.param3 != 0 ||
          item.param4 != 0) {
        commandParams = {
          'param1': item.param1,
          'param2': item.param2,
          'param3': item.param3,
          'param4': item.param4,
        };
      }

      newRoutePoints.add(
        RoutePoint(
          id: '${DateTime.now().millisecondsSinceEpoch}_$i',
          order: newRoutePoints.length + 1,
          latitude: item.x.toString(),
          longitude: item.y.toString(),
          altitude: item.z.toString(),
          command: item.command,
          commandParams: commandParams,
        ),
      );
    }

    setState(() {
      routePoints = newRoutePoints;
    });

    _calculateMissionStats();
    _showSuccess('Mission đã tải: ${newRoutePoints.length} waypoints');
  }

  bool _isGlobalCoordinate(double lat, double lon) {
    return lat.abs() <= 90 && lon.abs() <= 180 && (lat != 0.0 || lon != 0.0);
  }

  // New methods for map-centric interaction
  void _onMapTap(LatLng latLng) {
    // Handle template center selection
    if (isSelectingOrbitCenter) {
      _createOrbitAt(latLng);
      return;
    }

    if (isSelectingSurveyCenter) {
      _createSurveyAt(latLng);
      return;
    }

    if (isEditMode) {
      // Exit edit mode when clicking on map
      setState(() {
        isEditMode = false;
        selectedWaypoint = null;
        // Also cancel template selection
        isSelectingOrbitCenter = false;
        isSelectingSurveyCenter = false;
      });
      return;
    }

    // Add new waypoint
    _addWaypoint(latLng);
  }

  void _addWaypoint(LatLng latLng) {
    final newWaypoint = RoutePoint(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      order: routePoints.length + 1,
      latitude: latLng.latitude.toString(),
      longitude: latLng.longitude.toString(),
      altitude: "100", // Default altitude
      command: 16, // Default to waypoint
    );

    // Add to undo stack
    undoRedoManager.addAction(
      MissionAction(type: ActionType.addWaypoint, waypoint: newWaypoint),
    );

    setState(() {
      routePoints.add(newWaypoint);
      // Create LayerLink for new waypoint
      _waypointLayerLinks[newWaypoint.id] = LayerLink();
    });

    _calculateMissionStats();
  }

  void _addWaypointWithAltitude(LatLng latLng, double altitude) {
    final newWaypoint = RoutePoint(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      order: routePoints.length + 1,
      latitude: latLng.latitude.toString(),
      longitude: latLng.longitude.toString(),
      altitude: altitude.toInt().toString(), // Use provided altitude as integer
      command: 16, // Default to waypoint
    );

    // Add to undo stack
    undoRedoManager.addAction(
      MissionAction(type: ActionType.addWaypoint, waypoint: newWaypoint),
    );

    setState(() {
      routePoints.add(newWaypoint);
      // Create LayerLink for new waypoint
      _waypointLayerLinks[newWaypoint.id] = LayerLink();
    });

    _calculateMissionStats();
  }

  void _onWaypointDrag(int index, LatLng newPosition) {
    if (index >= 0 && index < routePoints.length) {
      final oldWaypoint = routePoints[index];

      // Add to undo stack
      undoRedoManager.addAction(
        MissionAction(
          type: ActionType.moveWaypoint,
          waypoint: routePoints[index].copyWith(
            latitude: newPosition.latitude.toString(),
            longitude: newPosition.longitude.toString(),
          ),
          previousWaypoint: oldWaypoint,
          index: index,
        ),
      );

      setState(() {
        routePoints[index] = routePoints[index].copyWith(
          latitude: newPosition.latitude.toString(),
          longitude: newPosition.longitude.toString(),
        );
      });

      _calculateMissionStats();
    }
  }

  void _onWaypointTap(
    int index,
    Offset globalPosition, {
    bool isCtrlPressed = false,
  }) {
    if (index >= 0 && index < routePoints.length) {
      final waypoint = routePoints[index];

      if (isCtrlPressed) {
        // Multi-select mode
        setState(() {
          if (selectedWaypointIds.contains(waypoint.id)) {
            selectedWaypointIds.remove(waypoint.id);
          } else {
            selectedWaypointIds.add(waypoint.id);
          }
          // Clear single selection when multi-selecting
          selectedWaypoint = null;
          isEditMode = false;
        });
      } else {
        // Single select mode
        setState(() {
          selectedWaypoint = waypoint;
          isEditMode = true;
          // Clear multi-selection when single selecting
          selectedWaypointIds.clear();
        });
      }
    }
  }

  void _onWaypointDragStart() {
    setState(() {
      isDragging = true;
    });
  }

  void _onWaypointDragEnd() {
    setState(() {
      isDragging = false;
    });
  }

  // Mission statistics calculation
  void _calculateMissionStats() {
    if (routePoints.isEmpty) {
      setState(() {
        totalDistance = null;
        estimatedTime = null;
        batteryUsage = null;
        riskLevel = 'Low';
      });
      return;
    }

    // Calculate total distance using only flight path points (excluding ROI)
    final flightPathPoints = MissionWaypointHelpers.getFlightPathPoints(
      routePoints,
    );
    double distance = 0;
    for (int i = 1; i < flightPathPoints.length; i++) {
      final prev = LatLng(
        double.parse(flightPathPoints[i - 1].latitude),
        double.parse(flightPathPoints[i - 1].longitude),
      );
      final curr = LatLng(
        double.parse(flightPathPoints[i].latitude),
        double.parse(flightPathPoints[i].longitude),
      );
      distance += _calculateDistance(prev, curr);
    }

    // Estimate flight time (assuming 10 m/s average speed)
    final avgSpeed = 10.0; // m/s
    final timeInSeconds = distance / avgSpeed;

    // Estimate battery usage (rough calculation)
    final batteryPercent = math.min(
      100,
      (timeInSeconds / 60) * 2,
    ); // 2% per minute

    // Determine risk level
    String risk = 'Low';
    if (batteryPercent > 80 || routePoints.length > 20) {
      risk = 'High';
    } else if (batteryPercent > 50 || routePoints.length > 10) {
      risk = 'Medium';
    }

    setState(() {
      totalDistance = distance;
      estimatedTime = Duration(seconds: timeInSeconds.round());
      batteryUsage = batteryPercent.toDouble();
      riskLevel = risk;
    });
  }

  double _calculateDistance(LatLng point1, LatLng point2) {
    const earthRadius = 6371000; // meters
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

    return earthRadius * c;
  }

  // Floating action handlers
  void _handleAddWaypoint() {
    showDialog(
      context: context,
      builder: (context) => AddWaypointDialog(
        onAddWaypoint: (position, altitude) {
          _addWaypointWithAltitude(position, altitude);
        },
      ),
    );
  }

  void _handleOrbitTemplate() {
    setState(() {
      isSelectingOrbitCenter = true;
      isSelectingSurveyCenter = false;
    });
    _showInfo('Nhấp vào bản đồ để chọn điểm tâm bay vòng');
  }

  void _handleSurveyTemplate() {
    setState(() {
      isSelectingSurveyCenter = true;
      isSelectingOrbitCenter = false;
    });
    _showInfo('Nhấp vào bản đồ để chọn điểm tâm khảo sát');
  }

  void _createOrbitAt(LatLng center) {
    setState(() {
      isSelectingOrbitCenter = false;
    });

    showDialog(
      context: context,
      builder: (context) => OrbitTemplateDialog(
        centerPoint: center,
        onConfirm: (radius, altitude, points) {
          final orbitWaypoints = MissionTemplates.createOrbitMission(
            center: center,
            radius: radius,
            altitude: altitude,
            points: points,
          );

          undoRedoManager.addAction(
            MissionAction(
              type: ActionType.addWaypoint,
              data: {'waypoints': orbitWaypoints},
            ),
          );

          setState(() {
            routePoints.addAll(orbitWaypoints);
            _reorderWaypoints();
          });

          _calculateMissionStats();
          _showSuccess(
            'Orbit mission created with ${orbitWaypoints.length} waypoints',
          );
        },
      ),
    );
  }

  void _createSurveyAt(LatLng center) {
    setState(() {
      isSelectingSurveyCenter = false;
    });

    showDialog(
      context: context,
      builder: (context) => SurveyTemplateDialog(
        centerPoint: center,
        onConfirm: (topLeft, bottomRight, altitude, spacing) {
          final surveyWaypoints = MissionTemplates.createSurveyMission(
            topLeft: topLeft,
            bottomRight: bottomRight,
            altitude: altitude,
            spacing: spacing,
          );

          undoRedoManager.addAction(
            MissionAction(
              type: ActionType.addWaypoint,
              data: {'waypoints': surveyWaypoints},
            ),
          );

          setState(() {
            routePoints.addAll(surveyWaypoints);
            _reorderWaypoints();
          });

          _calculateMissionStats();
          _showSuccess(
            'Nhiệm vụ khảo sát đã được tạo với ${surveyWaypoints.length} waypoints',
          );
        },
      ),
    );
  }

  void _handleUndo() {
    final action = undoRedoManager.undo();
    if (action != null) {
      _applyUndoAction(action);
    }
  }

  void _handleRedo() {
    final action = undoRedoManager.redo();
    if (action != null) {
      _applyRedoAction(action);
    }
  }

  void _applyUndoAction(MissionAction action) {
    switch (action.type) {
      case ActionType.addWaypoint:
        setState(() {
          routePoints.removeWhere((wp) => wp.id == action.waypoint!.id);
        });
        break;
      case ActionType.deleteWaypoint:
        if (action.waypoint != null && action.index != null) {
          setState(() {
            routePoints.insert(action.index!, action.waypoint!);
            _reorderWaypoints();
          });
        }
        break;
      case ActionType.moveWaypoint:
        if (action.previousWaypoint != null && action.index != null) {
          setState(() {
            routePoints[action.index!] = action.previousWaypoint!;
          });
        }
        break;
      case ActionType.editWaypoint:
        if (action.previousWaypoint != null && action.index != null) {
          setState(() {
            routePoints[action.index!] = action.previousWaypoint!;
          });
        }
        break;
      case ActionType.clearMission:
        // TODO: Restore previous mission
        break;
      case ActionType.convertWaypoint:
        if (action.previousWaypoint != null && action.index != null) {
          setState(() {
            routePoints[action.index!] = action.previousWaypoint!;
          });
        }
        break;
      case ActionType.batchEdit:
        // TODO: Implement batch edit undo
        break;
      case ActionType.batchDelete:
        // Restore deleted waypoints
        if (action.data != null && action.data!['deletedWaypoints'] != null) {
          final deletedWaypoints =
              action.data!['deletedWaypoints'] as List<RoutePoint>;
          setState(() {
            routePoints.addAll(deletedWaypoints);
            // Sort by order to maintain correct sequence
            routePoints.sort((a, b) => a.order.compareTo(b.order));
          });
        }
        break;
    }

    _calculateMissionStats();
  }

  void _applyRedoAction(MissionAction action) {
    switch (action.type) {
      case ActionType.addWaypoint:
        setState(() {
          routePoints.add(action.waypoint!);
        });
        break;
      case ActionType.deleteWaypoint:
        setState(() {
          routePoints.removeWhere((wp) => wp.id == action.waypoint!.id);
          _reorderWaypoints();
        });
        break;
      case ActionType.moveWaypoint:
      case ActionType.editWaypoint:
      case ActionType.convertWaypoint:
        if (action.waypoint != null && action.index != null) {
          setState(() {
            routePoints[action.index!] = action.waypoint!;
          });
        }
        break;
      case ActionType.clearMission:
        setState(() {
          routePoints.clear();
          _waypointLayerLinks.clear();
        });
        break;
      case ActionType.batchEdit:
        // TODO: Implement batch edit redo
        break;
      case ActionType.batchDelete:
        // Re-delete waypoints (redo delete action)
        if (action.data != null && action.data!['deletedWaypoints'] != null) {
          final deletedWaypoints =
              action.data!['deletedWaypoints'] as List<RoutePoint>;
          final idsToDelete = deletedWaypoints.map((wp) => wp.id).toSet();
          setState(() {
            routePoints.removeWhere((wp) => idsToDelete.contains(wp.id));
            // Update order for remaining waypoints
            for (int i = 0; i < routePoints.length; i++) {
              routePoints[i] = routePoints[i].copyWith(order: i + 1);
            }
          });
        }
        break;
    }

    _ensureLayerLinksForWaypoints();
    _calculateMissionStats();
  }

  void _handleClearMission() async {
    if (routePoints.isEmpty) return;

    final confirmed = await ConfirmDialog.confirmClear(
      context: context,
      itemName: 'các waypoints',
      additionalMessage:
          'Bạn có chắc chắn muốn xóa toàn bộ nhiệm vụ với ${routePoints.length} waypoints? Hành động này có thể hoàn tác.',
    );

    if (!confirmed) return;

    undoRedoManager.addAction(
      MissionAction(
        type: ActionType.clearMission,
        data: {'waypoints': List.from(routePoints)},
      ),
    );

    setState(() {
      routePoints.clear();
      _waypointLayerLinks.clear(); // Clear all LayerLinks

      // Clear edit state
      selectedWaypoint = null;
      selectedWaypointIds.clear();
      isEditMode = false;
    });

    _calculateMissionStats();

    if (TelemetryService().mavlinkAPI.isConnected) {
      TelemetryService().mavlinkAPI.clearMission();
      _showSuccess('Nhiệm vụ đã được xóa khỏi Flight Controller');
    }
  }

  void _handleImport(List<RoutePoint> importedRoutePoints) {
    setState(() {
      routePoints.clear();
      routePoints.addAll(importedRoutePoints);

      // Clear any selected states
      selectedWaypoint = null;
      isEditMode = false;
      selectedWaypointIds.clear();
    });

    // Update mission statistics
    _calculateMissionStats();
  }

  // Edit panel handlers
  void _handleDeleteWaypoint() async {
    if (selectedWaypoint != null) {
      final confirmed = await ConfirmDialog.confirmDelete(
        context: context,
        itemName: 'waypoint ${selectedWaypoint!.order}',
        additionalMessage:
            'Bạn có chắc chắn muốn xóa waypoint ${selectedWaypoint!.order}? Hành động này có thể hoàn tác bằng nút Hoàn tác.',
      );

      if (!confirmed) return;

      final index = routePoints.indexWhere(
        (wp) => wp.id == selectedWaypoint!.id,
      );
      if (index != -1) {
        undoRedoManager.addAction(
          MissionAction(
            type: ActionType.deleteWaypoint,
            waypoint: selectedWaypoint!,
            index: index,
          ),
        );

        setState(() {
          // Remove LayerLink for deleted waypoint
          _waypointLayerLinks.remove(selectedWaypoint!.id);
          routePoints.removeAt(index);
          _reorderWaypoints();

          selectedWaypoint = null;
          isEditMode = false;
        });

        _calculateMissionStats();
        _showSuccess('Waypoint đã được xoá ');
      }
    }
  }

  void _handleConvertWaypoint(int commandType) {
    if (selectedWaypoint != null) {
      final index = routePoints.indexWhere(
        (wp) => wp.id == selectedWaypoint!.id,
      );
      if (index != -1) {
        final oldWaypoint = routePoints[index];

        undoRedoManager.addAction(
          MissionAction(
            type: ActionType.convertWaypoint,
            waypoint: oldWaypoint.copyWith(command: commandType),
            previousWaypoint: oldWaypoint,
            index: index,
          ),
        );

        setState(() {
          routePoints[index] = routePoints[index].copyWith(
            command: commandType,
          );
          selectedWaypoint = null;
          isEditMode = false;
        });

        _calculateMissionStats();
        _showSuccess('Waypoint type changed');
      }
    }
  }

  // Edit panel handlers
  void _handleSaveWaypoint(RoutePoint updatedWaypoint) {
    final index = routePoints.indexWhere((wp) => wp.id == updatedWaypoint.id);
    if (index != -1) {
      undoRedoManager.addAction(
        MissionAction(
          type: ActionType.editWaypoint,
          waypoint: updatedWaypoint,
          previousWaypoint: routePoints[index],
          index: index,
        ),
      );

      setState(() {
        routePoints[index] = updatedWaypoint;
        isEditMode = false;
        selectedWaypoint = null;
        // Clear any other states that might interfere with map interactions
        isDragging = false;
        isSelectingOrbitCenter = false;
        isSelectingSurveyCenter = false;
      });

      _calculateMissionStats();

      // Clear map drag state
      _mapKey.currentState?.clearMapDragState();

      // Clear focus to ensure no text fields are capturing input
      FocusScope.of(context).unfocus();

      // Force a rebuild to ensure all states are properly updated
      Future.microtask(() => setState(() {}));

      _showSuccess('Waypoint đã được cập nhật');
    }
  }

  void _handleCancelEdit() {
    setState(() {
      isEditMode = false;
      selectedWaypoint = null;
      // Clear any other states that might interfere with map interactions
      isDragging = false;
      isSelectingOrbitCenter = false;
      isSelectingSurveyCenter = false;
    });

    // Clear map drag state
    _mapKey.currentState?.clearMapDragState();

    // Clear focus to ensure no text fields are capturing input
    FocusScope.of(context).unfocus();

    // Force a rebuild to ensure all states are properly updated
    Future.microtask(() => setState(() {}));
  }

  void _handleBatchEditCancel() {
    setState(() {
      selectedWaypointIds.clear();
      // Clear any other states that might interfere with map interactions
      isDragging = false;
      isEditMode = false;
      selectedWaypoint = null;
      isSelectingOrbitCenter = false;
      isSelectingSurveyCenter = false;
    });

    // Clear map drag state
    _mapKey.currentState?.clearMapDragState();

    // Clear focus to ensure no text fields are capturing input
    FocusScope.of(context).unfocus();

    // Force refresh map interactions by triggering a rebuild
    Future.microtask(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _handleBatchDelete() {
    if (selectedWaypointIds.isEmpty) return;

    // Get selected waypoints for undo operation
    final selectedWaypoints = routePoints
        .where((wp) => selectedWaypointIds.contains(wp.id))
        .toList();

    // Remove selected waypoints
    setState(() {
      routePoints.removeWhere((wp) => selectedWaypointIds.contains(wp.id));

      // Update order for remaining waypoints
      for (int i = 0; i < routePoints.length; i++) {
        routePoints[i] = routePoints[i].copyWith(order: i + 1);
      }

      selectedWaypointIds.clear();
      // Clear any other states that might interfere with map interactions
      isDragging = false;
      isEditMode = false;
      selectedWaypoint = null;
      isSelectingOrbitCenter = false;
      isSelectingSurveyCenter = false;
    });

    // Clear map drag state
    _mapKey.currentState?.clearMapDragState();

    // Clear focus to ensure no text fields are capturing input
    FocusScope.of(context).unfocus();

    // Force refresh map interactions
    Future.microtask(() {
      if (mounted) {
        setState(() {});
      }
    });

    // Add to undo history
    undoRedoManager.addAction(
      MissionAction(
        type: ActionType.batchDelete,
        data: {'deletedWaypoints': selectedWaypoints},
      ),
    );

    _calculateMissionStats();
    _showSuccess('${selectedWaypoints.length} waypoints deleted');
  }

  void _handleBatchEditApply(Map<String, dynamic> batchChanges) {
    if (selectedWaypointIds.isEmpty || batchChanges.isEmpty) return;

    // Get selected waypoints
    final selectedWaypoints = routePoints
        .where((wp) => selectedWaypointIds.contains(wp.id))
        .toList();

    // Apply batch changes to each waypoint
    final updatedWaypoints = <RoutePoint>[];
    final originalWaypoints = <RoutePoint>[];

    for (final waypoint in selectedWaypoints) {
      final originalWaypoint = waypoint.copyWith();
      originalWaypoints.add(originalWaypoint);

      // Build updated command params
      final updatedCommandParams = Map<String, dynamic>.from(
        waypoint.commandParams ?? {},
      );

      // Handle commandParams from BatchEditPanel
      if (batchChanges.containsKey('commandParams')) {
        final newParams = batchChanges['commandParams'] as Map<String, double>;
        updatedCommandParams.addAll(newParams);
      }

      // Legacy support for individual param fields
      if (batchChanges.containsKey('loiterRadius')) {
        updatedCommandParams['loiterRadius'] = batchChanges['loiterRadius'];
      }
      if (batchChanges.containsKey('param1')) {
        updatedCommandParams['param1'] = batchChanges['param1'];
      }
      if (batchChanges.containsKey('param2')) {
        updatedCommandParams['param2'] = batchChanges['param2'];
      }
      if (batchChanges.containsKey('param3')) {
        updatedCommandParams['param3'] = batchChanges['param3'];
      }
      if (batchChanges.containsKey('param4')) {
        updatedCommandParams['param4'] = batchChanges['param4'];
      }

      // Get command number (already int from BatchEditPanel)
      int? commandNum;
      if (batchChanges.containsKey('command')) {
        commandNum = batchChanges['command'] as int;
      }

      final updatedWaypoint = waypoint.copyWith(
        command: commandNum ?? waypoint.command,
        altitude: batchChanges.containsKey('altitude')
            ? batchChanges['altitude'] as String
            : waypoint.altitude,
        commandParams: updatedCommandParams.isNotEmpty
            ? updatedCommandParams
            : waypoint.commandParams,
      );
      updatedWaypoints.add(updatedWaypoint);

      // Update in route points
      final index = routePoints.indexWhere((wp) => wp.id == waypoint.id);
      if (index >= 0) {
        routePoints[index] = updatedWaypoint;
      }
    }

    // Add to undo/redo history - simplified for now
    // TODO: Implement proper batch edit undo/redo

    setState(() {
      selectedWaypointIds.clear();
      // Clear any other states that might interfere with map interactions
      isDragging = false;
      isEditMode = false;
      selectedWaypoint = null;
      isSelectingOrbitCenter = false;
      isSelectingSurveyCenter = false;
    });

    // Clear map drag state
    _mapKey.currentState?.clearMapDragState();

    // Clear focus to ensure no text fields are capturing input
    FocusScope.of(context).unfocus();

    // Force refresh map interactions
    Future.microtask(() {
      if (mounted) {
        setState(() {});
      }
    });

    _calculateMissionStats();
    _showSuccess('Batch edit applied to ${updatedWaypoints.length} waypoints');
  }

  void _handleModeToggle(bool simple) {
    setState(() {
      isSimpleMode = simple;
    });
  }

  void _handlePrevWaypoint() {
    if (selectedWaypoint == null || routePoints.isEmpty) return;

    final currentIndex = routePoints.indexWhere(
      (wp) => wp.order == selectedWaypoint!.order,
    );
    if (currentIndex > 0) {
      setState(() {
        selectedWaypoint = routePoints[currentIndex - 1];
      });
    }
  }

  void _handleNextWaypoint() {
    if (selectedWaypoint == null || routePoints.isEmpty) return;

    final currentIndex = routePoints.indexWhere(
      (wp) => wp.order == selectedWaypoint!.order,
    );
    if (currentIndex < routePoints.length - 1) {
      setState(() {
        selectedWaypoint = routePoints[currentIndex + 1];
      });
    }
  }

  int? _getCurrentWaypointIndex() {
    if (selectedWaypoint == null || routePoints.isEmpty) return null;
    return routePoints.indexWhere((wp) => wp.order == selectedWaypoint!.order);
  }

  void _reorderWaypoints() {
    for (int i = 0; i < routePoints.length; i++) {
      routePoints[i] = routePoints[i].copyWith(order: i + 1);
    }
  }

  // Mission sidebar handlers
  void _handleReorderWaypoints(List<RoutePoint> reorderedWaypoints) {
    // Save current state for undo
    undoRedoManager.addAction(
      MissionAction(
        type: ActionType.batchEdit,
        waypoint: routePoints.first, // Just use the first waypoint as reference
      ),
    );

    setState(() {
      routePoints.clear();
      routePoints.addAll(reorderedWaypoints);
    });

    _calculateMissionStats();
  }

  void _handleEditWaypoint(RoutePoint waypoint) {
    setState(() {
      selectedWaypoint = waypoint;
      isEditMode = true;
      // Clear other modes
      isDragging = false;
      selectedWaypointIds.clear();
      isSelectingOrbitCenter = false;
      isSelectingSurveyCenter = false;
    });
  }

  void _handleDeleteWaypointFromSidebar(String waypointId) {
    final waypointToDelete = routePoints.firstWhere(
      (wp) => wp.id == waypointId,
      orElse: () => throw StateError('Waypoint không tìm thấy'),
    );

    undoRedoManager.addAction(
      MissionAction(
        type: ActionType.deleteWaypoint,
        waypoint: waypointToDelete,
        index: routePoints.indexOf(waypointToDelete),
      ),
    );

    setState(() {
      routePoints.removeWhere((wp) => wp.id == waypointId);
      _waypointLayerLinks.remove(waypointId);

      // Clear selection if deleted waypoint was selected
      if (selectedWaypoint?.id == waypointId) {
        selectedWaypoint = null;
        isEditMode = false;
      }

      // Remove from multi-selection if present
      selectedWaypointIds.remove(waypointId);
    });

    // Reorder remaining waypoints
    _reorderWaypoints();
    _calculateMissionStats();
  }

  // Mission operations from original code
  void handleReadMission() {
    if (!TelemetryService().mavlinkAPI.isConnected) {
      _showError('Vui lòng kết nối với Flight Controller');
      return;
    }

    _isReadingMission = true;
    TelemetryService().mavlinkAPI.requestMissionList();
    _showProgress('Đang đọc kế hoạch bay từ Flight Controller...');
  }

  Future<void> handleSendConfigs(List<RoutePoint> points) async {
    if (!TelemetryService().mavlinkAPI.isConnected) {
      _showError('Vui lòng kết nối với Flight Controller');
      return;
    }

    if (points.isEmpty) {
      _showError('Không có waypoint nào để gửi');
      return;
    }

    try {
      final missionItems = <PlanMissionItem>[
        PlanMissionItem(
          seq: 0,
          current: 1,
          frame: 0,
          command: 16,
          param1: 0,
          param2: 0,
          param3: 0,
          param4: 0,
          x: double.parse(points.first.latitude),
          y: double.parse(points.first.longitude),
          z: double.parse(points.first.altitude),
          autocontinue: 1,
        ),
      ];

      for (var i = 0; i < points.length; i++) {
        final point = points[i];
        final params = point.commandParams ?? {};
        missionItems.add(
          PlanMissionItem(
            seq: i + 1,
            current: 0,
            frame: 3,
            command: point.command,
            param1: (params['param1'] as num?)?.toDouble() ?? 0.0,
            param2: (params['param2'] as num?)?.toDouble() ?? 0.0,
            param3: (params['param3'] as num?)?.toDouble() ?? 0.0,
            param4: (params['param4'] as num?)?.toDouble() ?? 0.0,
            x: double.parse(point.latitude),
            y: double.parse(point.longitude),
            z: double.parse(point.altitude),
            autocontinue: 1,
          ),
        );
      }

      bool uploadStarted = false;
      StreamSubscription? sub;
      final completer = Completer<void>();
      bool clearAckReceived = false;

      sub = TelemetryService().mavlinkAPI.eventStream.listen((event) {
        switch (event.type) {
          case MAVLinkEventType.missionCleared:
            clearAckReceived = true;
            if (!uploadStarted) {
              uploadStarted = true;
              Future.delayed(const Duration(milliseconds: 500), () {
                TelemetryService().mavlinkAPI.startMissionUpload(missionItems);
              });
            }
            break;

          case MAVLinkEventType.missionUploadComplete:
            if (!clearAckReceived) break;
            _showSuccess('Kế hoạch bay đã được tải lên thành công');
            MissionService().updateMission(points);
            sub?.cancel();
            if (!completer.isCompleted) completer.complete();
            break;

          case MAVLinkEventType.missionAck:
            if (!clearAckReceived) break;
            final errorCode = event.data as int;
            if (_isActualError(errorCode)) {
              final errorMessage = _getMavlinkErrorMessage(errorCode);
              _showError('Tải kế hoạch bay thất bại: $errorMessage');
              sub?.cancel();
              if (!completer.isCompleted) completer.completeError(errorMessage);
            } else {
              _showSuccess(
                'Kế hoạch bay đã được chấp nhận bởi Flight Controller',
              );
              MissionService().updateMission(points);
              sub?.cancel();
              if (!completer.isCompleted) completer.complete();
            }
            break;

          default:
            break;
        }
      });

      TelemetryService().mavlinkAPI.clearMission();

      try {
        await completer.future.timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            sub?.cancel();
            throw 'Mission upload timed out';
          },
        );
      } catch (e) {
        _showError(e.toString());
      }
    } catch (e) {
      _showError('Error preparing mission: $e');
    }
  }

  bool _isActualError(int errorCode) {
    switch (errorCode) {
      case 1:
      case 3:
      case 4:
      case 5:
      case 12:
      case 13:
      case 15:
      case 128:
      case 129:
      case 130:
      case 131:
      case 132:
        return true;
      default:
        return false;
    }
  }

  String _getMavlinkErrorMessage(int errorCode) {
    switch (errorCode) {
      case 1:
        return 'Lỗi: Mục nhiệm vụ vượt quá dung lượng lưu trữ';
      case 2:
        return 'Lỗi: Nhiệm vụ chỉ được chấp nhận một phần';
      case 3:
        return 'Lỗi: Thao tác nhiệm vụ không được hỗ trợ';
      case 4:
        return 'Lỗi: Tọa độ nhiệm vụ nằm ngoài phạm vi';
      case 5:
        return 'Lỗi: Mục nhiệm vụ không hợp lệ';
      case 10:
        return 'Lỗi: Thứ tự mục nhiệm vụ không hợp lệ';
      case 11:
        return 'Lỗi: Mục nhiệm vụ không nằm trong phạm vi hợp lệ';
      case 12:
        return 'Lỗi: Số lượng mục nhiệm vụ không hợp lệ';
      case 13:
        return 'Lỗi: Thao tác nhiệm vụ hiện bị từ chối';
      case 14:
        return 'Lỗi: Thao tác nhiệm vụ đang được thực hiện';
      case 15:
        return 'Lỗi: Hệ thống chưa sẵn sàng cho nhiệm vụ';
      case 30:
        return 'Cảnh báo: Tham số mục nhiệm vụ vượt quá phạm vi (nhưng vẫn được chấp nhận)';
      case 128:
        return 'Lỗi: Nhiệm vụ không hợp lệ';
      case 129:
        return 'Lỗi: Loại nhiệm vụ không được hỗ trợ';
      case 130:
        return 'Lỗi: Phương tiện chưa sẵn sàng thực hiện nhiệm vụ';
      case 131:
        return 'Lỗi: Điểm bay (waypoint) ngoài phạm vi';
      case 132:
        return 'Lỗi: Số lượng điểm bay (waypoint) vượt quá giới hạn';
      default:
        return 'Cảnh báo: Mã lỗi $errorCode';
    }
  }

  // UI feedback methods
  void _hideProgress() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
  }

  void _showProgress(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(width: 16),
            Text(message),
          ],
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 16),
            Text(message),
          ],
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 16),
            Text(message),
          ],
        ),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showInfo(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info, color: Colors.white),
            const SizedBox(width: 16),
            Text(message),
          ],
        ),
        backgroundColor: Colors.blue,
      ),
    );
  }

  @override
  void dispose() {
    _mavSub?.cancel();
    _telemetrySub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Map Section (70% width)
          Expanded(
            flex: 7,
            child: Stack(
              children: [
                // Main map
                MainMapSimple(
                  key: _mapKey,
                  mapController: mapController,
                  mapType: selectedMapType!,
                  routePoints: routePoints,
                  onTap: _onMapTap,
                  onWaypointDrag: _onWaypointDrag,
                  onWaypointTap: _onWaypointTap,
                  onWaypointDragStart: _onWaypointDragStart,
                  onWaypointDragEnd: _onWaypointDragEnd,
                  isConfigValid: true,
                  homePoint: homePoint,
                  waypointLayerLinks: _waypointLayerLinks,
                  selectedWaypoint: selectedWaypoint,
                  selectedWaypointIds: selectedWaypointIds,
                ),

                // Floating action buttons (left side)
                Positioned(
                  left: 16,
                  bottom: 16,
                  child: FloatingMissionActions(
                    onAddWaypoint: _handleAddWaypoint,
                    onOrbitTemplate: _handleOrbitTemplate,
                    onSurveyTemplate: _handleSurveyTemplate,
                    onUndo: _handleUndo,
                    onRedo: _handleRedo,
                    onClearMission: _handleClearMission,
                    canUndo: undoRedoManager.canUndo,
                    canRedo: undoRedoManager.canRedo,
                  ),
                ),

                // Template selection indicator
                if (isSelectingOrbitCenter || isSelectingSurveyCenter)
                  Positioned(
                    top: MediaQuery.of(context).size.height / 2 - 50,
                    left: MediaQuery.of(context).size.width * 0.35 - 120,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.teal.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.touch_app, color: Colors.white),
                          const SizedBox(width: 8),
                          Text(
                            isSelectingOrbitCenter
                                ? 'Nhấn chọn tâm bay vòng'
                                : 'Nhấn chọn tâm vùng khảo sát',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Waypoint edit panel overlay (single select)
                if (isEditMode && selectedWaypoint != null)
                  Positioned(
                    top: 16,
                    right: 16,
                    width: 320,
                    child: WaypointEditPanel(
                      waypoint: selectedWaypoint!,
                      onSave: _handleSaveWaypoint,
                      onCancel: _handleCancelEdit,
                      onDelete: _handleDeleteWaypoint,
                      onConvertType: _handleConvertWaypoint,
                      isSimpleMode: isSimpleMode,
                      onModeToggle: _handleModeToggle,
                      onPrevWaypoint: _handlePrevWaypoint,
                      onNextWaypoint: _handleNextWaypoint,
                      totalWaypoints: routePoints.length,
                      currentIndex: _getCurrentWaypointIndex(),
                    ),
                  ),

                // Batch edit panel overlay (multi-select)
                if (isBatchEditMode)
                  Positioned(
                    top: 16,
                    right: 16,
                    child: BatchEditPanel(
                      selectedWaypoints: routePoints
                          .where((wp) => selectedWaypointIds.contains(wp.id))
                          .toList(),
                      onCancel: _handleBatchEditCancel,
                      onSave: _handleBatchEditApply,
                      onDelete: _handleBatchDelete,
                      isSimpleMode: isSimpleMode,
                      onModeToggle: (isSimple) =>
                          setState(() => isSimpleMode = isSimple),
                    ),
                  ),

                // Tutorial overlay
                if (showTutorial)
                  MissionTutorialOverlay(
                    onClose: () => setState(() => showTutorial = false),
                    targetKey: _helpButtonKey,
                  ),
              ],
            ),
          ),

          // Mission Control Sidebar (30% width)
          Expanded(
            flex: 3,
            child: MissionSidebar(
              routePoints: routePoints,
              totalDistance: totalDistance,
              estimatedTime: estimatedTime,
              batteryUsage: batteryUsage,
              riskLevel: riskLevel,
              onReadMission: handleReadMission,
              onSendMission: routePoints.isNotEmpty
                  ? () => handleSendConfigs(routePoints)
                  : null,
              onImportMission: _handleImport,
              onReorderWaypoints: _handleReorderWaypoints,
              onEditWaypoint: _handleEditWaypoint,
              onDeleteWaypoint: _handleDeleteWaypointFromSidebar,
              isConnected: TelemetryService().mavlinkAPI.isConnected,
            ),
          ),
        ],
      ),
    );
  }
}
