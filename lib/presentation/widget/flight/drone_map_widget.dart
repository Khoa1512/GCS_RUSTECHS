import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
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

  // Professional UX controls
  bool _isFollowModeEnabled = true; // Follow drone by default
  bool _userInteractedWithMap = false; // Track user pan/zoom
  DateTime? _lastUserInteraction;

  // Home point
  LatLng? _homePoint;

  // Takeoff detection
  bool _hasSetHomePointOnTakeoff = false;
  bool _wasPreviouslyArmed = false;
  double _groundAltitude = 0.0;
  static const double _takeoffAltitudeThreshold = 2.0; // 2 meters

  // GPS smoothing để giảm jitter - Mission Planner style
  final List<LatLng> _gpsBuffer = [];
  static const int _gpsBufferSize =
      2; // Keep minimal buffer cho both connections

  // Interpolation variables - như Mission Planner
  LatLng? _targetPosition;
  LatLng? _currentInterpolatedPosition;
  Timer? _interpolationTimer;
  late AnimationController _positionController;
  late Animation<double> _positionAnimation;

  // UI Update optimization
  Timer? _uiUpdateTimer;
  bool _needsUIUpdate = false;

  // Debug option để tắt smoothing
  static const bool _enableGpsSmoothing = true; // Set false để tắt smoothing

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

    // Add listener for smooth position updates instead of Timer.periodic
    _positionController.addListener(_onPositionAnimationUpdate);

    // Initialize interpolated position
    _currentInterpolatedPosition = LatLng(_currentLatitude, _currentLongitude);
  }

  void _setupSubscriptions() {
    _missionSubscription = _missionService.missionStream.listen((points) {
      // Khi mission được clear, xóa home point
      if (points.isEmpty) {
        _clearHomePoint();
      }
      // NOTE: Không set home point khi có mission mới nữa
      // Home point sẽ được set khi drone thực sự cất cánh

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

          // Early return nếu không có thay đổi
          if (newLat == _currentLatitude &&
              newLon == _currentLongitude &&
              newAlt == _currentAltitude) {
            return;
          }

          // Nếu đây là GPS data đầu tiên (vẫn ở default position), khởi tạo ngay
          if (_currentLatitude == 10.7302 && _currentLongitude == 106.6988) {
            if (kDebugMode) {
              print(
                'Initializing position from first GPS data: ($newLat, $newLon)',
              );
            }
            _currentLatitude = newLat;
            _currentLongitude = newLon;
            _currentAltitude = newAlt;
            _currentInterpolatedPosition = LatLng(newLat, newLon);
            _gpsBuffer.clear();
            _gpsBuffer.add(LatLng(newLat, newLon));
            _updateMapPosition();
            return;
          }

          // Kiểm tra xem có thay đổi đáng kể không
          double distanceFromCurrent = _calculateRealDistance(
            _currentLatitude,
            _currentLongitude,
            newLat,
            newLon,
          );

          // Detect takeoff và set home point
          _detectTakeoffAndSetHome(newLat, newLon, newAlt);

          // Mission Planner approach: Quality-based GPS processing với caching
          String gpsFixType = _telemetryService.gpsFixType;
          double threshold = _getDistanceThreshold(gpsFixType);

          // Tối ưu cho mission mode: Giảm threshold khi có mission để responsive hơn
          if (_missionService.hasMission) {
            threshold =
                threshold * 0.6; // Giảm threshold 40% khi đang có mission
          }

          if (distanceFromCurrent > threshold) {
            _processMissionPlannerStyleGPS(newLat, newLon, newAlt);
          }
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

  // Professional UX: Handle user interaction with map
  void _onUserInteraction() {
    setState(() {
      _userInteractedWithMap = true;
      _lastUserInteraction = DateTime.now();
    });
  }

  // Professional UX: Check if we should resume following after user interaction timeout
  bool _shouldResumeFollowing() {
    if (!_userInteractedWithMap || _lastUserInteraction == null) return true;

    final now = DateTime.now();
    final timeSinceInteraction = now.difference(_lastUserInteraction!);

    // Resume following after 30 seconds of no interaction
    if (timeSinceInteraction.inSeconds > 30) {
      return true;
    }

    return false;
  }

  void _updateMapPosition() {
    LatLng newPosition = LatLng(_currentLatitude, _currentLongitude);

    // Initial zoom to GPS location
    if (!_hasZoomedToGPS && _telemetryService.hasValidGpsFix) {
      _mapController.move(newPosition, 17.0);
      _hasZoomedToGPS = true;
      return;
    }

    // Professional UX: Only follow drone if follow mode enabled and user hasn't interacted recently
    if (_isFollowModeEnabled && _shouldResumeFollowing()) {
      // Auto-resume follow mode after timeout
      if (_userInteractedWithMap && _shouldResumeFollowing()) {
        setState(() {
          _userInteractedWithMap = false;
        });
      }

      try {
        // Smooth camera movement without jerky updates
        _mapController.moveAndRotate(
          newPosition,
          _mapController.camera.zoom,
          _mapController.camera.rotation,
        );
      } catch (e) {
        _mapController.move(newPosition, _mapController.camera.zoom);
      }
    }
    // If follow mode disabled or user interacted, drone marker moves but camera stays
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

        // Reset takeoff detection khi disconnect
        _hasSetHomePointOnTakeoff = false;
        _wasPreviouslyArmed = false;
        _groundAltitude = 0.0;
        _homePoint = null;
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
    // Add to buffer với weight dựa trên GPS fix quality
    LatLng newPosition = LatLng(newLat, newLon);
    _gpsBuffer.add(newPosition);
    if (_gpsBuffer.length > _gpsBufferSize) {
      _gpsBuffer.removeAt(0);
    }

    // Adaptive smoothing
    LatLng smoothedPosition = _adaptiveSmoothing();

    // Set target position cho interpolation
    _targetPosition = smoothedPosition;
    _currentAltitude = newAlt;

    // Start smooth interpolation animation như Mission Planner
    _startInterpolation();
  }

  // Adaptive smoothing như Mission Planner - minimal cho high-quality GPS
  LatLng _adaptiveSmoothing() {
    if (_gpsBuffer.isEmpty) return LatLng(_currentLatitude, _currentLongitude);

    // Option để tắt smoothing trong debug
    if (!_enableGpsSmoothing) {
      return _gpsBuffer.last; // Return raw GPS position
    }

    // High-quality GPS (RTK/DGPS) → Almost raw với minimal smoothing
    String gpsFixType = _telemetryService.gpsFixType;
    if (gpsFixType == 'RTK Fixed' ||
        gpsFixType == 'RTK Float' ||
        gpsFixType == 'DGPS') {
      // Return latest GPS với minimal delay để mượt như Mission Planner
      return _gpsBuffer.last;
    }

    // Low-quality GPS → Light smoothing
    if (_gpsBuffer.length == 1) return _gpsBuffer.first;

    // Simple weighted average cho standard GPS
    double totalWeight = 0.0;
    double weightedLat = 0.0;
    double weightedLon = 0.0;

    for (int i = 0; i < _gpsBuffer.length; i++) {
      // Recent sample có weight cao hơn (Mission Planner: 80/20 split)
      double weight = i == _gpsBuffer.length - 1 ? 0.8 : 0.2;

      weightedLat += _gpsBuffer[i].latitude * weight;
      weightedLon += _gpsBuffer[i].longitude * weight;
      totalWeight += weight;
    }

    return LatLng(weightedLat / totalWeight, weightedLon / totalWeight);
  }

  // Smooth interpolation như Mission Planner - OPTIMIZED
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

    if (duration <= 0) {
      // Không cần animate, update trực tiếp
      _currentInterpolatedPosition = endPos;
      _updateCurrentPosition();
      return;
    }

    // Store interpolation data for listener
    _interpolationStartPos = startPos;
    _interpolationEndPos = endPos;

    // Start position animation using controller listener (more efficient)
    _positionController.duration = Duration(milliseconds: duration);
    _positionAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _positionController, curve: Curves.easeOut),
    );

    _positionController.reset();
    _positionController.forward();
  }

  // Interpolation state for listener
  LatLng? _interpolationStartPos;
  LatLng? _interpolationEndPos;

  // Position animation listener - more efficient than Timer.periodic
  void _onPositionAnimationUpdate() {
    if (!mounted ||
        _interpolationStartPos == null ||
        _interpolationEndPos == null)
      return;

    double t = _positionAnimation.value;
    _currentInterpolatedPosition = LatLng(
      _interpolationStartPos!.latitude +
          (_interpolationEndPos!.latitude - _interpolationStartPos!.latitude) *
              t,
      _interpolationStartPos!.longitude +
          (_interpolationEndPos!.longitude -
                  _interpolationStartPos!.longitude) *
              t,
    );

    _updateCurrentPosition();
  }

  // Helper method để get distance threshold dựa trên GPS quality - CACHED
  static const Map<String, double> _gpsThresholds = {
    'RTK Fixed': 0.05, // Giảm threshold cho RTK để responsive hơn
    'RTK Float': 0.05, // Giảm threshold cho RTK Float
    'DGPS': 0.05, // Giảm threshold cho DGPS
  };

  double _getDistanceThreshold(String gpsFixType) {
    return _gpsThresholds[gpsFixType] ?? 0.3; // Giảm default từ 0.5 xuống 0.3
  }

  int _calculateInterpolationDuration(double distance) {
    // Mission Planner style: Tối ưu cho Auto mode - giảm delay
    // Nếu đang trong mission, giảm thêm duration để responsive hơn
    double multiplier = _missionService.hasMission ? 0.7 : 1.0;

    if (distance < 0.1) return 0; // Không animate cho movement rất nhỏ
    if (distance < 0.5)
      return (25 * multiplier).round(); // Rất nhanh cho small movements
    if (distance < 2.0)
      return (50 * multiplier).round(); // Medium speed cho normal movements
    if (distance < 5.0)
      return (100 * multiplier).round(); // Slower cho longer movements

    return (150 * multiplier).round(); // Max duration cho very long movements
  }

  void _updateCurrentPosition() {
    if (_currentInterpolatedPosition == null) return;

    _currentLatitude = _currentInterpolatedPosition!.latitude;
    _currentLongitude = _currentInterpolatedPosition!.longitude;

    // Validate coordinate consistency in debug mode
    _validateCoordinateConsistency();

    _updateMapPositionInterpolated();
    _scheduleUIUpdate(); // Use debounced UI update
  }

  // Debounced UI update to reduce setState calls
  void _scheduleUIUpdate() {
    _needsUIUpdate = true;
    _uiUpdateTimer?.cancel();
    _uiUpdateTimer = Timer(const Duration(milliseconds: 8), () {
      // Giảm từ 16ms xuống 8ms
      if (mounted && _needsUIUpdate) {
        setState(() {});
        _needsUIUpdate = false;
      }
    });
  }

  void _updateMapPositionInterpolated() {
    LatLng newPosition = LatLng(_currentLatitude, _currentLongitude);

    // Initial zoom to GPS location
    if (!_hasZoomedToGPS && _telemetryService.hasValidGpsFix) {
      _mapController.move(newPosition, 17.0);
      _hasZoomedToGPS = true;
      return;
    }

    // Professional UX: Only follow drone if enabled and no recent user interaction
    if (_isFollowModeEnabled && _shouldResumeFollowing()) {
      // Auto-resume follow mode after timeout
      if (_userInteractedWithMap && _shouldResumeFollowing()) {
        setState(() {
          _userInteractedWithMap = false;
        });
      }

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

  // Method để detect takeoff và set home point
  void _detectTakeoffAndSetHome(double lat, double lon, double alt) {
    bool isCurrentlyArmed = _telemetryService.isArmed;

    // Set ground altitude when first armed (before takeoff)
    if (isCurrentlyArmed && !_wasPreviouslyArmed) {
      _groundAltitude = alt;
      _wasPreviouslyArmed = true;
      // if (kDebugMode) {
      //   print(
      //     'Armed detected. Ground altitude: ${_groundAltitude.toStringAsFixed(1)}m',
      //   );
      // }
    }

    // Reset when disarmed
    if (!isCurrentlyArmed && _wasPreviouslyArmed) {
      _wasPreviouslyArmed = false;
      _hasSetHomePointOnTakeoff = false;
      // if (kDebugMode) {
      //   print('Disarmed detected. Reset takeoff detection.');
      // }
    }

    // Reset takeoff detection khi drone đáp xuống (còn armed nhưng altitude thấp)
    if (isCurrentlyArmed &&
        _hasSetHomePointOnTakeoff &&
        (alt - _groundAltitude) < (_takeoffAltitudeThreshold - 0.5)) {
      _hasSetHomePointOnTakeoff = false;
      _groundAltitude = alt; // Cập nhật ground altitude mới
      // if (kDebugMode) {
      //   print('Landing detected. Reset takeoff detection for next takeoff.');
      //   print('New ground altitude: ${_groundAltitude.toStringAsFixed(1)}m');
      // }
    }

    // Detect takeoff: armed + altitude > threshold + chưa set home point
    if (isCurrentlyArmed &&
        !_hasSetHomePointOnTakeoff &&
        (alt - _groundAltitude) >= _takeoffAltitudeThreshold) {
      // Set home point tại vị trí cất cánh
      setState(() {
        _homePoint = LatLng(lat, lon);
        _hasSetHomePointOnTakeoff = true;
      });

      // if (kDebugMode) {
      //   print('TAKEOFF DETECTED! Home point set at: ($lat, $lon)');
      //   print(
      //     'Takeoff altitude: ${(alt - _groundAltitude).toStringAsFixed(1)}m above ground',
      //   );
      // }
    }
  }

  // Method để get raw GPS coordinates trực tiếp từ TelemetryService
  LatLng _getRawGpsPosition() {
    return LatLng(
      _telemetryService.gpsLatitude,
      _telemetryService.gpsLongitude,
    );
  }

  // Method để set home point từ GPS hiện tại
  void _setHomePointFromCurrentGPS() {
    if (!_telemetryService.hasValidGpsFix) return;

    double rawLat = _telemetryService.gpsLatitude;
    double rawLon = _telemetryService.gpsLongitude;

    setState(() {
      _homePoint = LatLng(rawLat, rawLon);
    });
  }

  // Method để clear home point
  void _clearHomePoint() {
    setState(() {
      _homePoint = null;
    });
  }

  // Method để force update home point (có thể gọi từ bên ngoài)
  void updateHomePoint() {
    if (_telemetryService.hasValidGpsFix) {
      _setHomePointFromCurrentGPS();
    }
  }

  // Method để manual set home point tại vị trí hiện tại
  void setHomePointHere() {
    if (_telemetryService.hasValidGpsFix) {
      double rawLat = _telemetryService.gpsLatitude;
      double rawLon = _telemetryService.gpsLongitude;

      setState(() {
        _homePoint = LatLng(rawLat, rawLon);
        _hasSetHomePointOnTakeoff = true; // Mark as set để không bị override
      });
    }
  }

  // Method để toggle home point (set/clear)
  void _toggleHomePoint() {
    if (_homePoint != null) {
      // Nếu đã có home point → Clear nó
      _clearHomePoint();
      _hasSetHomePointOnTakeoff = false; // Reset để có thể set lại
    } else {
      // Nếu chưa có home point → Set tại vị trí hiện tại
      setHomePointHere();
    }
  }

  // Method để kiểm tra sự khác biệt giữa raw GPS và smoothed position - OPTIMIZED
  void _validateCoordinateConsistency() {
    // Chỉ validate trong debug mode và khi cần thiết
    if (!kDebugMode || !_telemetryService.hasValidGpsFix) return;

    LatLng rawGps = _getRawGpsPosition();
    LatLng smoothed = LatLng(_currentLatitude, _currentLongitude);

    double difference = _calculateRealDistance(
      rawGps.latitude,
      rawGps.longitude,
      smoothed.latitude,
      smoothed.longitude,
    );

    // Chỉ log khi có vấn đề đáng kể (>10m)
    if (difference > 10.0) {
      print(
        'WARNING: Large GPS difference: ${difference.toStringAsFixed(2)}m\n'
        'Raw: (${rawGps.latitude.toStringAsFixed(7)}, ${rawGps.longitude.toStringAsFixed(7)})\n'
        'Smoothed: (${smoothed.latitude.toStringAsFixed(7)}, ${smoothed.longitude.toStringAsFixed(7)})',
      );
    }
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
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: LatLng(_currentLatitude, _currentLongitude),
                initialZoom: 18,
                minZoom: 1,
                maxZoom: 22,
                // Professional UX: Detect user interactions
                onPositionChanged: (position, hasGesture) {
                  if (hasGesture) {
                    _onUserInteraction();
                  }
                },
                onTap: (tapPosition, point) {
                  _onUserInteraction();
                },
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
                                _missionService
                                    .currentMissionPoints
                                    .first
                                    .latitude,
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
                    markers: [
                      // Regular waypoint markers
                      ..._missionService.currentMissionPoints
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
                                        padding: const EdgeInsets.only(
                                          bottom: 12,
                                        ),
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
                          }),
                    ],
                  ),
                ],

                if (_telemetryService.isConnected &&
                    _telemetryService.hasValidGpsFix)
                  MarkerLayer(
                    markers: [
                      // Home marker - render trước để nằm dưới UAV marker
                      if (_homePoint != null)
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
                      // Main drone marker (smoothed position) - render sau để nằm trên
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
                                    color: _getGpsStatusColor().withOpacity(
                                      0.8,
                                    ),
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
                    ],
                  ),
              ],
            ),

            // Map Controls - Top Left Column (chỉ hiện khi connected và có GPS)
            if (_telemetryService.isConnected &&
                _telemetryService.hasValidGpsFix)
              Positioned(
                top: 16,
                left: 16,
                child: Column(
                  children: [
                    // Follow Mode Toggle
                    Tooltip(
                      message: _isFollowModeEnabled
                          ? 'Disable Follow Mode'
                          : 'Enable Follow Mode',
                      child: FloatingActionButton.small(
                        onPressed: () {
                          setState(() {
                            _isFollowModeEnabled = !_isFollowModeEnabled;
                            if (_isFollowModeEnabled) {
                              _userInteractedWithMap = false;
                            }
                          });
                        },
                        backgroundColor: _isFollowModeEnabled
                            ? Colors.green.withOpacity(0.9)
                            : Colors.grey.withOpacity(0.9),
                        child: Icon(
                          _isFollowModeEnabled
                              ? Icons.my_location
                              : Icons.location_disabled,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Center on Drone
                    Tooltip(
                      message: 'Center on Drone',
                      child: FloatingActionButton.small(
                        onPressed: () {
                          LatLng dronePosition = LatLng(
                            _currentLatitude,
                            _currentLongitude,
                          );
                          _mapController.move(
                            dronePosition,
                            _mapController.camera.zoom,
                          );
                          setState(() {
                            _userInteractedWithMap = false;
                            _isFollowModeEnabled = true;
                          });
                        },
                        backgroundColor: Colors.blue.withOpacity(0.9),
                        child: const Icon(
                          Icons.center_focus_strong,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Set/Clear Home Point
                    Tooltip(
                      message: _homePoint != null
                          ? 'Clear Home Point'
                          : 'Set Home Point Here',
                      child: FloatingActionButton.small(
                        onPressed: _toggleHomePoint,
                        backgroundColor: _homePoint != null
                            ? Colors.red.withOpacity(0.9)
                            : Colors.orange.withOpacity(0.9),
                        child: Icon(
                          _homePoint != null
                              ? Icons.home_filled
                              : Icons.home_outlined,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
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
    // Cancel all timers first to prevent memory leaks
    _interpolationTimer?.cancel();
    _uiUpdateTimer?.cancel();

    // Remove animation listeners
    _positionController.removeListener(_onPositionAnimationUpdate);

    // Dispose animation controllers
    _pulseController.dispose();
    _rotationController.dispose();
    _positionController.dispose();

    // Cancel subscriptions
    _telemetrySubscription?.cancel();
    _connectionSubscription?.cancel();
    _missionSubscription?.cancel();

    super.dispose();
  }
}
