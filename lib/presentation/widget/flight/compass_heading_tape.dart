import 'package:flutter/material.dart';

class CompassHeadingTape extends StatefulWidget {
  final double heading; // Current heading 0-359°
  final double height; // Height of the tape
  final Color backgroundColor;
  final Color centerMarkerColor;
  final Color textColor;
  final Color tickColor;

  const CompassHeadingTape({
    super.key,
    required this.heading,
    this.height = 50,
    this.backgroundColor = const Color(0xFF2A3441),
    this.centerMarkerColor = const Color(0xFFFF9800),
    this.textColor = Colors.white,
    this.tickColor = Colors.white70,
  });

  @override
  State<CompassHeadingTape> createState() => _CompassHeadingTapeState();
}

class _CompassHeadingTapeState extends State<CompassHeadingTape>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _headingAnimation;
  double _previousHeading = 0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 500),
      vsync: this,
    );

    _previousHeading = widget.heading;
    _headingAnimation =
        Tween<double>(begin: widget.heading, end: widget.heading).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeInOut,
          ),
        );
  }

  @override
  void didUpdateWidget(CompassHeadingTape oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.heading != oldWidget.heading) {
      _updateHeadingAnimation();
    }
  }

  void _updateHeadingAnimation() {
    double newHeading = widget.heading;
    double oldHeading = _headingAnimation.value;

    // Handle 360/0 degree wrap-around for smooth animation
    if ((newHeading - oldHeading).abs() > 180) {
      if (newHeading > oldHeading) {
        oldHeading += 360;
      } else {
        newHeading += 360;
      }
    }

    _headingAnimation = Tween<double>(begin: oldHeading, end: newHeading)
        .animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeInOut,
          ),
        );

    _animationController.reset();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Container(
        height: widget.height,
        decoration: BoxDecoration(
          color: widget.backgroundColor,
          border: Border(
            bottom: BorderSide(
              color: widget.centerMarkerColor.withOpacity(0.3),
              width: 1,
            ),
          ),
        ),
        child: AnimatedBuilder(
          animation: _headingAnimation,
          builder: (context, child) {
            return CustomPaint(
              size: Size.infinite,
              painter: CompassHeadingTapePainter(
                heading: _headingAnimation.value % 360,
                centerMarkerColor: widget.centerMarkerColor,
                textColor: widget.textColor,
                tickColor: widget.tickColor,
              ),
            );
          },
        ),
      ),
    );
  }
}

class CompassHeadingTapePainter extends CustomPainter {
  final double heading;
  final Color centerMarkerColor;
  final Color textColor;
  final Color tickColor;

  CompassHeadingTapePainter({
    required this.heading,
    required this.centerMarkerColor,
    required this.textColor,
    required this.tickColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    // Draw heading scale from -90° to +90° relative to current heading
    for (int offset = -90; offset <= 90; offset += 15) {
      double displayHeading = (heading + offset) % 360;
      if (displayHeading < 0) displayHeading += 360;

      final x = center.dx + (offset * size.width / 180); // Scale factor

      if (x < -40 || x > size.width + 40) continue;

      bool isMajor = offset % 30 == 0; // Major ticks every 30°
      bool isCenter = offset == 0; // Center position
      bool isCardinal = _isCardinalDirection(displayHeading);

      // Draw tick marks
      _drawTickMark(canvas, x, size, isMajor, isCenter, isCardinal);

      // Draw labels for major ticks
      if (isMajor) {
        _drawHeadingLabel(canvas, textPainter, x, displayHeading, isCenter);
      }
    }

    // Draw center marker (triangle pointer)
    _drawCenterMarker(canvas, center, size);

    // Remove current heading display - numbers are already shown on the tape
    // _drawCurrentHeadingDisplay(canvas, textPainter, center, size);
  }

  void _drawTickMark(
    Canvas canvas,
    double x,
    Size size,
    bool isMajor,
    bool isCenter,
    bool isCardinal,
  ) {
    Color tickColor = this.tickColor;
    double strokeWidth = 1;
    double tickHeight = 8;

    if (isCenter) {
      tickColor = centerMarkerColor;
      strokeWidth = 3;
      tickHeight = 15;
    } else if (isCardinal) {
      tickColor = textColor;
      strokeWidth = 2;
      tickHeight = 12;
    } else if (isMajor) {
      strokeWidth = 1.5;
      tickHeight = 10;
    }

    final tickPaint = Paint()
      ..color = tickColor
      ..strokeWidth = strokeWidth;

    canvas.drawLine(
      Offset(x, size.height - tickHeight - 5),
      Offset(x, size.height - 5),
      tickPaint,
    );
  }

  void _drawHeadingLabel(
    Canvas canvas,
    TextPainter textPainter,
    double x,
    double displayHeading,
    bool isCenter,
  ) {
    String cardinalLabel = _getCardinalDirection(displayHeading);
    String degreeLabel = displayHeading.toInt().toString();

    Color labelColor = isCenter ? centerMarkerColor : textColor;

    // Draw cardinal direction (if applicable)
    if (cardinalLabel.isNotEmpty) {
      textPainter.text = TextSpan(
        text: cardinalLabel,
        style: TextStyle(
          color: labelColor,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x - textPainter.width / 2, 2));

      // Draw degree number below cardinal
      textPainter.text = TextSpan(
        text: degreeLabel,
        style: TextStyle(
          color: labelColor,
          fontSize: 11,
          fontWeight: FontWeight.w500,
          fontFamily: 'monospace',
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x - textPainter.width / 2, 18));
    } else {
      // Draw only degree number
      textPainter.text = TextSpan(
        text: degreeLabel,
        style: TextStyle(
          color: labelColor,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          fontFamily: 'monospace',
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x - textPainter.width / 2, 8));
    }
  }

  void _drawCenterMarker(Canvas canvas, Offset center, Size size) {
    // Draw triangle pointer at center
    final trianglePaint = Paint()
      ..color = centerMarkerColor
      ..style = PaintingStyle.fill;

    final trianglePath = Path();
    trianglePath.moveTo(center.dx, size.height - 2);
    trianglePath.lineTo(center.dx - 8, size.height - 15);
    trianglePath.lineTo(center.dx + 8, size.height - 15);
    trianglePath.close();

    canvas.drawPath(trianglePath, trianglePaint);

    // Add white outline
    final outlinePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawPath(trianglePath, outlinePaint);
  }


  String _getCardinalDirection(double heading) {
    // Normalize heading to 0-360
    heading = heading % 360;
    if (heading < 0) heading += 360;

    // Define cardinal and intercardinal directions
    if (heading >= 337.5 || heading < 22.5) return 'N'; // 0°
    if (heading >= 22.5 && heading < 67.5) return 'NE'; // 45°
    if (heading >= 67.5 && heading < 112.5) return 'E'; // 90°
    if (heading >= 112.5 && heading < 157.5) return 'SE'; // 135°
    if (heading >= 157.5 && heading < 202.5) return 'S'; // 180°
    if (heading >= 202.5 && heading < 247.5) return 'SW'; // 225°
    if (heading >= 247.5 && heading < 292.5) return 'W'; // 270°
    if (heading >= 292.5 && heading < 337.5) return 'NW'; // 315°

    return ''; // No cardinal direction
  }

  bool _isCardinalDirection(double heading) {
    return _getCardinalDirection(heading).isNotEmpty;
  }

  @override
  bool shouldRepaint(CompassHeadingTapePainter oldDelegate) {
    return oldDelegate.heading != heading;
  }
}
