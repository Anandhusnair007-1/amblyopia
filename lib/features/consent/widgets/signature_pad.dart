import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// A pad where the user draws a signature with their finger.
/// Use [SignaturePadState] via [GlobalKey] to call [captureToPngFile] and read [hasSignature].
class SignaturePad extends StatefulWidget {
  const SignaturePad({
    super.key,
    this.height = 140,
    this.backgroundColor,
    this.borderColor,
    this.strokeColor,
    this.hintText,
  });

  final double height;
  final Color? backgroundColor;
  final Color? borderColor;
  final Color? strokeColor;
  final String? hintText;

  @override
  State<SignaturePad> createState() => SignaturePadState();
}

class SignaturePadState extends State<SignaturePad> {
  final List<List<Offset>> _strokes = [];
  final GlobalKey _repaintKey = GlobalKey();

  bool get hasSignature => _strokes.isNotEmpty && _strokes.any((s) => s.length > 1);

  void clear() {
    setState(() => _strokes.clear());
  }

  /// Captures the current signature as PNG to [filePath]. Returns path if successful.
  Future<String?> captureToPngFile(String filePath) async {
    final boundary = _repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    try {
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;
      final file = File(filePath);
      await file.create(recursive: true);
      await file.writeAsBytes(byteData.buffer.asUint8List());
      return file.path;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.backgroundColor ?? const Color(0xFFF5F7FA);
    final border = widget.borderColor ?? const Color(0xFFE3EAF2);
    final stroke = widget.strokeColor ?? const Color(0xFF13213A);

    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border, width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: GestureDetector(
          onPanStart: (d) {
            setState(() => _strokes.add([d.localPosition]));
          },
          onPanUpdate: (d) {
            if (_strokes.isEmpty) return;
            setState(() => _strokes.last.add(d.localPosition));
          },
          child: RepaintBoundary(
            key: _repaintKey,
            child: CustomPaint(
              painter: _SignaturePainter(strokes: _strokes, strokeColor: stroke),
              size: Size.infinite,
            ),
          ),
        ),
      ),
    );
  }
}

class _SignaturePainter extends CustomPainter {
  _SignaturePainter({required this.strokes, required this.strokeColor});

  final List<List<Offset>> strokes;
  final Color strokeColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = strokeColor
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      if (stroke.length < 2) continue;
      final path = Path()..moveTo(stroke[0].dx, stroke[0].dy);
      for (var i = 1; i < stroke.length; i++) {
        path.lineTo(stroke[i].dx, stroke[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter old) => old.strokes != strokes;
}
