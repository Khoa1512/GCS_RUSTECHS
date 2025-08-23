import 'dart:async';
import 'package:dart_mavlink/dialects/common.dart';
import '../events.dart';

class HeartbeatHandler {
  final void Function(MAVLinkEvent) emit;

  // Debounce and state tracking
  String _currentMode = 'Unknown';
  String _pendingMode = 'Unknown';
  DateTime? _modeChangeTime;
  Timer? _modeDebounceTimer;
  static const Duration _modeDebounceDelay = Duration(seconds: 1);
  bool _isArmed = false;

  HeartbeatHandler(this.emit);

  void handle(Heartbeat msg) {
  // Decode mode based on vehicle type (copter vs plane/VTOL hybrid)
  final newMode = _decodeFlightMode(msg.type, msg.customMode);
    _isArmed = (msg.baseMode & 0x80) != 0;

    if (newMode != _pendingMode) {
      _pendingMode = newMode;
      _modeChangeTime = DateTime.now();
      _modeDebounceTimer?.cancel();
      _modeDebounceTimer = Timer(_modeDebounceDelay, () {
        if (_pendingMode == newMode && _modeChangeTime != null) {
          _currentMode = _pendingMode;
          _emit(msg);
        }
      });
    } else {
      _modeChangeTime = DateTime.now();
    }

    // Always emit to update armed state promptly
    _emit(msg);
  }

  void _emit(Heartbeat hb) {
    emit(MAVLinkEvent(MAVLinkEventType.heartbeat, {
      'mode': _currentMode,
      'armed': _isArmed,
      'type': _getSystemType(hb.type),
      'autopilot': _getAutopilotType(hb.autopilot),
      'baseMode': hb.baseMode,
      'customMode': hb.customMode,
      'systemStatus': _getSystemStatus(hb.systemStatus),
      'mavlinkVersion': hb.mavlinkVersion,
    }));
  }

  // Decode ArduPilot flight modes depending on vehicle type.
  // systemType: MAV_TYPE_* from heartbeat.type
  String _decodeFlightMode(int systemType, int customMode) {
    // Copter modes (ArduCopter) mapping (custom_mode -> name)
    const Map<int, String> copterModes = {
      0: 'STABILIZE',
      1: 'ACRO',
      2: 'ALT HOLD',
      3: 'AUTO',
      4: 'GUIDED',
      5: 'LOITER',
      6: 'RTL',
      7: 'CIRCLE',
      9: 'LAND',
      11: 'DRIFT',
      13: 'SPORT',
      14: 'FLIP',
      15: 'AUTOTUNE',
      16: 'POSHOLD',
      17: 'BRAKE',
      18: 'THROW',
      19: 'AVOID ADSB',
      20: 'GUIDED NOGPS',
      21: 'SMARTRTL',
      22: 'FLOWHOLD',
      23: 'FOLLOW',
      24: 'ZIGZAG',
      25: 'SYSTEMID',
      26: 'AUTOROTATE',
      27: 'AUTO RTL',
      28: 'TURTLE',
    };

    // Plane / QuadPlane modes (ArduPlane) mapping
    const Map<int, String> planeModes = {
      0: 'MANUAL',
      1: 'CIRCLE',
      2: 'STABILIZE',
      3: 'TRAINING',
      4: 'ACRO',
      5: 'FBWA',
      6: 'FBWB',
      7: 'CRUISE',
      8: 'AUTOTUNE',
      10: 'AUTO',
      11: 'RTL',
      12: 'LOITER',
      13: 'TAKEOFF',
      14: 'AVOID ADSB',
      15: 'GUIDED',
      16: 'INITIALISING',
      17: 'QSTABILIZE',
      18: 'QHOVER',
      19: 'QLOITER',
      20: 'QLAND',
      21: 'QRTL',
      22: 'QAUTOTUNE',
      23: 'QACRO',
      24: 'THERMAL',
      25: 'LOITER2QLAND',
      26: 'AUTOLAND',
    };

    // Determine which mapping to use.
    final bool isPlaneLike = (systemType == 1 /* Fixed Wing */) || (systemType == 19 /* VTOL */);
    final bool isCopterLike = !isPlaneLike && <int>{2, 3, 4, 13, 14, 15}.contains(systemType);

    final map = isPlaneLike
        ? planeModes
        : (isCopterLike ? copterModes : planeModes); // default to planeModes if unknown to keep previous behavior with Q modes

    return map[customMode] ?? 'UNKNOWN MODE ($customMode)';
  }

  String _getSystemType(int type) {
    switch (type) {
      case 0:
        return 'Generic';
      case 1:
        return 'Fixed Wing';
      case 2:
        return 'Quadrotor';
      case 3:
        return 'Coaxial helicopter';
      case 4:
        return 'Helicopter';
      case 5:
        return 'Antenna Tracker';
      case 6:
        return 'GCS';
      case 7:
        return 'Airship';
      case 8:
        return 'Free Balloon';
      case 9:
        return 'Rocket';
      case 10:
        return 'Ground Rover';
      case 11:
        return 'Surface Boat';
      case 12:
        return 'Submarine';
      case 13:
        return 'Hexarotor';
      case 14:
        return 'Octorotor';
      case 15:
        return 'Tricopter';
      case 19:
        return 'VTOL';
      default:
        return 'Unknown ($type)';
    }
  }

  String _getAutopilotType(int type) {
    switch (type) {
      case 0:
        return 'Generic';
      case 3:
        return 'ArduPilot';
      case 4:
        return 'PX4';
      default:
        return 'Unknown ($type)';
    }
  }

  String _getSystemStatus(int status) {
    switch (status) {
      case 0:
        return 'Uninit';
      case 1:
        return 'Boot';
      case 2:
        return 'Calibrating';
      case 3:
        return 'Standby';
      case 4:
        return 'Active';
      case 5:
        return 'Critical';
      case 6:
        return 'Emergency';
      case 7:
        return 'Poweroff';
      case 8:
        return 'Flight Termination';
      default:
        return 'Unknown ($status)';
    }
  }
}
