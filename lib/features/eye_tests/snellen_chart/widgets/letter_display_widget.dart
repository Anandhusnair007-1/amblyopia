import 'package:flutter/material.dart';

class LetterDisplayWidget extends StatelessWidget {
  const LetterDisplayWidget({
    super.key,
    required this.letter,
    required this.heightPx,
    required this.isListening,
  });

  final String letter;
  final double heightPx;
  final bool isListening;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isListening ? const Color(0xFFFFB300) : const Color(0xFFD8E0ED),
          width: isListening ? 2.4 : 1.2,
        ),
      ),
      child: Text(
        letter,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: heightPx.clamp(22, 180),
          fontWeight: FontWeight.w900,
          color: Colors.black,
          letterSpacing: 2.0,
        ),
      ),
    );
  }
}

