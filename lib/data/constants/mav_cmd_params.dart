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
  // MAV_CMD_CONDITION_YAW (115)
  84: [
    MavCmdParam(
      name: '',
      description: 'Empty',
      unit: '',
    ),
    MavCmdParam(
      name: 'Transition Heading',
      description: 'Front transition heading.',
      unit: '',
    ),
    MavCmdParam(name: '', description: 'Empty', unit: ''),
    MavCmdParam(
      name: 'Yaw Angle',
      description: 'Yaw angle. NaN to use the current system yaw heading mode',
      unit: 'deg',
    ),
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
