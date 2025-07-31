import 'package:flutter/material.dart';
import 'package:skylink/core/constant/app_color.dart';
import 'package:skylink/presentation/widget/custom/custom_corner_border.dart';

class ResolutionSetting extends StatefulWidget {
  final String currentResolution;
  final ValueChanged<String>? onResolutionChanged;

  const ResolutionSetting({
    super.key,
    this.currentResolution = "1080p",
    this.onResolutionChanged,
  });

  @override
  State<ResolutionSetting> createState() => _ResolutionSettingState();
}

class _ResolutionSettingState extends State<ResolutionSetting> {
  bool _isHovered = false;
  late String _selectedResolution;
  final List<String> _resolutions = ["720p", "1080p", "1440p", "4K"];

  @override
  void initState() {
    super.initState();
    _selectedResolution = widget.currentResolution;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Resolution Setting",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: MouseRegion(
            onEnter: (_) => setState(() => _isHovered = true),
            onExit: (_) => setState(() => _isHovered = false),
            child: AnimatedContainer(
              duration: Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              transform: Matrix4.identity()..scale(_isHovered ? 1.02 : 1.0),
              child: CustomPaint(
                painter: CornerBorderPainter(),
                child: Container(
                  color: _isHovered
                      ? AppColors.primaryColor
                      : Colors.grey.shade800,
                  padding: EdgeInsets.all(16),
                  width: double.infinity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.high_quality,
                            color: _isHovered
                                ? Colors.black
                                : AppColors.primaryColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _selectedResolution,
                            style: TextStyle(
                              color: _isHovered ? Colors.black : Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildResolutionSelector(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResolutionSelector() {
    return Column(
      children: [
        // Resolution options - Using Wrap for better responsiveness
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _resolutions.map((resolution) {
            final isSelected = _selectedResolution == resolution;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedResolution = resolution;
                });
                widget.onResolutionChanged?.call(resolution);
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: isSelected
                      ? (_isHovered ? Colors.black : AppColors.primaryColor)
                      : Colors.transparent,
                  border: Border.all(
                    color: isSelected
                        ? (_isHovered ? Colors.black : AppColors.primaryColor)
                        : (_isHovered ? Colors.black54 : Colors.white54),
                  ),
                ),
                child: Text(
                  resolution,
                  style: TextStyle(
                    color: isSelected
                        ? (_isHovered ? Colors.white : Colors.black)
                        : (_isHovered ? Colors.black54 : Colors.white54),
                    fontSize: 12,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
