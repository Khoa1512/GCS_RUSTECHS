import 'package:flutter/material.dart';

class DottedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    const cornerLength = 15.0;
    const dashWidth = 3.0;
    const dashSpace = 2.0;

    // Top-left corner
    _drawDottedLine(
      canvas,
      Offset(0, 0),
      Offset(cornerLength, 0),
      paint,
      dashWidth,
      dashSpace,
    );
    _drawDottedLine(
      canvas,
      Offset(0, 0),
      Offset(0, cornerLength),
      paint,
      dashWidth,
      dashSpace,
    );

    // Top-right corner
    _drawDottedLine(
      canvas,
      Offset(size.width - cornerLength, 0),
      Offset(size.width, 0),
      paint,
      dashWidth,
      dashSpace,
    );
    _drawDottedLine(
      canvas,
      Offset(size.width, 0),
      Offset(size.width, cornerLength),
      paint,
      dashWidth,
      dashSpace,
    );

    // Bottom-left corner
    _drawDottedLine(
      canvas,
      Offset(0, size.height - cornerLength),
      Offset(0, size.height),
      paint,
      dashWidth,
      dashSpace,
    );
    _drawDottedLine(
      canvas,
      Offset(0, size.height),
      Offset(cornerLength, size.height),
      paint,
      dashWidth,
      dashSpace,
    );

    // Bottom-right corner
    _drawDottedLine(
      canvas,
      Offset(size.width - cornerLength, size.height),
      Offset(size.width, size.height),
      paint,
      dashWidth,
      dashSpace,
    );
    _drawDottedLine(
      canvas,
      Offset(size.width, size.height - cornerLength),
      Offset(size.width, size.height),
      paint,
      dashWidth,
      dashSpace,
    );
  }

  void _drawDottedLine(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint,
    double dashWidth,
    double dashSpace,
  ) {
    final distance = (end - start).distance;
    final dashCount = (distance / (dashWidth + dashSpace)).floor();

    for (int i = 0; i < dashCount; i++) {
      final startRatio = (i * (dashWidth + dashSpace)) / distance;
      final endRatio = ((i * (dashWidth + dashSpace)) + dashWidth) / distance;

      final dashStart = Offset.lerp(start, end, startRatio)!;
      final dashEnd = Offset.lerp(start, end, endRatio)!;

      canvas.drawLine(dashStart, dashEnd, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
