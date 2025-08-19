import 'package:dart_mavlink/dialects/common.dart';

import '../events.dart';

/// Handles incoming CommandAck messages and emits a unified event
class CommandAckHandler {
  final void Function(MAVLinkEvent) emit;
  CommandAckHandler(this.emit);

  void handle(CommandAck msg) {
    emit(MAVLinkEvent(MAVLinkEventType.commandAck, msg));
  }
}
