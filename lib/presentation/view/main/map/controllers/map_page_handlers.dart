import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:skylink/data/models/route_point_model.dart';
import 'package:skylink/presentation/view/main/map/controllers/map_page_state.dart';
import 'package:skylink/presentation/widget/map/components/undo_redo_manager.dart';
import 'package:skylink/presentation/widget/map/components/add_waypoint_dialog.dart';
import 'package:skylink/presentation/widget/map/components/template_dialogs.dart';
import 'package:skylink/presentation/widget/map/components/survey_config_dialog.dart';
import 'package:skylink/presentation/widget/map/utils/mission_templates.dart';
import 'package:skylink/presentation/widget/map/utils/survey_generator.dart';
import 'package:skylink/presentation/widget/map/utils/polygon_survey_generator.dart';
import 'package:skylink/presentation/widget/common/confirm_dialog.dart';
import 'package:skylink/services/telemetry_service.dart';

/// Event handlers for MapPage
/// Handles all user interactions: taps, drags, edits, etc.
mixin MapPageHandlers<T extends StatefulWidget> on State<T> {
  MapPageState get state;

  void Function(void Function()) get updateState;

  void showSuccess(String message);
  void showInfo(String message);
  void calculateMissionStats();

  // ============================================================================
  // MAP INTERACTION HANDLERS
  // ============================================================================

  /// Handle map tap
  void onMapTap(LatLng latLng) {
    // Handle polygon drawing
    if (state.isDrawingPolygon) {
      updateState(() {
        state.polygonPoints.add(latLng);
      });
      return;
    }

    // Handle bounding box drawing
    if (state.isDrawingBoundingBox) {
      if (state.boundingBoxStart == null) {
        // First click - set start point
        updateState(() {
          state.boundingBoxStart = latLng;
        });
      } else {
        // Second click - set end point and show config dialog
        updateState(() {
          state.boundingBoxEnd = latLng;
        });
        showSurveyConfigDialog();
      }
      return;
    }

    // Handle template center selection
    if (state.isSelectingOrbitCenter) {
      createOrbitAt(latLng);
      return;
    }

    if (state.isEditMode) {
      // Exit edit mode when clicking on map
      updateState(() {
        state.isEditMode = false;
        state.selectedWaypoint = null;
        state.isSelectingOrbitCenter = false;
      });
      return;
    }

    // Add new waypoint
    addWaypoint(latLng);
  }

  /// Handle pointer hover (for bounding box preview)
  void onPointerHover(LatLng latLng) {
    if (state.isDrawingBoundingBox && state.boundingBoxStart != null) {
      updateState(() {
        state.boundingBoxEnd = latLng;
      });
    }
  }

  /// Handle waypoint drag
  void onWaypointDrag(int index, LatLng newPosition) {
    if (index >= 0 && index < state.routePoints.length) {
      final oldWaypoint = state.routePoints[index];

      state.undoRedoManager.addAction(
        MissionAction(
          type: ActionType.moveWaypoint,
          waypoint: state.routePoints[index].copyWith(
            latitude: newPosition.latitude.toString(),
            longitude: newPosition.longitude.toString(),
          ),
          previousWaypoint: oldWaypoint,
          index: index,
        ),
      );

      updateState(() {
        state.routePoints[index] = state.routePoints[index].copyWith(
          latitude: newPosition.latitude.toString(),
          longitude: newPosition.longitude.toString(),
        );
      });

      calculateMissionStats();
    }
  }

  /// Handle waypoint tap
  void onWaypointTap(
    int index,
    Offset globalPosition, {
    bool isCtrlPressed = false,
  }) {
    if (index >= 0 && index < state.routePoints.length) {
      final waypoint = state.routePoints[index];

      if (isCtrlPressed) {
        // Multi-select mode
        updateState(() {
          if (state.selectedWaypointIds.contains(waypoint.id)) {
            state.selectedWaypointIds.remove(waypoint.id);
          } else {
            state.selectedWaypointIds.add(waypoint.id);
          }
          state.selectedWaypoint = null;
          state.isEditMode = false;
        });
      } else {
        // Single select mode
        updateState(() {
          state.selectedWaypoint = waypoint;
          state.isEditMode = true;
          state.selectedWaypointIds.clear();
        });

        state.mapKey.currentState?.clearMapDragState();
      }
    }
  }

  void onWaypointDragStart() {
    updateState(() {
      state.isDragging = true;
    });
  }

  void onWaypointDragEnd() {
    updateState(() {
      state.isDragging = false;
    });
  }

  /// Handle home point drag
  void onHomePointDrag(LatLng newPosition) {
    updateState(() {
      state.homePoint = newPosition;
      state.isHomePointManuallySet = true; // Mark as manually set
    });
  }

  /// Reset home point to auto mode (GPS-based)
  void resetHomePointToAuto() {
    updateState(() {
      state.isHomePointManuallySet = false;
      state.hasSetHomePoint = false;
      state.homePoint = null;
    });
    showInfo('Home Point đã được reset về chế độ tự động');
  }

  // ============================================================================
  // WAYPOINT OPERATIONS
  // ============================================================================

  /// Add waypoint at position
  void addWaypoint(LatLng latLng) {
    final newWaypoint = RoutePoint(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      order: state.routePoints.length + 1,
      latitude: latLng.latitude.toString(),
      longitude: latLng.longitude.toString(),
      altitude: "10",
      command: 16,
    );

    state.undoRedoManager.addAction(
      MissionAction(type: ActionType.addWaypoint, waypoint: newWaypoint),
    );

    updateState(() {
      state.routePoints.add(newWaypoint);
      state.waypointLayerLinks[newWaypoint.id] = LayerLink();
    });

    calculateMissionStats();
  }

  /// Add waypoint with specific altitude
  void addWaypointWithAltitude(LatLng latLng, double altitude) {
    final newWaypoint = RoutePoint(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      order: state.routePoints.length + 1,
      latitude: latLng.latitude.toString(),
      longitude: latLng.longitude.toString(),
      altitude: altitude.toInt().toString(),
      command: 16,
    );

    state.undoRedoManager.addAction(
      MissionAction(type: ActionType.addWaypoint, waypoint: newWaypoint),
    );

    updateState(() {
      state.routePoints.add(newWaypoint);
      state.waypointLayerLinks[newWaypoint.id] = LayerLink();
    });

    calculateMissionStats();
  }

  // ============================================================================
  // FLOATING ACTION HANDLERS
  // ============================================================================

  void handleAddWaypoint() {
    if (state.isDrawingBoundingBox) {
      cancelBoundingBoxDrawing();
    }

    showDialog(
      context: context,
      builder: (context) => AddWaypointDialog(
        onAddWaypoint: (position, altitude) {
          addWaypointWithAltitude(position, altitude);
        },
      ),
    );
  }

  void handleOrbitTemplate() {
    updateState(() {
      state.isSelectingOrbitCenter = true;
    });
    showInfo('Nhấp vào bản đồ để chọn điểm tâm bay vòng');
  }

  void handleBoundingBoxSurvey() {
    updateState(() {
      state.isDrawingBoundingBox = true;
      state.boundingBoxStart = null;
      state.boundingBoxEnd = null;
      state.isSelectingOrbitCenter = false;
      state.isEditMode = false;
      state.selectedWaypoint = null;
      state.selectedWaypointIds.clear();
    });
    showInfo('Nhấp 2 lần trên bản đồ để vẽ vùng survey (góc đối diện)');
  }

  void handlePolygonSurvey() {
    updateState(() {
      state.isDrawingPolygon = true;
      state.polygonPoints.clear();
      state.isDrawingBoundingBox = false;
      state.boundingBoxStart = null;
      state.boundingBoxEnd = null;
      state.isSelectingOrbitCenter = false;
      state.isEditMode = false;
      state.selectedWaypoint = null;
      state.selectedWaypointIds.clear();
    });
    showInfo('Nhấp nhiều lần để tạo đa giác, tối thiểu 3 điểm');
  }

  void finishPolygonDrawing() {
    if (state.polygonPoints.length < 3) {
      showInfo('Cần ít nhất 3 điểm để tạo đa giác');
      return;
    }
    showSurveyConfigDialogForPolygon();
  }

  void undoLastPolygonPoint() {
    if (state.polygonPoints.isNotEmpty) {
      updateState(() {
        state.polygonPoints.removeLast();
      });
    }
  }

  void cancelPolygonDrawing() {
    updateState(() {
      state.isDrawingPolygon = false;
      state.polygonPoints.clear();
    });
  }

  void cancelBoundingBoxDrawing() {
    updateState(() {
      state.isDrawingBoundingBox = false;
      state.boundingBoxStart = null;
      state.boundingBoxEnd = null;
    });
  }

  // ============================================================================
  // TEMPLATE CREATION
  // ============================================================================

  void createOrbitAt(LatLng center) {
    updateState(() {
      state.isSelectingOrbitCenter = false;
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

          state.undoRedoManager.addAction(
            MissionAction(
              type: ActionType.addWaypoint,
              data: {'waypoints': orbitWaypoints},
            ),
          );

          updateState(() {
            state.routePoints.addAll(orbitWaypoints);
            state.reorderWaypoints();
          });

          calculateMissionStats();
          showSuccess(
            'Orbit mission created with ${orbitWaypoints.length} waypoints',
          );
        },
      ),
    );
  }

  void showSurveyConfigDialogForPolygon() {
    if (state.polygonPoints.length < 3) return;

    showDialog(
      context: context,
      builder: (context) => SurveyConfigDialog(
        isPolygon: true, // NEW: Indicate this is polygon survey
        onConfirm: (config) {
          final surveyWaypoints = PolygonSurveyGenerator.generateForPolygon(
            polygon: state.polygonPoints,
            config: config,
          );

          if (surveyWaypoints.isEmpty) {
            showInfo('Không thể tạo survey với cấu hình này');
            return;
          }

          state.undoRedoManager.addAction(
            MissionAction(
              type: ActionType.addWaypoint,
              data: {'waypoints': surveyWaypoints},
            ),
          );

          updateState(() {
            state.routePoints.addAll(surveyWaypoints);
            state.reorderWaypoints();
            state.isDrawingPolygon = false;
            state.polygonPoints.clear();
          });

          calculateMissionStats();
          showSuccess(
            'Đã tạo ${surveyWaypoints.length} waypoints cho vùng polygon',
          );
        },
      ),
    );
  }

  void showSurveyConfigDialog() {
    if (state.boundingBoxStart == null || state.boundingBoxEnd == null) return;

    showDialog(
      context: context,
      builder: (context) => SurveyConfigDialog(
        topLeft: state.boundingBoxStart!,
        bottomRight: state.boundingBoxEnd!,
        onConfirm: (config) {
          generateBoundingBoxSurvey(config);
        },
      ),
    );
  }

  void generateBoundingBoxSurvey(SurveyConfig config) {
    if (state.boundingBoxStart == null || state.boundingBoxEnd == null) return;

    final surveyWaypoints = SurveyGenerator.generateSurvey(
      topLeft: state.boundingBoxStart!,
      bottomRight: state.boundingBoxEnd!,
      config: config,
    );

    state.undoRedoManager.addAction(
      MissionAction(
        type: ActionType.addWaypoint,
        data: {'waypoints': surveyWaypoints},
      ),
    );

    updateState(() {
      state.routePoints.addAll(surveyWaypoints);
      state.reorderWaypoints();
      state.isDrawingBoundingBox = false;
      state.boundingBoxStart = null;
      state.boundingBoxEnd = null;
    });

    state.ensureLayerLinksForWaypoints();
    calculateMissionStats();

    final patternName = config.pattern == SurveyPattern.lawnmower
        ? 'Lawnmower'
        : config.pattern == SurveyPattern.grid
        ? 'Grid'
        : 'Perimeter';

    showSuccess(
      'Survey mission ($patternName) đã tạo với ${surveyWaypoints.length} waypoints',
    );
  }

  // ============================================================================
  // UNDO/REDO
  // ============================================================================

  void handleUndo() {
    final action = state.undoRedoManager.undo();
    if (action != null) {
      applyUndoAction(action);
    }
  }

  void handleRedo() {
    final action = state.undoRedoManager.redo();
    if (action != null) {
      applyRedoAction(action);
    }
  }

  void applyUndoAction(MissionAction action) {
    switch (action.type) {
      case ActionType.addWaypoint:
        updateState(() {
          state.routePoints.removeWhere((wp) => wp.id == action.waypoint!.id);
        });
        break;
      case ActionType.deleteWaypoint:
        if (action.waypoint != null && action.index != null) {
          updateState(() {
            state.routePoints.insert(action.index!, action.waypoint!);
            state.reorderWaypoints();
          });
        }
        break;
      case ActionType.moveWaypoint:
      case ActionType.editWaypoint:
      case ActionType.convertWaypoint:
        if (action.previousWaypoint != null && action.index != null) {
          updateState(() {
            state.routePoints[action.index!] = action.previousWaypoint!;
          });
        }
        break;
      case ActionType.clearMission:
        // TODO: Restore previous mission
        break;
      case ActionType.batchEdit:
        // TODO: Implement batch edit undo
        break;
      case ActionType.batchDelete:
        if (action.data != null && action.data!['deletedWaypoints'] != null) {
          final deletedWaypoints =
              action.data!['deletedWaypoints'] as List<RoutePoint>;
          updateState(() {
            state.routePoints.addAll(deletedWaypoints);
            state.routePoints.sort((a, b) => a.order.compareTo(b.order));
          });
        }
        break;
    }

    calculateMissionStats();
  }

  void applyRedoAction(MissionAction action) {
    switch (action.type) {
      case ActionType.addWaypoint:
        updateState(() {
          state.routePoints.add(action.waypoint!);
        });
        break;
      case ActionType.deleteWaypoint:
        updateState(() {
          state.routePoints.removeWhere((wp) => wp.id == action.waypoint!.id);
          state.reorderWaypoints();
        });
        break;
      case ActionType.moveWaypoint:
      case ActionType.editWaypoint:
      case ActionType.convertWaypoint:
        if (action.waypoint != null && action.index != null) {
          updateState(() {
            state.routePoints[action.index!] = action.waypoint!;
          });
        }
        break;
      case ActionType.clearMission:
        updateState(() {
          state.routePoints.clear();
          state.waypointLayerLinks.clear();
        });
        break;
      case ActionType.batchEdit:
        // TODO: Implement batch edit redo
        break;
      case ActionType.batchDelete:
        if (action.data != null && action.data!['deletedWaypoints'] != null) {
          final deletedWaypoints =
              action.data!['deletedWaypoints'] as List<RoutePoint>;
          final idsToDelete = deletedWaypoints.map((wp) => wp.id).toSet();
          updateState(() {
            state.routePoints.removeWhere((wp) => idsToDelete.contains(wp.id));
            for (int i = 0; i < state.routePoints.length; i++) {
              state.routePoints[i] = state.routePoints[i].copyWith(
                order: i + 1,
              );
            }
          });
        }
        break;
    }

    state.ensureLayerLinksForWaypoints();
    calculateMissionStats();
  }

  // ============================================================================
  // MISSION OPERATIONS
  // ============================================================================

  Future<void> handleClearMission() async {
    if (state.routePoints.isEmpty) return;

    final confirmed = await ConfirmDialog.confirmClear(
      context: context,
      itemName: 'các waypoints',
      additionalMessage:
          'Bạn có chắc chắn muốn xóa toàn bộ nhiệm vụ với ${state.routePoints.length} waypoints? Hành động này có thể hoàn tác.',
    );

    if (!confirmed) return;

    state.undoRedoManager.addAction(
      MissionAction(
        type: ActionType.clearMission,
        data: {'waypoints': List.from(state.routePoints)},
      ),
    );

    updateState(() {
      state.routePoints.clear();
      state.waypointLayerLinks.clear();
      state.selectedWaypoint = null;
      state.selectedWaypointIds.clear();
      state.isEditMode = false;
    });

    calculateMissionStats();

    if (TelemetryService().mavlinkAPI.isConnected) {
      TelemetryService().mavlinkAPI.clearMission();
      showSuccess('Nhiệm vụ đã được xóa khỏi Flight Controller');
    }
  }

  void handleImport(List<RoutePoint> importedRoutePoints) {
    updateState(() {
      state.routePoints.clear();
      state.routePoints.addAll(importedRoutePoints);
      state.selectedWaypoint = null;
      state.isEditMode = false;
      state.selectedWaypointIds.clear();
    });

    calculateMissionStats();
  }

  // Continued in next part...
}
