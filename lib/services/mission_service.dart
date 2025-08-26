import 'dart:async';
import 'package:skylink/api/telemetry/mavlink/mission/mission_models.dart';
import 'package:skylink/data/models/route_point_model.dart';

class MissionService {
  static final MissionService _instance = MissionService._internal();
  factory MissionService() => _instance;

  MissionService._internal();

  // Current mission plan
  List<RoutePoint> _currentMissionPoints = [];
  final _missionController = StreamController<List<RoutePoint>>.broadcast();

  // Public getters
  Stream<List<RoutePoint>> get missionStream => _missionController.stream;
  List<RoutePoint> get currentMissionPoints => List.from(_currentMissionPoints);
  bool get hasMission => _currentMissionPoints.isNotEmpty;

  // Update mission after successful upload
  void updateMission(List<RoutePoint> points) {
    _currentMissionPoints = List.from(points);
    _missionController.add(_currentMissionPoints);
  }

  // Clear current mission
  void clearMission() {
    _currentMissionPoints.clear();
    _missionController.add(_currentMissionPoints);
  }

  // Convert RoutePoints to PlanMissionItems
  List<PlanMissionItem> convertToPlanItems(List<RoutePoint> points) {
    if (points.isEmpty) return [];

    final missionItems = <PlanMissionItem>[
      // Home position (sequence 0)
      PlanMissionItem(
        seq: 0,
        current: 1, // Mark as current
        frame: 0, // MAV_FRAME_GLOBAL
        command: 16, // MAV_CMD_NAV_WAYPOINT
        param1: 0, // Hold time
        param2: 0, // Acceptance radius
        param3: 0, // Pass radius
        param4: 0, // Yaw
        x: double.parse(points.first.latitude),
        y: double.parse(points.first.longitude),
        z: double.parse(points.first.altitude),
        autocontinue: 1,
      ),
    ];

    // Add remaining waypoints
    for (var i = 0; i < points.length; i++) {
      final point = points[i];

      // Extract parameters from commandParams or use defaults
      double param1 = 0, param2 = 0, param3 = 0, param4 = 0;
      if (point.commandParams != null) {
        param1 = (point.commandParams!['param1'] as num?)?.toDouble() ?? 0;
        param2 = (point.commandParams!['param2'] as num?)?.toDouble() ?? 0;
        param3 = (point.commandParams!['param3'] as num?)?.toDouble() ?? 0;
        param4 = (point.commandParams!['param4'] as num?)?.toDouble() ?? 0;
      }

      missionItems.add(
        PlanMissionItem(
          seq: i + 1, // Start from 1
          current: 0, // Not current
          frame: 3, // MAV_FRAME_GLOBAL_RELATIVE_ALT
          command: point.command,
          param1: param1,
          param2: param2,
          param3: param3,
          param4: param4,
          x: double.parse(point.latitude),
          y: double.parse(point.longitude),
          z: double.parse(point.altitude),
          autocontinue: 1,
        ),
      );
    }

    return missionItems;
  }

  void dispose() {
    _missionController.close();
  }
}
