import 'package:skylink/data/models/route_point_model.dart';

enum ActionType {
  addWaypoint,
  deleteWaypoint,
  moveWaypoint,
  editWaypoint,
  clearMission,
  convertWaypoint,
  batchEdit,
  batchDelete,
}

class MissionAction {
  final ActionType type;
  final RoutePoint? waypoint;
  final RoutePoint? previousWaypoint; // For undo
  final int? index;
  final Map<String, dynamic>? data;

  MissionAction({
    required this.type,
    this.waypoint,
    this.previousWaypoint,
    this.index,
    this.data,
  });
}

class UndoRedoManager {
  final List<MissionAction> _undoStack = [];
  final List<MissionAction> _redoStack = [];
  static const int maxHistorySize = 50;

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  void addAction(MissionAction action) {
    _undoStack.add(action);
    _redoStack.clear(); // Clear redo stack when new action is added

    // Limit history size
    if (_undoStack.length > maxHistorySize) {
      _undoStack.removeAt(0);
    }
  }

  MissionAction? undo() {
    if (_undoStack.isEmpty) return null;

    final action = _undoStack.removeLast();
    _redoStack.add(action);
    return action;
  }

  MissionAction? redo() {
    if (_redoStack.isEmpty) return null;

    final action = _redoStack.removeLast();
    _undoStack.add(action);
    return action;
  }

  void clear() {
    _undoStack.clear();
    _redoStack.clear();
  }
}
