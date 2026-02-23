import 'package:flutter/material.dart';

class VoiceButton extends StatefulWidget {
  final bool isListening;
  final VoidCallback? onTap;

  const VoiceButton({super.key, required this.isListening, this.onTap});

  @override
  State<VoiceButton> createState() => _VoiceButtonState();
}

class _VoiceButtonState extends State<VoiceButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _pulse = Tween(begin: 1.0, end: 1.2).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void didUpdateWidget(VoiceButton old) {
    super.didUpdateWidget(old);
    if (widget.isListening) {
      _ctrl.repeat(reverse: true);
    } else {
      _ctrl.stop();
      _ctrl.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _pulse,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.isListening
                ? Colors.red.withOpacity(0.3)
                : const Color(0xFF0D1B2A),
            border: Border.all(
              color: widget.isListening ? Colors.red : const Color(0xFF1565C0),
              width: 2,
            ),
            boxShadow: widget.isListening
                ? [BoxShadow(color: Colors.red.withOpacity(0.4), blurRadius: 16)]
                : [],
          ),
          child: Icon(
            widget.isListening ? Icons.mic : Icons.mic_none,
            color: widget.isListening ? Colors.red : const Color(0xFF90CAF9),
            size: 32,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }
}
