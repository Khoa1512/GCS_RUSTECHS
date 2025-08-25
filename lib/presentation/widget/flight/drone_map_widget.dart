import 'dart:async';
import 'dart:math';
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
  static const double _movementThreshold = 0.00001; // ~1 mét

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

    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);

    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _rotationAnimation = Tween<double>(begin: 0, end: _currentYaw * (pi / 180))
        .animate(
          CurvedAnimation(parent: _rotationController, curve: Curves.easeInOut),
        );
    _rotationController.forward();
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
        bool needsMapUpdate = false;
        bool needsRotationUpdate = false;

        if (data.containsKey('yaw')) {
          double newYaw = data['yaw'] ?? 0.0;
          if ((_currentYaw - newYaw).abs() > 1.0) {
            _currentYaw = newYaw;
            needsRotationUpdate = true;
          }
        }

        if (_telemetryService.hasValidGpsFix) {
          double newLat = data['gps_latitude'] ?? _currentLatitude;
          double newLon = data['gps_longitude'] ?? _currentLongitude;
          double newAlt = data['gps_altitude'] ?? _currentAltitude;

          // print('GPS Update: lat=$newLat, lon=$newLon, alt=$newAlt');
          // print('Current GPS Fix: ${_telemetryService.gpsFixType}');
          // print('Has Valid GPS Fix: ${_telemetryService.hasValidGpsFix}');

          double latDiff = (_currentLatitude - newLat).abs();
          double lonDiff = (_currentLongitude - newLon).abs();

          if (latDiff > 0.000005 || lonDiff > 0.000005) {
            _currentLatitude = newLat;
            _currentLongitude = newLon;
            _currentAltitude = newAlt;

            // Track movement để quyết định có hiển thị home marker không
            if (_homePoint != null && _lastDronePosition != null) {
              double distanceFromStart = _calculateDistance(
                _lastDronePosition!.latitude,
                _lastDronePosition!.longitude,
                _currentLatitude,
                _currentLongitude,
              );
              if (distanceFromStart > _movementThreshold) {
                _hasMovedFromStart = true;
              }
            }

            needsMapUpdate = true;
            // print('Map position updated: $_currentLatitude, $_currentLongitude');
          }
        }

        if (needsRotationUpdate) {
          _updateRotationAnimation();
        }
        if (needsMapUpdate) {
          _updateMapPosition();
        }

        // Trigger rebuild to update marker visibility
        setState(() {});
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
    if (_rotationController.isAnimating) {
      _rotationController.stop();
    }

    _rotationAnimation =
        Tween<double>(
          begin: _rotationAnimation.value,
          end: _currentYaw * (pi / 180),
        ).animate(
          CurvedAnimation(parent: _rotationController, curve: Curves.easeInOut),
        );

    _rotationController.reset();
    _rotationController.forward();
  }

  void _updateMapPosition() {
    LatLng newPosition = LatLng(_currentLatitude, _currentLongitude);

    // Nếu chưa zoom về GPS và có GPS fix thì zoom về vị trí GPS
    if (!_hasZoomedToGPS && _telemetryService.hasValidGpsFix) {
      _mapController.move(newPosition, 16.0); // Zoom level 16 để thấy rõ drone
      _hasZoomedToGPS = true;
    } else {
      // Chỉ di chuyển mà không thay đổi zoom
      _mapController.move(newPosition, _mapController.camera.zoom);
    }
  }

  void _resetToDefaultPosition() {
    setState(() {
      if (!_telemetryService.isConnected) {
        _currentLatitude = widget.droneLatitude ?? 10.7302;
        _currentLongitude = widget.droneLongitude ?? 106.6988;
        _hasZoomedToGPS = false; // Reset zoom flag khi disconnect
      }
      _currentAltitude = 0.0;
      _currentYaw = 0.0;
    });
    _updateMapPosition();
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

  // Tính khoảng cách giữa 2 điểm GPS (độ)
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    double latDiff = (lat1 - lat2).abs();
    double lonDiff = (lon1 - lon2).abs();
    return latDiff +
        lonDiff; // Đơn giản hóa, chỉ cần biết có di chuyển hay không
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotationController.dispose();
    _telemetrySubscription?.cancel();
    _connectionSubscription?.cancel();
    _missionSubscription?.cancel();
    super.dispose();
  }
}
