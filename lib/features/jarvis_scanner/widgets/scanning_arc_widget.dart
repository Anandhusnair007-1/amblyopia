import 'package:flutter/material.dart';

class ScanningArcWidget extends StatelessWidget {
  const ScanningArcWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(seconds: 2),
      builder: (context, value, _) {
        return CustomPaint(
          painter: _ArcPainter(value),
          size: const Size(150, 150),
        );
      },
      onEnd: () {},
    );
  }
}

class _ArcPainter extends CustomPainter {
  final double progress;
  _ArcPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final paint = Paint()
      ..color = Colors.tealAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawArc(rect, -3.14 / 2, progress * 3.14 * 2, false, paint);
  }

  @override
  bool shouldRepaint(covariant _ArcPainter oldDelegate) => oldDelegate.progress != progress;
}
