import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

class TestScreenShell extends StatefulWidget {
  const TestScreenShell({
    super.key,
    required this.title,
    required this.step,
    required this.total,
    required this.progress,
    required this.child,
    required this.statusText,
    required this.isListening,
    required this.instructionTitle,
    required this.instructionBody,
    this.darkBackground = false,
    this.disableBack = false,
    this.onBack,
    this.showResult = false,
    this.resultTitle,
    this.resultValue,
    this.resultColor = const Color(0xFF00897B),
    this.nextLabel,
  });

  final String title;
  final int step;
  final int total;
  final double progress;
  final Widget child;
  final String statusText;
  final bool isListening;
  final String instructionTitle;
  final String instructionBody;
  final bool darkBackground;
  final bool disableBack;
  final VoidCallback? onBack;
  final bool showResult;
  final String? resultTitle;
  final String? resultValue;
  final Color resultColor;
  final String? nextLabel;

  @override
  State<TestScreenShell> createState() => _TestScreenShellState();
}

class _TestScreenShellState extends State<TestScreenShell>
    with TickerProviderStateMixin {
  bool _showInstruction = true;
  Timer? _instructionTimer;
  Timer? _resultTimer;
  int _countdown = 3;
  late final AnimationController _micController;

  @override
  void initState() {
    super.initState();
    _micController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _instructionTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _showInstruction = false);
    });
  }

  @override
  void didUpdateWidget(covariant TestScreenShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.showResult && widget.showResult) {
      _countdown = 3;
      _resultTimer?.cancel();
      _resultTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;
        if (_countdown <= 1) {
          timer.cancel();
        } else {
          setState(() => _countdown--);
        }
      });
    }
  }

  @override
  void dispose() {
    _instructionTimer?.cancel();
    _resultTimer?.cancel();
    _micController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.darkBackground ? Colors.black : Colors.white,
      body: Stack(
        children: [
          Positioned.fill(child: widget.child),
          SafeArea(
            child: Column(
              children: [
                _TopBar(
                  title: widget.title,
                  step: widget.step,
                  total: widget.total,
                  disableBack: widget.disableBack,
                  onBack: widget.onBack,
                ),
                LinearProgressIndicator(
                  value: widget.progress.clamp(0.0, 1.0),
                  minHeight: 3,
                  backgroundColor: widget.darkBackground
                      ? const Color(0x33FFFFFF)
                      : const Color(0xFFE6EEF6),
                  color: const Color(0xFF00B4D8),
                ),
              ],
            ),
          ),
          if (_showInstruction)
            _InstructionCard(
              title: widget.instructionTitle,
              body: widget.instructionBody,
              onDismiss: () => setState(() => _showInstruction = false),
            ),
          _StatusBar(
            text: widget.statusText,
            isListening: widget.isListening,
            controller: _micController,
          ),
          if (widget.showResult)
            _ResultCard(
              title: widget.resultTitle ?? 'Result',
              value: widget.resultValue ?? '',
              color: widget.resultColor,
              nextLabel: widget.nextLabel,
              countdown: _countdown,
            ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.step,
    required this.total,
    required this.disableBack,
    required this.onBack,
  });

  final String title;
  final int step;
  final int total;
  final bool disableBack;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Row(
        children: [
          IconButton(
            onPressed: disableBack
                ? null
                : onBack ?? () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_rounded),
            color: disableBack ? Colors.grey : const Color(0xFF0A1628),
          ),
          Expanded(
            child: Center(
              child: Text(
                title,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0A1628)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Text(
              'Test $step of $total',
              style: const TextStyle(fontSize: 12, color: Color(0xFF7B879C)),
            ),
          ),
        ],
      ),
    );
  }
}

class _InstructionCard extends StatelessWidget {
  const _InstructionCard({
    required this.title,
    required this.body,
    required this.onDismiss,
  });

  final String title;
  final String body;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 90,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 280),
        offset: Offset.zero,
        child: Material(
          borderRadius: BorderRadius.circular(14),
          elevation: 6,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0A1628)),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF6B7C93)),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: onDismiss,
                    child: const Text('Got it →'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({
    required this.text,
    required this.isListening,
    required this.controller,
  });

  final String text;
  final bool isListening;
  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: const BoxDecoration(
          color: Color(0xCC0A1628),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
            if (isListening)
              ScaleTransition(
                scale: Tween(begin: 0.9, end: 1.1).animate(controller),
                child: const Icon(Icons.mic_rounded, color: Color(0xFF00B4D8)),
              )
            else
              const Icon(Icons.mic_none_rounded, color: Color(0xFF7B879C)),
          ],
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.title,
    required this.value,
    required this.color,
    required this.countdown,
    this.nextLabel,
  });

  final String title;
  final String value;
  final Color color;
  final int countdown;
  final String? nextLabel;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 90,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 300),
        offset: Offset.zero,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color, width: 2),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 6),
                    Text(
                      value,
                      style: TextStyle(
                          color: color,
                          fontSize: 16,
                          fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      nextLabel == null
                          ? 'Next test in $countdown...'
                          : '${nextLabel!} in $countdown...',
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF7B879C)),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 36,
                height: 36,
                child: CustomPaint(
                  painter: _CountdownRingPainter(progress: countdown / 3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountdownRingPainter extends CustomPainter {
  const _CountdownRingPainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(2, 2, size.width - 4, size.height - 4);
    final bg = Paint()
      ..color = const Color(0xFFE3EAF2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final fg = Paint()
      ..color = const Color(0xFF00B4D8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, 2 * math.pi, false, bg);
    canvas.drawArc(
        rect, -math.pi / 2, 2 * math.pi * progress.clamp(0.0, 1.0), false, fg);
  }

  @override
  bool shouldRepaint(covariant _CountdownRingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
