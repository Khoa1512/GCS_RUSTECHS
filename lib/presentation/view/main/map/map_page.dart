import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:skylink/core/constant/map_type.dart';
import 'package:skylink/data/models/route_point_model.dart';
import 'package:skylink/data/models/mission_plan_model.dart';
import 'package:skylink/presentation/widget/map/main_map.dart';
import 'package:skylink/presentation/widget/map/section/route_point_table.dart';
import 'package:skylink/presentation/widget/map/section/plan_manager_widget.dart';
import 'package:skylink/presentation/widget/map/section/plan_details_widget.dart';
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

  // Mission Plans state
  List<UserMissionPlan> savedPlans = [];
  UserMissionPlan? selectedPlan;
  bool isCreatingNewPlan = false;

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

      // Build commandParams from PlanMissionItem parameters
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

    // Clear mission on Flight Controller if connected
    if (TelemetryService().mavlinkAPI.isConnected) {
      TelemetryService().mavlinkAPI.clearMission();
      _showSuccess('Mission cleared from Flight Controller');
    }
  }

  // Handle waypoint drag - update coordinates
  void _onWaypointDrag(int index, LatLng newPosition) {
    if (index >= 0 && index < routePoints.length) {
      setState(() {
        routePoints[index] = routePoints[index].copyWith(
          latitude: newPosition.latitude.toString(),
          longitude: newPosition.longitude.toString(),
        );
      });
    }
  }

  // Empty function để disable map tap khi không ở chế độ edit
  void _doNothing(LatLng latLng) {
    // Do nothing - chỉ xem, không thêm waypoint
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
    mapController.move(location, 18); // or use widget method
    // Add route point
    addRoutePoint(location);
  }

  void handleEditPoint(
    RoutePoint point,
    int command,
    String altitude, [
    Map<String, double>? params,
  ]) {
    setState(() {
      final index = routePoints.indexWhere((p) => p.id == point.id);
      if (index != -1) {
        // Convert params to commandParams format (param1, param2, param3, param4)
        Map<String, dynamic>? commandParams;
        if (params != null && params.isNotEmpty) {
          commandParams = {};
          for (final entry in params.entries) {
            commandParams[entry.key] = entry.value;
          }
        }

        routePoints[index] = RoutePoint(
          id: point.id,
          order: point.order,
          latitude: point.latitude,
          longitude: point.longitude,
          altitude: altitude,
          command: command,
          commandParams: commandParams ?? point.commandParams,
        );
      }
    });
  }

  void handleDeletePoint(RoutePoint point) {
    setState(() {
      routePoints.removeWhere((p) => p.id == point.id);

      // Update order sequence for remaining points
      for (int i = 0; i < routePoints.length; i++) {
        routePoints[i] = routePoints[i].copyWith(order: i + 1);
      }
    });

    // Show confirmation message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Waypoint ${point.order} deleted'),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // Mission Plan Handlers
  void handleCreateNewPlan() {
    // Show dialog first, don't change state yet
    _showCreatePlanDialog();
  }

  void _showCreatePlanDialog() {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2D2D2D),
          title: const Text(
            'Create New Mission Plan',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Plan Title',
                  labelStyle: TextStyle(color: Colors.grey),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.teal),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                style: const TextStyle(color: Colors.white),
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  labelStyle: TextStyle(color: Colors.grey),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.teal),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                if (titleController.text.trim().isNotEmpty) {
                  Navigator.of(context).pop();
                  // Start creating plan - show Route Point Table
                  _startCreatingPlan(
                    titleController.text.trim(),
                    descriptionController.text.trim(),
                  );
                }
              },
              child: const Text('Create', style: TextStyle(color: Colors.teal)),
            ),
          ],
        );
      },
    );
  }

  void _startCreatingPlan(String title, String description) {
    // Tạo plan ngay lập tức khi bấm Create trong dialog
    final newPlan = UserMissionPlan(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      description: description,
      waypoints: [], // Bắt đầu với waypoints rỗng
      createdAt: DateTime.now(),
    );

    print('_startCreatingPlan called - creating plan: ${newPlan.title}');

    setState(() {
      // Thêm plan vào list ngay lập tức
      savedPlans.add(newPlan);
      selectedPlan = newPlan;
      isCreatingNewPlan = true; // Vẫn giữ flag này để hiện RoutePointTable
      routePoints.clear();
    });

    print(
      '_startCreatingPlan completed - selectedPlan: ${selectedPlan?.title}, isCreatingNewPlan: $isCreatingNewPlan',
    );
  }

  void handleCreatePlan(String title, String description) {
    // Debug
    print(
      'handleCreatePlan called - selectedPlan: ${selectedPlan?.title}, isCreatingNewPlan: $isCreatingNewPlan',
    );

    // Update plan đã tồn tại với waypoints (có thể rỗng)
    if (selectedPlan == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No plan selected to save'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Tìm và update plan trong list
    final planIndex = savedPlans.indexWhere((p) => p.id == selectedPlan!.id);
    if (planIndex != -1) {
      final updatedPlan = UserMissionPlan(
        id: selectedPlan!.id,
        title: selectedPlan!.title,
        description: selectedPlan!.description,
        waypoints: List.from(routePoints), // Có thể rỗng, không sao
        createdAt: selectedPlan!.createdAt,
      );

      setState(() {
        savedPlans[planIndex] = updatedPlan;
        selectedPlan = updatedPlan;
        isCreatingNewPlan = false;
      });

      final waypointCount = routePoints.length;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Plan "${selectedPlan!.title}" saved with $waypointCount waypoint${waypointCount != 1 ? 's' : ''}',
          ),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void handleSelectPlan(UserMissionPlan plan) {
    setState(() {
      selectedPlan = plan;
      isCreatingNewPlan = false; // Chỉ view, không edit
      routePoints = List.from(plan.waypoints);
    });

    // Zoom to mission area với zoom level phù hợp
    if (plan.waypoints.isNotEmpty) {
      final bounds = plan.missionBounds;
      if (bounds != null) {
        final center = LatLng(
          (bounds['north']! + bounds['south']!) / 2,
          (bounds['east']! + bounds['west']!) / 2,
        );

        // Tính toán zoom level phù hợp dựa trên kích thước mission area
        final latDiff = bounds['north']! - bounds['south']!;
        final lngDiff = bounds['east']! - bounds['west']!;
        final maxDiff = latDiff > lngDiff ? latDiff : lngDiff;

        double zoomLevel = 18; // Default zoom - tăng từ 16 lên 18
        if (maxDiff > 0.01) {
          zoomLevel = 15; // tăng từ 13 lên 15
        } else if (maxDiff > 0.005)
          zoomLevel = 16; // tăng từ 14 lên 16
        else if (maxDiff > 0.002)
          zoomLevel = 17; // tăng từ 15 lên 17
        else if (maxDiff > 0.001)
          zoomLevel = 18; // tăng từ 16 lên 18
        else
          zoomLevel = 19; // tăng từ 17 lên 19

        mapController.move(center, zoomLevel);
      }
    }
  }

  void handleEditPlan(UserMissionPlan plan) {
    setState(() {
      selectedPlan = plan;
      isCreatingNewPlan = true; // Hiển thị route point table để edit
      routePoints = List.from(plan.waypoints);
    });

    // Zoom to mission area với zoom level phù hợp
    if (plan.waypoints.isNotEmpty) {
      final bounds = plan.missionBounds;
      if (bounds != null) {
        final center = LatLng(
          (bounds['north']! + bounds['south']!) / 2,
          (bounds['east']! + bounds['west']!) / 2,
        );

        // Tính toán zoom level phù hợp dựa trên kích thước mission area
        final latDiff = bounds['north']! - bounds['south']!;
        final lngDiff = bounds['east']! - bounds['west']!;
        final maxDiff = latDiff > lngDiff ? latDiff : lngDiff;

        double zoomLevel = 18; // Default zoom - tăng từ 16 lên 18
        if (maxDiff > 0.01) {
          zoomLevel = 15; // tăng từ 13 lên 15
        } else if (maxDiff > 0.005)
          zoomLevel = 16; // tăng từ 14 lên 16
        else if (maxDiff > 0.002)
          zoomLevel = 17; // tăng từ 15 lên 17
        else if (maxDiff > 0.001)
          zoomLevel = 18; // tăng từ 16 lên 18
        else
          zoomLevel = 19; // tăng từ 17 lên 19

        mapController.move(center, zoomLevel);
      }
    }
  }

  void handleDeletePlan(UserMissionPlan plan) {
    setState(() {
      savedPlans.removeWhere((p) => p.id == plan.id);
      if (selectedPlan?.id == plan.id) {
        selectedPlan = null;
        routePoints.clear();
        isCreatingNewPlan =
            false; // Ẩn route point table khi xóa plan đang select
      }

      // Nếu không còn plan nào và không đang tạo mới, clear state
      if (savedPlans.isEmpty && !isCreatingNewPlan) {
        selectedPlan = null;
        routePoints.clear();
        isCreatingNewPlan = false;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Plan "${plan.title}" deleted'),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  void dispose() {
    _mavSub?.cancel();
    _telemetrySub?.cancel(); // Cancel GPS subscription
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Cột trái chiếm 75% width - chứa map và mission plan
        Expanded(
          flex: 75,
          child: Column(
            children: [
              // Map - chiếm full khi không tạo plan, chiếm 6/10 khi tạo plan
              Expanded(
                flex: isCreatingNewPlan ? 6 : 10,
                child: MainMapSimple(
                  mapController: mapController,
                  mapType: selectedMapType!,
                  routePoints: routePoints,
                  onTap: isCreatingNewPlan ? addRoutePoint : _doNothing,
                  onWaypointDrag: isCreatingNewPlan ? _onWaypointDrag : null,
                  isConfigValid: true,
                  homePoint: homePoint,
                ),
              ),

              // Route Point Table - chỉ hiện khi đang tạo plan
              if (isCreatingNewPlan) ...[
                Expanded(
                  flex: 4,
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, -4),
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
                      onDeletePoint: handleDeletePoint,
                      onSavePlan: isCreatingNewPlan
                          ? () => handleCreatePlan('', '')
                          : null,
                      isCreatingNewPlan: isCreatingNewPlan,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        // Cột phải chiếm 25% width - chia thành 2 phần
        Expanded(
          flex: 25,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              border: Border(
                left: BorderSide(color: Colors.grey.shade800, width: 1),
              ),
            ),
            child: Column(
              children: [
                // Phần trên: Plan Manager (12.5%)
                Expanded(
                  flex: 5,
                  child: PlanManagerWidget(
                    plans: savedPlans,
                    selectedPlan: selectedPlan,
                    onCreatePlan: handleCreatePlan,
                    onSelectPlan: handleSelectPlan,
                    onEditPlan: handleEditPlan,
                    onDeletePlan: handleDeletePlan,
                    onCreateNewPlan: handleCreateNewPlan,
                  ),
                ),

                // Phần dưới: Plan Details (12.5%)
                Expanded(flex: 5, child: PlanDetailsWidget(plan: selectedPlan)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
