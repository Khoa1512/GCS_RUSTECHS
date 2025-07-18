import 'package:flutter/material.dart';

class LineChartSample2 extends StatefulWidget {
  const LineChartSample2({super.key});

  @override
  State<LineChartSample2> createState() => _LineChartSample2State();
}

class _LineChartSample2State extends State<LineChartSample2> {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(top: 8),
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border(
          top: BorderSide(color: Colors.white, width: 1),
          right: BorderSide(color: Colors.white, width: 1),
          bottom: BorderSide(color: Colors.white, width: 1),
          left: BorderSide(color: Colors.white, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header text
          Text(
            'H2.85',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          // Chart area
          SizedBox(
            height: 80,
            width: double.infinity,
            child: CustomPaint(painter: HistogramPainter()),
          ),
        ],
      ),
    );
  }
}

class HistogramPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // Create sample data for histogram bars
    final List<double> heights = [
      0.3,
      0.5,
      0.4,
      0.6,
      0.8,
      0.7,
      0.9,
      0.5,
      0.6,
      0.4,
      0.7,
      0.8,
      0.6,
      0.9,
      0.7,
      0.8,
      0.6,
      0.4,
      0.7,
      0.5,
      0.8,
      0.9,
      0.6,
      0.7,
      0.5,
      0.8,
      0.4,
      0.6,
      0.7,
      0.9,
      0.8,
      0.5,
      0.6,
      0.4,
      0.7,
      0.8,
      0.9,
      0.6,
      0.5,
      0.7,
      0.8,
      0.4,
      0.6,
      0.9,
      0.7,
      0.5,
      0.8,
      0.6,
      0.4,
      0.7,
      0.9,
      0.8,
      0.5,
      0.6,
      0.7,
      0.4,
      0.8,
      0.9,
      0.6,
      0.5,
    ];

    final double barWidth = size.width / heights.length;

    for (int i = 0; i < heights.length; i++) {
      // Determine bar color based on position (some bars should be orange)
      if (i >= 15 && i <= 18 || i >= 25 && i <= 30) {
        paint.color = Colors.orange;
      } else {
        paint.color = Colors.white;
      }

      final double barHeight = heights[i] * size.height;
      final double x = i * barWidth;
      final double y = size.height - barHeight;

      canvas.drawRect(Rect.fromLTWH(x, y, barWidth - 0.5, barHeight), paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
