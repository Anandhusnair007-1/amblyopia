import 'dart:async';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/services/distance_calculator.dart';
import '../../../../core/widgets/distance_indicator.dart';
import '../../../../core/widgets/enterprise_ui.dart';
import '../../../../core/widgets/test_back_guard.dart';
import '../../age_profile.dart';
import '../../test_flow_controller.dart';
import '../../widgets/test_pattern_scaffold.dart';
import '../controllers/snellen_controller.dart';
import '../models/snellen_result.dart';
import '../widgets/letter_display_widget.dart';
import '../widgets/picture_chart_widget.dart';
import '../widgets/snellen_chart_widget.dart';
import '../widgets/tumbling_e_widget.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../core/theme/ambyo_theme.dart';
import '../../../../core/widgets/all_tests_complete_screen.dart';
import '../../../offline/vosk_service.dart';

class SnellenScreen extends StatefulWidget {
  const SnellenScreen({super.key});

  @override
  State<SnellenScreen> createState() => _SnellenScreenState();
}

class _SnellenScreenState extends State<SnellenScreen> {
  final SnellenController _controller = SnellenController();
  bool _showInstruction = true;
  bool _reportTriggered = false;
  bool _testStarted = false;
  SnellenResult? _pictureResult;
  bool _micDialogShown = false;

  /// Letter variant: wait for distance zone before starting; show countdown when in zone.
  bool _waitingForDistance = false;
  int? _countdownValue;
  Timer? _distanceCheckTimer;
  Timer? _countdownTimer;

