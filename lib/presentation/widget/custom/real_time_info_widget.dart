import 'package:flutter/material.dart';
import 'package:skylink/core/constant/app_color.dart';
import 'package:skylink/data/telemetry_data.dart';
import 'package:skylink/data/constants/telemetry_constants.dart';
import 'package:skylink/presentation/widget/telemetry/telemetry_selector_dialog.dart';
import 'package:skylink/presentation/widget/telemetry/telemetry_item_widget.dart';
import 'package:skylink/presentation/widget/flight/drone_map_widget.dart';

class RealTimeInfoWidget extends StatefulWidget {
  const RealTimeInfoWidget({super.key});

  @override
  State<RealTimeInfoWidget> createState() => _RealTimeInfoWidgetState();
}

class _RealTimeInfoWidgetState extends State<RealTimeInfoWidget> {
  // Currently displayed telemetry (9 items)
  late List<TelemetryData> displayedTelemetry;

  // Drone position data (Đại học Tôn Đức Thắng coordinates)
  double? droneLatitude = 10.732789;
  double? droneLongitude = 106.699230;
  double? droneAltitude = 85.0;
  double? droneHeading = 45.0;

  @override
  void initState() {
    super.initState();
    // Initialize with default telemetry
    displayedTelemetry = TelemetryConstants.getDefaultTelemetry();
  }

  void _onTelemetrySelected(int index, TelemetryData newTelemetry) {
    setState(() {
      displayedTelemetry[index] = newTelemetry;
    });
  }

  void _showTelemetrySelector(int index) {
    TelemetrySelector.show(
      context: context,
      index: index,
      displayedTelemetry: displayedTelemetry,
      onTelemetrySelected: _onTelemetrySelected,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.grey.shade800, Colors.grey.shade900],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0), // Reduced from 24
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            SizedBox(height: 12), // Reduced from 20
            Expanded(child: _buildMainContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [_buildLiveIndicator()],
    );
  }

  Widget _buildLiveIndicator() {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primaryColor,
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryColor.withValues(alpha: 0.5),
                blurRadius: 8,
                offset: Offset(0, 0),
              ),
            ],
          ),
        ),
        SizedBox(width: 12),
        Text(
          'Live',
          style: TextStyle(
            color: AppColors.primaryColor,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildMainContent() {
    return Row(
      children: [
        _buildMapSection(),
        SizedBox(width: 20),
        _buildTelemetrySection(),
      ],
    );
  }

  Widget _buildMapSection() {
    return Expanded(
      flex: 5,
      child: DroneMapWidget(
        droneLatitude: droneLatitude,
        droneLongitude: droneLongitude,
        droneAltitude: droneAltitude,
        droneHeading: droneHeading,
      ),
    );
  }

  Widget _buildTelemetrySection() {
    return Expanded(
      flex: 4,
      child: Container(
        padding: EdgeInsets.all(12), // Reduced from 20
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.grey.shade900, Colors.black],
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTelemetryHeader(),
            SizedBox(height: 8), // Reduced from 16
            Expanded(child: _buildTelemetryGrid()),
          ],
        ),
      ),
    );
  }

  Widget _buildTelemetryHeader() {
    return Row(
      children: [
        Icon(Icons.analytics_outlined, color: AppColors.primaryColor, size: 18),
        SizedBox(width: 6),
        Text(
          'Flight Telemetry',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildTelemetryGrid() {
    return Column(
      children: [
        Expanded(child: _buildTelemetryRow([0, 1, 2])),
        SizedBox(height: 6), // Reduced from 12
        Expanded(child: _buildTelemetryRow([3, 4, 5])),
        SizedBox(height: 6), // Reduced from 12
        Expanded(child: _buildTelemetryRow([6, 7, 8])),
      ],
    );
  }

  Widget _buildTelemetryRow(List<int> indices) {
    return Row(
      children: [
        for (int i = 0; i < indices.length; i++) ...[
          Expanded(
            child: TelemetryItemWidget(
              telemetry: displayedTelemetry[indices[i]],
              onTap: () => _showTelemetrySelector(indices[i]),
            ),
          ),
          if (i < indices.length - 1) SizedBox(width: 6), // Reduced from 8
        ],
      ],
    );
  }
}
