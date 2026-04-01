import 'package:flutter/material.dart';

class OnboardingPage extends StatelessWidget {
  const OnboardingPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.painter,
    this.parallax = 0,
  });

  final String title;
  final String subtitle;
  final CustomPainter painter;
  final double parallax;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Transform.translate(
            offset: Offset(parallax * 12, 0),
            child: SizedBox(
              height: 220,
              child: CustomPaint(
                painter: painter,
                child: const SizedBox.expand(),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 22,
                  color: const Color(0xFF0A1628),
                ),
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontSize: 15,
                  color: const Color(0xFF55657E),
                ),
          ),
        ],
      ),
    );
  }
}
