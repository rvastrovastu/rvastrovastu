import 'package:flutter/material.dart';

class NorthIndianChartPainter extends CustomPainter {
  final Color lineColor;

  const NorthIndianChartPainter({
    required this.lineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final w = size.width;
    final h = size.height;

    final center = Offset(w / 2, h / 2);

    final top = Offset(w / 2, 0);
    final right = Offset(w, h / 2);
    final bottom = Offset(w / 2, h);
    final left = Offset(0, h / 2);

    final topLeft = Offset(0, 0);
    final topRight = Offset(w, 0);
    final bottomLeft = Offset(0, h);
    final bottomRight = Offset(w, h);

    // Outer North Indian diamond.
    final outer = Path()
      ..moveTo(top.dx, top.dy)
      ..lineTo(right.dx, right.dy)
      ..lineTo(bottom.dx, bottom.dy)
      ..lineTo(left.dx, left.dy)
      ..close();

    canvas.drawPath(outer, paint);

    // Top-left diagonal.
    canvas.drawLine(
      topLeft,
      center,
      paint,
    );

    // Top-right diagonal.
    canvas.drawLine(
      topRight,
      center,
      paint,
    );

    // Bottom-left diagonal.
    canvas.drawLine(
      bottomLeft,
      center,
      paint,
    );

    // Bottom-right diagonal.
    canvas.drawLine(
      bottomRight,
      center,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant NorthIndianChartPainter oldDelegate) {
    return oldDelegate.lineColor != lineColor;
  }
}
