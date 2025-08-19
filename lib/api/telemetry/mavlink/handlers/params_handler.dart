import 'package:dart_mavlink/dialects/common.dart';
import '../events.dart';

class ParamsHandler {
  final void Function(MAVLinkEvent) emit;
  final Map<String, double>? store;

  ParamsHandler(this.emit, [this.store]);

  void handle(ParamValue msg) {
    String id;
    final idx = msg.paramId.indexOf(0);
    if (idx >= 0) {
      id = String.fromCharCodes(msg.paramId.sublist(0, idx));
    } else {
      id = String.fromCharCodes(msg.paramId);
    }

    // update local store if provided
    if (store != null) {
      store![id] = msg.paramValue;
    }

    emit(MAVLinkEvent(MAVLinkEventType.parameterReceived, {
      'id': id,
      'value': msg.paramValue,
      'type': msg.paramType,
      'index': msg.paramIndex,
      'count': msg.paramCount,
    }));

    if (msg.paramCount > 0 && msg.paramIndex == msg.paramCount - 1) {
      emit(MAVLinkEvent(MAVLinkEventType.allParametersReceived, store ?? {}));
    }
  }
}
