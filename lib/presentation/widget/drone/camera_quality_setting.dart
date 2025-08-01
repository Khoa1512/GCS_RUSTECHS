import 'package:flutter/material.dart';
import 'package:skylink/core/constant/app_color.dart';

class CameraQualitySetting extends StatefulWidget {
  final String currentQuality;
  final ValueChanged<String>? onQualityChanged;

  const CameraQualitySetting({
    super.key,
    required this.currentQuality,
    this.onQualityChanged,
  });

  @override
  State<CameraQualitySetting> createState() => _CameraQualitySettingState();
}

class _CameraQualitySettingState extends State<CameraQualitySetting> {
  late String _selectedQuality;

  @override
  void initState() {
    super.initState();
    _selectedQuality = widget.currentQuality;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 1200;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Camera Quality Setting",
          style: TextStyle(
            fontSize: isSmallScreen ? 14 : 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Padding(
          padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.grey.shade800,
            ),
            width: double.infinity,
            child: SegmentedButton<String>(
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: AppColors.primaryColor,
                selectedForegroundColor: Colors.black,
                foregroundColor: Colors.white,
                backgroundColor: Colors.transparent,
                side: BorderSide(color: AppColors.primaryColor),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: TextStyle(fontSize: isSmallScreen ? 10 : 12),
              ),
              segments: [
                ButtonSegment<String>(
                  value: 'low',
                  label: Text('Low'),
                  icon: isSmallScreen ? null : Icon(Icons.camera, size: 16),
                ),
                ButtonSegment<String>(
                  value: 'medium',
                  label: Text(isSmallScreen ? 'Med' : 'Medium'),
                  icon: isSmallScreen ? null : Icon(Icons.camera_alt, size: 16),
                ),
                ButtonSegment<String>(
                  value: 'high',
                  label: Text('High'),
                  icon: isSmallScreen
                      ? null
                      : Icon(Icons.high_quality, size: 16),
                ),
                ButtonSegment<String>(
                  value: 'ultra',
                  label: Text('Ultra'),
                  icon: isSmallScreen
                      ? null
                      : Icon(Icons.photo_size_select_small, size: 16),
                ),
              ],
              selected: {_selectedQuality},
              onSelectionChanged: (Set<String> newSelection) {
                setState(() {
                  _selectedQuality = newSelection.first;
                });
                widget.onQualityChanged?.call(_selectedQuality);
              },
            ),
          ),
        ),
      ],
    );
  }
}
