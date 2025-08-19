import 'package:dart_mavlink/dialects/common.dart';

import '../events.dart';

/// Handles incoming SysStatus messages and emits a unified event
class SysStatusHandler {
  final void Function(MAVLinkEvent) emit;
  SysStatusHandler(this.emit);

  void handle(SysStatus msg) {
    emit(MAVLinkEvent(MAVLinkEventType.sysStatus, msg));
  }
}
