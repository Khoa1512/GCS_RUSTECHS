import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';

/// Modern Glass Cockpit Primary Flight Display
/// Features: Frosted glass panel, smooth animations, arc compass, status cards
class GlassPrimaryFlightDisplay extends StatefulWidget {
  final double roll;
  final double pitch;
  final double heading;
  final double altitude;
  final double airspeed;
  final double batteryPercent;
  final bool hasGpsLock;
  final int linkQuality; // 0-100%

  const GlassPrimaryFlightDisplay({
    super.key,
    required this.roll,
    required this.pitch,
    required this.heading,
    required this.altitude,
    required this.airspeed,
    this.batteryPercent = 100.0,
    this.hasGpsLock = true,
    this.linkQuality = 100,
  });

  @override
  State<GlassPrimaryFlightDisplay> createState() =>
      _GlassPrimaryFlightDisplayState();
}

class _GlassPrimaryFlightDisplayState extends State<GlassPrimaryFlightDisplay>
    with TickerProviderStateMixin {
  // Animated values for smooth transitions
  late AnimationController _animationController;
  late Animation<double> _rollAnimation;
  late Animation<double> _pitchAnimation;
  late Animation<double> _headingAnimation;
  late Animation<double> _altitudeAnimation;
  late Animation<double> _airspeedAnimation;

  // Previous values for interpolation
  double _previousRoll = 0;
  double _previousPitch = 0;
  double _previousHeading = 0;
  double _previousAltitude = 0;
  double _previousAirspeed = 0;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200), // Smooth 200ms transitions
      vsync: this,
    );

    _rollAnimation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _pitchAnimation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _headingAnimation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _altitudeAnimation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _airspeedAnimation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
  }

  @override
  void didUpdateWidget(GlassPrimaryFlightDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Update animations when new telemetry arrives
    if (_shouldUpdateAnimations(oldWidget)) {
      _updateAnimations();
    }
  }

  bool _shouldUpdateAnimations(GlassPrimaryFlightDisplay oldWidget) {
    return oldWidget.roll != widget.roll ||
        oldWidget.pitch != widget.pitch ||
        oldWidget.heading != widget.heading ||
        oldWidget.altitude != widget.altitude ||
        oldWidget.airspeed != widget.airspeed;
  }

  void _updateAnimations() {
    // Update Tween ranges and restart animation
    _rollAnimation = Tween<double>(begin: _previousRoll, end: widget.roll)
        .animate(
          CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
        );

    _pitchAnimation = Tween<double>(begin: _previousPitch, end: widget.pitch)
        .animate(
          CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
        );

    // Handle heading wrap-around (359° -> 1°)
    double headingDelta = widget.heading - _previousHeading;
    if (headingDelta > 180) headingDelta -= 360;
    if (headingDelta < -180) headingDelta += 360;

    _headingAnimation =
        Tween<double>(
          begin: _previousHeading,
          end: _previousHeading + headingDelta,
        ).animate(
          CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
        );

    _altitudeAnimation =
        Tween<double>(begin: _previousAltitude, end: widget.altitude).animate(
          CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
        );

    _airspeedAnimation =
        Tween<double>(begin: _previousAirspeed, end: widget.airspeed).animate(
          CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
        );

    // Update previous values
    _previousRoll = widget.roll;
    _previousPitch = widget.pitch;
    _previousHeading = widget.heading;
    _previousAltitude = widget.altitude;
    _previousAirspeed = widget.airspeed;

    // Start animation
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
    return Container(
      width: 400,
      height: 320,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(
                0xFF0A0A0A,
              ).withOpacity(0.85), // Semi-transparent dark
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF00E5FF).withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Stack(
              children: [
                // Main content
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Top row: Status + Compass
                      Row(
                        children: [
                          // Status bar (left side)
                          Expanded(child: _buildStatusBar()),

                          const SizedBox(width: 8),

                          // Compact compass (right side)
                          Container(
                            width: 120,
                            height: 40,
                            child: _buildCompactCompass(),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Main instruments row
                      Expanded(
                        child: Row(
                          children: [
                            // Speed readout (left)
                            _buildSpeedCard(),

                            const SizedBox(width: 12),

                            // Central attitude indicator
                            Expanded(child: _buildAttitudeIndicator()),

                            const SizedBox(width: 12),

                            // Altitude readout (right)
                            _buildAltitudeCard(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildStatusCard(
          icon: Icons.battery_std,
          value: "${widget.batteryPercent.toInt()}%",
          color: widget.batteryPercent > 20
              ? Colors.greenAccent
              : Colors.redAccent,
        ),
        _buildStatusCard(
          icon: widget.hasGpsLock ? Icons.gps_fixed : Icons.gps_not_fixed,
          value: "GPS",
          color: widget.hasGpsLock ? Colors.greenAccent : Colors.redAccent,
        ),
        _buildStatusCard(
          icon: Icons.signal_cellular_alt,
          value: "${widget.linkQuality}%",
          color: widget.linkQuality > 50
              ? Colors.greenAccent
              : widget.linkQuality > 20
              ? Colors.orangeAccent
              : Colors.redAccent,
        ),
      ],
    );
  }

  Widget _buildStatusCard({
    required IconData icon,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpeedCard() {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _airspeedAnimation,
        builder: (context, child) {
          return Container(
            width: 60,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.greenAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.greenAccent.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "SPD",
                  style: TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _airspeedAnimation.value.toStringAsFixed(1),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
                const Text(
                  "m/s",
                  style: TextStyle(color: Colors.greenAccent, fontSize: 8),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAltitudeCard() {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _altitudeAnimation,
        builder: (context, child) {
          return Container(
            width: 60,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orangeAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.orangeAccent.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "ALT",
                  style: TextStyle(
                    color: Colors.orangeAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _altitudeAnimation.value.toStringAsFixed(0),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
                const Text(
                  "m",
                  style: TextStyle(color: Colors.orangeAccent, fontSize: 8),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAttitudeIndicator() {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF00E5FF).withOpacity(0.3),
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CustomPaint(
                painter: AttitudeIndicatorPainter(
                  roll: _rollAnimation.value,
                  pitch: _pitchAnimation.value,
                ),
                child: Container(),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCompactCompass() {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _headingAnimation,
        builder: (context, child) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF00E5FF).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFF00E5FF).withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.navigation,
                  color: const Color(0xFF00E5FF),
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  "${_headingAnimation.value.round().toString().padLeft(3, '0')}°",
                  style: const TextStyle(
                    color: Color(0xFF00E5FF),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildArcCompass() {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _headingAnimation,
        builder: (context, child) {
          return Container(
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFF00E5FF).withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFF00E5FF).withOpacity(0.2),
                width: 1,
              ),
            ),
            child: CustomPaint(
              painter: ArcCompassPainter(heading: _headingAnimation.value),
              child: Container(),
            ),
          );
        },
      ),
    );
  }
}

/// Custom Painter for Attitude Indicator with smooth animations
class AttitudeIndicatorPainter extends CustomPainter {
  final double roll;
  final double pitch;

  AttitudeIndicatorPainter({required this.roll, required this.pitch});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    canvas.save();
    canvas.clipRect(rect);

    // Transform for roll and pitch
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-roll * math.pi / 180);
    canvas.translate(0, pitch * 3); // 3 pixels per degree

    // Sky gradient
    final skyGradient = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF87CEEB), // Sky blue top
          const Color(0xFF4A90E2), // Sky blue bottom
        ],
      ).createShader(Rect.fromLTRB(-500, -500, 500, 0));

    canvas.drawRect(Rect.fromLTRB(-500, -500, 500, 0), skyGradient);

    // Ground gradient
    final groundGradient = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF8B4513), // Brown top
          const Color(0xFF654321), // Darker brown bottom
        ],
      ).createShader(Rect.fromLTRB(-500, 0, 500, 500));

    canvas.drawRect(Rect.fromLTRB(-500, 0, 500, 500), groundGradient);

    // Horizon line
    canvas.drawLine(
      const Offset(-500, 0),
      const Offset(500, 0),
      Paint()
        ..color = Colors.white
        ..strokeWidth = 2,
    );

    // Pitch ladder (every 5 degrees)
    _drawPitchLadder(canvas);

    canvas.restore();

    // Fixed aircraft symbol
    _drawAircraftSymbol(canvas, center);
  }

  void _drawPitchLadder(Canvas canvas) {
    final linePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.5;

    final textStyle = TextStyle(
      color: Colors.white,
      fontSize: 10,
      fontWeight: FontWeight.bold,
    );

    // Draw pitch lines every 5 degrees, major every 10
    for (int deg = -40; deg <= 40; deg += 5) {
      if (deg == 0) continue; // Skip horizon line

      final y = deg * 3.0; // 3 pixels per degree
      final isMajor = deg % 10 == 0;
      final lineWidth = isMajor ? 40.0 : 20.0;

      // Draw line
      canvas.drawLine(
        Offset(-lineWidth / 2, y),
        Offset(lineWidth / 2, y),
        linePaint,
      );

      // Draw text for major lines
      if (isMajor) {
        final text = deg.abs().toString();
        final textPainter = TextPainter(
          text: TextSpan(text: text, style: textStyle),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();

        // Text on both sides
        textPainter.paint(
          canvas,
          Offset(lineWidth / 2 + 5, y - textPainter.height / 2),
        );
        textPainter.paint(
          canvas,
          Offset(
            -lineWidth / 2 - textPainter.width - 5,
            y - textPainter.height / 2,
          ),
        );
      }
    }
  }

  void _drawAircraftSymbol(Canvas canvas, Offset center) {
    final aircraftPaint = Paint()
      ..color = const Color(0xFFFFEB3B)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    // Aircraft wings
    canvas.drawLine(
      Offset(center.dx - 25, center.dy),
      Offset(center.dx - 8, center.dy),
      aircraftPaint,
    );
    canvas.drawLine(
      Offset(center.dx + 8, center.dy),
      Offset(center.dx + 25, center.dy),
      aircraftPaint,
    );

    // Center dot
    canvas.drawCircle(center, 3, Paint()..color = const Color(0xFFFFEB3B));
  }

  @override
  bool shouldRepaint(AttitudeIndicatorPainter oldDelegate) {
    return oldDelegate.roll != roll || oldDelegate.pitch != pitch;
  }
}

/// Custom Painter for Arc-style Compass
class ArcCompassPainter extends CustomPainter {
  final double heading;

  ArcCompassPainter({required this.heading});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height - 10);
    final radius = size.width * 0.4;

    canvas.save();
    canvas.translate(center.dx, center.dy);

    // Draw arc background
    final arcPaint = Paint()
      ..color = const Color(0xFF00E5FF).withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawArc(
      Rect.fromCircle(center: Offset.zero, radius: radius),
      -math.pi * 2 / 3, // Start angle
      math.pi * 4 / 3, // Sweep angle (240°)
      false,
      arcPaint,
    );

    // Draw heading marks
    for (int i = 0; i < 360; i += 10) {
      final angle = (i - heading) * math.pi / 180;
      if (angle < -math.pi * 2 / 3 || angle > math.pi * 2 / 3) continue;

      final isCardinal = i % 90 == 0;
      final tickLength = isCardinal ? 12.0 : 6.0;

      final startPoint = Offset(
        radius * math.cos(angle - math.pi / 2),
        radius * math.sin(angle - math.pi / 2),
      );
      final endPoint = Offset(
        (radius - tickLength) * math.cos(angle - math.pi / 2),
        (radius - tickLength) * math.sin(angle - math.pi / 2),
      );

      canvas.drawLine(
        startPoint,
        endPoint,
        Paint()
          ..color = isCardinal ? Colors.white : Colors.grey
          ..strokeWidth = isCardinal ? 2 : 1,
      );

      // Draw cardinal labels
      if (isCardinal) {
        String label = '';
        if (i == 0)
          label = 'N';
        else if (i == 90)
          label = 'E';
        else if (i == 180)
          label = 'S';
        else if (i == 270)
          label = 'W';

        if (label.isNotEmpty) {
          final textPainter = TextPainter(
            text: TextSpan(
              text: label,
              style: TextStyle(
                color: i == 0 ? Colors.redAccent : Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            textDirection: TextDirection.ltr,
          );
          textPainter.layout();

          final textOffset = Offset(
            (radius - 20) * math.cos(angle - math.pi / 2) -
                textPainter.width / 2,
            (radius - 20) * math.sin(angle - math.pi / 2) -
                textPainter.height / 2,
          );
          textPainter.paint(canvas, textOffset);
        }
      }
    }

    canvas.restore();

    // Draw heading bug (triangle pointing up)
    final headingBugPaint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..style = PaintingStyle.fill;

    final bugPath = Path();
    bugPath.moveTo(center.dx, center.dy - radius - 5);
    bugPath.lineTo(center.dx - 6, center.dy - radius + 3);
    bugPath.lineTo(center.dx + 6, center.dy - radius + 3);
    bugPath.close();

    canvas.drawPath(bugPath, headingBugPaint);

    // Draw heading value
    final headingText = heading.round().toString().padLeft(3, '0');
    final headingPainter = TextPainter(
      text: TextSpan(
        text: '$headingText°',
        style: const TextStyle(
          color: Color(0xFF00E5FF),
          fontSize: 16,
          fontWeight: FontWeight.bold,
          fontFamily: 'monospace',
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    headingPainter.layout();
    headingPainter.paint(
      canvas,
      Offset(center.dx - headingPainter.width / 2, center.dy - radius / 2),
    );
  }

  @override
  bool shouldRepaint(ArcCompassPainter oldDelegate) {
    return oldDelegate.heading != heading;
  }
}
