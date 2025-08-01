import 'package:flutter/material.dart';
import 'package:skylink/presentation/widget/camera/camera_main_view.dart';
import 'package:skylink/presentation/widget/drone/drone_information_section.dart';
import 'package:skylink/presentation/widget/custom/control_panel_widget.dart';
import 'package:skylink/presentation/widget/custom/real_time_info_widget.dart';
import 'package:skylink/presentation/widget/connection/connection_widget.dart'
    as connection;
import 'package:skylink/presentation/widget/flight/drone_map_widget.dart';
import 'package:skylink/responsive/responsive_layout.dart';
import 'package:skylink/responsive/mobile_body.dart';
import 'package:skylink/responsive/tablet_body.dart';

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  connection.ConnectionState _connectionState =
      connection.ConnectionState.disconnected;

  // Drone data
  double? droneLatitude;
  double? droneLongitude;
  double? droneAltitude;
  double? droneHeading;

  void _onConnectionStateChanged(connection.ConnectionState newState) {
    // print('Connection state changing from $_connectionState to $newState');

    setState(() {
      _connectionState = newState;

      // Update global connection manager
      connection.ConnectionManager.updateState(
        newState,
        onDisconnect: _disconnect,
      );

      // Simulate receiving GPS data when connected
      if (newState != connection.ConnectionState.disconnected) {
        droneLatitude = 10.732789;
        droneLongitude = 106.699230;
        droneAltitude = 85.0;
        droneHeading = 45.0;
      } else {
        droneLatitude = null;
        droneLongitude = null;
        droneAltitude = null;
        droneHeading = null;
      }
    });

  }

  void _simulateConnection() {
    // Simulate connection flow: disconnected -> GPS -> fully connected
    Future.delayed(Duration(milliseconds: 500), () {
      _onConnectionStateChanged(connection.ConnectionState.gpsConnected);
    });

    Future.delayed(Duration(milliseconds: 2500), () {
      _onConnectionStateChanged(connection.ConnectionState.fullyConnected);
    });
  }

  void _disconnect() {
    if (_connectionState != connection.ConnectionState.disconnected) {
      _onConnectionStateChanged(connection.ConnectionState.disconnected);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ResponsiveLayout(
        mobile: _buildMobileLayout(),
        tablet: _buildTabletLayout(),
        desktop: _buildDesktopLayout(),
      ),
    );
  }

  Widget _buildMobileLayout() {
    return MobileBody(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ],
      ),
    );
  }

  Widget _buildTabletLayout() {
    return TabletBody(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        ],
      ),
    );
  }

  Widget _buildDesktopLayout() {
    // Show connection screen if disconnected
    if (_connectionState == connection.ConnectionState.disconnected) {
      return _buildConnectionScreen();
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // Prioritize camera and real-time sections as they are more important
    final paddingValue = screenWidth > 1600 ? 32.0 : 20.0;

    // Camera/Real-time sections get much more space (5:2 ratio)
    final cameraFlex = screenWidth > 1600 ? 6 : 5;
    final infoPanelFlex = screenWidth > 1600 ? 2 : 2;

    return Padding(
      padding: EdgeInsets.all(paddingValue),
      child: Column(
        children: [
          // Camera section gets more vertical space (60% of screen)
          Expanded(
            flex: 3, // Increased from 1 to 3 for more camera space
            child: Row(
              children: [
                Expanded(flex: cameraFlex, child: _buildCameraOrMapView()),
                SizedBox(width: 16),
                Expanded(flex: infoPanelFlex, child: DroneInformationSection()),
              ],
            ),
          ),
          SizedBox(height: 16),
          // Real-time info section (40% of screen)
          Expanded(
            flex:
                2, // Reduced from 1 to 2, still important but less than camera
            child: Row(
              children: [
                Expanded(flex: cameraFlex, child: RealTimeInfoWidget()),
                SizedBox(width: 16),
                Expanded(flex: infoPanelFlex, child: ControlPanelWidget()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionScreen() {
    return connection.ConnectionWidget(
      connectionState: _connectionState,
      onConnectPressed: _simulateConnection,
      onDisconnectPressed: _disconnect,
    );
  }

  Widget _buildCameraOrMapView() {
    // If fully connected (gimbal available), show camera
    if (_connectionState == connection.ConnectionState.fullyConnected) {
      return CameraMainView();
    }

    // If only GPS connected, show large map view
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.black,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: DroneMapWidget(
              droneLatitude: droneLatitude,
              droneLongitude: droneLongitude,
              droneAltitude: droneAltitude,
              droneHeading: droneHeading,
            ),
          ),
          // Status overlay
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange.shade600.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.videocam_off, size: 16, color: Colors.white),
                  SizedBox(width: 6),
                  Text(
                    'Camera Offline',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
