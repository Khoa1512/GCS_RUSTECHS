import 'package:dart_mavlink/dialects/common.dart';
import '../events.dart';

class StatusTextHandler {
  final void Function(MAVLinkEvent) emit;
  StatusTextHandler(this.emit);

  void handle(Statustext msg) {
    emit(MAVLinkEvent(MAVLinkEventType.statusText, {
      'severity': _getStatusSeverity(msg.severity),
      'text': String.fromCharCodes(msg.text.takeWhile((c) => c != 0).toList()),
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
