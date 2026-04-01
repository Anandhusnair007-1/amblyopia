import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Giant E in 4 rotations for Profile B (Age 5-7). Child says direction or points.
enum TumblingEDirection {
  up,
  down,
  left,
  right,
}

class TumblingEWidget extends StatelessWidget {
  const TumblingEWidget({
    super.key,
    required this.direction,
    required this.sizePx,
  });

  final TumblingEDirection direction;
  /// Letter height in pixels — calculated same as Snellen.
  final double sizePx;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: _angleForDirection(direction),
      child: Text(
        'E',
        style: TextStyle(
          fontFamily: 'JetBrainsMono',
          fontSize: sizePx,
          fontWeight: FontWeight.w900,
          color: Colors.black,
        ),
      ),
    );
  }

  static double _angleForDirection(TumblingEDirection d) {
    switch (d) {
      case TumblingEDirection.right:
        return 0;
      case TumblingEDirection.up:
        return -math.pi / 2;
      case TumblingEDirection.left:
        return math.pi;
      case TumblingEDirection.down:
        return math.pi / 2;
    }
  }
}
