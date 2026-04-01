import 'package:flutter/material.dart';

class SnellenChartWidget extends StatelessWidget {
  const SnellenChartWidget({
    super.key,
    required this.lineFraction,
    required this.lineIndex,
    required this.totalLines,
  });

  final String lineFraction;
  final int lineIndex;
  final int totalLines;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F4FB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD8E0ED)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Current line: $lineFraction',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF13213A),
                  ),
            ),
          ),
          Text(
            '${lineIndex + 1} / $totalLines',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: const Color(0xFF66748B),
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

