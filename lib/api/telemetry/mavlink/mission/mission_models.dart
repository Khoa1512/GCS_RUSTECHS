import 'dart:convert';

/// Simple mission item model (subset sufficient for ArduPilot/Plane/Copter)
class PlanMissionItem {
  int seq;
  int command; // MAV_CMD
  int frame; // MAV_FRAME
  int current; // 1 if current
  int autocontinue; // 1 continue
  double param1;
  double param2;
  double param3;
  double param4;
  double x; // lat or local x
  double y; // lon or local y
  double z; // alt or local z

  PlanMissionItem({
    required this.seq,
    required this.command,
    required this.frame,
    this.current = 0,
    this.autocontinue = 1,
    this.param1 = 0,
    this.param2 = 0,
    this.param3 = 0,
    this.param4 = 0,
    this.x = 0,
    this.y = 0,
    this.z = 0,
  });

  Map<String, dynamic> toJson() => {
        'seq': seq,
        'command': command,
        'frame': frame,
        'current': current,
        'autocontinue': autocontinue,
        'param1': param1,
        'param2': param2,
        'param3': param3,
        'param4': param4,
        'x': x,
        'y': y,
        'z': z,
      };

  static PlanMissionItem fromJson(Map<String, dynamic> j) => PlanMissionItem(
        seq: j['seq'] ?? 0,
        command: j['command'] ?? 16,
        frame: j['frame'] ?? 3,
        current: j['current'] ?? 0,
        autocontinue: j['autocontinue'] ?? 1,
        param1: (j['param1'] ?? 0).toDouble(),
        param2: (j['param2'] ?? 0).toDouble(),
        param3: (j['param3'] ?? 0).toDouble(),
        param4: (j['param4'] ?? 0).toDouble(),
        x: (j['x'] ?? 0).toDouble(),
        y: (j['y'] ?? 0).toDouble(),
        z: (j['z'] ?? 0).toDouble(),
      );
}

class MissionPlan {
  List<PlanMissionItem> items;
  int missionType; // 0: MISSION_TYPE_MISSION
  MissionPlan({List<PlanMissionItem>? items, this.missionType = 0})
      : items = items ?? [];

  // QGC .plan minimal export
  String toQgcPlanJson() {
    // Determine planned home from the first item when possible (EKF origin/home)
    List<num> plannedHome = [0, 0, 0];
    if (items.isNotEmpty) {
      final first = items.first;
      // If the first item looks like a global coordinate, use it as home
      final isGlobal = first.frame == 0 ||
          first.frame == 3 ||
          first.frame == 10; // MAV_FRAME_GLOBAL, GLOBAL_RELATIVE_ALT, GLOBAL_TERRAIN_ALT
      final looksLikeLatLon = first.x.abs() <= 90 && first.y.abs() <= 180 &&
          (first.x != 0 || first.y != 0);
      if (isGlobal && looksLikeLatLon) {
        plannedHome = [first.x, first.y, first.z]; // [lat, lon, alt]
      }
    }
    final plan = {
      'fileType': 'Plan',
      'qgcVersion': '4.0',
      'geoFence': {'polys': []},
      'rallyPoints': {'points': []},
      'mission': {
        'cruiseSpeed': 0,
        'firmwareType': 12, // ArduPilot
        'hoverSpeed': 0,
        'vehicleType': 2, // Copter default
        'version': 2,
        'plannedHomePosition': plannedHome,
  'items': items
            .map((e) => {
                  'AMSLAltAboveTerrain': null,
                  'Altitude': e.z,
                  'AltitudeMode': 1,
                  'AutoContinue': e.autocontinue == 1,
                  'Command': e.command,
                  'DoJumpId': e.seq + 1,
                  'Frame': e.frame,
                  'Params': [
                    e.param1,
                    e.param2,
                    e.param3,
                    e.param4,
                    e.x,
                    e.y,
                    e.z,
                    0
                  ],
                  'Type': 'SimpleItem',
                })
            .toList(),
      },
    };
    return const JsonEncoder.withIndent('  ').convert(plan);
  }

  static MissionPlan fromQgcPlanJson(String jsonStr) {
    final map = json.decode(jsonStr) as Map<String, dynamic>;
    final mission = map['mission'] as Map<String, dynamic>?;
    final itemsList = (mission?['items'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final items = <PlanMissionItem>[];
    for (final it in itemsList) {
      final params = (it['Params'] as List<dynamic>? ?? []).map((e) =>
              (e is num) ? e.toDouble() : double.tryParse(e.toString()) ?? 0)
          .toList();
      double p(int i) => i < params.length ? params[i] : 0;
      items.add(PlanMissionItem(
        seq: (it['DoJumpId'] ?? items.length) - 1,
        command: it['Command'] ?? 16,
        frame: it['Frame'] ?? 3,
        autocontinue: (it['AutoContinue'] ?? true) ? 1 : 0,
        param1: p(0),
        param2: p(1),
        param3: p(2),
        param4: p(3),
        x: p(4),
        y: p(5),
        z: p(6),
      ));
    }
    return MissionPlan(items: items);
  }

  // ArduPilot plain text .waypoints format
  String toArduPilotWaypoints() {
    final b = StringBuffer();
    b.writeln('QGC WPL 110');
  for (final e in items) {
      b.writeln([
        e.seq,
        e.current,
        e.frame,
        e.command,
        e.param1,
        e.param2,
        e.param3,
        e.param4,
        e.x,
        e.y,
        e.z,
        e.autocontinue
      ].join('\t'));
    }
    return b.toString();
  }

  static MissionPlan fromArduPilotWaypoints(String content) {
    final lines = LineSplitter.split(content)
        .where((l) => l.trim().isNotEmpty && !l.startsWith('#'))
        .toList();
    if (lines.isEmpty || !lines.first.contains('QGC WPL')) {
      throw FormatException('Invalid waypoints header');
    }
    final items = <PlanMissionItem>[];
    for (final line in lines.skip(1)) {
      final parts = line.split(RegExp(r"\s+"));
      if (parts.length < 12) continue;
      items.add(PlanMissionItem(
        seq: int.parse(parts[0]),
        current: int.parse(parts[1]),
        frame: int.parse(parts[2]),
        command: int.parse(parts[3]),
        param1: double.parse(parts[4]),
        param2: double.parse(parts[5]),
        param3: double.parse(parts[6]),
        param4: double.parse(parts[7]),
        x: double.parse(parts[8]),
        y: double.parse(parts[9]),
        z: double.parse(parts[10]),
        autocontinue: int.parse(parts[11]),
      ));
    }
    return MissionPlan(items: items);
  }
}
