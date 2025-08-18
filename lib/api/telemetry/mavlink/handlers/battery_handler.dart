import 'package:dart_mavlink/dialects/common.dart';
import '../events.dart';

class BatteryHandler {
  final void Function(MAVLinkEvent) emit;
  BatteryHandler(this.emit);

  void handle(BatteryStatus msg) {
    emit(MAVLinkEvent(MAVLinkEventType.batteryStatus, {
      'batteryPercent': msg.batteryRemaining,
      'voltageBattery': msg.voltages.isNotEmpty ? (msg.voltages.first / 1000.0) : 0.0,
      'currentBattery': msg.currentBattery / 100.0,
      'temperature': msg.temperature / 100.0,
      'function': msg.batteryFunction,
      'type': msg.type,
    }));
  }
}
