import 'package:flutter/material.dart';
import 'package:skylink/data/models/route_point_model.dart';
import 'package:skylink/presentation/view/main/map/controllers/map_page_state.dart';
import 'package:skylink/presentation/widget/map/components/undo_redo_manager.dart';
import 'package:skylink/presentation/widget/common/confirm_dialog.dart';

/// Edit operation handlers for MapPage
/// Handles waypoint editing, deletion, conversion, batch operations
mixin MapPageEditHandlers<T extends StatefulWidget> on State<T> {
  MapPageState get state;
  void Function(void Function()) get updateState;
  void showSuccess(String message);
  void calculateMissionStats();

  // ============================================================================
  // SINGLE WAYPOINT EDIT
  // ============================================================================

  Future<void> handleDeleteWaypoint() async {
    if (state.selectedWaypoint == null) return;

    final confirmed = await ConfirmDialog.confirmDelete(
      context: context,
      itemName: 'waypoint ${state.selectedWaypoint!.order}',
      additionalMessage:
          'Bạn có chắc chắn muốn xóa waypoint ${state.selectedWaypoint!.order}? Hành động này có thể hoàn tác bằng nút Hoàn tác.',
    );

    if (!confirmed) return;

    final index = state.routePoints.indexWhere(
      (wp) => wp.id == state.selectedWaypoint!.id,
    );

    if (index != -1) {
      state.undoRedoManager.addAction(
        MissionAction(
          type: ActionType.deleteWaypoint,
          waypoint: state.selectedWaypoint!,
          index: index,
        ),
      );

      updateState(() {
        state.waypointLayerLinks.remove(state.selectedWaypoint!.id);
        state.routePoints.removeAt(index);
        state.reorderWaypoints();
        state.selectedWaypoint = null;
        state.isEditMode = false;
      });

      calculateMissionStats();
      showSuccess('Waypoint đã được xoá');
    }
  }

  void handleConvertWaypoint(int commandType) {
    if (state.selectedWaypoint == null) return;

    final index = state.routePoints.indexWhere(
      (wp) => wp.id == state.selectedWaypoint!.id,
    );

    if (index != -1) {
      final oldWaypoint = state.routePoints[index];

      state.undoRedoManager.addAction(
        MissionAction(
          type: ActionType.convertWaypoint,
          waypoint: oldWaypoint.copyWith(command: commandType),
          previousWaypoint: oldWaypoint,
          index: index,
        ),
      );

      updateState(() {
        state.routePoints[index] = state.routePoints[index].copyWith(
          command: commandType,
        );
        state.selectedWaypoint = null;
        state.isEditMode = false;
      });

      calculateMissionStats();
      showSuccess('Waypoint type changed');
    }
  }

  void handleSaveWaypoint(RoutePoint updatedWaypoint) {
    final index = state.routePoints.indexWhere(
      (wp) => wp.id == updatedWaypoint.id,
    );

    if (index != -1) {
      state.undoRedoManager.addAction(
        MissionAction(
          type: ActionType.editWaypoint,
          waypoint: updatedWaypoint,
          previousWaypoint: state.routePoints[index],
          index: index,
        ),
      );

      updateState(() {
        state.routePoints[index] = updatedWaypoint;
        state.isEditMode = false;
        state.selectedWaypoint = null;
        state.isDragging = false;
        state.isSelectingOrbitCenter = false;
      });

      calculateMissionStats();
      state.mapKey.currentState?.clearMapDragState();
      FocusScope.of(context).unfocus();
      Future.microtask(() => updateState(() {}));

      showSuccess('Waypoint đã được cập nhật');
    }
  }

  void handleCancelEdit() {
    updateState(() {
      state.isEditMode = false;
      state.selectedWaypoint = null;
      state.isDragging = false;
      state.isSelectingOrbitCenter = false;
    });

    state.mapKey.currentState?.clearMapDragState();
    FocusScope.of(context).unfocus();
    Future.microtask(() => updateState(() {}));
  }

  // ============================================================================
  // BATCH EDIT OPERATIONS
  // ============================================================================

  void handleBatchEditCancel() {
    updateState(() {
      state.selectedWaypointIds.clear();
      state.isDragging = false;
      state.isEditMode = false;
      state.selectedWaypoint = null;
      state.isSelectingOrbitCenter = false;
    });

    state.mapKey.currentState?.clearMapDragState();
    FocusScope.of(context).unfocus();
    Future.microtask(() {
      if (mounted) {
        updateState(() {});
      }
    });
  }

  void handleBatchDelete() {
    if (state.selectedWaypointIds.isEmpty) return;

    final selectedWaypoints = state.routePoints
        .where((wp) => state.selectedWaypointIds.contains(wp.id))
        .toList();

    updateState(() {
      state.routePoints.removeWhere(
        (wp) => state.selectedWaypointIds.contains(wp.id),
      );

      for (int i = 0; i < state.routePoints.length; i++) {
        state.routePoints[i] = state.routePoints[i].copyWith(order: i + 1);
      }

      state.selectedWaypointIds.clear();
      state.isDragging = false;
      state.isEditMode = false;
      state.selectedWaypoint = null;
      state.isSelectingOrbitCenter = false;
    });

    state.mapKey.currentState?.clearMapDragState();
    FocusScope.of(context).unfocus();
    Future.microtask(() {
      if (mounted) {
        updateState(() {});
      }
    });

    state.undoRedoManager.addAction(
      MissionAction(
        type: ActionType.batchDelete,
        data: {'deletedWaypoints': selectedWaypoints},
      ),
    );

    calculateMissionStats();
    showSuccess('${selectedWaypoints.length} waypoints đã được xoá');
  }

  void handleBatchEditApply(Map<String, dynamic> batchChanges) {
    if (state.selectedWaypointIds.isEmpty || batchChanges.isEmpty) return;

    final selectedWaypoints = state.routePoints
        .where((wp) => state.selectedWaypointIds.contains(wp.id))
        .toList();

    final updatedWaypoints = <RoutePoint>[];

    for (final waypoint in selectedWaypoints) {
      final updatedCommandParams = Map<String, dynamic>.from(
        waypoint.commandParams ?? {},
      );

      if (batchChanges.containsKey('commandParams')) {
        final newParams = batchChanges['commandParams'] as Map<String, double>;
        updatedCommandParams.addAll(newParams);
      }

      // Legacy support
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

      final index = state.routePoints.indexWhere((wp) => wp.id == waypoint.id);
      if (index >= 0) {
        state.routePoints[index] = updatedWaypoint;
      }
    }

    updateState(() {
      state.selectedWaypointIds.clear();
      state.isDragging = false;
      state.isEditMode = false;
      state.selectedWaypoint = null;
      state.isSelectingOrbitCenter = false;
    });

    state.mapKey.currentState?.clearMapDragState();
    FocusScope.of(context).unfocus();
    Future.microtask(() {
      if (mounted) {
        updateState(() {});
      }
    });

    calculateMissionStats();
    showSuccess(
      'Đã áp dụng chỉnh sửa cho ${updatedWaypoints.length} waypoints',
    );
  }

  // ============================================================================
  // NAVIGATION
  // ============================================================================

  void handleModeToggle(bool simple) {
    updateState(() {
      state.isSimpleMode = simple;
    });
  }

  void handlePrevWaypoint() {
    if (state.selectedWaypoint == null || state.routePoints.isEmpty) return;

    final currentIndex = state.routePoints.indexWhere(
      (wp) => wp.order == state.selectedWaypoint!.order,
    );

    if (currentIndex > 0) {
      updateState(() {
        state.selectedWaypoint = state.routePoints[currentIndex - 1];
      });
    }
  }

  void handleNextWaypoint() {
    if (state.selectedWaypoint == null || state.routePoints.isEmpty) return;

    final currentIndex = state.routePoints.indexWhere(
      (wp) => wp.order == state.selectedWaypoint!.order,
    );

    if (currentIndex < state.routePoints.length - 1) {
      updateState(() {
        state.selectedWaypoint = state.routePoints[currentIndex + 1];
      });
    }
  }

  // ============================================================================
  // SIDEBAR OPERATIONS
  // ============================================================================

  void handleReorderWaypoints(List<RoutePoint> reorderedWaypoints) {
    state.undoRedoManager.addAction(
      MissionAction(
        type: ActionType.batchEdit,
        waypoint: state.routePoints.first,
      ),
    );

    updateState(() {
      state.routePoints.clear();
      state.routePoints.addAll(reorderedWaypoints);
    });

    calculateMissionStats();
  }

  void handleEditWaypoint(RoutePoint waypoint) {
    updateState(() {
      state.selectedWaypoint = waypoint;
      state.isEditMode = true;
      state.isDragging = false;
      state.selectedWaypointIds.clear();
      state.isSelectingOrbitCenter = false;
    });

    state.mapKey.currentState?.clearMapDragState();
  }

  void handleDeleteWaypointFromSidebar(String waypointId) {
    final waypointToDelete = state.routePoints.firstWhere(
      (wp) => wp.id == waypointId,
      orElse: () => throw StateError('Waypoint không tìm thấy'),
    );

    state.undoRedoManager.addAction(
      MissionAction(
        type: ActionType.deleteWaypoint,
        waypoint: waypointToDelete,
        index: state.routePoints.indexOf(waypointToDelete),
      ),
    );

    updateState(() {
      state.routePoints.removeWhere((wp) => wp.id == waypointId);
      state.waypointLayerLinks.remove(waypointId);

      if (state.selectedWaypoint?.id == waypointId) {
        state.selectedWaypoint = null;
        state.isEditMode = false;
      }

      state.selectedWaypointIds.remove(waypointId);
    });

    state.reorderWaypoints();
    calculateMissionStats();
  }
}
