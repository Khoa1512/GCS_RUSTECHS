import 'dart:math';
import 'package:dart_mavlink/dialects/common.dart';
import '../events.dart';

class AttitudeHandler {
  final void Function(MAVLinkEvent) emit;
  AttitudeHandler(this.emit);

  void handle(Attitude msg) {
    final roll = msg.roll * 180 / pi;
    final pitch = msg.pitch * 180 / pi;
    final yaw = msg.yaw * 180 / pi;
    emit(MAVLinkEvent(MAVLinkEventType.attitude, {
      'roll': roll,
      'pitch': pitch,
      'yaw': yaw,
      'rollSpeed': msg.rollspeed * 180 / pi,
      'pitchSpeed': msg.pitchspeed * 180 / pi,
      'yawSpeed': msg.yawspeed * 180 / pi,
    }));
  }
}
