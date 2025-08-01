import 'package:flutter/material.dart';
import 'package:skylink/presentation/widget/camera/camera_main_view.dart';
import 'package:skylink/presentation/widget/drone/drone_information_section.dart';
import 'package:skylink/presentation/widget/custom/control_panel_widget.dart';
import 'package:skylink/presentation/widget/custom/real_time_info_widget.dart';
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // TODO: Add mobile layout content
        ],
      ),
    );
  }

  Widget _buildTabletLayout() {
    return TabletBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // TODO: Add tablet layout content
        ],
      ),
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
          // Camera/Map section (60% of screen)
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Expanded(flex: cameraFlex, child: _buildMainView()),
                const SizedBox(width: 16),
                Expanded(
                  flex: infoPanelFlex,
                  child: const DroneInformationSection(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Real-time info section (40% of screen)
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Expanded(flex: cameraFlex, child: const RealTimeInfoWidget()),
                const SizedBox(width: 16),
                Expanded(
                  flex: infoPanelFlex,
                  child: const ControlPanelWidget(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainView() {
    // For now, show camera view by default
    // Later you can add logic to switch between camera and map
    return const CameraMainView();
  }
}
