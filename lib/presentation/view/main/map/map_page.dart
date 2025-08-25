import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:skylink/core/constant/map_type.dart';
import 'package:skylink/data/models/route_point_model.dart';
import 'package:skylink/presentation/widget/map/main_map.dart';
import 'package:skylink/presentation/widget/map/section/route_point_table.dart';
import 'package:skylink/services/telemetry_service.dart';
import 'package:skylink/services/mission_service.dart';
import 'package:skylink/api/telemetry/mavlink/mission/mission_models.dart';
import 'package:skylink/api/telemetry/mavlink/events.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  MapType? selectedMapType;
  List<RoutePoint> routePoints = [];
  final MapController mapController = MapController();
  StreamSubscription? _mavSub;
  StreamSubscription? _telemetrySub; // Subscription cho GPS data
  LatLng? homePoint; // Home point từ GPS đầu tiên
  bool hasSetHomePoint = false; // Flag để chỉ set home point một lần
  bool _isReadingMission = false; // Flag để track việc đang read mission

  @override
  void initState() {
    super.initState();
    selectedMapType = mapTypes.first;
    _setupMavlinkListener();
    _setupGpsListener();
    _setupConnectionListener();
  }

  void _setupConnectionListener() {
    // Listen cho connection state changes
    TelemetryService().connectionStream.listen((isConnected) {
      if (!isConnected) {
        // Reset home point khi mất kết nối
        setState(() {
          homePoint = null;
          hasSetHomePoint = false;
        });
      }
    });
  }

  void _setupGpsListener() {
    // Listen để nhận GPS đầu tiên làm home point
    _telemetrySub = TelemetryService().telemetryStream.listen(
      _onTelemetryUpdate,
    );
  }

  void _onTelemetryUpdate(Map<String, double> telemetry) {
    // Kiểm tra trạng thái GPS hiện tại
    final hasValidGps = TelemetryService().hasValidGpsFix;
    final isConnected = TelemetryService().isConnected;

    if (!hasValidGps || !isConnected) {
      // Reset home point khi GPS mất hoặc mất kết nối
      if (homePoint != null) {
        setState(() {
          homePoint = null;
          hasSetHomePoint = false;
        });
      }
      return;
    }

    // Set home point khi có GPS valid
    if (!hasSetHomePoint && hasValidGps) {
      final lat = TelemetryService().gpsLatitude;
      final lng = TelemetryService().gpsLongitude;
      if (lat != 0.0 && lng != 0.0) {
        setState(() {
          homePoint = LatLng(lat, lng);
          hasSetHomePoint = true;
        });
      }
    }
  }

  void _setupMavlinkListener() {
    // Setup listener for mission download events - chỉ khi user bấm Read Mission
    _mavSub?.cancel();
    _mavSub = TelemetryService().mavlinkAPI.eventStream.listen((event) {
      switch (event.type) {
        case MAVLinkEventType.missionDownloadComplete:
          // Chỉ xử lý nếu đang trong quá trình read mission từ map page
          if (_isReadingMission) {
            final missionItems = event.data as List<PlanMissionItem>;
            _convertMissionToRoutePoints(missionItems);
            _isReadingMission = false;
            _hideProgress();
          }
          break;
        default:
          break;
      }
    });
  }

  void _convertMissionToRoutePoints(List<PlanMissionItem> missionItems) {
    final newRoutePoints = <RoutePoint>[];

    for (int i = 0; i < missionItems.length; i++) {
      final item = missionItems[i];

      // Skip home position (sequence 0) and non-global items
      if (item.seq == 0 || !_isGlobalCoordinate(item.x, item.y)) continue;

      newRoutePoints.add(
        RoutePoint(
          id: DateTime.now().millisecondsSinceEpoch.toString() + '_$i',
          order: newRoutePoints.length + 1,
          latitude: item.x.toString(),
          longitude: item.y.toString(),
          altitude: item.z.toString(),
          command: item.command,
        ),
      );
    }

    setState(() {
      routePoints = newRoutePoints;
    });

    // Cập nhật MissionService để hiển thị waypoint markers ngay lập tức
    MissionService().updateMission(newRoutePoints);

    _showSuccess('Mission downloaded: ${newRoutePoints.length} waypoints');
  }

  bool _isGlobalCoordinate(double lat, double lon) {
    return lat.abs() <= 90 && lon.abs() <= 180 && (lat != 0.0 || lon != 0.0);
  }

  void handleReadMission() {
    if (!TelemetryService().mavlinkAPI.isConnected) {
      _showError('Please connect to Flight Controller first');
      return;
    }

    // Set flag để chỉ map page xử lý response
    _isReadingMission = true;
    
    // Request mission list from Flight Controller
    TelemetryService().mavlinkAPI.requestMissionList();

    _showProgress('Reading mission from Flight Controller...');
  }

  void _hideProgress() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
  }

  void _showProgress(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(width: 16),
            Text(message),
          ],
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 16),
            Text(message),
          ],
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  String _getMavlinkErrorMessage(int errorCode) {
    switch (errorCode) {
      case 1:
        return 'Error: Mission item exceeds storage space';
      case 2:
        return 'Error: Mission accepted only partially';
      case 3:
        return 'Error: Mission operation not supported';
      case 4:
        return 'Error: Mission error - coordinates out of range';
      case 5:
        return 'Error: Mission item invalid';
      case 10:
        return 'Error: Mission item sequence invalid';
      case 11:
        return 'Error: Mission item not within valid range';
      case 12:
        return 'Error: Mission item count invalid';
      case 13:
        return 'Error: Mission operation currently denied';
      case 14:
        return 'Error: Mission operation already in progress';
      case 15:
        return 'Error: Mission system is not ready';
      case 30:
        return 'Warning: Mission item parameter out of range (but accepted)';
      case 128:
        return 'Error: Mission invalid';
      case 129:
        return 'Error: Mission type not supported';
      case 130:
        return 'Error: Mission vehicle not ready';
      case 131:
        return 'Error: Mission waypoint out of bounds';
      case 132:
        return 'Error: Mission waypoint count exceeded';
      default:
        return 'Warning code $errorCode';
    }
  }

  // Chỉ các error code nghiêm trọng mới coi là lỗi thật
  bool _isActualError(int errorCode) {
    switch (errorCode) {
      case 1: // Mission item exceeds storage space
      case 3: // Mission operation not supported
      case 4: // Mission error - coordinates out of range
      case 5: // Mission item invalid
      case 12: // Mission item count invalid
      case 13: // Mission operation currently denied
      case 15: // Mission system is not ready
      case 128: // Mission invalid
      case 129: // Mission type not supported
      case 130: // Mission vehicle not ready
      case 131: // Mission waypoint out of bounds
      case 132: // Mission waypoint count exceeded
        return true;
      default:
        // Tất cả các code khác (bao gồm 0, 30, v.v.) đều coi là OK
        return false;
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 16),
            Text(message),
          ],
        ),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> handleSendConfigs(List<RoutePoint> points) async {
    if (!TelemetryService().mavlinkAPI.isConnected) {
      _showError('Please connect to Flight Controller first');
      return;
    }

    if (points.isEmpty) {
      _showError('No waypoints to send');
      return;
    }

    try {
      // Create mission items list starting with home position
      final missionItems = <PlanMissionItem>[
        // Home position (sequence 0)
        PlanMissionItem(
          seq: 0,
          current: 1, // Mark as current
          frame: 0, // MAV_FRAME_GLOBAL
          command: 16, // MAV_CMD_NAV_WAYPOINT
          param1: 0, // Hold time
          param2: 0, // Acceptance radius
          param3: 0, // Pass radius
          param4: 0, // Yaw
          x: double.parse(points.first.latitude),
          y: double.parse(points.first.longitude),
          z: double.parse(points.first.altitude),
          autocontinue: 1,
        ),
      ];

      // Add remaining waypoints
      for (var i = 0; i < points.length; i++) {
        final point = points[i];
        missionItems.add(
          PlanMissionItem(
            seq: i + 1, // Start from 1
            current: 0, // Not current
            frame: 3, // MAV_FRAME_GLOBAL_RELATIVE_ALT
            command: point.command,
            param1: 0, // Hold time
            param2: 0, // Acceptance radius
            param3: 0, // Pass radius
            param4: 0, // Yaw
            x: double.parse(point.latitude),
            y: double.parse(point.longitude),
            z: double.parse(point.altitude),
            autocontinue: 1,
          ),
        );
      }

      // Set up event listeners first
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

            _showSuccess('Mission plan uploaded successfully');
            MissionService().updateMission(points);
            sub?.cancel();
            if (!completer.isCompleted) completer.complete();
            break;

          case MAVLinkEventType.missionAck:
            if (!clearAckReceived) break;

            final errorCode = event.data as int;
            print('Mission ACK received with error code: $errorCode');

            if (_isActualError(errorCode)) {
              // Chỉ các lỗi nghiêm trọng mới báo failed
              final errorMessage = _getMavlinkErrorMessage(errorCode);
              _showError('Mission failed: $errorMessage');
              sub?.cancel();
              if (!completer.isCompleted) completer.completeError(errorMessage);
            } else {
              // Tất cả trường hợp khác đều coi là thành công
              _showSuccess('Mission plan accepted by Flight Controller');
              MissionService().updateMission(points);
              sub?.cancel();
              if (!completer.isCompleted) completer.complete();
            }
            break;

          default: // Ignore all other event types
            break;
        }
      });

      // Clear existing mission
      TelemetryService().mavlinkAPI.clearMission();

      // Wait for completion or timeout
      try {
        await completer.future.timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            sub?.cancel();
            throw 'Mission upload timed out';
          },
        );
      } catch (e) {
        _showError(e.toString());
      }
    } catch (e) {
      _showError('Error preparing mission: $e');
    }
  }

  void handleMapTypeChange(MapType mapType) {
    setState(() {
      selectedMapType = mapType;
    });
  }

  void handleClearRoutePoints() {
    setState(() {
      routePoints = [];
    });
    // Clear mission in service so it's not shown in mini map
    MissionService().clearMission();
  }

  void addRoutePoint(LatLng latLng) {
    setState(() {
      routePoints.add(
        RoutePoint(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          order: routePoints.length + 1,
          latitude: latLng.latitude.toString(),
          longitude: latLng.longitude.toString(),
          altitude: "100", // Default to 100m
          command: 16, // Default to MAV_CMD_NAV_WAYPOINT
        ),
      );
    });
  }

  void handleSearchLocation(LatLng location) {
    setState(() {
      // Optional: Add a marker or jump
    });
    // Notify map
    mapController.move(location, 16); // or use widget method
    // Add route point
    addRoutePoint(location);
  }

  void handleEditPoint(RoutePoint point, int command, String altitude) {
    setState(() {
      final index = routePoints.indexWhere((p) => p.id == point.id);
      if (index != -1) {
        routePoints[index] = RoutePoint(
          id: point.id,
          order: point.order,
          latitude: point.latitude,
          longitude: point.longitude,
          altitude: altitude,
          command: command,
        );
      }
    });
  }

  @override
  void dispose() {
    _mavSub?.cancel();
    _telemetrySub?.cancel(); // Cancel GPS subscription
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Map chiếm full màn hình
        MainMap(
          mapController: mapController,
          mapType: selectedMapType!,
          routePoints: routePoints,
          onTap: addRoutePoint,
          isConfigValid: true,
          homePoint:
              homePoint, // Truyền home point để hiển thị marker H và zoom
        ),
        // Mission planning panel overlay ở góc phải
        Positioned(
          top: 16,
          right: 16,
          bottom: 16,
          child: Container(
            width: 600, // Độ rộng cố định cho panel
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: RoutePointTable(
              routePoints: routePoints,
              onClearTap: handleClearRoutePoints,
              onSearchLocation: handleSearchLocation,
              onSendConfigs: handleSendConfigs,
              onEditPoint: handleEditPoint,
              onReadMission: handleReadMission,
            ),
          ),
        ),
      ],
    );
  }
}
