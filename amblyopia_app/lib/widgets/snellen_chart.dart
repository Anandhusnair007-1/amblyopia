import 'package:flutter/material.dart';
import 'dart:math' as math;

class SnellenChart extends StatefulWidget {
  final String letter;
  final String vaLine;
  final String? direction;
  final bool showFeedback;
  final bool feedbackCorrect;

  const SnellenChart({
    super.key,
    required this.letter,
    required this.vaLine,
    this.direction,
    this.showFeedback = false,
    this.feedbackCorrect = false,
  });

  @override
  State<SnellenChart> createState() => _SnellenChartState();
}

class _SnellenChartState extends State<SnellenChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  late Animation<double> _fade;
  String _prev = '';

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..forward();
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);
  }

  @override
  void didUpdateWidget(SnellenChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.letter != widget.letter) {
      _prev = oldWidget.letter;
      _fadeCtrl.forward(from: 0);
    }
  }

  double _fontSize(String va) {
    const map = {
      '6/60': 120.0, '6/36': 100.0, '6/24': 84.0,
      '6/18': 72.0, '6/12': 60.0, '6/9': 48.0,
      '6/6': 36.0, '6/5': 28.0,
    };
    return map[va] ?? 60.0;
  }

  double _rotation(String? dir) {
    switch (dir) {
      case 'up': return 0.0;
      case 'right': return math.pi / 2;
      case 'down': return math.pi;
      case 'left': return -math.pi / 2;
      default: return 0.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = _fontSize(widget.vaLine);

    return FadeTransition(
      opacity: _fade,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // The letter
          Transform.rotate(
            angle: widget.direction != null
                ? _rotation(widget.direction)
                : 0,
            child: Text(
              widget.letter,
              style: TextStyle(
                color: Colors.white,
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
                fontFamily: 'Courier',
              ),
            ),
          ),
          // Feedback flash
          if (widget.showFeedback)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: widget.feedbackCorrect
                      ? Colors.green.withOpacity(0.2)
                      : Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Icon(
                    widget.feedbackCorrect ? Icons.check_circle : Icons.cancel,
                    color: widget.feedbackCorrect ? Colors.green : Colors.red,
                    size: 64,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }
}
