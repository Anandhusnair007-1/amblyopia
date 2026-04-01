// ignore_for_file: unused_element

import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/theme/ambyo_theme.dart';
import '../../../../core/widgets/enterprise_ui.dart';
import '../../../../core/widgets/test_back_guard.dart';
import '../../test_flow_controller.dart';
import '../../widgets/test_pattern_scaffold.dart';
import '../controllers/lang_controller.dart';
import '../models/lang_result.dart';
import '../widgets/random_dot_widget.dart';

class LangScreen extends StatefulWidget {
  const LangScreen({super.key});

  @override
  State<LangScreen> createState() => _LangScreenState();
}

class _LangScreenState extends State<LangScreen> {
  final LangController _controller = LangController();
  bool _showIntro = true;
  bool _showTransition = false;
  bool _testStarted = false;
  bool _micDialogShown = false;

  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    await _controller.initialize();
    if (!mounted || _controller.state == LangState.error) {
      setState(() {});
      return;
    }
    setState(() => _showIntro = true);
  }

  Future<void> _startTest() async {
    if (_testStarted) return;
    _testStarted = true;
    setState(() {});
    await _controller.startTest();
  }

  Future<void> _handleCompletion() async {
    final result = _controller.result;
    if (result == null) return;
    TestFlowController().onTestComplete('lang_stereo', result);
    if (!mounted) return;

    if (TestFlowController.isSingleTestMode &&
        TestFlowController.singleTestName == 'lang_stereo') {
      await TestFlowController.onSingleTestComplete(
        context,
        testName: 'lang_stereo',
        result: result,
      );
      return;
    }

    setState(() => _showTransition = true);
    await Future<void>.delayed(TestFlowController.transitionPreview);
    if (!mounted) return;
    final nextRoute = TestFlowController().getNextRoute('lang_stereo');
    if (nextRoute != null) {
      Navigator.of(context).pushReplacementNamed(nextRoute);
    }
  }

  void _maybeShowMicPermissionDialog() {
    if (_micDialogShown) return;
    if (!_controller.statusMessage
        .toLowerCase()
        .contains('microphone permission denied')) {
      return;
    }
    _micDialogShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_showMicPermissionDialog());
    });
  }

  Future<void> _showMicPermissionDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F1622),
        title: const Text('Microphone Permission Needed',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'Voice answers are unavailable because microphone permission is denied.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              unawaited(_skipVoiceTest());
            },
            child: const Text('Skip Voice Test'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _skipVoiceTest() async {
    const skipped = LangResult(
      pattern1Passed: false,
      pattern2Passed: false,
      pattern3Passed: false,
      patternsDetected: 0,
      stereopsisLevel: 'Absent',
      leftEyeConverged: false,
      rightEyeConverged: false,
      isNormal: false,
      requiresReferral: true,
      clinicalNote:
          'Lang stereo test skipped due to denied microphone permission.',
      normalityScore: 0.0,
    );
    TestFlowController().onTestComplete('lang_stereo', skipped);
    if (!mounted) return;
    final nextRoute = TestFlowController().getNextRoute('lang_stereo');
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
    final nextKey = TestFlowController().getNextTest('lang_stereo');
    final nextLabel = '▶ Next: ${TestUiMeta.displayName(nextKey)}';
    return TestBackGuard(
      testName: 'Lang Stereo',
      testInProgress: _controller.state == LangState.running,
      child: TestPatternScaffold(
        testKey: 'lang_stereo',
        testName: 'Lang Stereo Test',
        isCameraActive: _controller.camera?.value.isInitialized ?? false,
        statusText: _controller.statusMessage.isEmpty
            ? 'Follow the dot patterns.'
            : _controller.statusMessage,
        isListening: _controller.isListening,
        instruction: const TestInstructionData(
          title: 'Lang Stereo Test',
          body:
              'Look carefully at the dot pattern. Say what you see, or say NOTHING.',
          whatThisChecks: 'What this test checks: stereo depth perception.',
        ),
        showInstruction: _showIntro,
        onInstructionDismiss: () {
          setState(() => _showIntro = false);
          unawaited(_startTest());
        },
        result: _controller.result == null
            ? null
            : TestResultData(
                title: 'Stereo level',
                message: _controller.result!.stereopsisLevel,
                detail: _controller.result!.clinicalNote,
                borderColor: _levelColor(_controller.result!.stereopsisLevel),
                riskLevel: _langPatternsToRiskLevel(
                    _controller.result!.patternsDetected),
              ),
        nextTestLabel: nextLabel,
        onResultAdvance: () => unawaited(_handleCompletion()),
        showTransition: _showTransition,
        transitionLabel: nextLabel,
        content: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            _maybeShowMicPermissionDialog();
            final result = _controller.result;
            final pattern = _controller.currentPattern;
            return ListView(
              children: [
                EnterprisePanel(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pattern ${pattern + 1} of 3',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    color: const Color(0xFF13213A),
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            _DotProgress(current: pattern),
                          ],
                        ),
                      ),
                      _CameraMiniPreview(camera: _controller.camera),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: RandomDotWidget(
                    patternIndex: _controller.currentPattern,
                    headPosition: _controller.headPosition,
                  ),
                ),
                if (result != null) ...[
                  const SizedBox(height: 16),
                  EnterprisePanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Results',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF13213A),
                                  ),
                        ),
                        const SizedBox(height: 12),
                        _PatternRow(
                            icon: '⭐',
                            label: 'Star',
                            ok: result.pattern1Passed),
                        _PatternRow(
                            icon: '🚗',
                            label: 'Car',
                            ok: result.pattern2Passed),
                        _PatternRow(
                            icon: '🐱',
                            label: 'Cat',
                            ok: result.pattern3Passed),
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: _levelColor(result.stereopsisLevel),
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: Text(
                            result.stereopsisLevel.toUpperCase(),
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          result.clinicalNote,
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: const Color(0xFF334155),
                                  ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Color _levelColor(String level) {
    switch (level) {
      case 'Present':
        return const Color(0xFF2E7D32);
      case 'Partial':
        return const Color(0xFFF9A825);
      default:
        return AmbyoTheme.dangerColor;
    }
  }

  static String _langPatternsToRiskLevel(int patternsDetected) {
    if (patternsDetected >= 2) return 'NORMAL';
    if (patternsDetected == 1) return 'MILD';
    return 'HIGH';
  }
}

class _DotProgress extends StatelessWidget {
  const _DotProgress({required this.current});

  final int current;

  @override
  Widget build(BuildContext context) {
    Widget dot(bool filled) {
      return Container(
        width: 12,
        height: 12,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: filled ? AmbyoTheme.primaryColor : const Color(0xFFD8E0ED),
          shape: BoxShape.circle,
        ),
      );
    }

    return Row(
      children: [
        dot(current == 0),
        dot(current == 1),
        dot(current == 2),
      ],
    );
  }
}

class _MicBadge extends StatelessWidget {
  const _MicBadge({required this.isListening});

  final bool isListening;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: isListening ? const Color(0xFFFFF3E0) : const Color(0xFFEFF4FF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: isListening
                ? const Color(0xFFFFB300)
                : const Color(0xFFD8E0ED)),
      ),
      child: Icon(
        isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
        color: isListening ? const Color(0xFFFF8F00) : const Color(0xFF1A237E),
      ),
    );
  }
}

class _PatternRow extends StatelessWidget {
  const _PatternRow(
      {required this.icon, required this.label, required this.ok});

  final String icon;
  final String label;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF13213A),
                  ),
            ),
          ),
          Icon(ok ? Icons.check_circle_rounded : Icons.cancel_rounded,
              color: ok ? const Color(0xFF2E7D32) : const Color(0xFFC62828)),
        ],
      ),
    );
  }
}

class _CameraMiniPreview extends StatelessWidget {
  const _CameraMiniPreview({required this.camera});

  final CameraController? camera;

  @override
  Widget build(BuildContext context) {
    final c = camera;
    final previewSize = c?.value.previewSize;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 96,
        height: 132,
        child: c != null && c.value.isInitialized && previewSize != null
            ? FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: previewSize.height,
                  height: previewSize.width,
                  child: CameraPreview(c),
                ),
              )
            : const ColoredBox(color: Color(0x22000000)),
      ),
    );
  }
}
