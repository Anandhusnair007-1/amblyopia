import 'dart:async';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/theme/ambyo_theme.dart';
import '../../../../core/widgets/enterprise_ui.dart';
import '../../../../core/widgets/test_back_guard.dart';
import '../../age_profile.dart';
import '../../test_flow_controller.dart';
import '../../widgets/test_pattern_scaffold.dart';
import '../controllers/ishihara_controller.dart';
import '../models/ishihara_result.dart';
import '../widgets/ishihara_plate_widget.dart';

class IshiharaScreen extends StatefulWidget {
  const IshiharaScreen({super.key});

  @override
  State<IshiharaScreen> createState() => _IshiharaScreenState();
}

class _IshiharaScreenState extends State<IshiharaScreen> {
  final IshiharaController _controller = IshiharaController();
  bool _showInstruction = true;
  bool _showTransition = false;
  bool _testStarted = false;
  bool _micDialogShown = false;

  /// Profile A (age 3-4): test skipped, show N/A and continue.
  bool _naComplete = false;

  bool get _isProfileASkip => TestFlowController.currentProfile == AgeProfile.a;

  Future<void> _startTest() async {
    if (_testStarted) return;
    _testStarted = true;
    if (_isProfileASkip) {
      setState(() => _naComplete = true);
      return;
    }
    await _controller.startTest();
    if (!mounted) return;
    if (_controller.result != null) {
      TestFlowController()
          .onTestComplete('ishihara_color', _controller.result!);
    }
  }

  Future<void> _completeNaAndNavigate() async {
    TestFlowController().onTestComplete(
      'ishihara_color',
      IshiharaResult.notApplicableResult(),
    );
    if (!mounted) return;
    setState(() => _showTransition = true);
    await Future<void>.delayed(TestFlowController.transitionPreview);
    if (!mounted) return;
    final nextRoute = TestFlowController().getNextRoute('ishihara_color');
    if (nextRoute != null) {
      Navigator.of(context).pushReplacementNamed(nextRoute);
    }
  }

