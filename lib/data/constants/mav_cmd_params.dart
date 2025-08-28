// MAVLink command parameter definitions
class MavCmdParam {
  final String name;
  final String description;
  final String unit;
  final double? min;
  final double? max;
  final double defaultValue;
  final List<String>? enumValues; // For discrete values

  const MavCmdParam({
    required this.name,
    required this.description,
    this.unit = '',
    this.min,
    this.max,
    this.defaultValue = 0,
    this.enumValues,
  });
}

// Command parameter definitions for each MAV_CMD
final Map<int, List<MavCmdParam>> mavCmdParams = {
  // MAV_CMD_NAV_WAYPOINT (16)
  16: [
    MavCmdParam(
      name: 'Hold Time',
      description: 'Hold time at waypoint',
      unit: 'sec',
      min: 0,
      defaultValue: 0,
    ),
    MavCmdParam(
      name: 'Accept Radius',
      description: 'Acceptance radius',
      unit: 'm',
      min: 0,
      defaultValue: 0,
    ),
    MavCmdParam(
      name: 'Pass Radius',
      description: 'Pass through radius (0 = straight line)',
      unit: 'm',
      min: 0,
      defaultValue: 0,
    ),
    MavCmdParam(
      name: 'Yaw',
      description: 'Desired yaw angle',
      unit: 'deg',
      min: -180,
      max: 180,
      defaultValue: 0,
    ),
  ],

  // MAV_CMD_NAV_LOITER_TURNS (18)
  18: [
    MavCmdParam(
      name: 'Turns',
      description: 'Number of turns',
      unit: '',
      min: 1,
      defaultValue: 1,
    ),
    MavCmdParam(
      name: 'Head for exit',
      description: 'Heading required to face next waypoint',
      unit: 'deg',
      min: -180,
      max: 180,
      defaultValue: 0,
    ),
    MavCmdParam(
      name: 'Radius',
      description: 'Loiter radius',
      unit: 'm',
      min: 0,
      defaultValue: 0,
    ),
    MavCmdParam(
      name: 'Xtrack Location',
      description: 'Forward moving aircraft',
      unit: '',
      defaultValue: 0,
      enumValues: ['0: Center', '1: Forward'],
    ),
  ],

  // MAV_CMD_NAV_LOITER_TIME (19)
  19: [
    MavCmdParam(
      name: 'Time',
      description: 'Loiter time',
      unit: 'sec',
      min: 0,
      defaultValue: 0,
    ),
    MavCmdParam(
      name: 'Head for exit',
      description: 'Heading required to face next waypoint',
      unit: 'deg',
      min: -180,
      max: 180,
      defaultValue: 0,
    ),
    MavCmdParam(
      name: 'Radius',
      description: 'Loiter radius',
      unit: 'm',
      min: 0,
      defaultValue: 0,
    ),
    MavCmdParam(
      name: 'Xtrack Location',
      description: 'Forward moving aircraft',
      unit: '',
      defaultValue: 0,
      enumValues: ['0: Center', '1: Forward'],
    ),
  ],

  // MAV_CMD_NAV_RETURN_TO_LAUNCH (20)
  20: [
    MavCmdParam(name: 'Empty', description: 'Empty', unit: '', defaultValue: 0),
    MavCmdParam(name: 'Empty', description: 'Empty', unit: '', defaultValue: 0),
    MavCmdParam(name: 'Empty', description: 'Empty', unit: '', defaultValue: 0),
    MavCmdParam(name: 'Empty', description: 'Empty', unit: '', defaultValue: 0),
  ],

  // MAV_CMD_NAV_LAND (21)
  21: [
    MavCmdParam(
      name: 'Abort Alt',
      description: 'Minimum target altitude if landing is aborted',
      unit: 'm',
      min: 0,
      defaultValue: 0,
    ),
    MavCmdParam(
      name: 'Land Mode',
      description: 'Precision land mode',
      unit: '',
      defaultValue: 0,
      enumValues: ['0: Normal', '1: Opportunistic', '2: Required'],
    ),
    MavCmdParam(name: 'Empty', description: 'Empty', unit: '', defaultValue: 0),
    MavCmdParam(
      name: 'Yaw Angle',
      description: 'Desired yaw angle',
      unit: 'deg',
      min: -180,
      max: 180,
      defaultValue: 0,
    ),
  ],

  // MAV_CMD_NAV_TAKEOFF (22)
  22: [
    MavCmdParam(
      name: 'Pitch Angle',
      description: 'Minimum pitch (if airspeed sensor present)',
      unit: 'deg',
      min: -90,
      max: 90,
      defaultValue: 0,
    ),
    MavCmdParam(name: 'Empty', description: 'Empty', unit: '', defaultValue: 0),
    MavCmdParam(name: 'Empty', description: 'Empty', unit: '', defaultValue: 0),
    MavCmdParam(
      name: 'Yaw Angle',
      description: 'Yaw angle',
      unit: 'deg',
      min: -180,
      max: 180,
      defaultValue: 0,
    ),
  ],

  // MAV_CMD_NAV_SPLINE_WAYPOINT (82)
  82: [
    MavCmdParam(
      name: 'Hold Time',
      description: 'Hold time at waypoint',
      unit: 'sec',
      min: 0,
      defaultValue: 0,
    ),
    MavCmdParam(name: 'Empty', description: 'Empty', unit: '', defaultValue: 0),
    MavCmdParam(name: 'Empty', description: 'Empty', unit: '', defaultValue: 0),
    MavCmdParam(name: 'Empty', description: 'Empty', unit: '', defaultValue: 0),
  ],

  // MAV_CMD_DO_CHANGE_SPEED (178)
  178: [
    MavCmdParam(
      name: 'Speed Type',
      description: 'Speed type',
      unit: '',
      defaultValue: 0,
      enumValues: [
        '0: Airspeed',
        '1: Ground Speed',
        '2: Climb Speed',
        '3: Descent Speed',
      ],
    ),
    MavCmdParam(
      name: 'Speed',
      description: 'Speed value',
      unit: 'm/s',
      min: 0,
      defaultValue: 5,
    ),
    MavCmdParam(
      name: 'Throttle',
      description: 'Throttle as percentage (-1 = no change)',
      unit: '%',
      min: -1,
      max: 100,
      defaultValue: -1,
    ),
    MavCmdParam(
      name: 'Relative',
      description: 'Relative (1) or absolute (0)',
      unit: '',
      defaultValue: 0,
      enumValues: ['0: Absolute', '1: Relative'],
    ),
  ],

  // MAV_CMD_CONDITION_YAW (115)
  115: [
    MavCmdParam(
      name: 'Target Angle',
      description: 'Target angle',
      unit: 'deg',
      min: -180,
      max: 180,
      defaultValue: 0,
    ),
    MavCmdParam(
      name: 'Angular Speed',
      description: 'Angular speed',
      unit: 'deg/s',
      min: 0,
      defaultValue: 10,
    ),
    MavCmdParam(
      name: 'Direction',
      description: 'Direction: -1=CCW, 1=CW',
      unit: '',
      defaultValue: 1,
      enumValues: ['-1: Counter-Clockwise', '1: Clockwise'],
    ),
    MavCmdParam(
      name: 'Relative',
      description: 'Relative (1) or absolute (0)',
      unit: '',
      defaultValue: 1,
      enumValues: ['0: Absolute', '1: Relative'],
    ),
  ],

  // MAV_CMD_NAV_VTOL_TAKEOFF (84)
  84: [
    MavCmdParam(name: 'Empty', description: 'Empty', unit: '', defaultValue: 0),
    MavCmdParam(
      name: 'Transition Heading',
      description: 'Front transition heading',
      unit: '',
      defaultValue: 0,
    ),
    MavCmdParam(name: 'Empty', description: 'Empty', unit: '', defaultValue: 0),
    MavCmdParam(
      name: 'Yaw Angle',
      description: 'Yaw angle. NaN to use the current system yaw heading mode',
      unit: 'deg',
      min: -180,
      max: 180,
      defaultValue: 0,
    ),
  ],

  // MAV_CMD_NAV_VTOL_LAND (85)
  85: [
    MavCmdParam(name: 'Empty', description: 'Empty', unit: '', defaultValue: 0),
    MavCmdParam(name: 'Empty', description: 'Empty', unit: '', defaultValue: 0),
    MavCmdParam(
      name: 'Approach Altitude',
      description:
          'Approach altitude (with the same reference as the Altitude field)',
      unit: 'm',
      min: 0,
      defaultValue: 0,
    ),
    MavCmdParam(
      name: 'Yaw',
      description: 'Yaw angle',
      unit: 'deg',
      min: -180,
      max: 180,
      defaultValue: 0,
    ),
  ],

  // MAV_CMD_NAV_LOITER_UNLIM (17)
  17: [
    MavCmdParam(name: 'Empty', description: 'Empty', unit: '', defaultValue: 0),
    MavCmdParam(name: 'Empty', description: 'Empty', unit: '', defaultValue: 0),
    MavCmdParam(
      name: 'Radius',
      description: 'Loiter radius',
      unit: 'm',
      min: 0,
      defaultValue: 0,
    ),
    MavCmdParam(
      name: 'Xtrack Location',
      description: 'Forward moving aircraft',
      unit: '',
      defaultValue: 0,
      enumValues: ['0: Center', '1: Forward'],
    ),
  ],

  // MAV_CMD_NAV_LAND_LOCAL (23)
  23: [
    MavCmdParam(
      name: 'Target',
      description: 'Landing target number (if available)',
      unit: '',
      min: 0,
      defaultValue: 0,
    ),
    MavCmdParam(
      name: 'Offset',
      description: 'Maximum accepted offset from desired landing position',
      unit: 'm',
      min: 0,
      defaultValue: 0,
    ),
    MavCmdParam(
      name: 'Descend Rate',
      description: 'Landing descend rate',
      unit: 'm/s',
      min: 0,
      defaultValue: 0,
    ),
    MavCmdParam(
      name: 'Yaw',
      description: 'Desired yaw angle',
      unit: 'deg',
      min: -180,
      max: 180,
      defaultValue: 0,
    ),
  ],

  // MAV_CMD_NAV_LOITER_TO_ALT (31)
  31: [
    MavCmdParam(
      name: 'Heading Required',
      description: 'Heading required to face next waypoint',
      unit: 'deg',
      min: -180,
      max: 180,
      defaultValue: 0,
    ),
    MavCmdParam(
      name: 'Radius',
      description: 'Loiter radius',
      unit: 'm',
      min: 0,
      defaultValue: 0,
    ),
    MavCmdParam(name: 'Empty', description: 'Empty', unit: '', defaultValue: 0),
    MavCmdParam(
      name: 'Xtrack Location',
      description: 'Forward moving aircraft',
      unit: '',
      defaultValue: 0,
      enumValues: ['0: Center', '1: Forward'],
    ),
  ],

  // MAV_CMD_CONDITION_DELAY (112)
  112: [
    MavCmdParam(
      name: 'Time',
      description: 'Delay time',
      unit: 'sec',
      min: 0,
      defaultValue: 0,
    ),
    MavCmdParam(name: 'Empty', description: 'Empty', unit: '', defaultValue: 0),
    MavCmdParam(name: 'Empty', description: 'Empty', unit: '', defaultValue: 0),
    MavCmdParam(name: 'Empty', description: 'Empty', unit: '', defaultValue: 0),
  ],

  // MAV_CMD_CONDITION_CHANGE_ALT (113)
  113: [
    MavCmdParam(
      name: 'Rate',
      description: 'Descent/Ascent rate',
      unit: 'm/s',
      defaultValue: 0,
    ),
    MavCmdParam(name: 'Empty', description: 'Empty', unit: '', defaultValue: 0),
    MavCmdParam(name: 'Empty', description: 'Empty', unit: '', defaultValue: 0),
    MavCmdParam(name: 'Empty', description: 'Empty', unit: '', defaultValue: 0),
  ],

  // MAV_CMD_CONDITION_DISTANCE (114)
  114: [
    MavCmdParam(
      name: 'Distance',
      description: 'Distance to next waypoint',
      unit: 'm',
      min: 0,
      defaultValue: 0,
    ),
    MavCmdParam(name: 'Empty', description: 'Empty', unit: '', defaultValue: 0),
    MavCmdParam(name: 'Empty', description: 'Empty', unit: '', defaultValue: 0),
    MavCmdParam(name: 'Empty', description: 'Empty', unit: '', defaultValue: 0),
  ],

  // MAV_CMD_DO_SET_MODE (176)
  176: [
    MavCmdParam(
      name: 'Mode',
      description: 'System mode',
      unit: '',
      defaultValue: 0,
      enumValues: [
        '0: Preflight',
        '1: Manual',
        '2: Acro',
        '3: Stabilize',
        '4: Guided',
        '5: Loiter',
        '6: RTL',
        '7: Circle',
        '8: Land',
      ],
    ),
    MavCmdParam(
      name: 'Custom Mode',
      description: 'Custom mode - this is system specific',
      unit: '',
      defaultValue: 0,
    ),
    MavCmdParam(
      name: 'Custom Submode',
      description: 'Custom sub mode - this is system specific',
      unit: '',
      defaultValue: 0,
    ),
    MavCmdParam(name: 'Empty', description: 'Empty', unit: '', defaultValue: 0),
  ],

  // MAV_CMD_DO_JUMP (177)
  177: [
    MavCmdParam(
      name: 'Sequence Number',
      description: 'Sequence number',
      unit: '',
      min: 0,
      defaultValue: 0,
    ),
    MavCmdParam(
      name: 'Repeat',
      description: 'Repeat count',
      unit: '',
      min: 0,
      defaultValue: 0,
    ),
    MavCmdParam(name: 'Empty', description: 'Empty', unit: '', defaultValue: 0),
    MavCmdParam(name: 'Empty', description: 'Empty', unit: '', defaultValue: 0),
  ],

  // MAV_CMD_DO_SET_HOME (179)
  179: [
    MavCmdParam(
      name: 'Use Current',
      description:
          'Use current position (1=use current location, 0=use specified location)',
      unit: '',
      defaultValue: 1,
      enumValues: ['0: Use Specified', '1: Use Current'],
    ),
    MavCmdParam(name: 'Empty', description: 'Empty', unit: '', defaultValue: 0),
    MavCmdParam(name: 'Empty', description: 'Empty', unit: '', defaultValue: 0),
    MavCmdParam(
      name: 'Yaw',
      description: 'Yaw angle',
      unit: 'deg',
      min: -180,
      max: 180,
      defaultValue: 0,
    ),
  ],

  // MAV_CMD_DO_SET_PARAMETER (180)
  180: [
    MavCmdParam(
      name: 'Parameter Number',
      description: 'Parameter number',
      unit: '',
      min: 1,
      defaultValue: 1,
    ),
    MavCmdParam(
      name: 'Parameter Value',
      description: 'Parameter value',
      unit: '',
      defaultValue: 0,
    ),
    MavCmdParam(name: 'Empty', description: 'Empty', unit: '', defaultValue: 0),
    MavCmdParam(name: 'Empty', description: 'Empty', unit: '', defaultValue: 0),
  ],

  // MAV_CMD_DO_SET_RELAY (181)
  181: [
    MavCmdParam(
      name: 'Relay Number',
      description: 'Relay number',
      unit: '',
      min: 0,
      defaultValue: 0,
    ),
    MavCmdParam(
      name: 'Setting',
      description: 'Setting (1=on, 0=off, others invalid)',
      unit: '',
      defaultValue: 0,
      enumValues: ['0: Off', '1: On'],
    ),
    MavCmdParam(name: 'Empty', description: 'Empty', unit: '', defaultValue: 0),
    MavCmdParam(name: 'Empty', description: 'Empty', unit: '', defaultValue: 0),
  ],

  // MAV_CMD_DO_SET_SERVO (183)
  183: [
    MavCmdParam(
      name: 'Servo Number',
      description: 'Servo number',
      unit: '',
      min: 1,
      defaultValue: 1,
    ),
    MavCmdParam(
      name: 'PWM',
      description: 'PWM (microseconds, 1000 to 2000 typical)',
      unit: 'us',
      min: 1000,
      max: 2000,
      defaultValue: 1500,
    ),
    MavCmdParam(name: 'Empty', description: 'Empty', unit: '', defaultValue: 0),
    MavCmdParam(name: 'Empty', description: 'Empty', unit: '', defaultValue: 0),
  ],

  // MAV_CMD_DO_SET_ROI (201)
  201: [
    MavCmdParam(
      name: 'ROI Mode',
      description: 'Region of interest mode',
      unit: '',
      defaultValue: 0,
      enumValues: [
        '0: None',
        '1: WP Next',
        '2: WP Index',
        '3: Location',
        '4: Target',
      ],
    ),
    MavCmdParam(
      name: 'WP Index',
      description: 'Waypoint index',
      unit: '',
      min: 0,
      defaultValue: 0,
    ),
    MavCmdParam(
      name: 'ROI Index',
      description: 'ROI index',
      unit: '',
      min: 0,
      defaultValue: 0,
    ),
    MavCmdParam(name: 'Empty', description: 'Empty', unit: '', defaultValue: 0),
  ],

  // MAV_CMD_DO_DIGICAM_CONTROL (203)
  203: [
    MavCmdParam(
      name: 'Session Control',
      description: 'Session control e.g. show/hide lens',
      unit: '',
      defaultValue: 0,
    ),
    MavCmdParam(
      name: 'Zoom Pos',
      description: 'Zoom\'s absolute position',
      unit: '',
      defaultValue: 0,
    ),
    MavCmdParam(
      name: 'Zoom Step',
      description:
          'Zooming step value to offset zoom from the current position',
      unit: '',
      defaultValue: 0,
    ),
    MavCmdParam(
      name: 'Focus Lock',
      description: 'Focus Locking, Unlocking or Re-locking',
      unit: '',
      defaultValue: 0,
    ),
  ],

  // MAV_CMD_DO_MOUNT_CONTROL (205)
  205: [
    MavCmdParam(
      name: 'Pitch',
      description: 'Pitch',
      unit: 'deg',
      min: -90,
      max: 90,
      defaultValue: 0,
    ),
    MavCmdParam(
      name: 'Roll',
      description: 'Roll',
      unit: 'deg',
      min: -180,
      max: 180,
      defaultValue: 0,
    ),
    MavCmdParam(
      name: 'Yaw',
      description: 'Yaw',
      unit: 'deg',
      min: -180,
      max: 180,
      defaultValue: 0,
    ),
    MavCmdParam(name: 'Empty', description: 'Empty', unit: '', defaultValue: 0),
  ],

  // MAV_CMD_DO_SET_CAM_TRIGG_DIST (206)
  206: [
    MavCmdParam(
      name: 'Distance',
      description: 'Camera trigger distance interval',
      unit: 'm',
      min: 0,
      defaultValue: 0,
    ),
    MavCmdParam(
      name: 'Shutter',
      description: 'Camera shutter integration time',
      unit: 'ms',
      min: 0,
      defaultValue: 0,
    ),
    MavCmdParam(
      name: 'Trigger',
      description: 'Trigger camera once immediately',
      unit: '',
      defaultValue: 0,
      enumValues: ['0: No', '1: Yes'],
    ),
    MavCmdParam(name: 'Empty', description: 'Empty', unit: '', defaultValue: 0),
  ],

  // MAV_CMD_DO_PARACHUTE (208)
  208: [
    MavCmdParam(
      name: 'Action',
      description: 'Action',
      unit: '',
      defaultValue: 0,
      enumValues: ['0: Disable', '1: Enable', '2: Release'],
    ),
    MavCmdParam(name: 'Empty', description: 'Empty', unit: '', defaultValue: 0),
    MavCmdParam(name: 'Empty', description: 'Empty', unit: '', defaultValue: 0),
    MavCmdParam(name: 'Empty', description: 'Empty', unit: '', defaultValue: 0),
  ],
};

// Helper function to get parameters for a command
List<MavCmdParam> getCommandParams(int command) {
  return mavCmdParams[command] ?? [];
}

// Helper function to get parameter names for display
List<String> getParamNames(int command) {
  final params = getCommandParams(command);
  return params.map((p) => p.name).toList();
}

// Helper function to get default values for a command
List<double> getDefaultValues(int command) {
  final params = getCommandParams(command);
  return params.map((p) => p.defaultValue).toList();
}
