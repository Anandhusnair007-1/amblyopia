import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/widgets/ambyoai_widgets.dart';
import '../../../../core/widgets/test_back_guard.dart';
import '../../age_profile.dart';
import '../../test_flow_controller.dart';
import '../../widgets/test_pattern_scaffold.dart';
import '../controllers/parallax_controller.dart';
import '../models/depth_result.dart';
import '../widgets/parallax_image_widget.dart';

class DepthScreenArgs {
  const DepthScreenArgs({
    this.sessionId,
  });

  final String? sessionId;
}

class DepthScreen extends StatefulWidget {
  const DepthScreen({
    super.key,
    required this.args,
  });

  final DepthScreenArgs args;

  @override
  State<DepthScreen> createState() => _DepthScreenState();
}

class _DepthScreenState extends State<DepthScreen> {
  late final ParallaxController _controller;
  int _countdown = 5;
  bool _navigated = false;
  bool _showInstruction = true;
  bool _showTransition = false;
  bool _testStarted = false;

  @override
  void initState() {
    super.initState();
    _controller = ParallaxController()..addListener(_onChanged);
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    await _controller.initialize();
    if (!mounted || _controller.state == ParallaxState.error) {
      return;
    }
    setState(() => _showInstruction = true);
  }

  Future<void> _startTest() async {
    if (_testStarted) return;
    _testStarted = true;

    for (var i = 5; i >= 1; i--) {
      if (!mounted) {
        return;
      }
      setState(() => _countdown = i);
      await Future<void>.delayed(const Duration(seconds: 1));
    }

    if (mounted) {
      setState(() => _countdown = 0);
      await _controller.startTest();
    }
  }

  void _onChanged() {
    final result = _controller.result;
    if (!mounted || _navigated || result == null) {
      setState(() {});
      return;
    }
    if (_controller.state == ParallaxState.completed) {
      TestFlowController().onTestComplete('depth_perception', result);
    }
    setState(() {});
  }

