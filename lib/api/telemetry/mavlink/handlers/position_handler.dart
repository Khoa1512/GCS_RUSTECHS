import 'dart:math';
import 'package:dart_mavlink/dialects/common.dart';
// import 'package:flutter/foundation.dart';
import '../events.dart';

class PositionHandler {
  final void Function(MAVLinkEvent) emit;
  PositionHandler(this.emit);

  // Debug tracking (commented out)
  // static DateTime? _lastPositionTime;
  // static int _positionMessageCount = 0;

  void handle(GlobalPositionInt msg) {
    // Debug: Track position message frequency
    // if (kDebugMode) {
    //   DateTime now = DateTime.now();
    //   _positionMessageCount++;
    //
    //   if (_lastPositionTime != null) {
    //     int intervalMs = now.difference(_lastPositionTime!).inMilliseconds;
    //     if (_positionMessageCount % 20 == 0) { // Log every 20 messages
    //       double frequency = 1000.0 / intervalMs;
    //       print('GLOBAL_POSITION_INT frequency: ${frequency.toStringAsFixed(1)}Hz (interval: ${intervalMs}ms)');
    //     }
    //   }
    //   _lastPositionTime = now;
    // }

    final altMSL = msg.alt / 1000.0;
    final altRelative = msg.relativeAlt / 1000.0;
    final vx = msg.vx / 100.0;
    final vy = msg.vy / 100.0;
    final groundSpeed = sqrt(vx * vx + vy * vy);
    emit(
      MAVLinkEvent(MAVLinkEventType.position, {
        'lat': msg.lat / 1e7,
        'lon': msg.lon / 1e7,
        'altMSL': altMSL,
        'altRelative': altRelative,
        'vx': vx,
        'vy': vy,
        'vz': msg.vz / 100.0,
        'heading': msg.hdg / 100.0,
        'groundSpeed': groundSpeed,
      }),
    );
  }
}
