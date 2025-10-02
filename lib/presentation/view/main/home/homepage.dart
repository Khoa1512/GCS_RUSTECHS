import 'package:flutter/material.dart';
import 'package:skylink/presentation/widget/drone/drone_information_section.dart';
import 'package:skylink/presentation/widget/custom/control_panel_widget.dart';
import 'package:skylink/presentation/widget/custom/real_time_info_widget.dart';
import 'package:skylink/presentation/widget/flight/drone_map_widget.dart';
import 'package:skylink/presentation/widget/flight/primary_flight_display.dart';
import 'package:skylink/presentation/widget/camera/camera_main_view.dart';



class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  // State to track whether we're showing map or camera view
  bool _isMapView = true;

  void _toggleView() {
    setState(() {
      _isMapView = !_isMapView;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildDesktopLayout(),
    );
  }

  Widget _buildDesktopLayout() {
    final screenWidth = MediaQuery.of(context).size.width;
    final paddingValue = screenWidth > 1600 ? 32.0 : 20.0;
    final cameraFlex = screenWidth > 1600 ? 6 : 5;
    final infoPanelFlex = screenWidth > 1600 ? 2 : 2;

    return Padding(
      padding: EdgeInsets.all(paddingValue),
      child: Column(
        children: [
          Expanded(flex: 3, child: _buildMainView()),
          const SizedBox(height: 16),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Expanded(flex: cameraFlex, child: const RealTimeInfoWidget()),
                const SizedBox(width: 16),
                Expanded(flex: infoPanelFlex, child: _buildRightPanel()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainView() {
    return Row(
      children: [
        Expanded(flex: 4, child: PrimaryFlightDisplay()),
        const SizedBox(width: 16),
        Expanded(flex: 6, child: _buildMapOrCameraView()),
      ],
    );
  }

  Widget _buildMapOrCameraView() {
    return Stack(
      children: [
        // Main view (Map or Camera) - using IndexedStack to preserve state
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: IndexedStack(
              index: _isMapView ? 0 : 1,
              children: [
                // Map view (index 0)
                DroneMapWidget(
                  droneLatitude: 10.732789,
                  droneLongitude: 106.699230,
                  droneAltitude: 100,
                  droneHeading: 0,
                ),
                // Camera view (index 1)
                CameraMainView(),
              ],
            ),
          ),
        ),
        // Toggle button overlay
        Positioned(top: 16, right: 16, child: _buildToggleButton()),
      ],
    );
  }

  Widget _buildToggleButton() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: _toggleView,
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isMapView ? Icons.videocam : Icons.map,
                  color: Colors.white,
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  _isMapView ? 'Camera' : 'Map',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRightPanel() {
    // Switch between DroneInformationSection (for Map) and ControlPanelWidget (for Camera)
    return _isMapView
        ? const DroneInformationSection()
        : const ControlPanelWidget();
  }
}