  SnellenVariant get _variant =>
      snellenVariantForProfile(TestFlowController.currentProfile);
  bool get _isPictureChart => _variant == SnellenVariant.picture;
  bool get _isTumblingMode => _variant == SnellenVariant.tumblingE;
  static const _snellenZone = DistanceZone.snellen;

  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    await _controller.initialize();
    if (!mounted || _controller.state == SnellenState.error) {
      setState(() {});
      return;
    }
  }

  Future<void> _startTest() async {
    if (_testStarted) return;
    _testStarted = true;
    _waitingForDistance = false;
    _countdownValue = null;
    _distanceCheckTimer?.cancel();
    if (_isPictureChart || _isTumblingMode) {
      if (_isTumblingMode) await _controller.startTest();
      setState(() {});
      return;
    }
    await Future<void>.delayed(TestFlowController.transitionPreview);
    if (!mounted) return;
    await _controller.startTest();
    if (_isTumblingMode) setState(() {});
    if (!mounted) return;
    if (_controller.result != null) {
      TestFlowController().onTestComplete('snellen_chart', _controller.result!);
    }
  }

  void _onInstructionDismiss() {
    setState(() => _showInstruction = false);
    if (_isPictureChart || _isTumblingMode) {
      unawaited(_startTest());
      return;
    }
    setState(() => _waitingForDistance = true);
    _distanceCheckTimer?.cancel();
    _countdownTimer?.cancel();
    _distanceCheckTimer =
        Timer.periodic(const Duration(milliseconds: 400), (_) {
      if (!mounted || !_waitingForDistance || _testStarted) return;
      final inZone = isInOptimalZone(_controller.distanceCm, _snellenZone);
      if (!inZone) {
        _countdownTimer?.cancel();
        if (_countdownValue != null) {
          setState(() => _countdownValue = null);
        }
        return;
      }
      if (_countdownValue == null) {
        setState(() => _countdownValue = 3);
        _countdownTimer?.cancel();
        _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (!mounted || !_waitingForDistance || _testStarted) return;
          if (!isInOptimalZone(_controller.distanceCm, _snellenZone)) {
            _countdownTimer?.cancel();
            setState(() => _countdownValue = null);
            return;
          }
          setState(() => _countdownValue = (_countdownValue ?? 3) - 1);
          if (_countdownValue == 0) {
            _countdownTimer?.cancel();
            _distanceCheckTimer?.cancel();
            unawaited(_startTest());
          }
        });
      }
    });
  }

  void _onPictureChartComplete(SnellenResult result) {
    TestFlowController().onTestComplete('snellen_chart', result);
    setState(() => _pictureResult = result);
  }

  Future<void> _triggerReport() async {
    final result = _pictureResult ?? _controller.result;
    if (result == null || !mounted || _reportTriggered) return;
    _reportTriggered = true;
    if (TestFlowController.isSingleTestMode &&
        TestFlowController.singleTestName == 'snellen_chart') {
      await TestFlowController.onSingleTestComplete(
        context,
        testName: 'snellen_chart',
        result: result,
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const AllTestsCompleteScreen(),
      ),
    );
    if (!mounted) return;
    await TestFlowController().generateAndShowReport(context);
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
      builder: (context) {
        return AlertDialog(
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
        );
      },
    );
  }

  Future<void> _skipVoiceTest() async {
    const skipped = SnellenResult(
      lines: [],
      visualAcuity: 'Not completed',
      bothEyesAcuity: 'Not completed',
      acuityScore: 0.0,
      isNormal: false,
      requiresReferral: true,
      clinicalNote: 'Snellen test skipped due to denied microphone permission.',
      normalityScore: 0.0,
    );
    TestFlowController().onTestComplete('snellen_chart', skipped);
    if (!mounted) return;
    final nextRoute = TestFlowController().getNextRoute('snellen_chart');
    if (nextRoute != null) {
      Navigator.of(context).pushReplacementNamed(nextRoute);
    }
  }

  @override
  void dispose() {
    _distanceCheckTimer?.cancel();
    _countdownTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final deviceRatio = media.devicePixelRatio;
    final line = _controller.currentLine;
    final denominator =
        line == null ? 60 : int.parse(line.fraction.split('/').last);
    final heightPx = _controller.letterHeightPxForLine(
        devicePixelRatio: deviceRatio, denominator: denominator);
    final hint = _controller.distanceHint();

    final effectiveResult = _pictureResult ?? _controller.result;

    return TestBackGuard(
      testName: _isPictureChart ? 'Picture Chart' : 'Snellen Chart',
      testInProgress:
          _controller.state == SnellenState.running && !_isPictureChart,
      child: TestPatternScaffold(
        testKey: 'snellen_chart',
        testName: _isPictureChart
            ? 'Picture Chart (Age 3-4)'
            : (_isTumblingMode ? 'Tumbling E (Age 5-7)' : 'Snellen Chart'),
        isCameraActive: false,
        statusText: _isPictureChart
            ? 'Tap which picture the child points to.'
            : _isTumblingMode
                ? ('${AppStrings.get('snellen_e_instruction', VoskService.currentLanguage)} ${AppStrings.get('snellen_e_prompt', VoskService.currentLanguage)}')
                : (_controller.statusMessage.isEmpty
                    ? 'Read each letter aloud.'
                    : _controller.statusMessage),
        isListening: _controller.isListening,
        instruction: TestInstructionData(
          title: _isPictureChart
              ? 'Picture Chart (Age 3-4)'
              : (_isTumblingMode
                  ? 'Tumbling E (Age 5-7)'
                  : 'Visual Acuity Test'),
          body: _isPictureChart
              ? 'Show each picture. The child points to what they see. Tap the button that matches what they point to.'
              : _isTumblingMode
                  ? 'Which way does the E point? Say UP, DOWN, LEFT, or RIGHT. Use the arrows as hints.'
                  : 'Sit about 40cm from the screen. Read each letter aloud when you hear the beep. Keep your face centered.',
          whatThisChecks: _isPictureChart
              ? 'Approximate visual acuity for preverbal children.'
              : (_isTumblingMode
                  ? 'Visual acuity for children who cannot read letters yet.'
                  : 'What this test checks: visual acuity and clarity of vision.'),
        ),
        showInstruction: _showInstruction,
        onInstructionDismiss: _onInstructionDismiss,
        result: effectiveResult == null
            ? null
            : TestResultData(
                title: 'Visual acuity',
                message: effectiveResult.visualAcuity,
                detail: effectiveResult.clinicalNote,
                borderColor: _resultColor(effectiveResult),
                riskLevel:
                    _snellenScoreToRiskLevel(effectiveResult.acuityScore),
              ),
        nextTestLabel: null,
        onResultAdvance: () => unawaited(_triggerReport()),
        showTransition: false,
        content: _isPictureChart
            ? (_pictureResult != null
                ? _ResultsView(result: _pictureResult!)
                : PictureChartWidget(onComplete: _onPictureChartComplete))
            : _isTumblingMode
                ? AnimatedBuilder(
                    animation: _controller,
                    builder: (_, __) => _buildTumblingContent(heightPx),
                  )
                : AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) {
                      _maybeShowMicPermissionDialog();
                      final result = _controller.result;

                      if (result != null) {
                        return _ResultsView(result: result);
                      }

                      final current = _controller.currentLine;
                      return Column(
                        children: [
                          if (_waitingForDistance) ...[
                            DistanceIndicator(
                              distanceCm: _controller.distanceCm,
                              zone: _snellenZone,
                            ),
                            if (_countdownValue != null && _countdownValue! > 0)
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Text(
                                  'Hold still... $_countdownValue...',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              )
                            else if (_countdownValue == null)
                              const Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: Text(
                                  'Get to 35–45 cm',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 16),
                          ] else if (hint.isNotEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF8E1),
                                borderRadius: BorderRadius.circular(18),
                                border:
                                    Border.all(color: const Color(0xFFFFE082)),
                              ),
                              child: Text(
                                hint,
                                style: const TextStyle(
                                  color: Color(0xFF7B6000),
                                  fontWeight: FontWeight.w700,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          if (!_waitingForDistance) const SizedBox(height: 14),
                          if (current != null)
                            SnellenChartWidget(
                              lineFraction: current.fraction,
                              lineIndex: _controller.currentLineIndex,
                              totalLines: SnellenController.lines.length,
                            ),
                          const Spacer(),
                          Center(
                            child: LetterDisplayWidget(
                              letter: _controller.currentLetter.isEmpty
                                  ? (current?.letters.first ?? '')
                                  : _controller.currentLetter,
                              heightPx: heightPx,
                              isListening: _controller.isListening,
                            ),
                          ),
                          const Spacer(),
                          EnterprisePanel(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Icon(
                                  _controller.isListening
                                      ? Icons.mic_rounded
                                      : Icons.mic_none_rounded,
                                  color: _controller.isListening
                                      ? const Color(0xFFFF8F00)
                                      : const Color(0xFF1A237E),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _controller.statusMessage,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyLarge
                                        ?.copyWith(
                                          color: const Color(0xFF334155),
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
      ),
    );
  }

  Widget _buildTumblingContent(double heightPx) {
    final result = _controller.result;
    if (result != null) return _ResultsView(result: result);
    final direction =
        _controller.currentTumblingDirection ?? TumblingEDirection.right;
    final lang = VoskService.currentLanguage;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          AppStrings.get('snellen_e_instruction', lang),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          AppStrings.get('snellen_e_prompt', lang),
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _directionArrow(Icons.keyboard_arrow_up, 'UP'),
            const SizedBox(width: 24),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _directionArrow(Icons.keyboard_arrow_left, 'LEFT'),
            const SizedBox(width: 40),
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(24),
              child: TumblingEWidget(
                direction: direction,
                sizePx: heightPx.clamp(80.0, 200.0),
              ),
            ),
            const SizedBox(width: 40),
            _directionArrow(Icons.keyboard_arrow_right, 'RIGHT'),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _directionArrow(Icons.keyboard_arrow_down, 'DOWN'),
          ],
        ),
        const Spacer(),
        EnterprisePanel(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                _controller.isListening
                    ? Icons.mic_rounded
                    : Icons.mic_none_rounded,
                color: _controller.isListening
                    ? const Color(0xFFFF8F00)
                    : const Color(0xFF1A237E),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _controller.statusMessage,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: const Color(0xFF334155),
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _directionArrow(IconData icon, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AmbyoTheme.primaryColor, size: 36),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  static String _snellenScoreToRiskLevel(double acuityScore) {
    if (acuityScore >= 0.9) return 'NORMAL';
    if (acuityScore >= 0.7) return 'MILD';
    if (acuityScore >= 0.5) return 'HIGH';
    return 'URGENT';
  }

  Color _resultColor(SnellenResult result) {
    switch (result.visualAcuity) {
      case '6/6':
      case '6/9':
        return const Color(0xFF2E7D32);
      case '6/12':
        return const Color(0xFFF9A825);
      case '6/18':
        return const Color(0xFFEF6C00);
      default:
        return const Color(0xFFC62828);
    }
  }
}

class _ResultsView extends StatelessWidget {
  const _ResultsView({required this.result});

  final SnellenResult result;

  @override
  Widget build(BuildContext context) {
    final color = switch (result.visualAcuity) {
      '6/6' || '6/9' => const Color(0xFF2E7D32),
      '6/12' => const Color(0xFFF9A825),
      '6/18' => const Color(0xFFEF6C00),
      _ => const Color(0xFFC62828),
    };

    return ListView(
      children: [
        EnterprisePanel(
          child: Column(
            children: [
              Text(
                result.visualAcuity,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  result.isNormal
                      ? 'NORMAL'
                      : (result.requiresReferral ? 'REFERRAL' : 'FOLLOW-UP'),
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                result.clinicalNote,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: const Color(0xFF334155),
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        EnterprisePanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Line-by-line',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF13213A),
                    ),
              ),
              const SizedBox(height: 12),
              ...result.lines.map(
                (line) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 64,
                        child: Text(
                          line.snellenFraction,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF13213A)),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          '${line.displayedLetters.join()} → Said: ${line.spokenLetters.join()}',
                          style: const TextStyle(color: Color(0xFF334155)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Icon(
                        line.linePassed
                            ? Icons.check_circle_rounded
                            : Icons.cancel_rounded,
                        color: line.linePassed
                            ? const Color(0xFF2E7D32)
                            : const Color(0xFFC62828),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
