import 'package:dart_mavlink/dialects/common.dart' as common;
import '../events.dart';
import '../mission/mission_models.dart' as model;

/// Handles MAVLink Mission Protocol state machine (upload/download/clear/current)
class MissionHandler {
  final void Function(MAVLinkEvent) emit;
  MissionHandler(this.emit);

  // State
  final List<model.PlanMissionItem?> _buffer = [];
  int _expectedCount = 0;

  // Upload helpers
  List<model.PlanMissionItem>? _uploadQueue;
  int _uploadIndex = 0;

  // Public read-only
  List<model.PlanMissionItem> get currentMission =>
      List.unmodifiable(_buffer.whereType<model.PlanMissionItem>());

  // Incoming routing
  void handleMissionCount(common.MissionCount msg) {
    _buffer.clear();
    _expectedCount = msg.count;
    emit(MAVLinkEvent(MAVLinkEventType.missionCount, msg.count));
    emit(MAVLinkEvent(MAVLinkEventType.missionDownloadProgress, {
      'received': 0,
      'total': _expectedCount,
    }));
  }

  void handleMissionItemInt(common.MissionItemInt m) {
    final item = model.PlanMissionItem(
      seq: m.seq,
      command: m.command,
      frame: m.frame,
      current: m.current,
      autocontinue: m.autocontinue,
      param1: m.param1,
      param2: m.param2,
      param3: m.param3,
      param4: m.param4,
      x: m.x.toDouble() / 1e7, // assumes GLOBAL_INT degE7
      y: m.y.toDouble() / 1e7,
      z: m.z,
    );
    // Ensure list size
    if (_buffer.length <= item.seq) {
      _buffer.length = item.seq + 1;
    }
    _buffer[item.seq] = item;
    emit(MAVLinkEvent(MAVLinkEventType.missionItem, item));
    emit(MAVLinkEvent(MAVLinkEventType.missionDownloadProgress, {
      'received': _buffer.whereType<model.PlanMissionItem>().length,
      'total': _expectedCount,
    }));

    final received = _buffer.whereType<model.PlanMissionItem>().length;
    if (received >= _expectedCount && _expectedCount > 0) {
      emit(MAVLinkEvent(
          MAVLinkEventType.missionDownloadComplete, currentMission));
    }
  }

  // Support legacy float MissionItem for downloads
  void handleMissionItem(common.MissionItem m) {
    final item = model.PlanMissionItem(
      seq: m.seq,
      command: m.command,
      frame: m.frame,
      current: m.current,
      autocontinue: m.autocontinue,
      param1: m.param1,
      param2: m.param2,
      param3: m.param3,
      param4: m.param4,
      x: m.x, // already degrees or local units
      y: m.y,
      z: m.z,
    );
    if (_buffer.length <= item.seq) {
      _buffer.length = item.seq + 1;
    }
    _buffer[item.seq] = item;
    emit(MAVLinkEvent(MAVLinkEventType.missionItem, item));
    emit(MAVLinkEvent(MAVLinkEventType.missionDownloadProgress, {
      'received': _buffer.whereType<model.PlanMissionItem>().length,
      'total': _expectedCount,
    }));

    final received = _buffer.whereType<model.PlanMissionItem>().length;
    if (received >= _expectedCount && _expectedCount > 0) {
      emit(MAVLinkEvent(
          MAVLinkEventType.missionDownloadComplete, currentMission));
    }
  }

  void handleMissionCurrent(common.MissionCurrent m) {
    emit(MAVLinkEvent(MAVLinkEventType.missionCurrent, {
      'seq': m.seq,
      'total': m.total,
      'missionMode': m.missionMode,
    }));
  }

  void handleMissionItemReached(common.MissionItemReached m) {
    emit(MAVLinkEvent(MAVLinkEventType.missionItemReached, m.seq));
  }

  void handleMissionAck(common.MissionAck m) {
    emit(MAVLinkEvent(MAVLinkEventType.missionAck, m.type));
    if (_uploadQueue != null && m.type == common.mavMissionAccepted) {
      emit(MAVLinkEvent(
          MAVLinkEventType.missionUploadComplete, _uploadQueue));
      _uploadQueue = null;
      _uploadIndex = 0;
    }
  }

  // Upload control (GCS side) - called by API when vehicle requests items
  common.MissionItemInt makeMissionItemInt(
      int systemId, int componentId, model.PlanMissionItem it) {
    final isGlobal = it.frame == common.mavFrameGlobal ||
        it.frame == common.mavFrameGlobalRelativeAlt ||
        it.frame == common.mavFrameGlobalTerrainAlt;
    final x = isGlobal ? (it.x * 1e7).round() : (it.x * 1e4).round();
    final y = isGlobal ? (it.y * 1e7).round() : (it.y * 1e4).round();
    return common.MissionItemInt(
      param1: it.param1.toDouble(),
      param2: it.param2.toDouble(),
      param3: it.param3.toDouble(),
      param4: it.param4.toDouble(),
      x: x,
      y: y,
      z: it.z.toDouble(),
      seq: it.seq,
      command: it.command,
      targetSystem: systemId,
      targetComponent: componentId,
      frame: it.frame,
      current: it.current,
      autocontinue: it.autocontinue,
      missionType: common.mavMissionTypeMission,
    );
  }

  void startUpload(List<model.PlanMissionItem> items) {
    _uploadQueue = items;
    _uploadIndex = 0;
    emit(MAVLinkEvent(MAVLinkEventType.missionUploadProgress, {
      'sent': 0,
      'total': items.length,
    }));
  }

  model.PlanMissionItem? dequeueNextUploadItem() {
    if (_uploadQueue == null) return null;
    if (_uploadIndex >= _uploadQueue!.length) return null;
    final item = _uploadQueue![_uploadIndex++];
    emit(MAVLinkEvent(MAVLinkEventType.missionUploadProgress, {
      'sent': _uploadIndex,
      'total': _uploadQueue!.length,
    }));
    return item;
  }

  // Build legacy float MissionItem (non-INT)
  common.MissionItem makeMissionItem(
      int systemId, int componentId, model.PlanMissionItem it) {
    return common.MissionItem(
      param1: it.param1.toDouble(),
      param2: it.param2.toDouble(),
      param3: it.param3.toDouble(),
      param4: it.param4.toDouble(),
      x: it.x.toDouble(),
      y: it.y.toDouble(),
      z: it.z.toDouble(),
      seq: it.seq,
      command: it.command,
      targetSystem: systemId,
      targetComponent: componentId,
      frame: it.frame,
      current: it.current,
      autocontinue: it.autocontinue,
      missionType: common.mavMissionTypeMission,
    );
  }

  bool get hasPendingUpload => _uploadQueue != null;
}
