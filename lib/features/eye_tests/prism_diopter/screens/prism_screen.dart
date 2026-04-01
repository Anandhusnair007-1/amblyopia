import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/widgets/ambyoai_snackbar.dart';
import '../../../../core/widgets/ambyoai_widgets.dart';
import '../../../../core/widgets/enterprise_ui.dart';
import '../../../../core/widgets/test_back_guard.dart';
import '../../gaze_detection/models/gaze_result.dart';
import '../../hirschberg_test/models/hirschberg_result.dart';
import '../../hirschberg_test/screens/hirschberg_screen.dart';
import '../../test_flow_controller.dart';
import '../../widgets/test_pattern_scaffold.dart';
import '../controllers/prism_calculator.dart';
import '../models/prism_result.dart';

class PrismScreenArgs {
  const PrismScreenArgs({
    required this.sessionId,
    required this.gazeResult,
    this.hirschbergResult,
  });

  final String sessionId;
  final GazeTestResult? gazeResult;
  final HirschbergResult? hirschbergResult;
}

class PrismScreen extends StatefulWidget {
  const PrismScreen({
    super.key,
    required this.args,
  });

  final PrismScreenArgs args;

  @override
  State<PrismScreen> createState() => _PrismScreenState();
}

class _PrismScreenState extends State<PrismScreen>
    with SingleTickerProviderStateMixin {
  late final PrismCalculator _calculator;
  late final AnimationController _animationController;
  PrismDiopterResult? _result;
  final _manualDeviation = TextEditingController();
  bool _manualMode = false;
  bool _showInstruction = true;
  bool _showTransition = false;
  bool _testStarted = false;

  @override
  void initState() {
    super.initState();
    _calculator = PrismCalculator(sessionId: widget.args.sessionId);
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  Future<void> _startTest() async {
    if (_testStarted) return;
    _testStarted = true;
    await _run();
  }

  Future<void> _run() async {
    await Future<void>.delayed(const Duration(seconds: 2));
    final gaze = widget.args.gazeResult;
    if (gaze == null) {
      if (mounted) setState(() => _manualMode = true);
      return;
    }
    if (!mounted) return;
    final result = await _calculator.calculateFromGaze(gaze);
    TestFlowController().onTestComplete('prism_diopter', result);
    if (!mounted) return;
    setState(() => _result = result);
  }

  Future<void> _navigateToNext() async {
    final result = _result;
    if (result == null || !mounted) return;
    if (TestFlowController.isSingleTestMode &&
        TestFlowController.singleTestName == 'prism_diopter') {
      await TestFlowController.onSingleTestComplete(
        context,
        testName: 'prism_diopter',
        result: result,
      );
      return;
    }
    setState(() => _showTransition = true);
    await Future<void>.delayed(TestFlowController.transitionPreview);
    if (!mounted) return;
    final nextRoute = TestFlowController().getNextRoute('prism_diopter');
    if (nextRoute != null) {
      Navigator.of(context).pushReplacementNamed(
        nextRoute,
        arguments: HirschbergScreenArgs(
          sessionId: widget.args.sessionId,
          gazeResult: widget.args.gazeResult,
        ),
      );
    }
  }

  Future<void> _saveManual() async {
    final v = double.tryParse(_manualDeviation.text.trim());
    if (v == null || v < 0) {
      AmbyoSnackbar.show(context,
          message: 'Enter a valid deviation in prism diopters.',
          type: SnackbarType.warning);
      return;
    }
    final result = await _calculator.saveManual(totalDeviation: v);
    TestFlowController().onTestComplete('prism_diopter', result);
    if (!mounted) return;
    setState(() => _result = result);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _manualDeviation.dispose();
    _calculator.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final nextKey = TestFlowController().getNextTest('prism_diopter');
    final nextLabel = '▶ Next: ${TestUiMeta.displayName(nextKey)}';

    return TestBackGuard(
      testName: 'Prism Diopter',
      testInProgress: _result == null && !_showTransition,
      child: TestPatternScaffold(
        testKey: 'prism_diopter',
        testName: 'Prism Diopter',
        isCameraActive: false,
        statusText: result != null
            ? 'Prism calculation complete.'
            : _manualMode
                ? 'Enter the measured deviation and save.'
                : 'Calculating prism diopters...',
        isListening: false,
        instruction: const TestInstructionData(
          title: 'Prism Diopter',
          body:
              'This step converts gaze deviations into clinical prism diopters. It runs automatically from the prior test.',
          whatThisChecks:
              'What this test checks: deviation magnitude in prism diopters.',
        ),
        showInstruction: _showInstruction,
        onInstructionDismiss: () {
          setState(() => _showInstruction = false);
          unawaited(_startTest());
        },
        result: result == null
            ? null
            : TestResultData(
                title: 'Total deviation',
                message: '${result.totalDeviation.toStringAsFixed(1)}Δ',
                detail: result.severity,
                borderColor: _severityColor(result.severity),
                riskLevel: _severityToRiskLevel(result.severity),
              ),
        nextTestLabel: nextLabel,
        onResultAdvance: () => unawaited(_navigateToNext()),
        showTransition: _showTransition,
        transitionLabel: nextLabel,
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: result == null
              ? (_manualMode
                  ? _ManualEntry(
                      controller: _manualDeviation, onSave: _saveManual)
                  : _CalculationIntro(animation: _animationController))
              : _ResultLayout(result: result),
        ),
      ),
    );
  }

  Color _severityColor(String severity) {
    switch (severity) {
      case 'Severe':
        return const Color(0xFFC62828);
      case 'Moderate':
        return const Color(0xFFEF6C00);
      case 'Mild':
        return const Color(0xFFF9A825);
      default:
        return const Color(0xFF2E7D32);
    }
  }

  static String _severityToRiskLevel(String severity) {
    switch (severity) {
      case 'Severe':
        return 'URGENT';
      case 'Moderate':
        return 'HIGH';
      case 'Mild':
        return 'MILD';
      default:
        return 'NORMAL';
    }
  }
}

