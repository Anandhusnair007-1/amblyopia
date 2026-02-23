import 'package:flutter/material.dart';

class GazeOverlay extends StatelessWidget {
  final Rect? leftEyeRect;
  final Rect? rightEyeRect;
  final double asymmetryScore;

  const GazeOverlay({
    super.key,
    this.leftEyeRect,
    this.rightEyeRect,
    required this.asymmetryScore,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _GazePainter(
          leftEye: leftEyeRect,
          rightEye: rightEyeRect,
          asymmetry: asymmetryScore,
        ),
        child: Container(),
      ),
    );
  }
}

class _GazePainter extends CustomPainter {
  final Rect? leftEye;
  final Rect? rightEye;
  final double asymmetry;

  _GazePainter({this.leftEye, this.rightEye, required this.asymmetry});

  @override
  void paint(Canvas canvas, Size size) {
    final leftPaint = Paint()
      ..color = Colors.cyan.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final rightPaint = Paint()
      ..color = Colors.green.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final dotPaint = Paint()
      ..color = Colors.orange
      ..style = PaintingStyle.fill;

    if (leftEye != null) {
      final rect = Rect.fromLTWH(
        leftEye!.left * size.width,
        leftEye!.top * size.height,
        leftEye!.width * size.width,
        leftEye!.height * size.height,
      );
      canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(4)), leftPaint);
      canvas.drawCircle(rect.center, 4, dotPaint);
    }

    if (rightEye != null) {
      final rect = Rect.fromLTWH(
        rightEye!.left * size.width,
        rightEye!.top * size.height,
        rightEye!.width * size.width,
        rightEye!.height * size.height,
      );
      canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(4)), rightPaint);
      canvas.drawCircle(rect.center, 4, dotPaint);
    }

    // Asymmetry warning overlay
    if (asymmetry > 0.15 && leftEye != null && rightEye != null) {
      final warnPaint = Paint()
        ..color = Colors.red.withOpacity(0.15)
        ..style = PaintingStyle.fill;
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), warnPaint);
    }

    // Score text at bottom
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'Asymmetry: ${asymmetry.toStringAsFixed(2)}',
        style: TextStyle(
          color: asymmetry > 0.15 ? Colors.orange : Colors.green,
          fontSize: 12,
          backgroundColor: Colors.black45,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, Offset(8, size.height - 30));
  }

  @override
  bool shouldRepaint(_GazePainter old) =>
      old.leftEye != leftEye ||
      old.rightEye != rightEye ||
      old.asymmetry != asymmetry;
}
