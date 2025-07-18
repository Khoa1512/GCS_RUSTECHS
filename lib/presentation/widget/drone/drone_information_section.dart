import 'package:flutter/material.dart';
import 'package:skylink/data/fake_data.dart';
import 'package:skylink/presentation/widget/drone/altitude_limitation.dart';
import 'package:skylink/presentation/widget/drone/battery_status.dart';
import 'package:skylink/presentation/widget/drone/camera_quality_setting.dart';
import 'package:skylink/presentation/widget/drone/drone_information_item.dart';
import 'package:skylink/presentation/widget/drone/resolution_setting.dart';

class DroneInformationSection extends StatefulWidget {
  const DroneInformationSection({super.key});

  @override
  State<DroneInformationSection> createState() =>
      _DroneInformationSectionState();
}

class _DroneInformationSectionState extends State<DroneInformationSection> {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.grey.shade800,
      ),
      child: Column(
        children: [
          DroneInformationItem(droneInformation: FakeData.droneInformation[0]),
          BatteryStatus(flightInformation: FakeData.fightInformation[0]),
          AltitudeLimitation(
            currentAltitude: double.parse(FakeData.fightInformation[0].height),
            maxAltitude: 300.0,
            onAltitudeChanged: (value) {
              // Handle altitude change
            },
          ),
          ResolutionSetting(
            currentResolution: FakeData.fightInformation[0].resolution,
            onResolutionChanged: (value) {
              // Handle resolution change
            },
          ),
          CameraQualitySetting(
            currentQuality: "hdr",
            onQualityChanged: (value) {
              // Handle quality change
            },
          ),
        ],
      ),
    );
  }
}
