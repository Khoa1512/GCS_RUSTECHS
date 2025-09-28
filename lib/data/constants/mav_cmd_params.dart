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
      name: 'Thời gian dừng',
      description: 'Thời gian dừng lại tại waypoint (giây)',
      unit: 'giây',
      min: 0,
      defaultValue: 0,
    ),
    MavCmdParam(
      name: 'Bán kính chấp nhận',
      description:
          'Bán kính chấp nhận đến waypoint (máy bay coi như đã đến khi trong phạm vi này)',
      unit: 'm',
      min: 0,
      defaultValue: 0,
    ),
    MavCmdParam(
      name: 'Bán kính đi qua',
      description: 'Bán kính đi qua waypoint (0 = bay thẳng)',
      unit: 'm',
      min: 0,
      defaultValue: 0,
    ),
    MavCmdParam(
      name: 'Góc Yaw',
      description: 'Góc yaw mong muốn (hướng mũi máy bay)',
      unit: 'độ',
      min: -180,
      max: 180,
      defaultValue: 0,
    ),
  ],

  // MAV_CMD_NAV_LOITER_TURNS (18)
  18: [
    MavCmdParam(
      name: 'Số vòng',
      description: 'Số vòng bay tròn',
      unit: 'vòng',
      min: 1,
      defaultValue: 1,
    ),
    MavCmdParam(
      name: 'Hướng thoát',
      description: 'Hướng bay để đi đến waypoint tiếp theo',
      unit: 'độ',
      min: -180,
      max: 180,
      defaultValue: 0,
    ),
    MavCmdParam(
      name: 'Bán kính',
      description: 'Bán kính bay tròn',
      unit: 'm',
      min: 0,
      defaultValue: 0,
    ),
    MavCmdParam(
      name: 'Vị trí bay',
      description: 'Vị trí máy bay trong vòng tròn',
      unit: '',
      defaultValue: 0,
      enumValues: ['0: Giữa', '1: Phía trước'],
    ),
  ],

  // MAV_CMD_NAV_LOITER_TIME (19)
  19: [
    MavCmdParam(
      name: 'Thời gian',
      description: 'Thời gian bay tròn tại điểm này',
      unit: 'giây',
      min: 0,
      defaultValue: 0,
    ),
    MavCmdParam(
      name: 'Hướng thoát',
      description: 'Hướng bay để đi đến waypoint tiếp theo',
      unit: 'độ',
      min: -180,
      max: 180,
      defaultValue: 0,
    ),
    MavCmdParam(
      name: 'Bán kính',
      description: 'Bán kính bay tròn',
      unit: 'm',
      min: 0,
      defaultValue: 0,
    ),
    MavCmdParam(
      name: 'Vị trí bay',
      description: 'Vị trí máy bay trong vòng tròn',
      unit: '',
      defaultValue: 0,
      enumValues: ['0: Giữa', '1: Phía trước'],
    ),
  ],

  // MAV_CMD_NAV_RETURN_TO_LAUNCH (20)
  20: [
    MavCmdParam(
      name: 'Trống',
      description: 'Tham số không sử dụng',
      unit: '',
      defaultValue: 0,
    ),
    MavCmdParam(
      name: 'Trống',
      description: 'Tham số không sử dụng',
      unit: '',
      defaultValue: 0,
    ),
    MavCmdParam(
      name: 'Trống',
      description: 'Tham số không sử dụng',
      unit: '',
      defaultValue: 0,
    ),
    MavCmdParam(
      name: 'Trống',
      description: 'Tham số không sử dụng',
      unit: '',
      defaultValue: 0,
    ),
  ],

  // MAV_CMD_NAV_LAND (21)
  21: [
    MavCmdParam(
      name: 'Độ cao hủy',
      description: 'Độ cao tối thiểu nếu hủy hạ cánh',
      unit: 'm',
      min: 0,
      defaultValue: 0,
    ),
    MavCmdParam(
      name: 'Chế độ hạ cánh',
      description: 'Chế độ hạ cánh chính xác',
      unit: '',
      defaultValue: 0,
      enumValues: ['0: Bình thường', '1: Cơ hội', '2: Bắt buộc'],
    ),
    MavCmdParam(
      name: 'Trống',
      description: 'Tham số không sử dụng',
      unit: '',
      defaultValue: 0,
    ),
    MavCmdParam(
      name: 'Góc Yaw',
      description: 'Góc yaw mong muốn khi hạ cánh',
      unit: 'độ',
      min: -180,
      max: 180,
      defaultValue: 0,
    ),
  ],

  // MAV_CMD_NAV_TAKEOFF (22)
  22: [
    MavCmdParam(
      name: 'Góc Pitch',
      description: 'Góc pitch tối thiểu (nếu có cảm biến tốc độ)',
      unit: 'độ',
      min: -90,
      max: 90,
      defaultValue: 0,
    ),
    MavCmdParam(
      name: 'Trống',
      description: 'Tham số không sử dụng',
      unit: '',
      defaultValue: 0,
    ),
    MavCmdParam(
      name: 'Trống',
      description: 'Tham số không sử dụng',
      unit: '',
      defaultValue: 0,
    ),
    MavCmdParam(
      name: 'Góc Yaw',
      description: 'Góc yaw khi cất cánh',
      unit: 'độ',
      min: -180,
      max: 180,
      defaultValue: 0,
    ),
  ],

  // MAV_CMD_NAV_SPLINE_WAYPOINT (82)
  82: [
    MavCmdParam(
      name: 'Thời gian dừng',
      description: 'Thời gian dừng lại tại waypoint',
      unit: 'giây',
      min: 0,
      defaultValue: 0,
    ),
    MavCmdParam(
      name: 'Trống',
      description: 'Tham số không sử dụng',
      unit: '',
      defaultValue: 0,
    ),
    MavCmdParam(
      name: 'Trống',
      description: 'Tham số không sử dụng',
      unit: '',
      defaultValue: 0,
    ),
    MavCmdParam(
      name: 'Trống',
      description: 'Tham số không sử dụng',
      unit: '',
      defaultValue: 0,
    ),
  ],

  // MAV_CMD_DO_CHANGE_SPEED (178)
  178: [
    MavCmdParam(
      name: 'Loại tốc độ',
      description: 'Loại tốc độ thay đổi',
      unit: '',
      defaultValue: 0,
      enumValues: [
        '0: Tốc độ khí',
        '1: Tốc độ mặt đất',
        '2: Tốc độ leo',
        '3: Tốc độ hạ',
      ],
    ),
    MavCmdParam(
      name: 'Tốc độ',
      description: 'Giá trị tốc độ',
      unit: 'm/s',
      min: 0,
      defaultValue: 5,
    ),
    MavCmdParam(
      name: 'Ga',
      description: 'Ga theo phần trăm (-1 = không thay đổi)',
      unit: '%',
      min: -1,
      max: 100,
      defaultValue: -1,
    ),
    MavCmdParam(
      name: 'Tương đối',
      description: 'Tương đối (1) hoặc tuyệt đối (0)',
      unit: '',
      defaultValue: 0,
      enumValues: ['0: Tuyệt đối', '1: Tương đối'],
    ),
  ],

  // MAV_CMD_CONDITION_YAW (115)
  115: [
    MavCmdParam(
      name: 'Góc mục tiêu',
      description: 'Góc yaw mục tiêu',
      unit: 'độ',
      min: -180,
      max: 180,
      defaultValue: 0,
    ),
    MavCmdParam(
      name: 'Tốc độ góc',
      description: 'Tốc độ xoay',
      unit: 'độ/giây',
      min: 0,
      defaultValue: 10,
    ),
    MavCmdParam(
      name: 'Hướng',
      description: 'Hướng xoay: -1=Ngược kim đồng hồ, 1=Thuận kim đồng hồ',
      unit: '',
      defaultValue: 1,
      enumValues: ['-1: Ngược kim đồng hồ', '1: Thuận kim đồng hồ'],
    ),
    MavCmdParam(
      name: 'Tương đối',
      description: 'Tương đối (1) hoặc tuyệt đối (0)',
      unit: '',
      defaultValue: 1,
      enumValues: ['0: Tuyệt đối', '1: Tương đối'],
    ),
  ],

  // MAV_CMD_NAV_VTOL_TAKEOFF (84)
  84: [
    MavCmdParam(
      name: 'Trống',
      description: 'Tham số không sử dụng',
      unit: '',
      defaultValue: 0,
    ),
    MavCmdParam(
      name: 'Hướng chuyển đổi',
      description: 'Hướng chuyển đổi sang chế độ bay thẳng',
      unit: '',
      defaultValue: 0,
    ),
    MavCmdParam(
      name: 'Trống',
      description: 'Tham số không sử dụng',
      unit: '',
      defaultValue: 0,
    ),
    MavCmdParam(
      name: 'Góc Yaw',
      description: 'Góc yaw. NaN để sử dụng chế độ hiện tại',
      unit: 'độ',
      min: -180,
      max: 180,
      defaultValue: 0,
    ),
  ],

  // MAV_CMD_NAV_VTOL_LAND (85)
  85: [
    MavCmdParam(
      name: 'Trống',
      description: 'Tham số không sử dụng',
      unit: '',
      defaultValue: 0,
    ),
    MavCmdParam(
      name: 'Trống',
      description: 'Tham số không sử dụng',
      unit: '',
      defaultValue: 0,
    ),
    MavCmdParam(
      name: 'Độ cao tiếp cận',
      description: 'Độ cao tiếp cận (cùng tham chiếu với trường Độ cao)',
      unit: 'm',
      min: 0,
      defaultValue: 0,
    ),
    MavCmdParam(
      name: 'Góc Yaw',
      description: 'Góc yaw',
      unit: 'độ',
      min: -180,
      max: 180,
      defaultValue: 0,
    ),
  ],

  // MAV_CMD_NAV_LOITER_UNLIM (17)
  17: [
    MavCmdParam(
      name: 'Trống',
      description: 'Tham số không sử dụng',
      unit: '',
      defaultValue: 0,
    ),
    MavCmdParam(
      name: 'Trống',
      description: 'Tham số không sử dụng',
      unit: '',
      defaultValue: 0,
    ),
    MavCmdParam(
      name: 'Bán kính',
      description: 'Bán kính bay tròn vô hạn',
      unit: 'm',
      min: 0,
      defaultValue: 0,
    ),
    MavCmdParam(
      name: 'Vị trí bay',
      description: 'Vị trí máy bay trong vòng tròn',
      unit: '',
      defaultValue: 0,
      enumValues: ['0: Giữa', '1: Phía trước'],
    ),
  ],

  // MAV_CMD_NAV_LAND_LOCAL (23)
  23: [
    MavCmdParam(
      name: 'Mục tiêu',
      description: 'Số mục tiêu hạ cánh (nếu có)',
      unit: '',
      min: 0,
      defaultValue: 0,
    ),
    MavCmdParam(
      name: 'Độ lệch',
      description: 'Độ lệch tối đa chấp nhận từ vị trí hạ cánh mong muốn',
      unit: 'm',
      min: 0,
      defaultValue: 0,
    ),
    MavCmdParam(
      name: 'Tốc độ hạ',
      description: 'Tốc độ hạ cánh',
      unit: 'm/s',
      min: 0,
      defaultValue: 0,
    ),
    MavCmdParam(
      name: 'Góc Yaw',
      description: 'Góc yaw mong muốn',
      unit: 'độ',
      min: -180,
      max: 180,
      defaultValue: 0,
    ),
  ],

  // MAV_CMD_NAV_LOITER_TO_ALT (31)
  31: [
    MavCmdParam(
      name: 'Hướng yêu cầu',
      description: 'Hướng yêu cầu để đi đến waypoint tiếp theo',
      unit: 'độ',
      min: -180,
      max: 180,
      defaultValue: 0,
    ),
    MavCmdParam(
      name: 'Bán kính',
      description: 'Bán kính bay tròn',
      unit: 'm',
      min: 0,
      defaultValue: 0,
    ),
    MavCmdParam(
      name: 'Trống',
      description: 'Tham số không sử dụng',
      unit: '',
      defaultValue: 0,
    ),
    MavCmdParam(
      name: 'Vị trí bay',
      description: 'Vị trí máy bay trong vòng tròn',
      unit: '',
      defaultValue: 0,
      enumValues: ['0: Giữa', '1: Phía trước'],
    ),
  ],

  // MAV_CMD_CONDITION_DELAY (112)
  112: [
    MavCmdParam(
      name: 'Thời gian',
      description: 'Thời gian trì hoãn',
      unit: 'giây',
      min: 0,
      defaultValue: 0,
    ),
    MavCmdParam(
      name: 'Trống',
      description: 'Tham số không sử dụng',
      unit: '',
      defaultValue: 0,
    ),
    MavCmdParam(
      name: 'Trống',
      description: 'Tham số không sử dụng',
      unit: '',
      defaultValue: 0,
    ),
    MavCmdParam(
      name: 'Trống',
      description: 'Tham số không sử dụng',
      unit: '',
      defaultValue: 0,
    ),
  ],

  // MAV_CMD_CONDITION_CHANGE_ALT (113)
  113: [
    MavCmdParam(
      name: 'Tốc độ',
      description: 'Tốc độ hạ/leo',
      unit: 'm/s',
      defaultValue: 0,
    ),
    MavCmdParam(
      name: 'Trống',
      description: 'Tham số không sử dụng',
      unit: '',
      defaultValue: 0,
    ),
    MavCmdParam(
      name: 'Trống',
      description: 'Tham số không sử dụng',
      unit: '',
      defaultValue: 0,
    ),
    MavCmdParam(
      name: 'Trống',
      description: 'Tham số không sử dụng',
      unit: '',
      defaultValue: 0,
    ),
  ],

  // MAV_CMD_CONDITION_DISTANCE (114)
  114: [
    MavCmdParam(
      name: 'Khoảng cách',
      description: 'Khoảng cách đến waypoint tiếp theo',
      unit: 'm',
      min: 0,
      defaultValue: 0,
    ),
    MavCmdParam(
      name: 'Trống',
      description: 'Tham số không sử dụng',
      unit: '',
      defaultValue: 0,
    ),
    MavCmdParam(
      name: 'Trống',
      description: 'Tham số không sử dụng',
      unit: '',
      defaultValue: 0,
    ),
    MavCmdParam(
      name: 'Trống',
      description: 'Tham số không sử dụng',
      unit: '',
      defaultValue: 0,
    ),
  ],

  // MAV_CMD_DO_SET_ROI (201)
  201: [
    MavCmdParam(
      name: 'Chế độ ROI',
      description: 'Chế độ vùng quan tâm (ROI)',
      unit: '',
      defaultValue: 0,
      enumValues: [
        '0: Không',
        '1: WP tiếp theo',
        '2: WP theo chỉ số',
        '3: Vị trí',
        '4: Mục tiêu',
      ],
    ),
    MavCmdParam(
      name: 'Chỉ số WP',
      description: 'Chỉ số waypoint',
      unit: '',
      min: 0,
      defaultValue: 0,
    ),
    MavCmdParam(
      name: 'Chỉ số ROI',
      description: 'Chỉ số ROI',
      unit: '',
      min: 0,
      defaultValue: 0,
    ),
    MavCmdParam(
      name: 'Trống',
      description: 'Tham số không sử dụng',
      unit: '',
      defaultValue: 0,
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
