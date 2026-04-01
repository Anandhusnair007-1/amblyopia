import 'package:flutter/material.dart';

import '../controllers/titmus_controller.dart';

class StereoImageWidget extends StatelessWidget {
  const StereoImageWidget({
    super.key,
    required this.subTest,
    required this.headPosition,
    required this.circleTarget,
  });

  final TitmusSubTest subTest;
  final Offset headPosition;
  final String? circleTarget;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return CustomPaint(
      size: Size(size.width, size.height * 0.58),
      painter: _StereoPainter(
        subTest: subTest,
        headOffsetPx: (headPosition.dx - 0.5) * 120,
        circleTarget: circleTarget,
      ),
    );
  }
}

class _StereoPainter extends CustomPainter {
  _StereoPainter({
    required this.subTest,
    required this.headOffsetPx,
    required this.circleTarget,
  });

  final TitmusSubTest subTest;
  final double headOffsetPx;
  final String? circleTarget;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final bg = Paint()
      ..shader = const LinearGradient(
        colors: <Color>[
          Color(0xFF06111A),
          Color(0xFF0A2030),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(rect);
    canvas.drawRect(rect, bg);

    switch (subTest) {
      case TitmusSubTest.fly:
        _drawFly(canvas, size);
        break;
      case TitmusSubTest.animal:
        _drawAnimals(canvas, size);
        break;
      case TitmusSubTest.circles:
        _drawCircles(canvas, size);
        break;
    }
  }

  void _drawFly(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    final bodyPaint = Paint()
      ..color = const Color(0xFFB0BEC5)
      ..style = PaintingStyle.fill;
    final shadowPaint = Paint()
      ..color = const Color(0x334DD0E1)
      ..style = PaintingStyle.fill;

    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy + 10), width: 110, height: 160),
      shadowPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: 90, height: 140),
      bodyPaint,
    );

    final wingPaint = Paint()
      ..color = const Color(0xFF90A4AE)
      ..style = PaintingStyle.fill;

    final leftShift = headOffsetPx * -0.55;
    final rightShift = headOffsetPx * 0.55;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx - 110 + leftShift, cy - 40),
        width: 150,
        height: 62,
      ),
      wingPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx + 110 + rightShift, cy - 40),
        width: 150,
        height: 62,
      ),
      wingPaint,
    );

    final highlight = Paint()
      ..color = const Color(0x33FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy - 2), width: 90, height: 140),
      highlight,
    );
  }

  void _drawAnimals(Canvas canvas, Size size) {
    final centers = <Offset>[
      Offset(size.width * 0.26, size.height * 0.54),
      Offset(size.width * 0.50, size.height * 0.54),
      Offset(size.width * 0.74, size.height * 0.54),
    ];

    final shifts = <double>[
      headOffsetPx * 0.75, // Cat closest
      headOffsetPx * 0.45, // Duck medium
      headOffsetPx * 0.20, // Rabbit far
    ];

    final labels = <String>['CAT', 'DUCK', 'RABBIT'];
    final radii = <double>[70, 58, 52];
    final fills = <Color>[
      const Color(0xFF00897B),
      const Color(0xFF1A237E),
      const Color(0xFF546E7A),
    ];

    for (var i = 0; i < 3; i++) {
      _drawAnimal(
        canvas,
        center: Offset(centers[i].dx + shifts[i], centers[i].dy),
        radius: radii[i],
        label: labels[i],
        color: fills[i],
      );
    }
  }

  void _drawAnimal(
    Canvas canvas, {
    required Offset center,
    required double radius,
    required String label,
    required Color color,
  }) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, paint);

    final eyePaint = Paint()..color = const Color(0xCCFFFFFF);
    canvas.drawCircle(center.translate(-radius * 0.25, -radius * 0.15), radius * 0.12, eyePaint);
    canvas.drawCircle(center.translate(radius * 0.25, -radius * 0.15), radius * 0.12, eyePaint);
    canvas.drawCircle(center.translate(-radius * 0.25, -radius * 0.15), radius * 0.05, Paint()..color = const Color(0xFF0B1020));
    canvas.drawCircle(center.translate(radius * 0.25, -radius * 0.15), radius * 0.05, Paint()..color = const Color(0xFF0B1020));

    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(center.dx - textPainter.width / 2, center.dy + radius * 0.38),
    );
  }

  void _drawCircles(Canvas canvas, Size size) {
    final positions = <String, Offset>{
      'top': Offset(size.width / 2, size.height * 0.20),
      'left': Offset(size.width * 0.18, size.height / 2),
      'middle': Offset(size.width / 2, size.height / 2),
      'right': Offset(size.width * 0.82, size.height / 2),
      'bottom': Offset(size.width / 2, size.height * 0.80),
    };

    final target = circleTarget;
    for (final entry in positions.entries) {
      final isTarget = entry.key == target;
      final shift = isTarget ? headOffsetPx * 0.95 : headOffsetPx * 0.12;
      final pos = Offset(entry.value.dx + shift, entry.value.dy);
      final paint = Paint()
        ..color = isTarget ? const Color(0xFFFFB300) : const Color(0xFF4DD0E1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isTarget ? 4 : 3;
      canvas.drawCircle(pos, 44, paint);

      final inner = Paint()
        ..color = (isTarget ? const Color(0x66FFB300) : const Color(0x334DD0E1))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(pos, 26, inner);
    }
  }

  @override
  bool shouldRepaint(covariant _StereoPainter oldDelegate) {
    return oldDelegate.subTest != subTest ||
        oldDelegate.headOffsetPx != headOffsetPx ||
        oldDelegate.circleTarget != circleTarget;
  }
}

