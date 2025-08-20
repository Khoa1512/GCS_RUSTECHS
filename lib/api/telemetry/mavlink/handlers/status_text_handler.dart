import 'dart:convert';
import 'package:dart_mavlink/dialects/common.dart';
import '../events.dart';

class StatusTextHandler {
  final void Function(MAVLinkEvent) emit;
  StatusTextHandler(this.emit);

  void handle(Statustext msg) {
    // MAVLink STATUSTEXT is a fixed-size C-string (null-terminated) and may contain
    // negative bytes (e.g., -1) due to signed representation. Sanitize before decoding.
    final List<int> bytes = [];
    for (final b in msg.text) {
      final u = b & 0xFF; // ensure unsigned 0..255
      if (u == 0) break; // stop at first NUL terminator
      bytes.add(u);
    }
    // Try UTF-8 first, then fall back to Latin-1 to be safe
    String text;
    try {
      text = utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      text = latin1.decode(bytes, allowInvalid: true);
    }
    // Strip non-printable control characters
    text = text.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '').trim();

    emit(MAVLinkEvent(MAVLinkEventType.statusText, {
      'severity': _getStatusSeverity(msg.severity),
      'text': text,
    }));
  }

  String _getStatusSeverity(int severity) {
    switch (severity) {
      case 0:
        return 'Emergency';
      case 1:
        return 'Alert';
      case 2:
        return 'Critical';
      case 3:
        return 'Error';
      case 4:
        return 'Warning';
      case 5:
        return 'Notice';
      case 6:
        return 'Info';
      case 7:
        return 'Debug';
      default:
        return 'Unknown ($severity)';
    }
  }
}
