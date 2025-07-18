import 'package:flutter/material.dart';
import 'package:skylink/presentation/widget/camera/camera_main_view.dart';
import 'package:skylink/presentation/widget/drone/drone_information_section.dart';
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
    return Column(
      children: [
        Row(
          children: [
            Expanded(flex: 5, child: CameraMainView()),
            SizedBox(width: 16),
            Expanded(flex: 2, child: DroneInformationSection()),
          ],
        ),
        // Row(
        //   children: [
        //     Expanded(flex: 1, child: RealTimeInforSection()),
        //     SizedBox(width: 16),
        //   ],
        // ),
      ],
    );
  }
}
