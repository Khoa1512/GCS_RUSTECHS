import 'package:flutter/material.dart';
import 'package:skylink/core/constant/app_image.dart';
import 'package:skylink/data/fake_data.dart';
import 'package:skylink/data/models/drone_information_mode.dart';
import 'package:skylink/presentation/widget/drone/altitude_limitation.dart';
import 'package:skylink/presentation/widget/drone/battery_status.dart';
import 'package:skylink/presentation/widget/drone/camera_quality_setting.dart';
import 'package:skylink/presentation/widget/drone/drone_information_item.dart';
import 'package:skylink/presentation/widget/drone/resolution_setting.dart';
import 'package:skylink/services/telemetry_service.dart';

class DroneInformationSection extends StatefulWidget {
  const DroneInformationSection({super.key});

  @override
  State<DroneInformationSection> createState() =>
      _DroneInformationSectionState();
}

class _DroneInformationSectionState extends State<DroneInformationSection> {
  final TelemetryService _telemetryService = TelemetryService();

  // Generate drone information based on vehicle type
  DroneInformationModel _getDroneInformation(
    String? vehicleType,
    bool isConnected,
  ) {
    if (!isConnected) {
      return DroneInformationModel(
        name: 'No Vehicle Connected',
        image: AppImage.vtol, // Default image
        description: 'Please connect to a vehicle',
      );
    }

    // Map vehicle types to appropriate images and descriptions
    switch (vehicleType?.toLowerCase()) {
      case 'fixed wing':
        return DroneInformationModel(
          name: 'Fixed Wing Aircraft',
          image: AppImage.vtol, // Can add plane icon later
          description: 'Fixed wing aircraft for long range missions',
        );
      case 'vtol':
        return DroneInformationModel(
          name: 'VTOL Aircraft',
          image: AppImage.vtol,
          description: 'Vertical Take-Off and Landing hybrid aircraft',
        );
      case 'quadrotor':
        return DroneInformationModel(
          name: 'Quadrotor Drone',
          image: AppImage.vtol, // Can add quadrotor icon later
          description: 'Four-rotor multicopter for precision flying',
        );
      case 'tricopter':
        return DroneInformationModel(
          name: 'Tricopter Drone',
          image: AppImage.vtol, // Can add tricopter icon later
          description: 'Three-rotor multicopter',
        );
      case 'helicopter':
        return DroneInformationModel(
          name: 'Helicopter',
          image: AppImage.vtol, // Can add helicopter icon later
          description: 'Traditional helicopter',
        );
      case 'coaxial helicopter':
        return DroneInformationModel(
          name: 'Coaxial Helicopter',
          image: AppImage.vtol, // Can add coaxial helicopter icon later
          description: 'Dual-rotor coaxial helicopter',
        );
      default:
        return DroneInformationModel(
          name: vehicleType ?? 'Unknown Vehicle',
          image: AppImage.vtol, // Default image
          description: 'Connected vehicle type: ${vehicleType ?? 'Unknown'}',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.grey.shade800,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: StreamBuilder<bool>(
          stream: _telemetryService.connectionStream,
          initialData: _telemetryService.isConnected,
          builder: (context, connectionSnapshot) {
            final isConnected = connectionSnapshot.data ?? false;
            final vehicleType = _telemetryService.vehicleType;
            final droneInfo = _getDroneInformation(vehicleType, isConnected);

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DroneInformationItem(droneInformation: droneInfo),
                SizedBox(height: 12),
                BatteryStatus(flightInformation: FakeData.fightInformation[0]),
                SizedBox(height: 12),
                AltitudeLimitation(
                  currentAltitude: double.parse(
                    FakeData.fightInformation[0].height,
                  ),
                  maxAltitude: 300.0,
                  onAltitudeChanged: (value) {
                    // Handle altitude change
                  },
                ),
                SizedBox(height: 12),
                ResolutionSetting(
                  currentResolution: FakeData.fightInformation[0].resolution,
                  onResolutionChanged: (value) {
                    // Handle resolution change
                  },
                ),
                SizedBox(height: 12),
                CameraQualitySetting(
                  currentQuality: "hdr",
                  onQualityChanged: (value) {
                    // Handle quality change
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