  Future<void> _handleCompletion() async {
    final result = _controller.result;
    if (result == null || !mounted) return;
    if (TestFlowController.isSingleTestMode &&
        TestFlowController.singleTestName == 'ishihara_color') {
      await TestFlowController.onSingleTestComplete(
        context,
        testName: 'ishihara_color',
        result: result,
      );
      return;
    }
    setState(() => _showTransition = true);
    await Future<void>.delayed(TestFlowController.transitionPreview);
    if (!mounted) return;
    final nextRoute = TestFlowController().getNextRoute('ishihara_color');
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
    const skipped = IshiharaResult(
      attempts: [],
      correctAnswers: 0,
      totalTestPlates: 0,
      colorVisionStatus: 'Inconclusive',
      isNormal: false,
      requiresReferral: true,
      clinicalNote:
          'Ishihara test skipped due to denied microphone permission.',
      normalityScore: 0.0,
    );
    TestFlowController().onTestComplete('ishihara_color', skipped);
    if (!mounted) return;
    final nextRoute = TestFlowController().getNextRoute('ishihara_color');
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
    final plateSize =
        (MediaQuery.sizeOf(context).width - 40).clamp(260.0, 420.0);
    final nextKey = TestFlowController().getNextTest('ishihara_color');
    final nextLabel = '▶ Next: ${TestUiMeta.displayName(nextKey)}';

    final effectiveResult = _naComplete
        ? const TestResultData(
            title: 'Color vision',
            message: 'Not applicable',
            detail: 'Skipped for age 3-4 (Profile A).',
            borderColor: AmbyoTheme.secondaryColor,
            riskLevel: 'NORMAL',
          )
        : (_controller.result == null
            ? null
            : TestResultData(
                title: 'Color vision',
                message: _controller.result!.colorVisionStatus,
                detail: _controller.result!.clinicalNote,
                borderColor: _resultColor(_controller.result!),
                riskLevel: _ishiharaStatusToRiskLevel(
                    _controller.result!.colorVisionStatus),
              ));

    return TestBackGuard(
      testName: 'Ishihara Color',
      testInProgress:
          _controller.state == IshiharaState.running && !_naComplete,
      child: TestPatternScaffold(
        testKey: 'ishihara_color',
        testName: 'Ishihara Color Test',
        isCameraActive: false,
        statusText: _isProfileASkip
            ? 'Not used for age 3-4. Tap Continue to proceed.'
            : (_controller.statusMessage.isEmpty
                ? 'Say the number you see.'
                : _controller.statusMessage),
        isListening: _controller.isListening,
        instruction: TestInstructionData(
          title: 'Color Vision Test',
          body: _isProfileASkip
              ? 'This test is not used for children age 3-4. Tap Continue to proceed to the next test.'
              : 'Look at each plate and say the number you see. If you cannot see a number, say NONE.',
          whatThisChecks: _isProfileASkip
              ? null
              : 'What this test checks: red-green color vision defects.',
        ),
        showInstruction: _showInstruction,
        onInstructionDismiss: () {
          setState(() => _showInstruction = false);
          unawaited(_startTest());
        },
        result: effectiveResult,
        nextTestLabel: nextLabel,
        onResultAdvance: _naComplete
            ? () => unawaited(_completeNaAndNavigate())
            : () => unawaited(_handleCompletion()),
        showTransition: _showTransition,
        transitionLabel: nextLabel,
        content: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            _maybeShowMicPermissionDialog();
            final result = _controller.result;
            final plate = _controller.currentPlate;
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
                              'Plate ${plate + 1} of ${_controller.totalPlates}',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF13213A),
                                  ),
                            ),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: ((_controller.currentPlate + 1) /
                                      _controller.totalPlates)
                                  .clamp(0.0, 1.0),
                              minHeight: 10,
                              backgroundColor: const Color(0x33D8E0ED),
                              color: AmbyoTheme.primaryColor,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      _MicBadge(isListening: _controller.isListening),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: ColoredBox(
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: IshiharaPlateWidget(
                          plateNumber: plate,
                          size: plateSize,
                        ),
                      ),
                    ),
                  ),
                ),
                if (result != null) ...[
                  const SizedBox(height: 16),
                  _ResultsPanel(result: result),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  static String _ishiharaStatusToRiskLevel(String status) {
    switch (status) {
      case 'Normal':
        return 'NORMAL';
      case 'Mild Deficiency':
        return 'MILD';
      case 'Moderate Deficiency':
        return 'HIGH';
      default:
        return 'HIGH';
    }
  }

  Color _resultColor(IshiharaResult result) {
    switch (result.colorVisionStatus) {
      case 'Normal':
        return const Color(0xFF2E7D32);
      case 'Mild Deficiency':
        return const Color(0xFFF9A825);
      case 'Moderate Deficiency':
        return const Color(0xFFEF6C00);
      default:
        return const Color(0xFFC62828);
    }
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

class _ResultsPanel extends StatelessWidget {
  const _ResultsPanel({required this.result});

  final IshiharaResult result;

  @override
  Widget build(BuildContext context) {
    final color = switch (result.colorVisionStatus) {
      'Normal' => const Color(0xFF2E7D32),
      'Mild Deficiency' => const Color(0xFFF9A825),
      'Moderate Deficiency' => const Color(0xFFEF6C00),
      _ => const Color(0xFFC62828),
    };

    return EnterprisePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Results',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF13213A),
                ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Text(
              result.colorVisionStatus.toUpperCase(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            result.clinicalNote,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: const Color(0xFF334155),
                ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: result.attempts
                .map((attempt) => _AttemptChip(attempt: attempt))
                .toList(growable: false),
          ),
        ],
      ),
    );
  }
}

class _AttemptChip extends StatelessWidget {
  const _AttemptChip({required this.attempt});

  final PlateAttempt attempt;

  @override
  Widget build(BuildContext context) {
    final ok = attempt.isCorrect;
    return Container(
      width: 156,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: ok ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
            width: 1.1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Plate ${attempt.plateIndex + 1}',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: const Color(0xFF66748B),
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            ok ? '✓ Correct' : '✗ Wrong',
            style: TextStyle(
                color: ok ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
                fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
              'Said: ${attempt.patientAnswer.isEmpty ? '-' : attempt.patientAnswer}'),
          Text('Ans: ${attempt.correctAnswer}'),
        ],
      ),
    );
  }
}
