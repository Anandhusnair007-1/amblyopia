import 'package:flutter/material.dart';

class GazeCrosshairWidget extends StatelessWidget {
  const GazeCrosshairWidget({
    super.key,
    this.color = Colors.amber,
    this.size = 80,
  });

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _CrosshairPainter(color),
      size: Size(size, size),
    );
  }
}

class _CrosshairPainter extends CustomPainter {
  _CrosshairPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2;
    final center = size.center(Offset.zero);
    canvas.drawLine(Offset(center.dx, 0), Offset(center.dx, size.height), paint);
    canvas.drawLine(Offset(0, center.dy), Offset(size.width, center.dy), paint);
    canvas.drawCircle(center, 6, paint..style = PaintingStyle.stroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
