import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:skylink/core/constant/map_type.dart';
import 'package:skylink/services/telemetry_service.dart';
import 'package:skylink/services/mission_service.dart';

class DroneMapWidget extends StatefulWidget {
  final double? droneLatitude;
  final double? droneLongitude;
  final double? droneAltitude;
  final double? droneHeading;

  const DroneMapWidget({
    super.key,
    this.droneLatitude,
    this.droneLongitude,
    this.droneAltitude,
    this.droneHeading,
  });

  @override
  State<DroneMapWidget> createState() => _DroneMapWidgetState();
}

class _DroneMapWidgetState extends State<DroneMapWidget>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _rotationController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rotationAnimation;
  late MapController _mapController;
  late MapType _selectedMapType;

  final TelemetryService _telemetryService = TelemetryService();
  final MissionService _missionService = MissionService();
  StreamSubscription? _telemetrySubscription;
  StreamSubscription? _connectionSubscription;
  StreamSubscription? _missionSubscription;
  double _currentYaw = 0.0;
  double _currentLatitude = 10.7302;
  double _currentLongitude = 106.6988;
  double _currentAltitude = 0.0;
  bool _hasZoomedToGPS = false;

  // Home point và tracking
  LatLng? _homePoint;
  LatLng? _lastDronePosition;
  bool _hasMovedFromStart = false;

  // GPS smoothing để giảm jitter - Mission Planner style
  List<LatLng> _gpsBuffer = [];
  static const int _gpsBufferSize = 5; // Tăng buffer size

  // Interpolation variables - như Mission Planner
  LatLng? _targetPosition;
  LatLng? _currentInterpolatedPosition;
  Timer? _interpolationTimer;
  late AnimationController _positionController;
  late Animation<double> _positionAnimation;

  // Adaptive smoothing
  double _currentSpeed = 0.0;
  DateTime _lastGpsUpdate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _setupControllers();
    _setupSubscriptions();
  }

  void _setupControllers() {
    _mapController = MapController();
    _selectedMapType = mapTypes.firstWhere(
      (mapType) => mapType.name == 'Satellite Map',
      orElse: () => mapTypes.first,
    );

    // Pulse animation
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);

    // Rotation animation - tối ưu
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 200), // Giảm xuống 200ms
      vsync: this,
    );
    _rotationAnimation =
        Tween<double>(begin: 0, end: _currentYaw * (math.pi / 180)).animate(
          CurvedAnimation(parent: _rotationController, curve: Curves.easeOut),
        );
    _rotationController.forward();

    // Position interpolation controller - Mission Planner style
    _positionController = AnimationController(
      duration: const Duration(milliseconds: 100), // Rất nhanh để smooth
      vsync: this,
    );
    _positionAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _positionController, curve: Curves.easeOut),
    );

    // Initialize interpolated position
    _currentInterpolatedPosition = LatLng(_currentLatitude, _currentLongitude);
  }

  void _setupSubscriptions() {
    _missionSubscription = _missionService.missionStream.listen((points) {
      if (points.isNotEmpty && _telemetryService.hasValidGpsFix) {
        // Khi có mission mới, set home point tại vị trí hiện tại của drone
        setState(() {
          _homePoint = LatLng(_currentLatitude, _currentLongitude);
          _lastDronePosition = LatLng(_currentLatitude, _currentLongitude);
          _hasMovedFromStart = false; // Reset movement tracking
        });
      } else {
        // Khi mission bị clear, xóa home point
        setState(() {
          _homePoint = null;
          _lastDronePosition = null;
          _hasMovedFromStart = false;
        });
      }

      setState(() {});
    });

    _telemetrySubscription = _telemetryService.telemetryStream.listen((data) {
      if (mounted) {
        bool needsRotationUpdate = false;

        if (data.containsKey('yaw')) {
          double newYaw = data['yaw'] ?? 0.0;
          // Tăng threshold để giảm animation yaw không cần thiết
          if ((_currentYaw - newYaw).abs() > 2.0) {
            _currentYaw = newYaw;
            needsRotationUpdate = true;
          }
        }

        if (_telemetryService.hasValidGpsFix) {
          double newLat = data['gps_latitude'] ?? _currentLatitude;
          double newLon = data['gps_longitude'] ?? _currentLongitude;
          double newAlt = data['gps_altitude'] ?? _currentAltitude;

          // Mission Planner style GPS processing
          _processMissionPlannerStyleGPS(newLat, newLon, newAlt);
        }

        if (needsRotationUpdate) {
          _updateRotationAnimation();
        }
      }
    });

    _connectionSubscription = _telemetryService.connectionStream.listen((
      isConnected,
    ) {
      // print('Connection status changed: $isConnected');
      if (mounted && !isConnected) {
        _resetToDefaultPosition();
      }
      setState(() {});
    });
  }

  void _updateRotationAnimation() {
    // Chỉ animate nếu controller không đang chạy để tránh xung đột
    if (!_rotationController.isAnimating) {
      _rotationAnimation =
          Tween<double>(
            begin: _rotationAnimation.value,
            end: _currentYaw * (math.pi / 180),
          ).animate(
            CurvedAnimation(parent: _rotationController, curve: Curves.easeOut),
          );

      _rotationController.reset();
      _rotationController.forward();
    }
  }

  void _updateMapPosition() {
    LatLng newPosition = LatLng(_currentLatitude, _currentLongitude);

    // Nếu chưa zoom về GPS và có GPS fix thì zoom về vị trí GPS
    if (!_hasZoomedToGPS && _telemetryService.hasValidGpsFix) {
      _mapController.move(newPosition, 16.0); // Zoom level 16 để thấy rõ drone
      _hasZoomedToGPS = true;
    } else {
      // Chỉ di chuyển mà không thay đổi zoom - sử dụng moveAndRotate cho smooth animation
      try {
        _mapController.moveAndRotate(
          newPosition,
          _mapController.camera.zoom,
          _mapController.camera.rotation,
        );
      } catch (e) {
        // Fallback nếu moveAndRotate không khả dụng
        _mapController.move(newPosition, _mapController.camera.zoom);
      }
    }
  }

  void _resetToDefaultPosition() {
    setState(() {
      if (!_telemetryService.isConnected) {
        _currentLatitude = widget.droneLatitude ?? 10.7302;
        _currentLongitude = widget.droneLongitude ?? 106.6988;
        _hasZoomedToGPS = false; // Reset zoom flag khi disconnect
        _gpsBuffer.clear(); // Clear GPS buffer khi disconnect
        _targetPosition = null;
        _currentInterpolatedPosition = LatLng(
          _currentLatitude,
          _currentLongitude,
        );
      }
      _currentAltitude = 0.0;
      _currentYaw = 0.0;
    });
    _updateMapPosition();
  }

  // Mission Planner Style GPS Processing
  void _processMissionPlannerStyleGPS(
    double newLat,
    double newLon,
    double newAlt,
  ) {
    DateTime now = DateTime.now();
    double deltaTime = now.difference(_lastGpsUpdate).inMilliseconds / 1000.0;
    _lastGpsUpdate = now;

    // Add to buffer với weight dựa trên GPS fix quality
    LatLng newPosition = LatLng(newLat, newLon);
    _gpsBuffer.add(newPosition);
    if (_gpsBuffer.length > _gpsBufferSize) {
      _gpsBuffer.removeAt(0);
    }

    // Adaptive smoothing dựa trên tốc độ di chuyển
    LatLng smoothedPosition = _adaptiveSmoothing();

    // Calculate speed cho adaptive processing
    if (_currentInterpolatedPosition != null) {
      double distance = _calculateRealDistance(
        _currentInterpolatedPosition!.latitude,
        _currentInterpolatedPosition!.longitude,
        smoothedPosition.latitude,
        smoothedPosition.longitude,
      );
      _currentSpeed = deltaTime > 0 ? distance / deltaTime : 0.0;
    }

    // Set target position cho interpolation
    _targetPosition = smoothedPosition;
    _currentAltitude = newAlt;

    // Start smooth interpolation animation như Mission Planner
    _startInterpolation();
  }

  // Adaptive smoothing như Mission Planner - mạnh khi đứng yên, nhẹ khi di chuyển nhanh
  LatLng _adaptiveSmoothing() {
    if (_gpsBuffer.isEmpty) return LatLng(_currentLatitude, _currentLongitude);

    // Weighted average với trọng số cao hơn cho data mới
    double totalWeight = 0.0;
    double weightedLat = 0.0;
    double weightedLon = 0.0;

    for (int i = 0; i < _gpsBuffer.length; i++) {
      // Weight tăng theo thời gian (data mới có weight cao hơn)
      double weight = (i + 1).toDouble();

      // Adaptive weight dựa trên speed - speed cao thì ít smooth hơn
      if (_currentSpeed > 5.0) {
        // >5 m/s thì giảm smoothing
        weight = i == _gpsBuffer.length - 1 ? weight * 3 : weight * 0.5;
      }

      weightedLat += _gpsBuffer[i].latitude * weight;
      weightedLon += _gpsBuffer[i].longitude * weight;
      totalWeight += weight;
    }

    return LatLng(weightedLat / totalWeight, weightedLon / totalWeight);
  }

  // Smooth interpolation như Mission Planner
  void _startInterpolation() {
    if (_targetPosition == null || _currentInterpolatedPosition == null) return;

    // Cancel timer cũ nếu có
    _interpolationTimer?.cancel();

    LatLng startPos = _currentInterpolatedPosition!;
    LatLng endPos = _targetPosition!;

    // Tính distance để quyết định animation duration
    double distance = _calculateRealDistance(
      startPos.latitude,
      startPos.longitude,
      endPos.latitude,
      endPos.longitude,
    );

    // Adaptive duration dựa trên distance và speed
    int duration = _calculateInterpolationDuration(distance);

    if (duration <= 50) {
      // Quá gần thì update trực tiếp
      _currentInterpolatedPosition = endPos;
      _updateCurrentPosition();
      return;
    }

    // Start position animation
    _positionController.duration = Duration(milliseconds: duration);
    _positionAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _positionController, curve: Curves.easeOut),
    );

    _positionController.reset();
    _positionController.forward();

    // Update position during animation
    _interpolationTimer = Timer.periodic(const Duration(milliseconds: 16), (
      timer,
    ) {
      if (!mounted || _positionController.isCompleted) {
        timer.cancel();
        return;
      }

      double t = _positionAnimation.value;
      _currentInterpolatedPosition = LatLng(
        startPos.latitude + (endPos.latitude - startPos.latitude) * t,
        startPos.longitude + (endPos.longitude - startPos.longitude) * t,
      );

      _updateCurrentPosition();
    });
  }

  int _calculateInterpolationDuration(double distance) {
    // Distance < 1m: 50ms, distance > 100m: 300ms
    if (distance < 1.0) return 50;
    if (distance > 100.0) return 300;

    // Linear interpolation cho các giá trị ở giữa
    return (50 + (distance / 100.0) * 250).round();
  }

  void _updateCurrentPosition() {
    if (_currentInterpolatedPosition == null) return;

    _currentLatitude = _currentInterpolatedPosition!.latitude;
    _currentLongitude = _currentInterpolatedPosition!.longitude;

    // Track movement để quyết định có hiển thị home marker không
    if (_homePoint != null && _lastDronePosition != null) {
      double distanceFromStart = _calculateRealDistance(
        _lastDronePosition!.latitude,
        _lastDronePosition!.longitude,
        _currentLatitude,
        _currentLongitude,
      );
      if (distanceFromStart > 1.0) {
        // 1 meter threshold
        _hasMovedFromStart = true;
      }
    }

    _updateMapPositionInterpolated();
    setState(() {});
  }

  void _updateMapPositionInterpolated() {
    LatLng newPosition = LatLng(_currentLatitude, _currentLongitude);

    // Nếu chưa zoom về GPS và có GPS fix thì zoom về vị trí GPS
    if (!_hasZoomedToGPS && _telemetryService.hasValidGpsFix) {
      _mapController.move(newPosition, 16.0);
      _hasZoomedToGPS = true;
    } else {
      // Smooth map movement - không dùng animation của map mà dùng interpolation riêng
      _mapController.move(newPosition, _mapController.camera.zoom);
    }
  }

  // Accurate distance calculation using Haversine formula
  double _calculateRealDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371000; // meters
    double dLat = (lat2 - lat1) * (math.pi / 180);
    double dLon = (lon2 - lon1) * (math.pi / 180);
    double a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * (math.pi / 180)) *
            math.cos(lat2 * (math.pi / 180)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: LatLng(_currentLatitude, _currentLongitude),
            initialZoom: 18,
            minZoom: 1,
            maxZoom: 22,
          ),
          children: [
            TileLayer(
              urlTemplate: _selectedMapType.urlTemplate,
              userAgentPackageName: "com.example.vtol_rustech",
              maxZoom: 22,
            ),

            if (_missionService.hasMission) ...[
              // Mission route line
              PolylineLayer(
                polylines: [
                  // Route từ home point đến waypoint đầu tiên (nếu có home point)
                  if (_homePoint != null &&
                      _missionService.currentMissionPoints.isNotEmpty)
                    Polyline(
                      points: [
                        _homePoint!,
                        LatLng(
                          double.parse(
                            _missionService.currentMissionPoints.first.latitude,
                          ),
                          double.parse(
                            _missionService
                                .currentMissionPoints
                                .first
                                .longitude,
                          ),
                        ),
                      ],
                      strokeWidth: 4.0,
                      strokeCap: StrokeCap.round,
                      color: Colors.cyanAccent.withOpacity(0.8),
                    ),
                  // Route giữa các mission waypoints
                  Polyline(
                    points: _missionService.currentMissionPoints
                        .map(
                          (point) => LatLng(
                            double.parse(point.latitude),
                            double.parse(point.longitude),
                          ),
                        )
                        .toList(),
                    strokeWidth: 4.0,
                    strokeCap: StrokeCap.round,
                    color: Colors.cyanAccent.withOpacity(0.8),
                  ),
                ],
              ),

              // Waypoint markers
              MarkerLayer(
                markers: _missionService.currentMissionPoints
                    .asMap()
                    .entries
                    .map((entry) {
                      final index = entry.key;
                      final point = entry.value;
                      return Marker(
                        point: LatLng(
                          double.parse(point.latitude),
                          double.parse(point.longitude),
                        ),
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        child: Stack(
                          children: [
                            Icon(
                              Icons.location_on,
                              color: Colors.red,
                              size: 40,
                            ),
                            Positioned.fill(
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Text(
                                    '${index + 1}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    })
                    .toList(),
              ),
            ],

            if (_telemetryService.isConnected &&
                _telemetryService.hasValidGpsFix)
              MarkerLayer(
                markers: [
                  Marker(
                    point: LatLng(_currentLatitude, _currentLongitude),
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    child: AnimatedBuilder(
                      animation: Listenable.merge([
                        _pulseAnimation,
                        _rotationAnimation,
                      ]),
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _pulseAnimation.value,
                          child: Transform.rotate(
                            angle: _rotationAnimation.value,
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _getGpsStatusColor().withOpacity(0.8),
                                boxShadow: [
                                  BoxShadow(
                                    color: _getGpsStatusColor().withOpacity(
                                      0.6,
                                    ),
                                    blurRadius: 15,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.flight,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  // Home marker - chỉ hiển thị khi có mission và drone đã di chuyển
                  if (_homePoint != null && _hasMovedFromStart)
                    Marker(
                      point: _homePoint!,
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Center(
                          child: Text(
                            'H',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Color _getGpsStatusColor() {
    switch (_telemetryService.gpsFixType) {
      case 'RTK Fixed':
        return Colors.green.shade700;
      case 'RTK Float':
        return Colors.green;
      case 'DGPS':
        return Colors.lightGreen;
      case '3D Fix':
        return Colors.blue;
      case '2D Fix':
        return Colors.orange;
      default:
        return Colors.red;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotationController.dispose();
    _positionController.dispose();
    _interpolationTimer?.cancel();
    _telemetrySubscription?.cancel();
    _connectionSubscription?.cancel();
    _missionSubscription?.cancel();
    super.dispose();
  }
}