class _CalculationIntro extends StatelessWidget {
  const _CalculationIntro({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GlassCard(
        radius: 28,
        backgroundColor: const Color(0xCC101B2C),
        borderColor: Colors.white.withValues(alpha: 0.10),
        glowColor: const Color(0xFF00B4D8),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RotationTransition(
              turns: animation,
              child: const Icon(
                Icons.auto_graph_rounded,
                size: 54,
                color: Color(0xFF1A237E),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Calculating prism diopters...',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF13213A),
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              'Δ = 100 × tan(θ)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF1A237E),
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 10),
            Text(
              'Using the captured 9-direction gaze vectors to derive clinical prism values.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white70,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ManualEntry extends StatelessWidget {
  const _ManualEntry({
    required this.controller,
    required this.onSave,
  });

  final TextEditingController controller;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GlassCard(
        radius: 28,
        backgroundColor: const Color(0xCC101B2C),
        borderColor: Colors.white.withValues(alpha: 0.10),
        glowColor: const Color(0xFF00B4D8),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Manual Prism Entry',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF13213A),
                  ),
            ),
            const SizedBox(height: 10),
            Text(
              'This session does not include gaze tracking data. Enter the measured prism deviation (Δ) to record the result.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                  ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Total deviation (Δ)',
                prefixIcon: Icon(Icons.straighten_rounded),
                hintText: 'e.g. 12.0',
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onSave,
                icon: const Icon(Icons.save_rounded),
                label: const Text('Save Result'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultLayout extends StatelessWidget {
  const _ResultLayout({required this.result});

  final PrismDiopterResult result;

  @override
  Widget build(BuildContext context) {
    final color = switch (result.severity) {
      'Severe' => const Color(0xFFC62828),
      'Moderate' => const Color(0xFFEF6C00),
      'Mild' => const Color(0xFFF9A825),
      _ => const Color(0xFF2E7D32),
    };

    const gridOrder = <String>[
      'upLeft',
      'up',
      'upRight',
      'left',
      'center',
      'right',
      'downLeft',
      'down',
      'downRight',
    ];

    return ListView(
      children: [
        EnterprisePanel(
          child: Column(
            children: [
              Text(
                '${result.totalDeviation.toStringAsFixed(1)}Δ',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Prism Diopters',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: const Color(0xFF13213A),
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 14),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  result.severity,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.1,
          ),
          itemCount: gridOrder.length,
          itemBuilder: (context, index) {
            final key = gridOrder[index];
            final value = result.prismPerDirection[key] ?? 0;
            final tileColor = value >= 40
                ? const Color(0xFFC62828)
                : value >= 20
                    ? const Color(0xFFEF6C00)
                    : value >= 10
                        ? const Color(0xFFF9A825)
                        : const Color(0xFF2E7D32);
            return GlassCard(
              radius: 20,
              backgroundColor: const Color(0xCC101B2C),
              borderColor: tileColor.withValues(alpha: 0.45),
              glowColor: tileColor,
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    key,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Colors.white60,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${value.toStringAsFixed(1)}Δ',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: tileColor,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        EnterprisePanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ClinicalLine(
                  label: 'Deviation Type', value: result.deviationType),
              _ClinicalLine(
                  label: 'Base Direction', value: result.baseDirection),
              _ClinicalLine(label: 'Severity', value: result.severity),
              _ClinicalLine(
                label: 'Correction',
                value: result.requiresCorrection
                    ? 'Prism correction may be needed'
                    : 'No correction indicated',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ClinicalLine extends StatelessWidget {
  const _ClinicalLine({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: const Color(0xFF66748B),
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: const Color(0xFF13213A),
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
