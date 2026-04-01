import 'dart:math' as math;

import 'package:flutter/material.dart';

class RandomDotWidget extends StatefulWidget {
  const RandomDotWidget({
    super.key,
    required this.patternIndex,
    required this.headPosition,
  });

  final int patternIndex;
  final Offset headPosition;

  @override
  State<RandomDotWidget> createState() => _RandomDotWidgetState();
}

class _RandomDotWidgetState extends State<RandomDotWidget> {
  static const int gridSize = 64;
  late List<List<bool>> _dotGrid;
  late List<List<bool>> _shapeMask;

  @override
  void initState() {
    super.initState();
    _generatePattern();
  }

  @override
  void didUpdateWidget(covariant RandomDotWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.patternIndex != widget.patternIndex) {
      _generatePattern();
    }
  }

  void _generatePattern() {
    final random = math.Random(42 + widget.patternIndex * 100);
    _dotGrid = List<List<bool>>.generate(
      gridSize,
      (_) => List<bool>.generate(gridSize, (_) => random.nextBool()),
    );
    _shapeMask = List<List<bool>>.generate(
      gridSize,
      (_) => List<bool>.filled(gridSize, false),
    );
    _applyShape(widget.patternIndex);
  }

  void _applyShape(int pattern) {
    const cx = gridSize ~/ 2;
    const cy = gridSize ~/ 2;

    switch (pattern) {
      case 0: // Star-like cross
        for (var y = 0; y < gridSize; y++) {
          for (var x = 0; x < gridSize; x++) {
            final dx = (x - cx).abs();
            final dy = (y - cy).abs();
            if (dx < 3 || dy < 3) {
              _shapeMask[y][x] = true;
            }
            if ((dx - dy).abs() < 2) {
              _shapeMask[y][x] = true;
            }
          }
        }
        break;
      case 1: // Car (body + top)
        for (var y = cy - 6; y <= cy + 6; y++) {
          for (var x = cx - 16; x <= cx + 16; x++) {
            if (y >= 0 && y < gridSize && x >= 0 && x < gridSize) {
              _shapeMask[y][x] = true;
            }
          }
        }
        for (var y = cy - 12; y <= cy - 7; y++) {
          for (var x = cx - 8; x <= cx + 8; x++) {
            if (y >= 0 && y < gridSize && x >= 0 && x < gridSize) {
              _shapeMask[y][x] = true;
            }
          }
        }
        break;
      case 2: // Cat face (circle + ears)
        for (var y = 0; y < gridSize; y++) {
          for (var x = 0; x < gridSize; x++) {
            final dx = x - cx;
            final dy = y - cy;
            if (dx * dx + dy * dy < 10 * 10) {
              _shapeMask[y][x] = true;
            }
          }
        }
        for (var y = cy - 16; y <= cy - 8; y++) {
          for (var x = cx - 14; x <= cx - 6; x++) {
            if (y >= 0 && y < gridSize && x >= 0 && x < gridSize) {
              _shapeMask[y][x] = true;
            }
          }
        }
        for (var y = cy - 16; y <= cy - 8; y++) {
          for (var x = cx + 6; x <= cx + 14; x++) {
            if (y >= 0 && y < gridSize && x >= 0 && x < gridSize) {
              _shapeMask[y][x] = true;
            }
          }
        }
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final maxSquare = size.width < size.height ? size.width : size.height * 0.58;
    return CustomPaint(
      size: Size.square(maxSquare),
      painter: _DotPainter(
        dotGrid: _dotGrid,
        shapeMask: _shapeMask,
        headOffset: (widget.headPosition.dx - 0.5) * 10,
      ),
    );
  }
}

class _DotPainter extends CustomPainter {
  const _DotPainter({
    required this.dotGrid,
    required this.shapeMask,
    required this.headOffset,
  });

  final List<List<bool>> dotGrid;
  final List<List<bool>> shapeMask;
  final double headOffset;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / dotGrid.length;
    final bgPaint = Paint()..color = const Color(0xFF263238);
    final shapePaint = Paint()..color = const Color(0xFF455A64);

    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(24)),
      Paint()..color = const Color(0xFF06111A),
    );

    for (var y = 0; y < dotGrid.length; y++) {
      for (var x = 0; x < dotGrid[y].length; x++) {
        if (!dotGrid[y][x]) continue;
        final inShape = shapeMask[y][x];
        final shift = inShape ? headOffset : headOffset * 0.12;
        final dx = x * cell + shift;
        final dy = y * cell;

        canvas.drawCircle(
          Offset(dx, dy),
          cell * 0.34,
          inShape ? shapePaint : bgPaint,
        );
      }
    }

    final border = Paint()
      ..color = const Color(0x334DD0E1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(24)),
      border,
    );
  }

  @override
  bool shouldRepaint(covariant _DotPainter oldDelegate) {
    return oldDelegate.headOffset != headOffset ||
        oldDelegate.dotGrid != dotGrid ||
        oldDelegate.shapeMask != shapeMask;
  }
}
