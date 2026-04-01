import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/ambyo_theme.dart';
import '../../../../core/widgets/ambyoai_widgets.dart';
import '../../../../core/widgets/test_back_guard.dart';
import '../../test_flow_controller.dart';
import '../../widgets/test_pattern_scaffold.dart';
import '../controllers/worth_four_dot_controller.dart';

class WorthFourDotScreen extends StatefulWidget {
  const WorthFourDotScreen({super.key});

  @override
  State<WorthFourDotScreen> createState() => _WorthFourDotScreenState();
}

class _WorthFourDotScreenState extends State<WorthFourDotScreen> {
  final WorthFourDotController _controller = WorthFourDotController();
  bool _showInstruction = true;
  bool _showTransition = false;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    await _controller.initialize();
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _start() async {
    if (_started) return;
    _started = true;
    await _controller.startTest();
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _complete() async {
    final result = _controller.result;
    if (result == null) return;
    TestFlowController().onTestComplete('worth_four_dot', result);
    if (TestFlowController.isSingleTestMode &&
        TestFlowController.singleTestName == 'worth_four_dot') {
      await TestFlowController.onSingleTestComplete(
        context,
        testName: 'worth_four_dot',
        result: result,
      );
      return;
    }
    setState(() => _showTransition = true);
    await Future<void>.delayed(TestFlowController.transitionPreview);
    if (!mounted) return;

    final nextRoute = TestFlowController().getNextRoute('worth_four_dot');
    if (nextRoute != null) {
      Navigator.of(context).pushReplacementNamed(nextRoute);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = _controller.result;
    return TestBackGuard(
      testName: 'Worth 4 Dot',
      testInProgress: _controller.state == WorthFourDotState.running,
      child: TestPatternScaffold(
        testKey: 'worth_four_dot',
        testName: 'Worth 4 Dot',
        totalTests: 1,
        isCameraActive: false,
        statusText: _controller.statusMessage,
        isListening: _controller.isListening,
        instruction: const TestInstructionData(
          title: 'Worth 4 Dot',
          body:
              'Look at the colored dots, then answer how many dots you see. Use voice or tap a number.',
          whatThisChecks:
              'What this test checks: binocular fusion and suppression using a glasses-free hand-cover method.',
          autoDismissDuration: Duration(seconds: 6),
        ),
        showInstruction: _showInstruction,
        onInstructionDismiss: () {
          setState(() => _showInstruction = false);
          unawaited(_start());
        },
        result: result == null
            ? null
            : TestResultData(
                title: 'Fusion status',
                message: result.fusionStatus,
                detail: result.clinicalNote,
                borderColor: result.requiresReferral
                    ? AmbyoTheme.warningColor
                    : AmbyoTheme.successColor,
                riskLevel: result.requiresReferral ? 'MILD' : 'NORMAL',
              ),
        nextTestLabel:
            '▶ Next: ${TestUiMeta.displayName(TestFlowController().getNextTest('worth_four_dot'))}',
        onResultAdvance: () => unawaited(_complete()),
        showTransition: _showTransition,
        transitionLabel:
            '▶ Next: ${TestUiMeta.displayName(TestFlowController().getNextTest('worth_four_dot'))}',
        content: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return ListView(
              children: [
                GlassCard(
                  radius: 26,
                  backgroundColor: const Color(0xCC101B2C),
                  borderColor: Colors.white.withValues(alpha: 0.10),
                  glowColor: const Color(0xFF00B4D8),
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Stage ${(_controller.currentStage + 1).clamp(1, _controller.totalStages)} of ${_controller.totalStages}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value:
                            (_controller.currentStage / _controller.totalStages)
                                .clamp(0.0, 1.0),
                        minHeight: 8,
                        backgroundColor: const Color(0x2238BDF8),
                        color: const Color(0xFF38BDF8),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        _controller.stageLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _controller.prompt,
                        style:
                            const TextStyle(color: Colors.white70, height: 1.4),
                      ),
                      const SizedBox(height: 18),
                      const Center(child: _WorthDots()),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: List<Widget>.generate(5, (index) {
                    final count = index + 1;
                    return SizedBox(
                      width: 64,
                      child: FilledButton(
                        onPressed:
                            _controller.state == WorthFourDotState.running
                                ? () => _controller.submitManualAnswer(count)
                                : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0EA5E9),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text('$count'),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 14),
                GlassCard(
                  radius: 22,
                  backgroundColor: const Color(0xCC0F1726),
                  borderColor: Colors.white.withValues(alpha: 0.08),
                  glowColor: const Color(0xFF22D3EE),
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _controller.helper,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _WorthDots extends StatelessWidget {
  const _WorthDots();

  @override
  Widget build(BuildContext context) {
    Widget dot(Color color) => Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.45),
                blurRadius: 18,
                spreadRadius: -2,
              ),
            ],
          ),
        );

    return SizedBox(
      width: 180,
      height: 140,
      child: Stack(
        children: [
          Positioned(left: 24, top: 24, child: dot(const Color(0xFFFF5252))),
          Positioned(right: 24, top: 24, child: dot(const Color(0xFFFF5252))),
          Positioned(left: 72, top: 54, child: dot(const Color(0xFFFFFFFF))),
          Positioned(left: 24, bottom: 24, child: dot(const Color(0xFF22C55E))),
          Positioned(
              right: 24, bottom: 24, child: dot(const Color(0xFF22C55E))),
        ],
      ),
    );
  }
}
