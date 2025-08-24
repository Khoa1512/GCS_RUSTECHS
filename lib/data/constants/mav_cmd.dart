// MAVLink command definitions
class MavCmd {
  static const int waypoint = 16;
  static const int loiterTurns = 18;
  static const int loiterTime = 19;
  static const int returnToLaunch = 20;
  static const int land = 21;
  static const int takeoff = 22;
  static const int splineWaypoint = 82;
  static const int changeSpeed = 178;
  static const int conditionYaw = 115;
}

// Command name to number mapping
final Map<String, int> mavCmdMap = {
  'Waypoint': MavCmd.waypoint,
  'Loiter (Turns)': MavCmd.loiterTurns,
  'Loiter (Time)': MavCmd.loiterTime,
  'Return to Launch': MavCmd.returnToLaunch,
  'Land': MavCmd.land,
  'Takeoff': MavCmd.takeoff,
  'Spline Waypoint': MavCmd.splineWaypoint,
  'Change Speed': MavCmd.changeSpeed,
  'Set Yaw': MavCmd.conditionYaw,
};

// Command number to name mapping (reverse of above)
final Map<int, String> mavCmdNameMap = mavCmdMap.map((k, v) => MapEntry(v, k));
