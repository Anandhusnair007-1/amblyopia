import 'package:flutter/material.dart';

class TestProgressBar extends StatelessWidget {
  const TestProgressBar({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    this.height = 8,
    this.color = const Color(0xFF00BCD4),
  });

  final int currentStep;
  final int totalSteps;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final safeTotal = totalSteps <= 0 ? 1 : totalSteps;
    final clamped = currentStep.clamp(0, safeTotal);
    final value = clamped / safeTotal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Test $clamped of $safeTotal',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: const Color(0xFF64748B),
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: value,
            minHeight: height,
            color: color,
            backgroundColor: const Color(0x1A00BCD4),
          ),
        ),
      ],
    );
  }
}
