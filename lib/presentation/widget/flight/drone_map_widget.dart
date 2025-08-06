import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:skylink/core/constant/map_type.dart';
import 'package:skylink/services/telemetry_service.dart';
import 'dart:async';

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

  // Telemetry service for real-time data
  final TelemetryService _telemetryService = TelemetryService();
  StreamSubscription? _telemetrySubscription;
  StreamSubscription? _connectionSubscription;
  double _currentYaw = 0.0;
  double _currentLatitude = 10.7302; // Default: Trường ĐH Tôn Đức Thắng
  double _currentLongitude = 106.6988; // Default: Trường ĐH Tôn Đức Thắng
  double _currentAltitude = 0.0;

  @override
  void initState() {
    super.initState();

    // Initialize map controller and select Satellite Map
    _mapController = MapController();
    _selectedMapType = mapTypes.firstWhere(
      (mapType) => mapType.name == 'Satellite Map',
      orElse: () => mapTypes.first,
    );

    // Initialize current position from widget or default
    _currentYaw = widget.droneHeading ?? 0.0;
        // Set default position
    _currentLatitude = widget.droneLatitude ?? 10.7302; // Default: Trường ĐH Tôn Đức Thắng
    _currentLongitude = widget.droneLongitude ?? 106.6988; // Default: Trường ĐH Tôn Đức Thắng
    _currentAltitude = widget.droneAltitude ?? 0.0;

    // Pulse animation for drone indicator
    _pulseController = AnimationController(
      duration: Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);

    // Rotation animation for drone heading
    _rotationController = AnimationController(
      duration: Duration(milliseconds: 500),
      vsync: this,
    );
    
    // Initialize rotation animation first
    _rotationAnimation = Tween<double>(
      begin: 0,
      end: _currentYaw * (3.14159 / 180),
    ).animate(
      CurvedAnimation(parent: _rotationController, curve: Curves.easeInOut),
    );
    
    _rotationController.forward();

    // Listen to telemetry stream for real-time yaw updates
    _listenToTelemetryStream();
    
    // Listen to connection state changes
    _listenToConnectionState();
    
    // Force initial GPS position update
    _forceUpdateGpsPosition();
  }

  void _forceUpdateGpsPosition() {
    // Try to get GPS position immediately when widget initializes
    if (_telemetryService.hasValidGpsFix) {
      _currentLatitude = _telemetryService.gpsLatitude;
      _currentLongitude = _telemetryService.gpsLongitude;
      _currentAltitude = _telemetryService.gpsAltitude;
    }
  }

  // Debug method to check GPS data
  void debugGpsData() {
    // Debug method available for manual debugging if needed
  }

  // Reset to default position when disconnected
  void _resetToDefaultPosition() {
    setState(() {
      // Only reset position if FC is completely disconnected
      // Don't reset if FC is connected but just missing GPS
      if (!_telemetryService.isConnected) {
        _currentLatitude = widget.droneLatitude ?? 10.7302; // Default: Trường ĐH Tôn Đức Thắng
        _currentLongitude = widget.droneLongitude ?? 106.6988; // Default: Trường ĐH Tôn Đức Thắng
      }
      _currentAltitude = 0.0;
      _currentYaw = 0.0;
    });
    
    // Also move map to default position
    _updateMapPosition();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotationController.dispose();
    _telemetrySubscription?.cancel();
    _connectionSubscription?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(DroneMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Update rotation when heading changes from widget
    if (widget.droneHeading != oldWidget.droneHeading) {
      _currentYaw = widget.droneHeading ?? _currentYaw;
      _updateRotationAnimation();
    }

    // Update map position when drone coordinates change
    if ((widget.droneLatitude != oldWidget.droneLatitude ||
            widget.droneLongitude != oldWidget.droneLongitude) &&
        widget.droneLatitude != null &&
        widget.droneLongitude != null) {
      _mapController.move(
        LatLng(widget.droneLatitude!, widget.droneLongitude!),
        _mapController.camera.zoom,
      );
    }
  }

  void _listenToConnectionState() {
    // Listen to connection state changes to reset GPS position when disconnected
    _connectionSubscription = _telemetryService.connectionStream.listen((isConnected) {
      if (mounted) {
        if (!isConnected) {
          // Reset to default position when disconnected
          _resetToDefaultPosition();
        }
      }
    });
  }

  void _listenToTelemetryStream() {
    // Listen to telemetry stream for real-time updates
    _telemetrySubscription = _telemetryService.telemetryStream.listen((
      telemetryData,
    ) {
      if (mounted) {
        bool needsMapUpdate = false;
        bool needsRotationUpdate = false;

        // Update yaw/heading
        if (telemetryData.containsKey('yaw')) {
          double newYaw = telemetryData['yaw'] ?? 0.0;
          if ((_currentYaw - newYaw).abs() > 1.0) {
            // Only update if significant change
            _currentYaw = newYaw;
            needsRotationUpdate = true;
          }
        }

        // Update GPS position if available and valid
        if (_telemetryService.hasValidGpsFix) {
          double newLat = telemetryData['gps_latitude'] ?? _currentLatitude;
          double newLon = telemetryData['gps_longitude'] ?? _currentLongitude;
          double newAlt = telemetryData['gps_altitude'] ?? _currentAltitude;

          // Check if position changed significantly (approximately 0.5 meters)
          double latDiff = (_currentLatitude - newLat).abs();
          double lonDiff = (_currentLongitude - newLon).abs();
          
          if (latDiff > 0.000005 || lonDiff > 0.000005) {
            _currentLatitude = newLat;
            _currentLongitude = newLon;
            _currentAltitude = newAlt;
            needsMapUpdate = true;
          }
        }
        // Note: Don't update GPS coordinates when no valid fix
        // Keep last known good position or default position

        // Apply updates
        if (needsRotationUpdate) {
          _updateRotationAnimation();
        }
        if (needsMapUpdate) {
          _updateMapPosition();
        }
      }
    });
  }

  void _updateRotationAnimation() {
    if (_rotationController.isAnimating) {
      _rotationController.stop();
    }
    
    _rotationAnimation = Tween<double>(
      begin: _rotationAnimation.value,
      end: _currentYaw * (3.14159 / 180), // Convert degrees to radians
    ).animate(
      CurvedAnimation(parent: _rotationController, curve: Curves.easeInOut),
    );
    
    _rotationController.reset();
    _rotationController.forward();
  }

  void _updateMapPosition() {
    // Update map position to follow drone
    _mapController.move(
      LatLng(_currentLatitude, _currentLongitude),
      _mapController.camera.zoom,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Background container to prevent white flash
            Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 0.8,
                  colors: [Colors.grey.shade600, Colors.grey.shade800],
                ),
              ),
            ),
            _buildFlutterMap(),
            _buildMapInfoOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildFlutterMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: LatLng(_currentLatitude, _currentLongitude),
        initialZoom: 18,
        minZoom: 1,
        maxZoom: 22,
        interactionOptions: InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
      ),
      children: [
        // Base map tiles (Satellite Map)
        TileLayer(
          urlTemplate: _selectedMapType.urlTemplate,
          userAgentPackageName: "com.example.vtol_rustech",
          maxZoom: 22,
          errorTileCallback: (tile, error, stackTrace) {
            print('Tile loading error: $error');
          },
        ),

        // Drone marker - use GPS position with StreamBuilder for real-time updates
        StreamBuilder<Map<String, double>>(
          stream: _telemetryService.telemetryStream,
          builder: (context, snapshot) {
            // Only show marker if we have valid GPS connection AND valid GPS fix
            bool shouldShowMarker = false;
            LatLng? markerPosition;
            
            if (_telemetryService.isConnected && _telemetryService.hasValidGpsFix) {
              // Connected with valid GPS - show marker at GPS position
              markerPosition = LatLng(_currentLatitude, _currentLongitude);
              shouldShowMarker = true;
            }
            // If not connected OR no GPS fix - don't show marker at all
            
            return MarkerLayer(
              markers: shouldShowMarker && markerPosition != null ? [
                Marker(
                  point: markerPosition,
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  child: _buildDroneMarker(),
                ),
              ] : [], // Empty list = no markers
            );
          },
        ),
      ],
    );
  }

  Widget _buildDroneMarker() {
    // Determine drone marker color based on GPS status
    Color droneColor = _telemetryService.hasValidGpsFix 
      ? _getGpsStatusColor() 
      : Colors.grey;
    
    return AnimatedBuilder(
      animation: Listenable.merge([_pulseAnimation, _rotationAnimation]),
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Transform.rotate(
            angle: _rotationAnimation.value,
            child: Stack(
              children: [
                // Main drone marker
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        droneColor,
                        droneColor.withValues(alpha: 0.8),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: droneColor.withValues(alpha: 0.6),
                        blurRadius: 15,
                        offset: Offset(0, 0),
                      ),
                      BoxShadow(
                        color: droneColor.withValues(alpha: 0.3),
                        blurRadius: 25,
                        offset: Offset(0, 0),
                      ),
                    ],
                  ),
                  child: Icon(Icons.flight, size: 20, color: Colors.white),
                ),
                // GPS status indicator
                if (_telemetryService.hasValidGpsFix)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _getGpsStatusColor(),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
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

  Widget _buildMapInfoOverlay() {
    return Positioned(
      top: 16,
      left: 16,
      child: StreamBuilder<Map<String, double>>(
        stream: _telemetryService.telemetryStream,
        builder: (context, snapshot) {
          final hasGps = _telemetryService.hasValidGpsFix;
          final satellites = _telemetryService.currentTelemetry['satellites']?.toInt() ?? 0;
          final gpsAccuracy = _telemetryService.gpsAccuracyString;
          
          return Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.black.withValues(alpha: 0.7),
              border: Border.all(
                color: hasGps ? _getGpsStatusColor().withValues(alpha: 0.3) : Colors.red.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      hasGps ? Icons.gps_fixed : Icons.gps_off,
                      size: 16,
                      color: hasGps ? _getGpsStatusColor() : Colors.red,
                    ),
                    SizedBox(width: 6),
                    Text(
                      hasGps ? _telemetryService.gpsFixType : 'No GPS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(width: 8),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: hasGps ? _getGpsStatusColor() : Colors.red,
                        boxShadow: [
                          BoxShadow(
                            color: (hasGps ? _getGpsStatusColor() : Colors.red).withValues(alpha: 0.5),
                            blurRadius: 4,
                            offset: Offset(0, 0),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (hasGps) ...[
                  SizedBox(height: 4),
                  Text(
                    'Sats: $satellites | $gpsAccuracy',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 10,
                    ),
                  ),
                  Text(
                    'Lat: ${_currentLatitude.toStringAsFixed(6)}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 10,
                    ),
                  ),
                  Text(
                    'Lon: ${_currentLongitude.toStringAsFixed(6)}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 10,
                    ),
                  ),
                  SizedBox(height: 2),
                  GestureDetector(
                    onTap: debugGpsData,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Debug GPS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
