import 'package:flutter/material.dart';

class IrisHudOverlay extends StatelessWidget {
  const IrisHudOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _IrisHudPainter(),
        size: Size.infinite,
      ),
    );
  }
}

class _IrisHudPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x4DFFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final center = size.center(Offset.zero);
    canvas.drawCircle(center, size.shortestSide * 0.25, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
