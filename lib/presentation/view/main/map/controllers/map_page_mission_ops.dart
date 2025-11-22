import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:skylink/data/models/route_point_model.dart';
import 'package:skylink/presentation/view/main/map/controllers/map_page_state.dart';
import 'package:skylink/services/telemetry_service.dart';
import 'package:skylink/services/mission_service.dart';
import 'package:skylink/api/telemetry/mavlink/mission/mission_models.dart';
import 'package:skylink/api/telemetry/mavlink/events.dart';

mixin MapPageMissionOps<T extends StatefulWidget> on State<T> {
  MapPageState get state;
  void Function(void Function()) get updateState;

  void showSuccess(String message);
  void showError(String message);
  void showProgress(String message);
  void hideProgress();
  String getMavlinkErrorMessage(int errorCode);
  bool isActualError(int errorCode);
  void calculateMissionStats();

  // ============================================================================
  // SETUP & LISTENERS
  // ============================================================================

  void setupMavlinkListener() {
    state.mavSub?.cancel();
    state.mavSub = TelemetryService().mavlinkAPI.eventStream.listen((event) {
      switch (event.type) {
        case MAVLinkEventType.missionDownloadComplete:
          if (state.isReadingMission) {
            final missionItems = event.data as List<PlanMissionItem>;
            convertMissionToRoutePoints(missionItems);
            state.isReadingMission = false;
            hideProgress();
          }
          break;
        default:
          break;
      }
    });
  }

  void setupGpsListener() {
    state.telemetrySub = TelemetryService().telemetryStream.listen(
      onTelemetryUpdate,
    );
  }

  void setupConnectionListener() {
    TelemetryService().connectionStream.listen((isConnected) {
      if (!isConnected) {
        updateState(() {
          state.homePoint = null;
          state.hasSetHomePoint = false;
        });
      }
    });
  }

  void onTelemetryUpdate(Map<String, double> telemetry) {
    final hasValidGps = TelemetryService().hasValidGpsFix;
    final isConnected = TelemetryService().isConnected;

    if (!hasValidGps || !isConnected) {
      if (state.homePoint != null) {
        updateState(() {
          state.homePoint = null;
          state.hasSetHomePoint = false;
        });
      }
      return;
    }

    if (!state.hasSetHomePoint && hasValidGps) {
      final lat = TelemetryService().gpsLatitude;
      final lng = TelemetryService().gpsLongitude;
      if (lat != 0.0 && lng != 0.0) {
        updateState(() {
          state.homePoint = LatLng(lat, lng);
          state.hasSetHomePoint = true;
        });
      }
    }
  }

  // ============================================================================
  // MISSION DOWNLOAD (READ FROM DRONE)
  // ============================================================================

  void handleReadMission() {
    if (!TelemetryService().mavlinkAPI.isConnected) {
      showError('Vui lòng kết nối với Flight Controller');
      return;
    }

    state.isReadingMission = true;
    TelemetryService().mavlinkAPI.requestMissionList();
    showProgress('Đang đọc kế hoạch bay từ Flight Controller...');
  }

  void convertMissionToRoutePoints(List<PlanMissionItem> missionItems) {
    final newRoutePoints = <RoutePoint>[];

    for (int i = 0; i < missionItems.length; i++) {
      final item = missionItems[i];

      if (item.seq == 0 || !isGlobalCoordinate(item.x, item.y)) continue;

      Map<String, dynamic>? commandParams;
      if (item.param1 != 0 ||
          item.param2 != 0 ||
          item.param3 != 0 ||
          item.param4 != 0) {
        commandParams = {
          'param1': item.param1,
          'param2': item.param2,
          'param3': item.param3,
          'param4': item.param4,
        };
      }

      newRoutePoints.add(
        RoutePoint(
          id: '${DateTime.now().millisecondsSinceEpoch}_$i',
          order: newRoutePoints.length + 1,
          latitude: item.x.toString(),
          longitude: item.y.toString(),
          altitude: item.z.toString(),
          command: item.command,
          commandParams: commandParams,
        ),
      );
    }

    updateState(() {
      state.routePoints = newRoutePoints;
    });

    calculateMissionStats();
    showSuccess('Mission đã tải: ${newRoutePoints.length} waypoints');
  }

  bool isGlobalCoordinate(double lat, double lon) {
    return lat.abs() <= 90 && lon.abs() <= 180 && (lat != 0.0 || lon != 0.0);
  }

  // ============================================================================
  // MISSION UPLOAD (SEND TO DRONE)
  // ============================================================================

  Future<void> handleSendConfigs(List<RoutePoint> points) async {
    if (!TelemetryService().mavlinkAPI.isConnected) {
      showError('Vui lòng kết nối với Flight Controller');
      return;
    }

    if (points.isEmpty) {
      showError('Không có waypoint nào để gửi');
      return;
    }

    try {
      final missionItems = <PlanMissionItem>[
        PlanMissionItem(
          seq: 0,
          current: 1,
          frame: 0,
          command: 16,
          param1: 0,
          param2: 0,
          param3: 0,
          param4: 0,
          x: double.parse(points.first.latitude),
          y: double.parse(points.first.longitude),
          z: double.parse(points.first.altitude),
          autocontinue: 1,
        ),
      ];

      for (var i = 0; i < points.length; i++) {
        final point = points[i];
        final params = point.commandParams ?? {};
        missionItems.add(
          PlanMissionItem(
            seq: i + 1,
            current: 0,
            frame: 3,
            command: point.command,
            param1: (params['param1'] as num?)?.toDouble() ?? 0.0,
            param2: (params['param2'] as num?)?.toDouble() ?? 0.0,
            param3: (params['param3'] as num?)?.toDouble() ?? 0.0,
            param4: (params['param4'] as num?)?.toDouble() ?? 0.0,
            x: double.parse(point.latitude),
            y: double.parse(point.longitude),
            z: double.parse(point.altitude),
            autocontinue: 1,
          ),
        );
      }

      bool uploadStarted = false;
      StreamSubscription? sub;
      final completer = Completer<void>();
      bool clearAckReceived = false;

      sub = TelemetryService().mavlinkAPI.eventStream.listen((event) {
        switch (event.type) {
          case MAVLinkEventType.missionCleared:
            clearAckReceived = true;
            if (!uploadStarted) {
              uploadStarted = true;
              Future.delayed(const Duration(milliseconds: 500), () {
                TelemetryService().mavlinkAPI.startMissionUpload(missionItems);
              });
            }
            break;

          case MAVLinkEventType.missionUploadComplete:
            if (!clearAckReceived) break;
            showSuccess('Kế hoạch bay đã được tải lên thành công');
            MissionService().updateMission(points);
            sub?.cancel();
            if (!completer.isCompleted) completer.complete();
            break;

          case MAVLinkEventType.missionAck:
            if (!clearAckReceived) break;
            final errorCode = event.data as int;
            if (isActualError(errorCode)) {
              final errorMessage = getMavlinkErrorMessage(errorCode);
              showError('Tải kế hoạch bay thất bại: $errorMessage');
              sub?.cancel();
              if (!completer.isCompleted) completer.completeError(errorMessage);
            } else {
              showSuccess('Kế hoạch bay đã được gửi thành công');
              MissionService().updateMission(points);
              sub?.cancel();
              if (!completer.isCompleted) completer.complete();
            }
            break;

          default:
            break;
        }
      });

      TelemetryService().mavlinkAPI.clearMission();

      try {
        await completer.future.timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            sub?.cancel();
            throw 'Mission upload timed out';
          },
        );
      } catch (e) {
        showError(e.toString());
      }
    } catch (e) {
      showError('Error preparing mission: $e');
    }
  }
}
