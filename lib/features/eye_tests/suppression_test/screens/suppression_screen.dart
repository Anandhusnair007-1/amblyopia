import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/theme/ambyo_theme.dart';
import '../../../../core/widgets/test_back_guard.dart';
import '../../../offline/vosk_service.dart';
import '../../age_profile.dart';
import '../../depth_perception/screens/depth_screen.dart';
import '../../test_flow_controller.dart';
import '../../widgets/test_pattern_scaffold.dart';
import '../controllers/rivalry_controller.dart';
import '../models/suppression_result.dart';
import '../widgets/rivalry_pattern_widget.dart';

class SuppressionScreenArgs {
  const SuppressionScreenArgs({
    this.sessionId,
  });

  final String? sessionId;
}

class SuppressionScreen extends StatefulWidget {
  const SuppressionScreen({
    super.key,
    required this.args,
  });

  final SuppressionScreenArgs args;

  @override
  State<SuppressionScreen> createState() => _SuppressionScreenState();
}

class _SuppressionScreenState extends State<SuppressionScreen> {
  late final RivalryController _controller;
  int _countdown = 5;
  bool _navigated = false;
  bool _showInstruction = true;
  bool _showTransition = false;
  bool _testStarted = false;
  String? _lastHeard;
  SuppressionResult? _simplifiedResult;

  bool get _isSimplifiedFlash =>
      suppressionVariantForProfile(TestFlowController.currentProfile) ==
      SuppressionVariant.simplifiedFlash;

  bool get _isSimplifiedVoice =>
      suppressionVariantForProfile(TestFlowController.currentProfile) ==
      SuppressionVariant.simplifiedVoice;

  @override
  void initState() {
    super.initState();
    _controller = RivalryController()
      ..initForProfile(TestFlowController.currentProfile)
      ..addListener(_onChanged);
  }

  Future<void> _startTest() async {
    if (_testStarted) return;
    _testStarted = true;
    if (_isSimplifiedFlash) {
      setState(() {});
      return;
    }
    for (var i = 5; i >= 1; i--) {
      if (!mounted) return;
      setState(() => _countdown = i);
      await Future<void>.delayed(const Duration(seconds: 1));
    }

    if (mounted) {
      setState(() => _countdown = 0);
      await _controller.startTest();
    }
  }

  void _completeSimplifiedFlash(bool bothEyesBlinked) {
    final result =
        SuppressionResult.forSimplifiedFlash(bothEyesBlinked: bothEyesBlinked);
    TestFlowController().onTestComplete('suppression_test', result);
    setState(() => _simplifiedResult = result);
  }

  void _onChanged() {
    final result = _controller.result;
    if (!mounted || _navigated || result == null) {
      setState(() {});
      return;
    }

    if (_controller.state == RivalryState.completed ||
        _controller.state == RivalryState.inconclusive) {
      TestFlowController().onTestComplete('suppression_test', result);
    }

    setState(() {});
  }