  Future<void> _handleCompletion(DepthPerceptionResult result) async {
    if (!mounted) return;
    if (TestFlowController.isSingleTestMode &&
        TestFlowController.singleTestName == 'depth_perception') {
      await TestFlowController.onSingleTestComplete(
        context,
        testName: 'depth_perception',
        result: result,
      );
      return;
    }

    setState(() => _showTransition = true);
    await Future<void>.delayed(TestFlowController.transitionPreview);
    if (!mounted) return;

    final nextRoute = TestFlowController().getNextRoute('depth_perception');
    if (nextRoute != null) {
      Navigator.of(context).pushReplacementNamed(nextRoute);
    }
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = _controller.result;
    final nextKey = TestFlowController().getNextTest('depth_perception');
    final nextLabel = '▶ Next: ${TestUiMeta.displayName(nextKey)}';

    return TestBackGuard(
      testName: 'Depth Perception',
      testInProgress: _controller.state == ParallaxState.running,
      child: TestPatternScaffold(
        testKey: 'depth_perception',
        testName: isDepthSimplifiedForProfile(TestFlowController.currentProfile)
            ? 'Depth (Simplified, Age 3-4)'
            : 'Depth Perception',
        isCameraActive: false,
        statusText: isDepthSimplifiedForProfile(
                TestFlowController.currentProfile)
            ? 'Observe if the child turns their head toward the moving shape.'
            : (_controller.statusMessage.isEmpty
                ? 'Say FRONT if the dot looks closer, BACK if it looks farther.'
                : _controller.statusMessage),
        isListening: _controller.waitingForResponse,
        instruction: TestInstructionData(
          title: isDepthSimplifiedForProfile(TestFlowController.currentProfile)
              ? 'Depth (Simplified, Age 3-4)'
              : 'Depth Perception Test',
          body: isDepthSimplifiedForProfile(TestFlowController.currentProfile)
              ? 'Observe if the child turns their head toward the moving shape. Complete when done.'
              : 'You will see a glowing dot. Say FRONT if it looks closer, BACK if it looks farther.',
          whatThisChecks:
              isDepthSimplifiedForProfile(TestFlowController.currentProfile)
                  ? 'Simple depth response for preverbal children.'
                  : 'What this test checks: stereo depth perception accuracy.',
        ),
        showInstruction: _showInstruction,
        onInstructionDismiss: () {
          setState(() => _showInstruction = false);
          unawaited(_startTest());
        },
        result: result == null
            ? null
            : TestResultData(
                title: 'Stereo acuity',
                message:
                    '${result.stereoAcuityArcSeconds.toStringAsFixed(0)} arc-seconds',
                detail: result.stereoGrade,
                borderColor: _gradeColor(result.stereoGrade),
                riskLevel: _depthGradeToRiskLevel(result.stereoGrade),
              ),
        nextTestLabel: nextLabel,
        onResultAdvance: () {
          if (_navigated || result == null) return;
          _navigated = true;
          unawaited(_handleCompletion(result));
        },
        showTransition: _showTransition,
        transitionLabel: nextLabel,
        content: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return result == null
                ? _buildTestingState(context)
                : _buildResults(context, result);
          },
        ),
      ),
    );
  }

  Widget _buildTestingState(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_controller.state != ParallaxState.running)
          GlassCard(
            radius: 26,
            backgroundColor: const Color(0xCC101B2C),
            borderColor: Colors.white.withValues(alpha: 0.10),
            glowColor: const Color(0xFF00B4D8),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Depth Perception Test',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                ),
                const SizedBox(height: 12),
                const _Bullet(text: 'Sit still and look at the screen'),
                const _Bullet(text: 'You will see a glowing dot'),
                const _Bullet(text: 'Say FRONT if the dot looks closer'),
                const _Bullet(text: 'Say BACK if the dot looks further'),
                const _Bullet(text: '6 quick trials'),
                const SizedBox(height: 12),
                Text(
                  _countdown > 0
                      ? 'Auto starts in $_countdown...'
                      : _controller.statusMessage,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: const Color(0xFF7DD3FC),
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: ColoredBox(
              color: const Color(0xFF06111A),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ParallaxImageWidget(
                      headPosition: _controller.headPosition,
                      disparity: _controller.currentDisparity == 0
                          ? 40
                          : _controller.currentDisparity,
                      targetPosition: _controller.correctAnswer,
                    ),
                  ),
                  Positioned(
                    top: 20,
                    left: 20,
                    right: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Trial ${(_controller.currentTrial + 1).clamp(1, 6)} of 6',
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: (_controller.currentTrial / 6).clamp(0.0, 1.0),
                          minHeight: 8,
                          backgroundColor: const Color(0x224DD0E1),
                          color: const Color(0xFFFFB300),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 26,
                    child: Column(
                      children: [
                        Icon(
                          Icons.mic_rounded,
                          size: 44,
                          color: _controller.waitingForResponse
                              ? const Color(0xFFFFB300)
                              : Colors.white70,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _controller.waitingForResponse
                              ? 'Listening... say FRONT or BACK'
                              : _controller.statusMessage,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResults(BuildContext context, DepthPerceptionResult result) {
    final color = _gradeColor(result.stereoGrade);

    return ListView(
      children: [
        GlassCard(
          radius: 28,
          backgroundColor: const Color(0xCC15131D),
          borderColor: color.withValues(alpha: 0.35),
          glowColor: color,
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              Text(
                '${result.correctAnswers} / ${result.totalTrials}',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  result.stereoGrade.toUpperCase(),
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Stereo acuity: ${result.stereoAcuityArcSeconds.toStringAsFixed(0)} arc-seconds',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        GlassCard(
          radius: 28,
          backgroundColor: const Color(0xCC101B2C),
          borderColor: Colors.white.withValues(alpha: 0.10),
          glowColor: const Color(0xFF00B4D8),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Trial Breakdown',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 12),
              ...result.trials.map(
                (trial) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Trial ${trial.trialNumber}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          '${trial.disparityPixels.toStringAsFixed(0)} px',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          trial.patientAnswer.toUpperCase(),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      Text(
                        trial.isCorrect ? '✓' : '✗',
                        style: TextStyle(
                          color: trial.isCorrect
                              ? const Color(0xFF22C55E)
                              : const Color(0xFFF87171),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                result.clinicalNote,
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _gradeColor(String grade) {
    return switch (grade) {
      'Excellent' => const Color(0xFF2E7D32),
      'Good' => const Color(0xFF00897B),
      'Reduced' => const Color(0xFFF9A825),
      _ => const Color(0xFFC62828),
    };
  }

  static String _depthGradeToRiskLevel(String grade) {
    return switch (grade) {
      'Excellent' || 'Good' => 'NORMAL',
      'Reduced' => 'MILD',
      _ => 'HIGH',
    };
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(Icons.circle, size: 8, color: Color(0xFF38BDF8)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }
}
