import 'dart:math' as math;
import 'package:flutter/material.dart';

class SolidFlightDisplay extends StatelessWidget {
  final double roll; // Độ nghiêng (Degree)
  final double pitch; // Độ ngóc (Degree)
  final double heading; // Hướng (0-360)
  final double altitude; // Mét
  final double airspeed; // m/s
  final double batteryPercent; // Battery %
  final double voltageBattery;
  final String flightMode; // Flight mode from telemetry
  final bool isArmed; // ARM status from telemetry
  final bool isConnected; // Connection status
  final bool hasGpsLock; // GPS lock status
  final int linkQuality; // Link quality %
  final int satellites; // Number of satellites

  const SolidFlightDisplay({
    super.key,
    required this.roll,
    required this.pitch,
    required this.heading,
    required this.altitude,
    required this.airspeed,
    this.batteryPercent = 100.0,
    this.voltageBattery = 0.0,
    this.flightMode = 'Unknown',
    this.isArmed = false,
    this.isConnected = false,
    this.hasGpsLock = true,
    this.linkQuality = 100,
    this.satellites = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 440,
      height: 320,
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A).withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF00E5FF).withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Status bar at top
          _buildStatusRow(),

          // Main PFD display with vertical tapes
          Expanded(
            child: Row(
              children: [
                // Speed Tape (Left)
                _SpeedTape(airspeed: airspeed),

                // Central instruments column
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      // Circular instruments from solid_pdf
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // 1. ATTITUDE GAUGE (Trái)
                            _buildInstrumentFrame(
                              child: Stack(
                                children: [
                                  ClipOval(
                                    child: CustomPaint(
                                      size: const Size(130, 130),
                                      painter: _SolidAttitudePainter(
                                        roll: roll,
                                        pitch: pitch,
                                      ),
                                    ),
                                  ),
                                  // Vòng tròn viền bezel bên trong
                                  Container(
                                    width: 130,
                                    height: 130,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.grey[700]!,
                                        width: 3,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(width: 15),

                            // 2. COMPASS GAUGE (Phải)
                            _buildInstrumentFrame(
                              child: Stack(
                                children: [
                                  Container(
                                    width: 130,
                                    height: 130,
                                    decoration: const BoxDecoration(
                                      color: Colors
                                          .black, // Nền đen tuyệt đối cho la bàn
                                      shape: BoxShape.circle,
                                    ),
                                    child: TweenAnimationBuilder<double>(
                                      tween: HeadingTween(
                                        begin: heading,
                                        end: heading,
                                      ),
                                      duration: const Duration(
                                        milliseconds: 300,
                                      ),
                                      builder:
                                          (context, animatedHeading, child) {
                                            return CustomPaint(
                                              painter: _SolidCompassPainter(
                                                heading: animatedHeading,
                                              ),
                                            );
                                          },
                                    ),
                                  ),
                                  Positioned.fill(
                                    child: TweenAnimationBuilder<double>(
                                      tween: HeadingTween(
                                        begin: heading,
                                        end: heading,
                                      ),
                                      duration: const Duration(
                                        milliseconds: 300,
                                      ),
                                      builder:
                                          (context, animatedHeading, child) {
                                            return Transform.rotate(
                                              angle:
                                                  animatedHeading *
                                                  math.pi /
                                                  180,
                                              child: Center(
                                                child: Icon(
                                                  Icons.navigation,
                                                  color: Color(0xFF00E5FF),
                                                  size: 24,
                                                ),
                                              ),
                                            );
                                          },
                                    ),
                                  ),
                                  // Heading text
                                  Positioned(
                                    top: 77,
                                    left: 0,
                                    right: 0,
                                    child: Center(
                                      child: Text(
                                        "${heading.toStringAsFixed(0)}°",
                                        style: const TextStyle(
                                          color: Color(0xFF00E5FF),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Vòng tròn viền bezel bên trong
                                  Container(
                                    width: 130,
                                    height: 130,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.grey[700]!,
                                        width: 3,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // ARM status above bottom bar
                      if (isConnected) _buildArmStatus(),
                      const SizedBox(height: 14),

                      // Bottom status info
                      _buildBottomStatusBar(),
                    ],
                  ),
                ),

                // Altitude Tape (Right)
                _AltitudeTape(altitude: altitude),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Top status bar - glass cockpit style
  Widget _buildStatusRow() {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF001F3F).withOpacity(0.8),
            const Color(0xFF003366).withOpacity(0.6),
          ],
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildGlassStatusItem(
            icon: Icons.flight,
            label: "Mode",
            value: flightMode,
            color: const Color(0xFF00E5FF),
          ),
          _buildGlassStatusItem(
            icon: Icons.battery_std,
            label: "Pin",
            value: "${voltageBattery}V",
            color: const Color(0xFFFF6B35),
          ),
          _buildGlassStatusItem(
            icon: hasGpsLock ? Icons.gps_fixed : Icons.gps_not_fixed,
            label: "GPS",
            value: hasGpsLock ? "LOCK" : "NO FIX",
            color: hasGpsLock
                ? const Color(0xFF00E5FF)
                : const Color(0xFFFF6B35),
          ),
          _buildGlassStatusItem(
            icon: Icons.satellite_alt,
            label: "Vệ tinh",
            value: satellites.toString(),
            color: _getSatelliteGlassColor(satellites),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassStatusItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 6),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: color.withOpacity(0.8),
                fontSize: 9,
                fontWeight: FontWeight.w500,
              ),
            ),
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
      ],
    );
  }

  // Bottom status bar for additional info
  Widget _buildBottomStatusBar() {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A).withOpacity(0.8),
        border: Border(
          top: BorderSide(
            color: const Color(0xFF00E5FF).withOpacity(0.3),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Text(
            "Tốc độ: ${airspeed.toStringAsFixed(1)} m/s",
            style: const TextStyle(
              color: Color(0xFF00E5FF),
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          Container(
            width: 1,
            height: 20,
            color: const Color(0xFF00E5FF).withOpacity(0.3),
          ),
          Text(
            "Độ cao: ${altitude.toStringAsFixed(0)} m",
            style: const TextStyle(
              color: Color(0xFFFFC107),
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ARM Status widget - Right aligned above bottom bar
  Widget _buildArmStatus() {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A).withOpacity(0.8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: isArmed
                  ? const Color(0xFFFF6B35).withOpacity(0.2)
                  : const Color(0xFF4CAF50).withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: isArmed
                    ? const Color(0xFFFF6B35)
                    : const Color(0xFF4CAF50),
                width: 1.5,
              ),
            ),
            child: Text(
              isArmed ? 'ARMED' : 'DISARMED',
              style: TextStyle(
                color: isArmed
                    ? const Color(0xFFFF6B35)
                    : const Color(0xFF4CAF50),
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Glass cockpit satellite color
  Color _getSatelliteGlassColor(int sats) {
    if (sats >= 8) return const Color(0xFF00E5FF); // Cyan for excellent
    if (sats >= 6) return const Color(0xFF4CAF50); // Green for good
    if (sats >= 4) return const Color(0xFFFFC107); // Amber for marginal
    return const Color(0xFFFF6B35); // Orange-red for poor
  }

  Widget _buildInstrumentFrame({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFF1A1A1A),
      ),
      child: child,
    );
  }
}

// Speed Tape Widget - Vertical speed indicator on left
class _SpeedTape extends StatelessWidget {
  final double airspeed;

  const _SpeedTape({required this.airspeed});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A).withOpacity(0.9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF00E5FF).withOpacity(0.4),
          width: 1,
        ),
      ),
      child: Stack(
        children: [
          // Speed scale
          CustomPaint(
            size: Size.infinite,
            painter: _SpeedTapePainter(airspeed: airspeed),
          ),
          // Current speed indicator
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: Center(
              child: Container(
                width: 50,
                height: 24,
                decoration: BoxDecoration(
                  color: const Color(0xFF00E5FF),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Center(
                  child: Text(
                    airspeed.toStringAsFixed(0),
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Altitude Tape Widget - Vertical altitude indicator on right
class _AltitudeTape extends StatelessWidget {
  final double altitude;

  const _AltitudeTape({required this.altitude});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A).withOpacity(0.9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFFFC107).withOpacity(0.4),
          width: 1,
        ),
      ),
      child: Stack(
        children: [
          // Altitude scale
          CustomPaint(
            size: Size.infinite,
            painter: _AltitudeTapePainter(altitude: altitude),
          ),
          // Current altitude indicator
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Center(
              child: Container(
                width: 50,
                height: 24,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFC107),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Center(
                  child: Text(
                    altitude.toStringAsFixed(0),
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Speed Tape Painter - Draws vertical speed scale
class _SpeedTapePainter extends CustomPainter {
  final double airspeed;

  _SpeedTapePainter({required this.airspeed});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..strokeWidth = 1;
    final textPaint = TextPainter(textDirection: TextDirection.ltr);

    // Draw speed markings
    double center = size.height / 2;
    double pixelsPerUnit = 3.0; // 3 pixels per m/s

    for (int speed = 0; speed <= 50; speed += 5) {
      double offset = (speed - airspeed) * pixelsPerUnit;
      double y = center - offset;

      if (y >= 0 && y <= size.height) {
        // Major tick marks
        canvas.drawLine(
          Offset(0, y),
          Offset(speed % 10 == 0 ? 20 : 12, y),
          paint,
        );

        // Speed labels
        if (speed % 10 == 0) {
          textPaint.text = TextSpan(
            text: speed.toString(),
            style: const TextStyle(
              color: Color(0xFF00E5FF),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          );
          textPaint.layout();
          textPaint.paint(canvas, Offset(25, y - textPaint.height / 2));
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SpeedTapePainter oldDelegate) {
    return oldDelegate.airspeed != airspeed;
  }
}

// Altitude Tape Painter - Draws vertical altitude scale
class _AltitudeTapePainter extends CustomPainter {
  final double altitude;

  _AltitudeTapePainter({required this.altitude});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFFC107)
      ..strokeWidth = 1;
    final textPaint = TextPainter(textDirection: TextDirection.ltr);

    // Draw altitude markings
    double center = size.height / 2;
    double pixelsPerUnit = 0.5; // 0.5 pixels per meter

    for (int alt = 0; alt <= 1000; alt += 20) {
      double offset = (alt - altitude) * pixelsPerUnit;
      double y = center - offset;

      if (y >= 0 && y <= size.height) {
        // Major tick marks
        canvas.drawLine(
          Offset(size.width - (alt % 100 == 0 ? 20 : 12), y),
          Offset(size.width, y),
          paint,
        );

        // Altitude labels
        if (alt % 100 == 0) {
          textPaint.text = TextSpan(
            text: alt.toString(),
            style: const TextStyle(
              color: Color(0xFFFFC107),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          );
          textPaint.layout();
          textPaint.paint(
            canvas,
            Offset(size.width - 25 - textPaint.width, y - textPaint.height / 2),
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AltitudeTapePainter oldDelegate) {
    return oldDelegate.altitude != altitude;
  }
}

// --- PAINTER VẼ CHÂN TRỜI (SOLID COLORS) ---
class _SolidAttitudePainter extends CustomPainter {
  final double roll;
  final double pitch;

  _SolidAttitudePainter({required this.roll, required this.pitch});

  // Màu sắc rực rỡ, không trong suốt
  final Color skyColor = const Color(
    0xFF0091EA,
  ); // Xanh da trời đậm (Light Blue 600)
  final Color groundColor = const Color(0xFF795548); // Nâu đất (Brown 500)
  final Color horizonLine = Colors.white;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-roll * math.pi / 180);
    canvas.translate(0, pitch * 4);

    // Vẽ Trời & Đất (Kích thước cực lớn để che hết)
    double bigSize = 400;
    canvas.drawRect(
      Rect.fromLTRB(-bigSize, -bigSize, bigSize, 0),
      Paint()..color = skyColor,
    );
    canvas.drawRect(
      Rect.fromLTRB(-bigSize, 0, bigSize, bigSize),
      Paint()..color = groundColor,
    );

    // Đường chân trời
    canvas.drawLine(
      Offset(-bigSize, 0),
      Offset(bigSize, 0),
      Paint()
        ..color = horizonLine
        ..strokeWidth = 3,
    );

    // Thang chia độ (Pitch Ladder)
    Paint linePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2;
    for (int i = 1; i <= 4; i++) {
      double y = i * 10 * 4.0;
      canvas.drawLine(Offset(-15, -y), Offset(15, -y), linePaint); // Vạch trên
      canvas.drawLine(Offset(-15, y), Offset(15, y), linePaint); // Vạch dưới
    }
    canvas.restore();

    // Vẽ Máy bay cố định (Màu vàng rực)
    Paint planePaint = Paint()
      ..color = const Color(0xFFFFEB3B)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(center.dx - 30, center.dy),
      Offset(center.dx - 10, center.dy),
      planePaint,
    ); // Cánh trái
    canvas.drawLine(
      Offset(center.dx + 10, center.dy),
      Offset(center.dx + 30, center.dy),
      planePaint,
    ); // Cánh phải
    canvas.drawCircle(
      center,
      4,
      Paint()..color = const Color(0xFFFFEB3B),
    ); // Tâm
  }

  @override
  bool shouldRepaint(covariant _SolidAttitudePainter old) => true;
}

// --- PAINTER VẼ LA BÀN (SOLID COLORS) ---
class _SolidCompassPainter extends CustomPainter {
  final double heading;
  _SolidCompassPainter({required this.heading});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    canvas.save();
    canvas.translate(center.dx, center.dy);

    // Compass rose cố định - N luôn ở trên
    Paint tickPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2;

    for (int i = 0; i < 360; i += 15) {
      // Góc tuyệt đối cho compass marks (không phụ thuộc heading)
      double angle = (i - 90) * math.pi / 180; // -90 để N ở trên
      bool isCardinal = i % 90 == 0;
      double tickLen = isCardinal ? 12 : 7;

      // Tọa độ vạch compass cố định
      double x1 = (radius - 5) * math.cos(angle);
      double y1 = (radius - 5) * math.sin(angle);
      double x2 = (radius - 5 - tickLen) * math.cos(angle);
      double y2 = (radius - 5 - tickLen) * math.sin(angle);

      // Color coding
      if (i == 0) {
        tickPaint.color = Colors.redAccent; // North - always red
      } else {
        tickPaint.color = Colors.grey[400]!;
      }

      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), tickPaint);

      // Vẽ chữ NESW - cố định, không xoay
      if (isCardinal) {
        String label = "";
        if (i == 0)
          label = "N";
        else if (i == 90)
          label = "E";
        else if (i == 180)
          label = "S";
        else if (i == 270)
          label = "W";

        double textDist = radius - 25;
        double tx = textDist * math.cos(angle);
        double ty = textDist * math.sin(angle);

        // Text luôn đứng thẳng và cố định
        TextSpan span = TextSpan(
          text: label,
          style: TextStyle(
            color: label == "N" ? Colors.redAccent : Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        );
        TextPainter tp = TextPainter(
          text: span,
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(tx - tp.width / 2, ty - tp.height / 2));
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SolidCompassPainter old) {
    return old.heading != heading;
  }
}

/// Custom Tween for compass heading that handles 360°/0° wrap-around
class HeadingTween extends Tween<double> {
  HeadingTween({double? begin, double? end}) : super(begin: begin, end: end);

  @override
  double lerp(double t) {
    final double? begin = this.begin;
    final double? end = this.end;

    if (begin == null || end == null) return super.lerp(t);

    double difference = end - begin;

    // Handle wrap-around: choose shorter rotation path
    if (difference > 180) {
      difference -= 360;
    } else if (difference < -180) {
      difference += 360;
    }

    double result = begin + (difference * t);

    // Normalize result to 0-360 range
    if (result < 0) {
      result += 360;
    } else if (result >= 360) {
      result -= 360;
    }

    return result;
  }
}
