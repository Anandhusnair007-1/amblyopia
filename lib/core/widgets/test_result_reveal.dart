import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/ambyoai_design_system.dart';
import 'ambyoai_widgets.dart';
import '../../features/eye_tests/test_quality.dart';

/// White rounded top sheet: result value (risk color), label, AmbyoRiskBadge, clinical note, countdown + Next.
class TestResultReveal extends StatefulWidget {
  const TestResultReveal({
    super.key,
    required this.testName,
    required this.resultValue,
    required this.resultLabel,
    required this.riskLevel,
    this.clinicalNote,
    this.autoAdvanceSeconds = 3,
    required this.onAdvance,
    this.quality,
  });

  final String testName;
  final String resultValue;
  final String resultLabel;
  final String riskLevel;
  final String? clinicalNote;
  final int autoAdvanceSeconds;
  final VoidCallback onAdvance;
  final TestQuality? quality;

  @override
  State<TestResultReveal> createState() => _TestResultRevealState();
}

class _TestResultRevealState extends State<TestResultReveal> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Timer? _timer;
  int _remaining = 0;

  @override
  void initState() {
    super.initState();
    _remaining = widget.autoAdvanceSeconds;
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.autoAdvanceSeconds),
    )..forward();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _remaining = (_remaining - 1).clamp(0, widget.autoAdvanceSeconds);
        if (_remaining <= 0) {
          _timer?.cancel();
          widget.onAdvance();
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final riskColor = AmbyoColors.riskColor(widget.riskLevel);
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AmbyoColors.borderLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.resultLabel,
                style: AmbyoTextStyles.caption(),
              ),
              const SizedBox(height: 4),
              Text(
                widget.resultValue,
                style: AmbyoTextStyles.data(size: 22, color: riskColor),
              ),
              const SizedBox(height: 8),
              AmbyoRiskBadge(level: widget.riskLevel),
              if (widget.clinicalNote != null && widget.clinicalNote!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AmbyoSpacing.cardPadding),
                  decoration: BoxDecoration(
                    color: riskColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AmbyoSpacing.cardRadius),
                  ),
                  child: Text(
                    widget.clinicalNote!,
                    style: AmbyoTextStyles.body(color: AmbyoColors.textSecondary, fontSize: 13),
                  ),
                ),
              ],
              if (widget.quality != null && widget.quality!.score < 0.8) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: widget.quality!.color.withValues(alpha: 0.08),
                    border: Border.all(
                      color: widget.quality!.color.withValues(alpha: 0.3),
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Icon(
                            Icons.info_outline,
                            size: 14,
                            color: widget.quality!.color,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Quality: ${widget.quality!.label}',
                            style: AmbyoTextStyles.caption(color: widget.quality!.color),
                          ),
                        ],
                      ),
                      ...widget.quality!.warnings.map(
                        (w) => Padding(
                          padding: const EdgeInsets.only(top: 4, left: 20),
                          child: Text(
                            '• $w',
                            style: AmbyoTextStyles.caption(),
                          ),
                        ),
                      ),
                      if (!widget.quality!.isAcceptable)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            'Consider repeating this test for better accuracy.',
                            style: AmbyoTextStyles.caption(color: AmbyoColors.urgentRed),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              _CountdownRow(
                remaining: _remaining,
                total: widget.autoAdvanceSeconds,
                color: riskColor,
                onAdvanceNow: () {
                  _timer?.cancel();
                  widget.onAdvance();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountdownRow extends StatelessWidget {
  const _CountdownRow({
    required this.remaining,
    required this.total,
    required this.color,
    required this.onAdvanceNow,
  });

  final int remaining;
  final int total;
  final Color color;
  final VoidCallback onAdvanceNow;

  @override
  Widget build(BuildContext context) {
    final value = total > 0 ? (remaining / total).clamp(0.0, 1.0) : 0.0;
    return Row(
      children: [
        SizedBox(
          width: 38,
          height: 38,
          child: CircularProgressIndicator(
            value: value,
            strokeWidth: 3.2,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            backgroundColor: color.withValues(alpha: 0.15),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          remaining > 0 ? 'Next test in $remaining seconds' : 'Next test in 0 seconds',
          style: AmbyoTextStyles.data(size: 12, color: AmbyoColors.textPrimary),
        ),
        const Spacer(),
        TextButton(
          onPressed: onAdvanceNow,
          child: const Text('Next Now'),
        ),
      ],
    );
  }
}
