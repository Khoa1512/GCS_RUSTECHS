import 'package:dart_mavlink/dialects/common.dart';
import '../events.dart';

class VfrHudHandler {
  final void Function(MAVLinkEvent) emit;
  VfrHudHandler(this.emit);

  void handle(VfrHud msg) {
    // Debug: Log raw VFR_HUD heading data to understand format
    // if (kDebugMode) {
    //   print('VFR_HUD Handler - Raw heading: ${msg.heading} (type: ${msg.heading.runtimeType})');
    //   print('VFR_HUD Handler - Raw data: airspeed=${msg.airspeed}, groundspeed=${msg.groundspeed}, heading=${msg.heading}, throttle=${msg.throttle}, alt=${msg.alt}, climb=${msg.climb}');
    // }

    emit(
      MAVLinkEvent(MAVLinkEventType.vfrHud, {
        'airspeed': msg.airspeed,
        'groundspeed': msg.groundspeed,
        'heading': msg.heading,
        'throttle': msg.throttle,
        'alt': msg.alt,
        'climb': msg.climb,
      }),
    );
  }
}
