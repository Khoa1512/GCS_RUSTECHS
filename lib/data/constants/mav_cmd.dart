// MAVLink command definitions
class MavCmd {
  // Navigation commands
  static const int waypoint = 16;
  static const int loiterUnlimited = 17;
  static const int loiterTurns = 18;
  static const int loiterTime = 19;
  static const int returnToLaunch = 20;
  static const int land = 21;
  static const int takeoff = 22;
  static const int landStart = 23;
  static const int loiterToAlt = 31;
  static const int splineWaypoint = 82;
  static const int vtolTakeoff = 84;
  static const int vtolLand = 85;

  // Condition commands
  static const int conditionDelay = 112;
  static const int conditionChangeAlt = 113;
  static const int conditionDistance = 114;
  static const int conditionYaw = 115;

  // DO commands
  static const int doSetMode = 176;
  static const int doJump = 177;
  static const int changeSpeed = 178;
  static const int doSetHome = 179;
  static const int doSetParameter = 180;
  static const int doSetRelay = 181;
  static const int doRepeatRelay = 182;
  static const int doSetServo = 183;
  static const int doRepeatServo = 184;
  static const int doFlighttermination = 185;
  static const int doChangeAltitude = 186;
  static const int doLandStart = 189;
  static const int doRallyLand = 190;
  static const int doGoPosAndReorient = 191;
  static const int doSetRoi = 201;
  static const int doDigicamConfigure = 202;
  static const int doDigicamControl = 203;
  static const int doMountConfigure = 204;
  static const int doMountControl = 205;
  static const int doSetCamTriggDist = 206;
  static const int doFenceEnable = 207;
  static const int doParachute = 208;
  static const int doMotorTest = 209;
  static const int doInvertedFlight = 210;
  static const int doGripper = 211;
  static const int doAutotunEnable = 212;
  static const int doSetReverseThrottle = 213;
}

// Command name to number mapping
final Map<String, int> mavCmdMap = {
  // Navigation commands
  'Waypoint': MavCmd.waypoint,
  'Loiter Unlimited': MavCmd.loiterUnlimited,
  'Loiter Turns': MavCmd.loiterTurns,
  'Loiter Time': MavCmd.loiterTime,
  'Return to Launch': MavCmd.returnToLaunch,
  'Land': MavCmd.land,
  'Takeoff': MavCmd.takeoff,
  'Land Start': MavCmd.landStart,
  'Loiter to Alt': MavCmd.loiterToAlt,
  'Spline Waypoint': MavCmd.splineWaypoint,
  'VTOL Takeoff': MavCmd.vtolTakeoff,
  'VTOL Land': MavCmd.vtolLand,

  // Condition commands
  'Condition Delay': MavCmd.conditionDelay,
  'Condition Change Alt': MavCmd.conditionChangeAlt,
  'Condition Distance': MavCmd.conditionDistance,
  'Set Yaw': MavCmd.conditionYaw,

  // DO commands
  'Set Mode': MavCmd.doSetMode,
  'Jump': MavCmd.doJump,
  'Change Speed': MavCmd.changeSpeed,
  'Set Home': MavCmd.doSetHome,
  'Set Parameter': MavCmd.doSetParameter,
  'Set Relay': MavCmd.doSetRelay,
  'Repeat Relay': MavCmd.doRepeatRelay,
  'Set Servo': MavCmd.doSetServo,
  'Repeat Servo': MavCmd.doRepeatServo,
  'Flight Termination': MavCmd.doFlighttermination,
  'Change Altitude': MavCmd.doChangeAltitude,
  'Do Land Start': MavCmd.doLandStart,
  'Rally Land': MavCmd.doRallyLand,
  'Go Pos And Reorient': MavCmd.doGoPosAndReorient,
  'Do Set ROI': MavCmd.doSetRoi,
  'Camera Configure': MavCmd.doDigicamConfigure,
  'Camera Control': MavCmd.doDigicamControl,
  'Mount Configure': MavCmd.doMountConfigure,
  'Mount Control': MavCmd.doMountControl,
  'Camera Trigger Distance': MavCmd.doSetCamTriggDist,
  'Fence Enable': MavCmd.doFenceEnable,
  'Parachute': MavCmd.doParachute,
  'Motor Test': MavCmd.doMotorTest,
  'Inverted Flight': MavCmd.doInvertedFlight,
  'Gripper': MavCmd.doGripper,
  'Autotune Enable': MavCmd.doAutotunEnable,
  'Set Reverse Throttle': MavCmd.doSetReverseThrottle,
};

// Command number to name mapping (reverse of above)
final Map<int, String> mavCmdNameMap = mavCmdMap.map((k, v) => MapEntry(v, k));
