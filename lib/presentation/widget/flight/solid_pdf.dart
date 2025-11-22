import 'dart:math' as math;
import 'package:flutter/material.dart';

class SolidFlightDisplay extends StatelessWidget {
  final double roll; // Độ nghiêng (Degree)
  final double pitch; // Độ ngóc (Degree)
  final double heading; // Hướng (0-360)
  final double altitude; // Mét
  final double airspeed; // m/s
  final double batteryPercent; // Battery %
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
    this.hasGpsLock = true,
    this.linkQuality = 100,
    this.satellites = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 340, // Fixed width để đảm bảo đủ không gian
      padding: const EdgeInsets.all(8),
      decoration: const BoxDecoration(
        color: Color(0xFF000000), // Nền đen đơn giản
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Status cards row - info cơ bản
          _buildStatusRow(),

          const SizedBox(height: 8),

          Row(
            mainAxisAlignment:
                MainAxisAlignment.center, // Center the instruments
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
                        border: Border.all(color: Colors.grey[700]!, width: 3),
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
                        color: Colors.black, // Nền đen tuyệt đối cho la bàn
                        shape: BoxShape.circle,
                      ),
                      child: CustomPaint(
                        painter: _SolidCompassPainter(heading: heading),
                      ),
                    ),
                    Positioned.fill(
                      child: Transform.rotate(
                        angle:
                            heading *
                            math.pi /
                            180, // Xoay aircraft symbol theo heading
                        child: Center(
                          child: Icon(
                            Icons.navigation,
                            color: Color(0xFF00E5FF),
                            size: 24,
                          ),
                        ),
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
                        border: Border.all(color: Colors.grey[700]!, width: 3),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Thông tin SPD & ALT ở dưới - căn giữa đẹp
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly, // Căn đều 2 bên
            children: [
              // Speed Info
              Text(
                "SPD: ${airspeed.toStringAsFixed(1)} m/s",
                style: const TextStyle(
                  color: Colors.greenAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              // Altitude Info
              Text(
                "ALT: ${altitude.toStringAsFixed(0)} m",
                style: const TextStyle(
                  color: Colors.orangeAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Status cards row - hiển thị info cơ bản
  Widget _buildStatusRow() {
    return SizedBox(
      width: double.infinity, // Use full available width
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Flexible(
              flex: 1,
              child: _buildStatusCard(
                icon: Icons.battery_std,
                value: "${batteryPercent.toInt()}%",
                color: batteryPercent > 20
                    ? Colors.greenAccent
                    : Colors.redAccent,
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              flex: 1,
              child: _buildStatusCard(
                icon: hasGpsLock ? Icons.gps_fixed : Icons.gps_not_fixed,
                value: "GPS",
                color: hasGpsLock ? Colors.greenAccent : Colors.redAccent,
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              flex: 1,
              child: _buildStatusCard(
                icon: Icons.satellite_alt,
                value: "${satellites}",
                color: _getSatelliteColor(satellites),
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              flex: 1,
              child: _buildStatusCard(
                icon: Icons.signal_cellular_alt,
                value: "${linkQuality}%",
                color: linkQuality > 50
                    ? Colors.greenAccent
                    : linkQuality > 20
                    ? Colors.orangeAccent
                    : Colors.redAccent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard({
    required IconData icon,
    required String value,
    required Color color,
  }) {
    return Container(
      constraints: const BoxConstraints(minWidth: 50, minHeight: 40),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // Khung viền cho từng đồng hồ tròn
  Widget _buildInstrumentFrame({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFF1A1A1A), // Nền xám đơn giản
      ),
      child: child,
    );
  }

  // Satellite color coding method
  Color _getSatelliteColor(int sats) {
    if (sats >= 8) return Colors.greenAccent; // Excellent GPS
    if (sats >= 6) return Colors.orangeAccent; // Good GPS
    if (sats >= 4) return Colors.yellowAccent; // Marginal GPS
    return Colors.redAccent; // Poor/No GPS
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
