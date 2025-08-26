import 'package:flutter/material.dart';
import 'package:skylink/core/constant/app_color.dart';
import 'package:skylink/presentation/widget/custom/custom_corner_border.dart';

class AltitudeLimitation extends StatefulWidget {
  final double currentAltitude;
  final double maxAltitude;
  final ValueChanged<double>? onAltitudeChanged;

  const AltitudeLimitation({
    super.key,
    this.currentAltitude = 200.0,
    this.maxAltitude = 300.0,
    this.onAltitudeChanged,
  });

  @override
  State<AltitudeLimitation> createState() => _AltitudeLimitationState();
}

class _AltitudeLimitationState extends State<AltitudeLimitation> {
  bool _isHovered = false;
  late double _selectedAltitude;

  @override
  void initState() {
    super.initState();
    _selectedAltitude = widget.currentAltitude.clamp(10.0, widget.maxAltitude);
  }

  @override
  void didUpdateWidget(AltitudeLimitation oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update selected altitude when widget updates, but keep it in valid range
    if (oldWidget.currentAltitude != widget.currentAltitude) {
      _selectedAltitude = widget.currentAltitude.clamp(
        10.0,
        widget.maxAltitude,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Altitude Limited",
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
                            Icons.height,
                            color: _isHovered
                                ? Colors.black
                                : AppColors.primaryColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "${_selectedAltitude.toInt()} ML",
                            style: TextStyle(
                              color: _isHovered ? Colors.black : Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildAltitudeSlider(),
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

  Widget _buildAltitudeSlider() {
    return Column(
      children: [
        // Altitude scale markers
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (int i = 10; i <= 300; i += 50)
              Container(
                width: 2,
                height: 8,
                color: _isHovered ? Colors.black54 : Colors.white54,
              ),
          ],
        ),
        const SizedBox(height: 4),
        // Slider
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: _isHovered
                ? Colors.black87
                : AppColors.primaryColor,
            inactiveTrackColor: _isHovered ? Colors.black26 : Colors.white24,
            thumbColor: _isHovered ? Colors.black : AppColors.primaryColor,
            overlayColor: _isHovered
                ? Colors.black12
                : AppColors.primaryColor.withOpacity(0.2),
            thumbShape: RoundSliderThumbShape(enabledThumbRadius: 8),
            trackHeight: 4,
          ),
          child: Slider(
            value: _selectedAltitude,
            min: 10,
            max: widget.maxAltitude,
            divisions: 58, // (300-10)/5 = 58 divisions for 5 ML increments
            onChanged: (value) {
              setState(() {
                _selectedAltitude = value;
              });
              widget.onAltitudeChanged?.call(value);
            },
          ),
        ),
        // Scale labels
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (int i = 10; i <= 300; i += 50)
              Text(
                "$i",
                style: TextStyle(
                  color: _isHovered ? Colors.black54 : Colors.white54,
                  fontSize: 10,
                ),
              ),
          ],
        ),
      ],
    );
  }
}
