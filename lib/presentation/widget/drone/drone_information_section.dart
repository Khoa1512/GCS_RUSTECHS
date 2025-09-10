import 'package:flutter/material.dart';
import 'package:skylink/core/constant/app_image.dart';
import 'package:skylink/data/models/drone_information_mode.dart';
import 'package:skylink/presentation/widget/drone/altitude_limitation.dart';
import 'package:skylink/presentation/widget/drone/battery_status.dart';
import 'package:skylink/presentation/widget/drone/drone_information_item.dart';
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
      case 'hexarotor':
        return DroneInformationModel(
          name: 'Hexarotor Drone',
          image: AppImage.vtol,
          description: 'Six-rotor multicopter for heavy lifting',
        );
      case 'octorotor':
        return DroneInformationModel(
          name: 'Octorotor Drone',
          image: AppImage.vtol,
          description: 'Eight-rotor multicopter for maximum stability',
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
        child: StreamBuilder<Map<String, dynamic>>(
          stream: _telemetryService.telemetryStream,
          builder: (context, telemetrySnapshot) {
            return StreamBuilder<bool>(
              stream: _telemetryService.connectionStream,
              builder: (context, connectionSnapshot) {
                // Check all connection sources
                // final streamConnection = connectionSnapshot.data;
                final serviceConnection = _telemetryService.isConnected;
                // final hasStreamData = connectionSnapshot.hasData;

                // Use service connection as primary source (same as app bar)
                final isConnected = serviceConnection;
                final vehicleType = _telemetryService.vehicleType;

                final droneInfo = _getDroneInformation(
                  vehicleType,
                  isConnected,
                );

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DroneInformationItem(droneInformation: droneInfo),
                    SizedBox(height: 12),
                    BatteryStatus(),
                    SizedBox(height: 12),
                    AltitudeLimitation(
                      currentAltitude: _telemetryService.isConnected
                          ? (_telemetryService.gpsAltitude > 10.0
                                ? _telemetryService.gpsAltitude
                                : 10.0)
                          : 10.0, // Default to minimum value when disconnected
                      maxAltitude: 300.0,
                      onAltitudeChanged: (value) {
                        // Handle altitude change
                      },
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}
