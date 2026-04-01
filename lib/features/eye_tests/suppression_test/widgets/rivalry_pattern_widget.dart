import 'package:flutter/material.dart';

class RivalryPatternWidget extends StatefulWidget {
  const RivalryPatternWidget({
    super.key,
    required this.size,
  });

  final double size;

  @override
  State<RivalryPatternWidget> createState() => _RivalryPatternWidgetState();
}

class _RivalryPatternWidgetState extends State<RivalryPatternWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: _RivalryPainter(
            pulseValue: _pulseController.value,
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }
}

class _RivalryPainter extends CustomPainter {
  _RivalryPainter({required this.pulseValue});

  final double pulseValue;

  @override
  void paint(Canvas canvas, Size size) {
    const stripeWidth = 12.0;
    const stripeGap = 12.0;
    const period = stripeWidth + stripeGap;

    final redPaint = Paint()
      ..color = const Color(0xFFE53935).withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;

    double y = 0;
    while (y < size.height) {
      canvas.drawRect(
        Rect.fromLTWH(0, y, size.width, stripeWidth),
        redPaint,
      );
      y += period;
    }

    final bluePaint = Paint()
      ..color = const Color(0xFF1565C0).withValues(alpha: 0.75)
      ..style = PaintingStyle.fill;

    double x = 0;
    while (x < size.width) {
      canvas.drawRect(
        Rect.fromLTWH(x, 0, stripeWidth, size.height),
        bluePaint,
      );
      x += period;
    }

    final borderPaint = Paint()
      ..color = Colors.grey.shade300
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RivalryPainter old) =>
      old.pulseValue != pulseValue;
}
