import 'dart:async';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:skylink/core/constant/map_type.dart';
import 'package:skylink/services/telemetry_service.dart';
import 'package:skylink/services/mission_service.dart';
import 'package:skylink/presentation/widget/mission/mission_waypoint_helpers.dart';
import 'package:skylink/services/no_fly_zone_service.dart';
import 'package:skylink/core/utils/geo_utils.dart';
import 'package:flutter_map_cache/flutter_map_cache.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:skylink/services/map_cache_service.dart';

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

  // Biến cho thuật toán nội suy vị trí (Interpolation) - Giúp icon di chuyển mượt mà
  LatLng? _targetPosition; // Vị trí đích đến
  LatLng? _currentInterpolatedPosition; // Vị trí hiện tại đang vẽ trên màn hình
  Timer? _interpolationTimer;
  late AnimationController _positionController;
  late Animation<double> _positionAnimation;

  // Flight Trail (Breadcrumbs)
  final List<LatLng> _flightTrail = [];
  static const int _maxTrailPoints = 100; // Limit to prevent clutter
  static const double _trailUpdateThreshold =
      2.0; // Only add point if moved > 2m

  // Tối ưu cập nhật UI (Throttle/Debounce)
  Timer? _uiUpdateTimer;
  bool _needsUIUpdate = false;

  // Cờ debug: Tắt làm mượt GPS nếu cần test dữ liệu thô
  static const bool _enableGpsSmoothing = true;

  // No-Fly Zones
  List<List<LatLng>> _allNoFlyZones = [];
  List<List<LatLng>> _visibleNoFlyZones = [];
  bool _isLoadingZones = false;
  Timer? _cullingDebounceTimer;

  // Cache store future
  late final Future<CacheStore> _cacheStoreFuture;

  @override
  void initState() {
    super.initState();
    _setupControllers();
    _setupListeners();
    _loadNoFlyZones();

    // Initialize cache store
    _cacheStoreFuture = _initCacheStore();
  }

  Future<CacheStore> _initCacheStore() async {
    return MapCacheService.instance.getCacheStore();
  }

  Future<void> _loadNoFlyZones() async {
    setState(() {
      _isLoadingZones = true;
    });


    final zones = await NoFlyZoneService().loadNoFlyZones(
      'hcmc_nofly_zones.json',
    );

    if (mounted) {
      setState(() {
        _allNoFlyZones = zones;
        _isLoadingZones = false;
      });
      // Initial culling check after loading
      _updateVisibleZones();
    }
  }

  void _setupControllers() {
    _mapController = MapController();
    _selectedMapType = mapTypes.firstWhere(
      (mapType) => mapType.name == 'Google Hybrid',
      orElse: () => mapTypes.first,
    );

    // 1. Hiệu ứng "Thở" (Pulse) cho icon
    // Tạo cảm giác drone đang hoạt động (alive)
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);

    // 2. Animation Xoay (Rotation)
    // Giúp mũi drone quay mượt mà thay vì giật cục khi đổi hướng
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 200), // 200ms là đủ nhanh và mượt
      vsync: this,
    );
    _rotationAnimation =
        Tween<double>(begin: 0, end: _currentYaw * (math.pi / 180)).animate(
          CurvedAnimation(parent: _rotationController, curve: Curves.easeOut),
        );
    _rotationController.forward();

    // 3. Animation Di chuyển (Position Interpolation)
    // Quan trọng nhất: Biến các tọa độ GPS rời rạc thành chuyển động liên tục
    _positionController = AnimationController(
      duration: const Duration(
        milliseconds: 100,
      ), // Thời gian sẽ được tính toán động (adaptive)
      vsync: this,
    );
    _positionAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _positionController, curve: Curves.easeOut),
    );

    // Lắng nghe animation để cập nhật vị trí từng frame
    _positionController.addListener(_onPositionAnimationUpdate);

    // Khởi tạo vị trí ban đầu
    _currentInterpolatedPosition = LatLng(_currentLatitude, _currentLongitude);
  }

  void _setupListeners() {
    // Lắng nghe Mission (để vẽ đường bay)
    _missionSubscription = _missionService.missionStream.listen((points) {
      if (points.isEmpty) {
        _clearHomePoint();
      }
      // NOTE: Không set home point khi có mission mới nữa
      // Home point sẽ được set khi drone thực sự cất cánh

      setState(() {});
    });

    // Lắng nghe Telemetry (Dữ liệu bay realtime)
    _telemetrySubscription = _telemetryService.telemetryStream.listen((data) {
      if (mounted) {
        bool needsRotationUpdate = false;

        // Xử lý hướng mũi (Yaw)
        if (data.containsKey('yaw')) {
          double newYaw = data['yaw'] ?? 0.0;
          // Giảm threshold xuống 0.1 độ để phản hồi nhạy hơn với slider test
          if ((_currentYaw - newYaw).abs() > 0.1) {
            // print('Yaw update: $_currentYaw -> $newYaw');
            _currentYaw = newYaw;
            needsRotationUpdate = true;
          }
        }

        // Xử lý vị trí GPS
        if (_telemetryService.hasValidGpsFix) {
          double newLat = data['gps_latitude'] ?? _currentLatitude;
          double newLon = data['gps_longitude'] ?? _currentLongitude;
          double newAlt = data['gps_altitude'] ?? _currentAltitude;

          // Bỏ qua nếu tọa độ không đổi
          if (newLat == _currentLatitude &&
              newLon == _currentLongitude &&
              newAlt == _currentAltitude) {
            return;
          }

          // Khởi tạo vị trí ngay lập tức nếu là lần đầu nhận GPS
          if (_currentLatitude == 10.7302 && _currentLongitude == 106.6988) {
            _currentLatitude = newLat;
            _currentLongitude = newLon;
            _currentAltitude = newAlt;
            _currentInterpolatedPosition = LatLng(newLat, newLon);
            _gpsBuffer.clear();
            _gpsBuffer.add(LatLng(newLat, newLon));
            _syncMapCamera();
            return;
          }

          // Tính khoảng cách di chuyển thực tế
          double distanceFromCurrent = _calculateRealDistance(
            _currentLatitude,
            _currentLongitude,
            newLat,
            newLon,
          );

          // Logic tự động set Home          // Detect takeoff và set home point
          _detectTakeoffAndSetHome(newLat, newLon, newAlt);

          // Update Flight Trail (Smart Sampling)
          _updateFlightTrail(newLat, newLon);

          // Lọc nhiễu GPS (Smoothing) dựa trên chất lượng tín hiệu
          String gpsFixType = _telemetryService.gpsFixType;
          double threshold = _getDistanceThreshold(gpsFixType);

          // Khi đang bay Mission, giảm ngưỡng lọc để icon phản hồi nhạy hơn
          if (_missionService.hasMission) {
            threshold =
                threshold * 0.6; // Giảm threshold 40% khi đang có mission
          }

          // Chỉ cập nhật nếu di chuyển vượt quá ngưỡng nhiễu (Threshold)
          if (distanceFromCurrent > threshold) {
            _processMissionPlannerStyleGPS(newLat, newLon, newAlt);
          }
        }

        if (needsRotationUpdate) {
          _updateRotationAnimation();
        }
      }
    });

    // Lắng nghe trạng thái kết nối
    _connectionSubscription = _telemetryService.connectionStream.listen((
      isConnected,
    ) {
      // print('Connection status changed: $isConnected');
      if (mounted && !isConnected) {
        _handleDisconnect();
      }
      setState(() {});
    });
  }

  void _updateFlightTrail(double lat, double lon) {
    // Chỉ thêm điểm mới nếu drone đã di chuyển đủ xa (> 2m)
    // Giúp đường bay không bị rối khi drone hover một chỗ
    if (_flightTrail.isEmpty) {
      _flightTrail.add(LatLng(lat, lon));
      return;
    }

    double dist = _calculateRealDistance(
      _flightTrail.last.latitude,
      _flightTrail.last.longitude,
      lat,
      lon,
    );

    if (dist > _trailUpdateThreshold) {
      _flightTrail.add(LatLng(lat, lon));

      // Giới hạn số lượng điểm (FIFO) để tránh clutter và lag
      if (_flightTrail.length > _maxTrailPoints) {
        _flightTrail.removeAt(0);
      }
    }
  }

  // Cập nhật Animation Xoay (Có xử lý góc ngắn nhất)
  void _updateRotationAnimation() {
    // Dừng animation cũ để phản hồi ngay lập tức
    _rotationController.stop();

    double currentRad = _rotationAnimation.value;
    double targetRad = _currentYaw * (math.pi / 180);

    // Tính toán đường đi ngắn nhất (Shortest Path)
    // Ví dụ: Từ 350 độ sang 10 độ -> Quay phải 20 độ (thay vì quay trái 340 độ)
    double diff = targetRad - currentRad;
    while (diff < -math.pi) {
      diff += 2 * math.pi;
    }
    while (diff > math.pi) {
      diff -= 2 * math.pi;
    }

    _rotationAnimation =
        Tween<double>(begin: currentRad, end: currentRad + diff).animate(
          CurvedAnimation(parent: _rotationController, curve: Curves.easeOut),
        );

    _rotationController.reset();
    _rotationController.forward();
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

  void _syncMapCamera() {
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
  }

  // Xử lý khi mất kết nối (Ghost Mode)
  void _handleDisconnect() {
    setState(() {
      if (!_telemetryService.isConnected) {
        // CHUẨN GCS: Ghost Mode
        // Giữ nguyên vị trí cuối cùng để người dùng biết drone đang ở đâu

        // Chỉ reset các trạng thái bay realtime
        _hasZoomedToGPS = false;
        _gpsBuffer.clear();
        _targetPosition = null;

        // Reset logic cất cánh nhưng GIỮ LẠI Home Point
        _hasSetHomePointOnTakeoff = false;
        _wasPreviouslyArmed = false;
        _groundAltitude = 0.0;
      }
      _currentAltitude = 0.0;
    });
    // Don't call _syncMapCamera() to avoid jumping to default
  }

  // Xử lý GPS theo phong cách Mission Planner (Smoothing + Interpolation)
  void _processMissionPlannerStyleGPS(
    double newLat,
    double newLon,
    double newAlt,
  ) {
    // 1. Thêm vào bộ đệm (Buffer)
    LatLng newPosition = LatLng(newLat, newLon);
    _gpsBuffer.add(newPosition);
    if (_gpsBuffer.length > _gpsBufferSize) {
      _gpsBuffer.removeAt(0);
    }

    // 2. Làm mượt dữ liệu (Adaptive Smoothing)
    LatLng smoothedPosition = _adaptiveSmoothing();

    // 3. Đặt mục tiêu mới cho animation
    _targetPosition = smoothedPosition;
    _currentAltitude = newAlt;

    // 4. Bắt đầu animation di chuyển
    _startInterpolation();
  }

  // Thuật toán làm mượt thích ứng (Adaptive Smoothing)
  LatLng _adaptiveSmoothing() {
    if (_gpsBuffer.isEmpty) return LatLng(_currentLatitude, _currentLongitude);

    if (!_enableGpsSmoothing) {
      return _gpsBuffer.last; // Trả về dữ liệu thô nếu tắt smoothing
    }

    // Nếu GPS tốt (RTK/DGPS) -> Dùng trực tiếp, ít can thiệp
    String gpsFixType = _telemetryService.gpsFixType;
    if (gpsFixType == 'RTK Fixed' ||
        gpsFixType == 'RTK Float' ||
        gpsFixType == 'DGPS') {
      return _gpsBuffer.last;
    }

    if (_gpsBuffer.length == 1) return _gpsBuffer.first;

    // Nếu GPS thường -> Tính trung bình có trọng số (Weighted Average)
    // Ưu tiên dữ liệu mới nhất (80%) để giảm độ trễ
    double totalWeight = 0.0;
    double weightedLat = 0.0;
    double weightedLon = 0.0;

    for (int i = 0; i < _gpsBuffer.length; i++) {
      double weight = i == _gpsBuffer.length - 1 ? 0.8 : 0.2;

      weightedLat += _gpsBuffer[i].latitude * weight;
      weightedLon += _gpsBuffer[i].longitude * weight;
      totalWeight += weight;
    }

    return LatLng(weightedLat / totalWeight, weightedLon / totalWeight);
  }

  // Bắt đầu nội suy vị trí (Interpolation)
  void _startInterpolation() {
    if (_targetPosition == null || _currentInterpolatedPosition == null) return;

    // Cancel timer cũ nếu có
    _interpolationTimer?.cancel();

    LatLng startPos = _currentInterpolatedPosition!;
    LatLng endPos = _targetPosition!;

    // Tính khoảng cách để quyết định tốc độ animation
    double distance = _calculateRealDistance(
      startPos.latitude,
      startPos.longitude,
      endPos.latitude,
      endPos.longitude,
    );

    // Tính thời gian animation dựa trên khoảng cách (Adaptive Duration)
    int duration = _calculateInterpolationDuration(distance);

    if (duration <= 0) {
      // Nếu quá gần -> Cập nhật ngay lập tức (Snap)
      _currentInterpolatedPosition = endPos;
      _updateCurrentPosition();
      return;
    }

    // Lưu điểm đầu/cuối cho listener
    _interpolationStartPos = startPos;
    _interpolationEndPos = endPos;

    // Chạy animation
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
        _interpolationEndPos == null) {
      return;
    }

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
    'RTK Fixed': 0.01, // Cực nhạy cho RTK
    'RTK Float': 0.02,
    'DGPS': 0.05,
    '3D Fix': 0.01,
  };

  double _getDistanceThreshold(String gpsFixType) {
    // Giảm default threshold xuống thấp để update mượt hơn
    return _gpsThresholds[gpsFixType] ?? 0.05; // Default 5cm
  }

  int _calculateInterpolationDuration(double distance) {
    // Nếu đang trong mission, giảm thêm duration để responsive hơn
    double multiplier = _missionService.hasMission ? 0.9 : 1.0;

    if (distance < 0.01) return 0; // Chỉ snap nếu < 1cm

    // Hovering / drifting (small moves)
    if (distance < 0.2) {
      return (200 * multiplier).round(); // Match 5Hz rate
    }

    // Flying (normal speed)
    // Update rate is now 5Hz (200ms)
    // Set duration to exactly 200ms for 1:1 sync
    return (200 * multiplier).round();
  }

  void _updateCurrentPosition() {
    if (_currentInterpolatedPosition == null) return;

    _currentLatitude = _currentInterpolatedPosition!.latitude;
    _currentLongitude = _currentInterpolatedPosition!.longitude;

    _syncMapCamera();
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

    // PROFESSIONAL STANDARD: Set Home Point ngay khi ARM (nếu có GPS)
    // Điều này chính xác hơn là đợi bay lên 2m mới set (vì có thể bị drift)
    if (isCurrentlyArmed && !_wasPreviouslyArmed) {
      _groundAltitude = alt;
      _wasPreviouslyArmed = true;

      // Clear flight trail on Arming for a fresh view
      _flightTrail.clear();

      // Nếu chưa có Home Point, set ngay lập tức tại vị trí Arm
      if (!_hasSetHomePointOnTakeoff) {
        setState(() {
          _homePoint = LatLng(lat, lon);
          _hasSetHomePointOnTakeoff = true;
          print("Home Point set at Arming: $lat, $lon");
        });
      }
    }

    // Reset state khi Disarmed (để chuẩn bị cho lần bay sau)
    if (!isCurrentlyArmed && _wasPreviouslyArmed) {
      _wasPreviouslyArmed = false;
      // Note: Không clear Home Point ở đây, giữ lại để tham khảo sau khi đáp
      // Chỉ clear flag takeoff để lần arm sau có thể set lại home mới
      _hasSetHomePointOnTakeoff = false;
    }

    // Backup: Nếu lúc Arm chưa có GPS, nhưng khi bay lên mới có GPS
    // Detect takeoff: armed + altitude > threshold + chưa set home point
    if (isCurrentlyArmed &&
        !_hasSetHomePointOnTakeoff &&
        (alt - _groundAltitude) >= _takeoffAltitudeThreshold) {
      // Set home point tại vị trí cất cánh (Backup)
      setState(() {
        _homePoint = LatLng(lat, lon);
        _hasSetHomePointOnTakeoff = true;
        print("Home Point set at Takeoff (Backup): $lat, $lon");
      });
    }
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
                minZoom: 4, // Prevent zooming out too far
                maxZoom: 22,
                // Removed cameraConstraint to fix crash
                onPositionChanged: (position, hasGesture) {
                  if (hasGesture) {
                    _onUserInteraction();
                  }
                  // Debounce culling update
                  _cullingDebounceTimer?.cancel();
                  _cullingDebounceTimer = Timer(
                    const Duration(milliseconds: 300),
                    () {
                      _updateVisibleZones();
                    },
                  );
                },
                onTap: (tapPosition, point) {
                  _onUserInteraction();
                },
              ),
              children: [
                // Map Layer with Caching
                FutureBuilder<CacheStore>(
                  future: _cacheStoreFuture,
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      return TileLayer(
                        urlTemplate: _selectedMapType.urlTemplate,
                        userAgentPackageName: "com.example.vtol_rustech",
                        tileProvider: CachedTileProvider(
                          store: snapshot.data!,
                          maxStale: const Duration(
                            days: 30,
                          ), // Cache for 30 days
                        ),
                      );
                    }
                    // Fallback while initializing cache (or error)
                    return TileLayer(
                      urlTemplate: _selectedMapType.urlTemplate,
                      userAgentPackageName: "com.example.vtol_rustech",
                    );
                  },
                ),

                // No-flight zone polygon layer (Optimized)
                // PolygonLayer(
                //   polygons: [
                //     ..._visibleNoFlyZones.map(
                //       (points) => Polygon(
                //         points: points,
                //         color: const Color(0xFFB71C1C).withOpacity(0.4),
                //         borderColor: const Color(0xFFB71C1C),
                //         borderStrokeWidth: 1.5,
                //       ),
                //     ),
                //   ],
                // ),

                // Flight Trail (Breadcrumbs) with Fading Effect
                if (_flightTrail.isNotEmpty)
                  PolylineLayer(polylines: _buildFadingTrail()),

                if (_missionService.hasMission) ...[
                  // Mission route line
                  PolylineLayer(
                    polylines: [
                      // Route từ home point đến waypoint đầu tiên (nếu có home point)
                      if (_homePoint != null &&
                          MissionWaypointHelpers.getFlightPathPoints(
                            _missionService.currentMissionPoints,
                          ).isNotEmpty)
                        Polyline(
                          points: [
                            _homePoint!,
                            LatLng(
                              double.parse(
                                MissionWaypointHelpers.getFlightPathPoints(
                                  _missionService.currentMissionPoints,
                                ).first.latitude,
                              ),
                              double.parse(
                                MissionWaypointHelpers.getFlightPathPoints(
                                  _missionService.currentMissionPoints,
                                ).first.longitude,
                              ),
                            ),
                          ],
                          strokeWidth: 4.0,
                          strokeCap: StrokeCap.round,
                          color: Colors.cyanAccent.withOpacity(0.8),
                        ),
                      // Route giữa các mission waypoints (flight path only)
                      Polyline(
                        points:
                            MissionWaypointHelpers.getFlightPathPoints(
                                  _missionService.currentMissionPoints,
                                )
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
                      ..._missionService.currentMissionPoints.asMap().entries.map((
                        entry,
                      ) {
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
                                MissionWaypointHelpers.getWaypointIcon(point),
                                color: MissionWaypointHelpers.getWaypointColor(
                                  point,
                                ),
                                size: 35,
                              ),
                              if (!MissionWaypointHelpers.isROIPoint(point))
                                Positioned.fill(
                                  child: Center(
                                    child: Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 12,
                                        right: 4,
                                      ),
                                      child: Text(
                                        '${index + 1}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              // ROI indicator - show "ROI" text instead of number
                              if (MissionWaypointHelpers.isROIPoint(point))
                                Positioned.fill(
                                  child: Center(
                                    child: Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 8,
                                        right: 4,
                                      ),
                                      child: Text(
                                        'ROI',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
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
                        width: 120, // Tăng size để vẽ FOV cone và ripple
                        height: 120,
                        alignment: Alignment.center,
                        child: AnimatedBuilder(
                          animation: Listenable.merge([
                            _pulseAnimation,
                            _rotationController,
                          ]),
                          builder: (context, child) {
                            return Transform.rotate(
                              angle: _rotationAnimation.value,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // 1. Radar Ripple Effect (Pulsing)
                                  Transform.scale(
                                    scale:
                                        1.0 +
                                        (_pulseAnimation.value - 0.8) * 1.5,
                                    child: Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: _getGpsStatusColor()
                                              .withOpacity(
                                                0.5 *
                                                    (1.2 -
                                                        _pulseAnimation.value),
                                              ),
                                          width: 2,
                                        ),
                                        color: _getGpsStatusColor().withOpacity(
                                          0.1 * (1.2 - _pulseAnimation.value),
                                        ),
                                      ),
                                    ),
                                  ),
                                  // 2. Drone Icon & FOV Cone (Custom Painted)
                                  CustomPaint(
                                    size: const Size(60, 60),
                                    painter: DroneMarkerPainter(
                                      color: _getGpsStatusColor(),
                                      isArmed: _telemetryService.isArmed,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
              ],
            ),

            Positioned(
              top: 16,
              right: 16,
              child: _isLoadingZones
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
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
                          ? 'Tắt chế độ theo dõi'
                          : 'Bật chế độ theo dõi',
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
                      message: 'Tập trung vào Drone',
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
                          ? 'Xóa điểm Home'
                          : 'Đặt điểm Home tại đây',
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
                    const SizedBox(height: 8),
                    // Clear Mission Button (Only visible if mission exists)
                    if (_missionService.hasMission)
                      Tooltip(
                        message: 'Xóa Mission trên Map',
                        child: FloatingActionButton.small(
                          onPressed: () {
                            // Confirm dialog
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                backgroundColor: const Color(0xFF1E1E1E),
                                title: const Text(
                                  'Xóa Mission?',
                                  style: TextStyle(color: Colors.white),
                                ),
                                content: const Text(
                                  'Bạn có chắc muốn xóa mission khỏi bản đồ không? (Lưu ý: Mission trên Drone vẫn còn nếu đã upload)',
                                  style: TextStyle(color: Colors.white70),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Hủy'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      _missionService.clearMission();
                                      Navigator.pop(context);
                                      setState(() {});
                                    },
                                    child: const Text(
                                      'Xóa',
                                      style: TextStyle(color: Colors.redAccent),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                          backgroundColor: Colors.redAccent.withOpacity(0.9),
                          child: const Icon(
                            Icons.delete_forever,
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
    // Visual Feedback cho Ghost Mode:
    // Nếu mất kết nối, icon chuyển sang màu Xám để báo hiệu dữ liệu cũ
    if (!_telemetryService.isConnected) {
      return Colors.grey;
    }

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

  // Helper to build fading flight trail
  List<Polyline> _buildFadingTrail() {
    if (_flightTrail.length < 2) return [];

    final List<Polyline> segments = [];
    final int totalPoints = _flightTrail.length;

    // Create segments from oldest to newest
    for (int i = 0; i < totalPoints - 1; i++) {
      // Calculate opacity: Newer points (higher index) are more opaque
      // i=0 (oldest) -> opacity close to 0
      // i=total-2 (newest segment) -> opacity close to 1.0
      double opacity = (i + 1) / totalPoints;

      // Apply non-linear fade for better visual (ease-in)
      opacity = opacity * opacity;

      // Ensure minimum visibility
      if (opacity < 0.1) opacity = 0.1;

      segments.add(
        Polyline(
          points: [_flightTrail[i], _flightTrail[i + 1]],
          strokeWidth: 3.0, // Slightly thicker for better visibility
          color: Colors.white.withOpacity(opacity),
          strokeCap: StrokeCap.round,
          strokeJoin: StrokeJoin.round,
        ),
      );
    }

    return segments;
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

  void _updateVisibleZones() {
    if (!mounted || _allNoFlyZones.isEmpty) return;

    final bounds = _mapController.camera.visibleBounds;
    final double zoom = _mapController.camera.zoom;

    // Calculate tolerance based on zoom level
    // Higher zoom (closer) -> smaller tolerance (more detail)
    // Lower zoom (farther) -> larger tolerance (less detail)
    // Example: Zoom 10 -> tolerance 0.001, Zoom 18 -> tolerance 0.00001
    double tolerance = 0.0;
    if (zoom < 10) {
      tolerance = 0.001;
    } else if (zoom < 13) {
      tolerance = 0.0005;
    } else if (zoom < 15) {
      tolerance = 0.0001;
    } else {
      tolerance = 0.00001; // Very detailed
    }

    // Run culling and simplification
    // For large datasets, this should definitely be in an Isolate or compute()
    final visible = _allNoFlyZones
        .where((polygon) {
          return GeoUtils.isPolygonVisible(polygon, bounds);
        })
        .map((polygon) {
          // Apply simplification if zoomed out
          if (zoom < 16) {
            return GeoUtils.simplifyPolygon(polygon, tolerance);
          }
          return polygon;
        })
        .toList();

    setState(() {
      _visibleNoFlyZones = visible;
    });

    // print('Visible zones: ${visible.length} / ${_allNoFlyZones.length}');
  }
}

class DroneMarkerPainter extends CustomPainter {
  final Color color;
  final bool isArmed;

  DroneMarkerPainter({required this.color, required this.isArmed});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final double scale = size.width / 60.0; // Base size 60

    // 1. Draw FOV Cone (Field of View)
    final Paint fovPaint = Paint()
      ..shader = RadialGradient(
        colors: [color.withOpacity(0.4), color.withOpacity(0.0)],
        stops: const [0.2, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: 40 * scale))
      ..style = PaintingStyle.fill;

    // Draw arc -90 degrees (up) +/- 30 degrees
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: 40 * scale),
      -math.pi / 2 - (math.pi / 6), // Start angle (-90 - 30)
      math.pi / 3, // Sweep angle (60 degrees)
      true,
      fovPaint,
    );

    // 2. Draw Drop Shadow
    final ui.Path shadowPath = ui.Path();
    shadowPath.moveTo(center.dx, center.dy - 18 * scale); // Nose
    shadowPath.lineTo(
      center.dx + 14 * scale,
      center.dy + 14 * scale,
    ); // Right wing
    shadowPath.lineTo(center.dx, center.dy + 8 * scale); // Tail notch
    shadowPath.lineTo(
      center.dx - 14 * scale,
      center.dy + 14 * scale,
    ); // Left wing
    shadowPath.close();

    canvas.drawPath(
      shadowPath.shift(Offset(2 * scale, 2 * scale)),
      Paint()
        ..color = Colors.black.withOpacity(0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    // 3. Draw Drone Body (Delta Wing)
    final ui.Path dronePath = ui.Path();
    dronePath.moveTo(center.dx, center.dy - 20 * scale); // Nose (Top)
    dronePath.lineTo(
      center.dx + 16 * scale,
      center.dy + 16 * scale,
    ); // Right wing
    dronePath.lineTo(center.dx, center.dy + 10 * scale); // Tail notch
    dronePath.lineTo(
      center.dx - 16 * scale,
      center.dy + 16 * scale,
    ); // Left wing
    dronePath.close();

    // Fill
    canvas.drawPath(
      dronePath,
      Paint()
        ..color = isArmed
            ? const Color(0xFFFF3D00)
            : const Color(0xFF00E676) // Red if armed, Green if disarmed
        ..style = PaintingStyle.fill,
    );

    // Border
    canvas.drawPath(
      dronePath,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5 * scale
        ..strokeJoin = StrokeJoin.round,
    );

    // 4. Center Point (Prop/Hub)
    canvas.drawCircle(
      Offset(center.dx, center.dy + 2 * scale),
      3 * scale,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant DroneMarkerPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.isArmed != isArmed;
  }
}
