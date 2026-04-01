import 'package:flutter/material.dart';

class ParallaxImageWidget extends StatelessWidget {
  const ParallaxImageWidget({
    super.key,
    required this.headPosition,
    required this.disparity,
    required this.targetPosition,
  });

  final Offset headPosition;
  final double disparity;
  final String targetPosition;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final headOffset = (headPosition.dx - 0.5) * size.width * 0.3;
    final bgShift = headOffset * 0.3;
    final fgShift = targetPosition == 'front' ? headOffset * 0.8 : headOffset * 0.1;

    return Stack(
      children: [
        Transform.translate(
          offset: Offset(bgShift, 0),
          child: CustomPaint(
            size: size,
            painter: _GridPainter(),
          ),
        ),
        Transform.translate(
          offset: Offset(fgShift, 0),
          child: Center(
            child: Container(
              width: 40 + disparity * 0.25,
              height: 40 + disparity * 0.25,
              decoration: BoxDecoration(
                color: const Color(0xFFFFB300),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFB300).withValues(alpha: 0.6),
                    blurRadius: 15,
                    spreadRadius: 5,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0x334DD0E1);
    for (double x = 20; x < size.width; x += 28) {
      for (double y = 20; y < size.height; y += 28) {
        canvas.drawCircle(Offset(x, y), 1.8, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
