import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:skylink/core/constant/app_color.dart';
import 'package:skylink/core/constant/map_type.dart';

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

  @override
  void initState() {
    super.initState();

    // Initialize map controller and select Satellite Map
    _mapController = MapController();
    _selectedMapType = mapTypes.firstWhere(
      (mapType) => mapType.name == 'Satellite Map',
      orElse: () => mapTypes.first,
    );

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
    _rotationAnimation =
        Tween<double>(
          begin: 0,
          end:
              (widget.droneHeading ?? 0) *
              (3.14159 / 180), // Convert to radians
        ).animate(
          CurvedAnimation(parent: _rotationController, curve: Curves.easeInOut),
        );
    _rotationController.forward();

    // The map will automatically center using initialCenter in MapOptions
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(DroneMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Update rotation when heading changes
    if (widget.droneHeading != oldWidget.droneHeading) {
      _rotationAnimation =
          Tween<double>(
            begin: _rotationAnimation.value,
            end: (widget.droneHeading ?? 0) * (3.14159 / 180),
          ).animate(
            CurvedAnimation(
              parent: _rotationController,
              curve: Curves.easeInOut,
            ),
          );
      _rotationController.reset();
      _rotationController.forward();
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
        initialCenter:
            widget.droneLatitude != null && widget.droneLongitude != null
            ? LatLng(widget.droneLatitude!, widget.droneLongitude!)
            : LatLng(10.732789, 106.699230),
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

        // Drone marker
        if (widget.droneLatitude != null && widget.droneLongitude != null)
          MarkerLayer(
            markers: [
              Marker(
                point: LatLng(widget.droneLatitude!, widget.droneLongitude!),
                width: 40,
                height: 40,
                alignment: Alignment.center,
                child: _buildDroneMarker(),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildDroneMarker() {
    return AnimatedBuilder(
      animation: Listenable.merge([_pulseAnimation, _rotationAnimation]),
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Transform.rotate(
            angle: _rotationAnimation.value,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primaryColor,
                    AppColors.primaryColor.withValues(alpha: 0.8),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryColor.withValues(alpha: 0.6),
                    blurRadius: 15,
                    offset: Offset(0, 0),
                  ),
                  BoxShadow(
                    color: AppColors.primaryColor.withValues(alpha: 0.3),
                    blurRadius: 25,
                    offset: Offset(0, 0),
                  ),
                ],
              ),
              child: Icon(Icons.flight, size: 20, color: Colors.white),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMapInfoOverlay() {
    return Positioned(
      top: 16,
      left: 16,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.black.withValues(alpha: 0.7),
          border: Border.all(
            color: AppColors.primaryColor.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.gps_fixed, size: 16, color: AppColors.primaryColor),
            SizedBox(width: 6),
            Text(
              'GPS Lock',
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
                color: AppColors.primaryColor,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryColor.withValues(alpha: 0.5),
                    blurRadius: 4,
                    offset: Offset(0, 0),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