  Future<void> _handleCompletion(SuppressionResult result) async {
    if (!mounted) return;

    if (TestFlowController.isSingleTestMode &&
        TestFlowController.singleTestName == 'suppression_test') {
      await TestFlowController.onSingleTestComplete(
        context,
        testName: 'suppression_test',
        result: result,
      );
      return;
    }

    setState(() => _showTransition = true);
    await Future<void>.delayed(TestFlowController.transitionPreview);
    if (!mounted) return;

    final nextRoute = TestFlowController().getNextRoute('suppression_test');
    if (nextRoute != null) {
      Navigator.of(context).pushReplacementNamed(
        nextRoute,
        arguments: const DepthScreenArgs(),
      );
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
    final result = _simplifiedResult ?? _controller.result;
    final nextKey = TestFlowController().getNextTest('suppression_test');
    final nextLabel = '▶ Next: ${TestUiMeta.displayName(nextKey)}';

    return TestBackGuard(
      testName: 'Suppression (Rivalry)',
      testInProgress: _controller.state == RivalryState.running &&
          _simplifiedResult == null,
      child: TestPatternScaffold(
        testKey: 'suppression_test',
        testName: _isSimplifiedFlash
            ? 'Simplified Flash (Age 3-4)'
            : 'Binocular Vision Test',
        isCameraActive: false,
        statusText: _isSimplifiedFlash
            ? 'Observe the child. Did both eyes blink or only one?'
            : _isSimplifiedVoice
                ? (_controller.statusMessage.isEmpty
                    ? 'What color do you see? Say RED, BLUE, or BOTH'
                    : _controller.statusMessage)
                : (_controller.statusMessage.isEmpty
                    ? 'Say what you see: HORIZONTAL, VERTICAL, or SWITCHING'
                    : _controller.statusMessage),
        isListening: _controller.state == RivalryState.running,
        instruction: TestInstructionData(
          title: _isSimplifiedFlash
              ? 'Simplified Flash Test (Age 3-4)'
              : 'Binocular Vision Test',
          body: _isSimplifiedFlash
              ? 'Red and blue screens will flash. Observe the child.\n'
                  'Did BOTH eyes blink, or only ONE eye? Tap your observation when done.'
              : _isSimplifiedVoice
                  ? 'Look at this pattern. Tell us what color you see:\n\n'
                      '• Say RED if you see red stripes\n'
                      '• Say BLUE if you see blue stripes\n'
                      '• Say BOTH if you see both or it changes'
                  : 'Look at this pattern for 30 seconds.\n'
                      'Tell us what you see:\n\n'
                      '• Say HORIZONTAL if you see ━━━ stripes\n'
                      '• Say VERTICAL if you see ||| stripes\n'
                      '• Say SWITCHING if it changes',
          whatThisChecks: _isSimplifiedFlash
              ? 'Simple binocular response for preverbal children.'
              : _isSimplifiedVoice
                  ? 'Binocular rivalry with simple color question (Age 5-7).'
                  : 'Binocular rivalry: normal vision alternates between patterns.',
        ),
        showInstruction: _showInstruction,
        onInstructionDismiss: () {
          setState(() => _showInstruction = false);
          unawaited(_startTest());
        },
        result: result == null
            ? null
            : TestResultData(
                title: 'Suppression / Rivalry',
                message: result.result,
                detail: result.isAbnormal
                    ? 'Abnormal response detected'
                    : 'Normal binocular vision',
                borderColor: result.isAbnormal
                    ? AmbyoTheme.dangerColor
                    : AmbyoTheme.successColor,
                riskLevel: _suppressionResultToRiskLevel(result),
              ),
        nextTestLabel: nextLabel,
        onResultAdvance: () {
          if (_navigated || result == null) return;
          _navigated = true;
          unawaited(_handleCompletion(result));
        },
        showTransition: _showTransition,
        transitionLabel: nextLabel,
        content: _countdown > 0
            ? _buildCountdown()
            : _isSimplifiedFlash && result == null
                ? _buildSimplifiedFlashContent()
                : result == null
                    ? _buildTestContent()
                    : _buildResults(result),
      ),
    );
  }

  Widget _buildCountdown() {
    return Center(
      child: Text(
        'Starting in $_countdown...',
        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }

  Widget _buildTestContent() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          '━━━ = HORIZONTAL',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        const Center(
          child: RivalryPatternWidget(size: 280),
        ),
        const SizedBox(height: 16),
        const Text(
          '||| = VERTICAL',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 24),
        LinearProgressIndicator(
          value: _controller.progress,
          minHeight: 8,
          backgroundColor: const Color(0x2200FF00),
          color: AmbyoTheme.warningColor,
        ),
        const SizedBox(height: 12),
        Text(
          AppStrings.get('suppression_reading', VoskService.currentLanguage)
              .replaceAll('{n}', '${_controller.currentReading}')
              .replaceAll('{total}', '${RivalryController.totalReadings}'),
          style: AmbyoTheme.dataTextStyle(
            color: Colors.white70,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 16),
        if (_controller.state == RivalryState.running)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.mic,
                color: Colors.greenAccent.shade200,
                size: 28,
              ),
              const SizedBox(width: 8),
              Text(
                'Say what you see...',
                style: TextStyle(
                  color: Colors.greenAccent.shade200,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        if (_lastHeard != null && _lastHeard!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF2E7D32).withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Heard: $_lastHeard',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSimplifiedFlashContent() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'After showing red/blue flash, what did you observe?',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _completeSimplifiedFlash(true),
                icon: const Icon(Icons.visibility_rounded),
                label: const Text('Both eyes blinked'),
                style: FilledButton.styleFrom(
                  backgroundColor: AmbyoTheme.successColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _completeSimplifiedFlash(false),
                icon: const Icon(Icons.visibility_off_rounded),
                label: const Text('Only one eye blinked'),
                style: FilledButton.styleFrom(
                  backgroundColor: AmbyoTheme.warningColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults(SuppressionResult result) {
    final riskLevel = result.isAbnormal
        ? (result.suppressionScore > 0.7 ? 'HIGH' : 'MILD')
        : 'NORMAL';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(
              result.responses.length,
              (i) => _responseBubble(result.responses[i]),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '${result.switchCount} Switches Detected',
            textAlign: TextAlign.center,
            style: AmbyoTheme.dataTextStyle(
              color: Colors.white,
              fontSize: 32,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            decoration: BoxDecoration(
              color: riskLevel == 'NORMAL'
                  ? AmbyoTheme.successColor.withValues(alpha: 0.2)
                  : riskLevel == 'HIGH'
                      ? AmbyoTheme.dangerColor.withValues(alpha: 0.2)
                      : AmbyoTheme.warningColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: riskLevel == 'NORMAL'
                    ? AmbyoTheme.successColor
                    : riskLevel == 'HIGH'
                        ? AmbyoTheme.dangerColor
                        : AmbyoTheme.warningColor,
              ),
            ),
            child: Text(
              riskLevel,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: riskLevel == 'NORMAL'
                    ? AmbyoTheme.successColor
                    : riskLevel == 'HIGH'
                        ? AmbyoTheme.dangerColor
                        : AmbyoTheme.warningColor,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            result.clinicalNote,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                ),
          ),
          if (result.suppressedEye != 'None' &&
              result.suppressedEye.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AmbyoTheme.warningColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AmbyoTheme.warningColor),
              ),
              child: Text(
                '${result.suppressedEye} eye suppression suspected',
                style: const TextStyle(
                  color: AmbyoTheme.warningColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _responseBubble(String response) {
    Color color;
    String label;
    switch (response) {
      case 'horizontal':
        color = const Color(0xFFE53935);
        label = 'H';
        break;
      case 'vertical':
        color = const Color(0xFF1565C0);
        label = 'V';
        break;
      case 'switching':
        color = const Color(0xFF00897B);
        label = 'S';
        break;
      default:
        color = Colors.grey;
        label = '?';
    }
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.8),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
    );
  }

  static String _suppressionResultToRiskLevel(SuppressionResult result) {
    if (!result.isAbnormal) return 'NORMAL';
    if (result.suppressionScore > 0.7) return 'HIGH';
    return 'MILD';
  }
}
