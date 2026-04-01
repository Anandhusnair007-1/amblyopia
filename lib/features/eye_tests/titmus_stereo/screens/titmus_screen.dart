import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/theme/ambyo_theme.dart';
import '../../../../core/widgets/enterprise_ui.dart';
import '../../../../core/widgets/test_back_guard.dart';
import '../../test_flow_controller.dart';
import '../../widgets/test_pattern_scaffold.dart';
import '../controllers/titmus_controller.dart';
import '../models/titmus_result.dart';
import '../widgets/stereo_image_widget.dart';

class TitmusScreen extends StatefulWidget {
  const TitmusScreen({super.key});

  @override
  State<TitmusScreen> createState() => _TitmusScreenState();
}

class _TitmusScreenState extends State<TitmusScreen> {
  final TitmusController _controller = TitmusController();
  bool _showInstruction = true;
  bool _showTransition = false;
  bool _testStarted = false;
  bool _micDialogShown = false;

  TextStyle _titleStyle(BuildContext context,
      {Color color = const Color(0xFF13213A)}) {
    return Theme.of(context).textTheme.titleLarge!.copyWith(
          fontFamily: 'Poppins',
          fontSize: 22,
          fontWeight: FontWeight.w600,
          height: 1.25,
          color: color,
        );
  }

  TextStyle _bodyStyle(BuildContext context,
      {Color color = const Color(0xFF334155)}) {
    return Theme.of(context).textTheme.bodyLarge!.copyWith(
          fontFamily: 'Poppins',
          fontSize: 15,
          fontWeight: FontWeight.w400,
          height: 1.45,
          color: color,
        );
  }

  TextStyle _captionStyle(BuildContext context,
      {Color color = const Color(0xFF66748B)}) {
    return Theme.of(context).textTheme.bodySmall!.copyWith(
          fontFamily: 'Poppins',
          fontSize: 12,
          fontWeight: FontWeight.w400,
          height: 1.35,
          color: color,
        );
  }

