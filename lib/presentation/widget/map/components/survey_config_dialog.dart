import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:skylink/presentation/widget/map/utils/survey_generator.dart';

class SurveyConfigDialog extends StatefulWidget {
  final LatLng? topLeft;
  final LatLng? bottomRight;
  final Function(SurveyConfig) onConfirm;
  final bool isPolygon; // NEW: Flag to indicate polygon survey

  const SurveyConfigDialog({
    super.key,
    this.topLeft,
    this.bottomRight,
    required this.onConfirm,
    this.isPolygon = false, // Default: bounding box survey
  });

  @override
  State<SurveyConfigDialog> createState() => _SurveyConfigDialogState();
}

class _SurveyConfigDialogState extends State<SurveyConfigDialog> {
  double _spacing = 20.0;
  double _angle = 0.0;
  double _altitude = 50.0;
  SurveyPattern _pattern = SurveyPattern.lawnmower;
  double _overlap = 70.0;

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Dialog(
      backgroundColor: Colors.grey.shade900,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.teal.withOpacity(0.3), width: 1),
      ),
      child: Container(
        width: screenWidth > 500 ? 450 : screenWidth * 0.9,
        constraints: BoxConstraints(
          maxHeight: screenHeight * 0.85, // Max 85% of screen height
          maxWidth: 500,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header (fixed)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Icon(Icons.grid_on, color: Colors.teal.shade400, size: 28),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Cấu hình Survey Mission',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Scrollable content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!widget.isPolygon) ...[
                      _buildLabel('Kiểu bay'),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade800,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.teal.withOpacity(0.3),
                          ),
                        ),
                        child: Column(
                          children: [
                            _buildPatternOption(
                              SurveyPattern.lawnmower,
                              'Lawnmower (Zigzag)',
                              'Bay qua lại như cắt cỏ - Phổ biến nhất',
                              Icons.compare_arrows,
                            ),
                            Divider(height: 1, color: Colors.grey.shade700),
                            _buildPatternOption(
                              SurveyPattern.grid,
                              'Grid (Double Grid)',
                              'Bay ngang + dọc - 3D mapping chất lượng cao',
                              Icons.grid_4x4,
                            ),
                            Divider(height: 1, color: Colors.grey.shade700),
                            _buildPatternOption(
                              SurveyPattern.perimeter,
                              'Perimeter (Viền)',
                              'Bay theo viền bounding box',
                              Icons.border_outer,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ] else ...[
                      // Info cho polygon survey
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.teal.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.teal.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.teal,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Polygon survey tự động dùng Lawnmower pattern (tối ưu nhất)',
                                style: TextStyle(
                                  color: Colors.teal.shade200,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Spacing
                    _buildLabel('Khoảng cách giữa các đường bay (m)'),
                    const SizedBox(height: 6),
                    _buildSlider(
                      value: _spacing,
                      min: 5,
                      max: 100,
                      divisions: 19,
                      label: '${_spacing.toInt()}m',
                      onChanged: (value) => setState(() => _spacing = value),
                    ),
                    const SizedBox(height: 12),

                    // Angle
                    _buildLabel('Góc quét (độ)'),
                    const SizedBox(height: 6),
                    _buildSlider(
                      value: _angle,
                      min: 0,
                      max: 180,
                      divisions: 36,
                      label: '${_angle.toInt()}°',
                      onChanged: (value) => setState(() => _angle = value),
                    ),
                    const SizedBox(height: 12),

                    // Altitude
                    _buildLabel('Độ cao (m)'),
                    const SizedBox(height: 6),
                    _buildSlider(
                      value: _altitude,
                      min: 10,
                      max: 200,
                      divisions: 38,
                      label: '${_altitude.toInt()}m',
                      onChanged: (value) => setState(() => _altitude = value),
                    ),
                    const SizedBox(height: 12),

                    // Overlap (for photogrammetry)
                    _buildLabel('Độ chồng lấp ảnh (%)'),
                    const SizedBox(height: 6),
                    _buildSlider(
                      value: _overlap,
                      min: 50,
                      max: 90,
                      divisions: 8,
                      label: '${_overlap.toInt()}%',
                      onChanged: (value) => setState(() => _overlap = value),
                    ),
                    const SizedBox(height: 16),

                    // Info box
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.blue.shade400,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Waypoints sẽ được tạo tự động. Bạn có thể chỉnh sửa sau.',
                              style: TextStyle(
                                color: Colors.blue.shade200,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // Action buttons (fixed at bottom)
            Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.grey.shade800, width: 1),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey.shade400,
                    ),
                    child: const Text('Hủy'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _handleConfirm,
                    label: const Text('Tạo Mission'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.grey.shade300,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildPatternOption(
    SurveyPattern pattern,
    String title,
    String description,
    IconData icon,
  ) {
    final isSelected = _pattern == pattern;
    return InkWell(
      onTap: () => setState(() => _pattern = pattern),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        color: isSelected ? Colors.teal.withOpacity(0.2) : Colors.transparent,
        child: Row(
          children: [
            Radio<SurveyPattern>(
              value: pattern,
              groupValue: _pattern,
              onChanged: (value) => setState(() => _pattern = value!),
              activeColor: Colors.teal,
              visualDensity: VisualDensity.compact,
            ),
            Icon(
              icon,
              color: isSelected ? Colors.teal.shade400 : Colors.grey.shade400,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey.shade300,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlider({
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String label,
    required ValueChanged<double> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade800,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.teal.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                activeTrackColor: Colors.teal,
                inactiveTrackColor: Colors.grey.shade700,
                thumbColor: Colors.teal.shade400,
                overlayColor: Colors.teal.withOpacity(0.2),
                valueIndicatorColor: Colors.teal,
                valueIndicatorTextStyle: const TextStyle(color: Colors.white),
              ),
              child: Slider(
                value: value,
                min: min,
                max: max,
                divisions: divisions,
                label: label,
                onChanged: onChanged,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.teal.withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: Colors.teal.shade400,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleConfirm() {
    final config = SurveyConfig(
      spacing: _spacing,
      angle: _angle,
      altitude: _altitude,
      pattern: _pattern,
      overlap: _overlap,
    );
    widget.onConfirm(config);
    Navigator.pop(context);
  }
}
