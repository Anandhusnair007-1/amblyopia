import 'package:flutter/material.dart';

/// Animated microphone indicator shown at the bottom of all voice tests.
/// Pulses when actively listening; fades when idle.
class MicListeningIndicator extends StatefulWidget {
  const MicListeningIndicator({
    super.key,
    required this.isListening,
    required this.statusText,
  });

  final bool isListening;
  final String statusText;

  @override
  State<MicListeningIndicator> createState() => _MicListeningIndicatorState();
}

class _MicListeningIndicatorState extends State<MicListeningIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    if (widget.isListening) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(MicListeningIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isListening && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!widget.isListening && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.animateTo(0);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) {
        final pulseOpacity = widget.isListening ? (0.7 + _pulse.value * 0.3) : 0.4;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.isListening
                    ? const Color(0xFF00B4D8).withValues(alpha: 0.15 + _pulse.value * 0.1)
                    : Colors.white.withValues(alpha: 0.07),
                border: Border.all(
                  color: widget.isListening
                      ? const Color(0xFF00B4D8).withValues(alpha: 0.4 + _pulse.value * 0.2)
                      : Colors.white.withValues(alpha: 0.15),
                ),
              ),
              child: Icon(
                widget.isListening ? Icons.mic_rounded : Icons.mic_off_rounded,
                color: widget.isListening
                    ? Color.lerp(const Color(0xFF00B4D8), Colors.white,
                        _pulse.value * 0.3)!
                    : Colors.white38,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Opacity(
              opacity: pulseOpacity,
              child: Text(
                widget.statusText,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  color: Colors.white70,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