  TextStyle _dataStyle(
      {Color color = Colors.white,
      double size = 20,
      FontWeight weight = FontWeight.w700}) {
    return GoogleFonts.jetBrainsMono(
      color: color,
      fontSize: size,
      fontWeight: weight,
      height: 1.2,
      letterSpacing: 0.15,
    );
  }

  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    await _controller.initialize();
    if (!mounted || _controller.state == TitmusState.error) {
      setState(() {});
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() => _showInstruction = true);
  }

  Future<void> _startTest() async {
    if (_testStarted) return;
    _testStarted = true;
    setState(() {});
    await _controller.startTest();
    if (!mounted) return;
  }

  Future<void> _handleCompletion() async {
    final result = _controller.result;
    if (result == null) return;
    TestFlowController().onTestComplete('titmus_stereo', result);
    if (!mounted) return;

    if (TestFlowController.isSingleTestMode &&
        TestFlowController.singleTestName == 'titmus_stereo') {
      await TestFlowController.onSingleTestComplete(
        context,
        testName: 'titmus_stereo',
        result: result,
      );
      return;
    }

    setState(() => _showTransition = true);
    await Future<void>.delayed(TestFlowController.transitionPreview);
    if (!mounted) return;
    final nextRoute = TestFlowController().getNextRoute('titmus_stereo');
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
    const skipped = TitmusResult(
      flyTestPassed: false,
      animalTestPassed: false,
      circlesCorrect: 0,
      circlesTotal: TitmusController.totalCircles,
      stereoAcuityArcSeconds: 9999,
      stereoGrade: 'Absent',
      isNormal: false,
      requiresReferral: true,
      clinicalNote: 'Titmus test skipped due to denied microphone permission.',
      normalityScore: 0.0,
    );
    TestFlowController().onTestComplete('titmus_stereo', skipped);
    if (!mounted) return;
    final nextRoute = TestFlowController().getNextRoute('titmus_stereo');
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
    final subTest = _controller.currentSubTest;
    final title = switch (subTest) {
      TitmusSubTest.fly => 'Fly Test',
      TitmusSubTest.animal => 'Animal Test',
      TitmusSubTest.circles =>
        'Circle Test (${(_controller.currentCircle + 1).clamp(1, TitmusController.totalCircles)} of ${TitmusController.totalCircles})',
    };
    final nextKey = TestFlowController().getNextTest('titmus_stereo');
    final nextLabel = '▶ Next: ${TestUiMeta.displayName(nextKey)}';

    return TestBackGuard(
      testName: 'Titmus Stereo',
      testInProgress: _controller.state == TitmusState.running,
      child: TestPatternScaffold(
        testKey: 'titmus_stereo',
        testName: 'Titmus Stereo Test',
        isCameraActive: _controller.camera?.value.isInitialized ?? false,
        statusText: _controller.statusMessage.isEmpty
            ? 'Follow the instructions and respond by voice.'
            : _controller.statusMessage,
        isListening: _controller.isListening,
        instruction: const TestInstructionData(
          title: 'Titmus Stereo Test',
          body:
              'Look at the images carefully. Say what you see as each plate appears.',
          whatThisChecks: 'What this test checks: stereo depth perception.',
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
                borderColor: _badgeColor(result.stereoAcuityArcSeconds),
                riskLevel: _titmusGradeToRiskLevel(result.stereoGrade),
              ),
        nextTestLabel: nextLabel,
        onResultAdvance: () => unawaited(_handleCompletion()),
        showTransition: _showTransition,
        transitionLabel: nextLabel,
        content: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            _maybeShowMicPermissionDialog();
            return ListView(
              children: [
                EnterprisePanel(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: _titleStyle(context),
                      ),
                      const SizedBox(height: 10),
                      _StepperRow(subTest: subTest),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: ColoredBox(
                    color: const Color(0xFF06111A),
                    child: Stack(
                      children: [
                        StereoImageWidget(
                          subTest: subTest,
                          headPosition: _controller.headPosition,
                          circleTarget: _controller.currentCircleTarget,
                        ),
                        Positioned(
                          top: 14,
                          right: 14,
                          child: _CameraMiniPreview(camera: _controller.camera),
                        ),
                      ],
                    ),
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
                          style: _titleStyle(context),
                        ),
                        const SizedBox(height: 12),
                        _ResultRow(
                            label: 'Fly',
                            value: result.flyTestPassed ? 'Passed' : 'Failed'),
                        _ResultRow(
                            label: 'Animals',
                            value:
                                result.animalTestPassed ? 'Passed' : 'Failed'),
                        _ResultRow(
                          label: 'Circles',
                          value:
                              '${result.circlesCorrect}/${result.circlesTotal} correct',
                        ),
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _badgeColor(result.stereoAcuityArcSeconds),
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${result.stereoAcuityArcSeconds.toStringAsFixed(0)} arc-seconds',
                                style: _dataStyle(weight: FontWeight.w700),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                result.stereoGrade,
                                style: _captionStyle(context,
                                    color:
                                        Colors.white.withValues(alpha: 0.95)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          result.clinicalNote,
                          style: _bodyStyle(context),
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

  static String _titmusGradeToRiskLevel(String grade) {
    return switch (grade) {
      'Excellent' || 'Fine' => 'NORMAL',
      'Moderate' => 'MILD',
      'Gross Only' || 'Absent' => 'HIGH',
      _ => 'HIGH',
    };
  }

  Color _badgeColor(double arcSeconds) {
    if (arcSeconds >= 9999) return AmbyoTheme.dangerColor;
    if (arcSeconds >= 3000) return const Color(0xFFEF6C00);
    if (arcSeconds >= 400) return const Color(0xFFF9A825);
    if (arcSeconds >= 200) return const Color(0xFF00897B);
    return const Color(0xFF2E7D32);
  }
}

class _StepperRow extends StatelessWidget {
  const _StepperRow({required this.subTest});

  final TitmusSubTest subTest;

  @override
  Widget build(BuildContext context) {
    bool active(TitmusSubTest t) => t == subTest;
    bool done(TitmusSubTest t) => t.index < subTest.index;

    Widget chip(String label, TitmusSubTest t) {
      final isActive = active(t);
      final isDone = done(t);
      final color = isDone
          ? const Color(0xFF2E7D32)
          : isActive
              ? AmbyoTheme.primaryColor
              : const Color(0xFF94A3B8);
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: isActive ? 0.12 : 0.08),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: color.withValues(alpha: isActive ? 0.5 : 0.25)),
          ),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'Poppins',
                color: Color(0xFF13213A),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        chip('FLY', TitmusSubTest.fly),
        const SizedBox(width: 10),
        chip('ANIMALS', TitmusSubTest.animal),
        const SizedBox(width: 10),
        chip('CIRCLES', TitmusSubTest.circles),
      ],
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
        width: 110,
        height: 160,
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

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    color: const Color(0xFF66748B),
                    fontWeight: FontWeight.w400,
                  ),
            ),
          ),
          Text(
            value,
            style: value.contains('/') || value.contains('correct')
                ? GoogleFonts.jetBrainsMono(
                    color: const Color(0xFF13213A),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  )
                : Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontFamily: 'Poppins',
                      fontSize: 15,
                      color: const Color(0xFF13213A),
                      fontWeight: FontWeight.w400,
                    ),
          ),
        ],
      ),
    );
  }
}
