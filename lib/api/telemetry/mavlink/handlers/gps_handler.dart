import 'package:dart_mavlink/dialects/common.dart';
// import 'package:flutter/foundation.dart';
import '../events.dart';

class GpsHandler {
  final void Function(MAVLinkEvent) emit;
  GpsHandler(this.emit);

  // Debug tracking (commented out)
  // static DateTime? _lastGpsTime;
  // static int _gpsMessageCount = 0;

  void handle(GpsRawInt msg) {
    // Debug: Track GPS message frequency
    // if (kDebugMode) {
    //   DateTime now = DateTime.now();
    //   _gpsMessageCount++;
    //
    //   if (_lastGpsTime != null) {
    //     int intervalMs = now.difference(_lastGpsTime!).inMilliseconds;
    //     if (_gpsMessageCount % 20 == 0) { // Log every 20 messages
    //       double frequency = 1000.0 / intervalMs;
    //       print('GPS_RAW_INT frequency: ${frequency.toStringAsFixed(1)}Hz (interval: ${intervalMs}ms)');
    //     }
    //   }
    //   _lastGpsTime = now;
    // }

    emit(
      MAVLinkEvent(MAVLinkEventType.gpsInfo, {
        'fixType': _getGpsFix(msg.fixType),
        'satellites': msg.satellitesVisible,
        'lat': msg.lat / 1e7,
        'lon': msg.lon / 1e7,
        'alt': msg.alt / 1000.0,
        'eph': msg.eph / 100.0,
        'epv': msg.epv / 100.0,
        'vel': msg.vel / 100.0,
        'cog': msg.cog / 100.0,
      }),
    );
  }

  String _getGpsFix(int fixType) {
    switch (fixType) {
      case 0:
        return 'No GPS';
      case 1:
        return 'No Fix';
      case 2:
        return '2D Fix';
      case 3:
        return '3D Fix';
      case 4:
        return 'DGPS';
      case 5:
        return 'RTK Float';
      case 6:
        return 'RTK Fixed';
      case 7:
        return 'Static';
      case 8:
        return 'PPP';
      default:
        return 'Unknown ($fixType)';
    }
  }
}
