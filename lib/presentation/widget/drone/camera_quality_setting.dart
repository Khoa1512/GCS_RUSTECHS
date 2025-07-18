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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Camera Quality Setting",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
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
              ),
              segments: const [
                ButtonSegment<String>(
                  value: 'low',
                  label: Text('Low'),
                  icon: Icon(Icons.camera),
                ),
                ButtonSegment<String>(
                  value: 'medium',
                  label: Text('Medium'),
                  icon: Icon(Icons.camera_alt),
                ),
                ButtonSegment<String>(
                  value: 'high',
                  label: Text('High'),
                  icon: Icon(Icons.high_quality),
                ),
                ButtonSegment<String>(
                  value: 'ultra',
                  label: Text('Ultra'),
                  icon: Icon(Icons.photo_size_select_small),
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
