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
    final newMode = _decodeFlightMode(msg.baseMode, msg.customMode);
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

  String _decodeFlightMode(int baseMode, int customMode) {
    const List<String> arduPilotModes = [
      'MANUAL',
      'CIRCLE',
      'STABILIZE',
      'TRAINING',
      'ACRO',
      'FBWA',
      'FBWB',
      'CRUISE',
      'AUTOTUNE',
      'AUTO',
      'RTL',
      'LOITER',
      'TAKEOFF',
      'AVOID_ADSB',
      'GUIDED',
      'INITIALIZING',
      'QSTABILIZE',
      'QLAND',
      'QHOVER',
      'QLOITER',
      'QAUTOTUNE',
      'QRTL',
      'QACRO',
    ];
    if (customMode >= 0 && customMode < arduPilotModes.length) {
      return arduPilotModes[customMode];
    }
    return 'UNKNOWN MODE ($customMode)';
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
