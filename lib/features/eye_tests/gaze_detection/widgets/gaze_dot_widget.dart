import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class GazeDotWidget extends StatefulWidget {
  const GazeDotWidget({
    super.key,
    required this.position,
    required this.isCapturing,
    required this.screenSize,
  });

  final Offset position;
  final bool isCapturing;
  final Size screenSize;

  @override
  State<GazeDotWidget> createState() => _GazeDotWidgetState();
}

class _GazeDotWidgetState extends State<GazeDotWidget> {
  @override
  Widget build(BuildContext context) {
    final left = (widget.screenSize.width * widget.position.dx) - 20;
    final top = (widget.screenSize.height * widget.position.dy) - 20;

    const glow = BoxShadow(
      color: Color(0xCCFFB300),
      blurRadius: 24,
      spreadRadius: 6,
    );
    final dot = Container(
      width: 40,
      height: 40,
      decoration: const BoxDecoration(
        color: Color(0xFFFFB300),
        shape: BoxShape.circle,
        boxShadow: <BoxShadow>[glow],
      ),
    );

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOutCubic,
      left: left,
      top: top,
      child: widget.isCapturing
          ? dot
              .animate(onPlay: (controller) => controller.repeat(reverse: true))
              .scale(begin: const Offset(0.86, 0.86), end: const Offset(1.18, 1.18), duration: 500.ms)
              .fade(begin: 0.75, end: 1.0, duration: 500.ms)
          : dot,
    );
  }
}
