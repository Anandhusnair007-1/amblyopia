import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:screen_brightness/screen_brightness.dart';

import 'package:permission_handler/permission_handler.dart'
    show openAppSettings;

import '../../../../core/widgets/ambyoai_error_state.dart';
import '../../../../core/widgets/enterprise_ui.dart';
import '../../../../core/widgets/test_back_guard.dart';
import '../../../reports/models/urgent_finding.dart';
import '../../suppression_test/screens/suppression_screen.dart';
import '../../test_flow_controller.dart';
import '../../widgets/test_pattern_scaffold.dart';
import '../controllers/red_reflex_controller.dart';
import '../models/red_reflex_result.dart';

class RedReflexScreenArgs {
  const RedReflexScreenArgs({
    this.sessionId,
  });

  final String? sessionId;
}

class RedReflexScreen extends StatefulWidget {
  const RedReflexScreen({
    super.key,
    required this.args,
  });

  final RedReflexScreenArgs args;

  @override
  State<RedReflexScreen> createState() => _RedReflexScreenState();
}

class _RedReflexScreenState extends State<RedReflexScreen> {
  late final RedReflexController _controller;
  String? _cameraError;
  int _countdown = 5;
  bool _flashOverlay = false;
  bool _navigated = false;
  bool _showInstruction = true;
  bool _showTransition = false;
  bool _testStarted = false;
  double _originalBrightness = 0.5;
  bool _showWhiteScreen = false;

  @override
  void initState() {
    super.initState();
    _controller = RedReflexController()..addListener(_onChanged);
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    try {
      await _controller.initialize();
    } catch (e) {
      if (mounted) setState(() => _cameraError = e.toString());
      return;
    }
    if (!mounted) return;
    if (_controller.state == RedReflexState.error) {
      setState(() => _cameraError = _controller.statusMessage);
      return;
    }
    setState(() {
      _cameraError = null;
      _showInstruction = true;
    });
  }

  Future<void> _startTest() async {
    if (_testStarted) return;
    _testStarted = true;

    try {
      _originalBrightness = await ScreenBrightness().current;
    } catch (_) {
      _originalBrightness = 0.5;
    }

    for (var i = 5; i >= 1; i--) {
      if (!mounted) {
        return;
      }
      setState(() => _countdown = i);
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    if (!mounted) {
      return;
    }
    if (!mounted) return;
    try {
      await ScreenBrightness().setScreenBrightness(1.0);
    } catch (_) {}

    setState(() {
      _flashOverlay = false;
      _showWhiteScreen = true;
    });
    await Future<void>.delayed(const Duration(milliseconds: 2000));

    if (!mounted) return;
    await _controller.runTest();
    if (!mounted) return;
    setState(() => _showWhiteScreen = false);

    try {
      await ScreenBrightness().setScreenBrightness(_originalBrightness);
    } catch (_) {}
  }

  void _onChanged() {
    final result = _controller.result;
    if (!mounted || _navigated || result == null) {
      setState(() {});
      return;
    }

    if (_controller.state == RedReflexState.completed ||
        _controller.state == RedReflexState.inconclusive) {
      final flow = TestFlowController()..onTestComplete('red_reflex', result);
      if (result.requiresUrgentReferral) {
        _navigated = true;
        flow.navigateToUrgentReport(
          context,
          flow.buildUrgentReport(
            findings: <UrgentFinding>[
              UrgentFinding(
                testName: 'red_reflex',
                findingName: 'Leukocoria Detected',
                measuredValue:
                    '${result.leftReflexType}/${result.rightReflexType}',
                normalRange: 'Red/orange bilateral reflex',
                severity: 'critical',
              ),
            ],
          ),
        );
        return;
      }
    }
    setState(() {});
  }

  Future<void> _handleCompletion(RedReflexResult result) async {
    if (!mounted) return;

    if (TestFlowController.isSingleTestMode &&
        TestFlowController.singleTestName == 'red_reflex') {
      await TestFlowController.onSingleTestComplete(
        context,
        testName: 'red_reflex',
        result: result,
      );
      return;
    }

    setState(() => _showTransition = true);
    await Future<void>.delayed(TestFlowController.transitionPreview);
    if (!mounted) return;

    final nextRoute = TestFlowController().getNextRoute('red_reflex');
    if (nextRoute != null) {
      Navigator.of(context).pushReplacementNamed(
        nextRoute,
        arguments: const SuppressionScreenArgs(),
      );
    }
  }

  @override
  void dispose() {
    unawaited(ScreenBrightness().setScreenBrightness(_originalBrightness));
    _controller
      ..removeListener(_onChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraError != null || _controller.state == RedReflexState.error) {
      final msg = _cameraError ?? _controller.statusMessage;
      final isPermission = msg.toLowerCase().contains('permission');
      return TestBackGuard(
        testName: 'Red Reflex',
        testInProgress: true,
        child: Scaffold(
          body: AmbyoErrorState(
            message:
                'Camera could not start. Check camera permission and try again.',
            isPermissionError: isPermission,
            onRetry: () {
              if (isPermission) {
                openAppSettings();
              } else {
                setState(() => _cameraError = null);
                unawaited(_initialize());
              }
            },
          ),
        ),
      );
    }

    final camera = _controller.camera;
    final previewSize = camera?.value.previewSize;
    final result = _controller.result;
    final nextKey = TestFlowController().getNextTest('red_reflex');
    final nextLabel = '▶ Next: ${TestUiMeta.displayName(nextKey)}';

    return TestBackGuard(
      testName: 'Red Reflex',
      testInProgress: _controller.state == RedReflexState.running,
      child: TestPatternScaffold(
        testKey: 'red_reflex',
        testName: 'Red Reflex',
        isCameraActive: camera?.value.isInitialized ?? false,
        statusText: _controller.statusMessage.isEmpty
            ? 'Hold phone 25-35cm from face. Screen will turn white briefly.'
            : _controller.statusMessage,
        isListening: false,
        instruction: const TestInstructionData(
          title: 'Red Reflex Test',
          body:
              'Hold phone 25-35cm from face. Screen will turn white briefly. Keep child\'s eyes open and looking at the bright screen.',
          whatThisChecks:
              'What this test checks: red reflex symmetry and leukocoria risk.',
        ),
        showInstruction: _showInstruction,
        onInstructionDismiss: () {
          setState(() => _showInstruction = false);
          unawaited(_startTest());
        },
        result: result == null
            ? null
            : TestResultData(
                title: 'Red reflex',
                message: result.overallResult,
                detail: result.requiresUrgentReferral
                    ? 'Immediate referral required'
                    : result.clinicalNote,
                borderColor: _noteColor(result),
                riskLevel: result.requiresUrgentReferral
                    ? 'URGENT'
                    : (result.isNormal ? 'NORMAL' : 'MILD'),
              ),
        nextTestLabel: nextLabel,
        onResultAdvance: () {
          if (_navigated || result == null) return;
          _navigated = true;
          unawaited(_handleCompletion(result));
        },
        showTransition: _showTransition,
        transitionLabel: nextLabel,
        content: LayoutBuilder(
          builder: (context, constraints) {
            final previewHeight = constraints.maxHeight * 0.6;
            return Column(
              children: [
                SizedBox(
                  height: previewHeight,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Stack(
                      children: [
                        if (camera != null &&
                            camera.value.isInitialized &&
                            previewSize != null)
                          Positioned.fill(
                            child: FittedBox(
                              fit: BoxFit.cover,
                              child: SizedBox(
                                width: previewSize.height,
                                height: previewSize.width,
                                child: CameraPreview(camera),
                              ),
                            ),
                          )
                        else
                          const Positioned.fill(
                              child: ColoredBox(color: Color(0xFF081018))),
                        const Positioned.fill(
                            child: ColoredBox(color: Color(0x99051018))),
                        if (_countdown > 0)
                          Positioned.fill(
                            child: ColoredBox(
                              color: const Color(0x66000000),
                              child: Center(
                                child: Text(
                                  'Preparing... $_countdown',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ),
                            ),
                          ),
                        if (_flashOverlay)
                          const Positioned.fill(
                              child: ColoredBox(color: Colors.white)),
                        if (_showWhiteScreen)
                          Positioned.fill(
                            child: Container(
                              color: Colors.white,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Keep eyes open',
                                    style: TextStyle(
                                      color: Colors.grey.shade400,
                                      fontFamily: 'Poppins',
                                      fontSize: 18,
                                      fontWeight: FontWeight.w300,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Look at the screen',
                                    style: TextStyle(
                                      color: Colors.grey.shade400,
                                      fontFamily: 'Poppins',
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    child: result == null
                        ? _InstructionPanel(countdown: _countdown)
                        : _ResultsPanel(result: result),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Color _noteColor(RedReflexResult result) {
    if (result.requiresUrgentReferral) {
      return const Color(0xFFC62828);
    }
    if (result.isNormal) {
      return const Color(0xFF2E7D32);
    }
    if (result.leftReflexType == 'Dull' || result.rightReflexType == 'Dull') {
      return const Color(0xFFF9A825);
    }
    return const Color(0xFFEF6C00);
  }
}

class _InstructionPanel extends StatelessWidget {
  const _InstructionPanel({required this.countdown});

  final int countdown;

  @override
  Widget build(BuildContext context) {
    return EnterprisePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How to perform Red Reflex Test',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: const Color(0xFF13213A),
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 16),
          const _Instruction(text: "Hold phone 25-35cm from the child's face"),
          const _Instruction(text: 'Screen will turn white briefly'),
          const _Instruction(
              text: 'Child should look directly at the bright screen'),
          const _Instruction(text: 'Keep the phone steady'),
          const _Instruction(text: 'Front camera will capture reflex'),
          const SizedBox(height: 18),
          Text(
            countdown > 0
                ? 'Preparing... $countdown'
                : 'Scanning red reflex...',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: const Color(0xFF1A237E),
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _Instruction extends StatelessWidget {
  const _Instruction({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Icon(Icons.circle, size: 8, color: Color(0xFF1A237E)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: const Color(0xFF334155),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultsPanel extends StatelessWidget {
  const _ResultsPanel({required this.result});

  final RedReflexResult result;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (result.requiresUrgentReferral)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFC62828),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Text(
              'LEUKOCORIA DETECTED\nIMMEDIATE REFERRAL REQUIRED\nThis may indicate Retinoblastoma',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                height: 1.4,
              ),
            ),
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _EyeCard(
                title: 'Left Eye',
                hue: result.leftReflexHue,
                brightness: result.leftReflexBrightness,
                reflexType: result.leftReflexType,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _EyeCard(
                title: 'Right Eye',
                hue: result.rightReflexHue,
                brightness: result.rightReflexBrightness,
                reflexType: result.rightReflexType,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        EnterprisePanel(
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _noteColor(result),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                result.clinicalNote,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Color _noteColor(RedReflexResult result) {
    if (result.requiresUrgentReferral) {
      return const Color(0xFFC62828);
    }
    if (result.isNormal) {
      return const Color(0xFF2E7D32);
    }
    if (result.leftReflexType == 'Dull' || result.rightReflexType == 'Dull') {
      return const Color(0xFFF9A825);
    }
    return const Color(0xFFEF6C00);
  }
}

class _EyeCard extends StatelessWidget {
  const _EyeCard({
    required this.title,
    required this.hue,
    required this.brightness,
    required this.reflexType,
  });

  final String title;
  final double hue;
  final double brightness;
  final String reflexType;

  @override
  Widget build(BuildContext context) {
    return EnterprisePanel(
      child: Column(
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF13213A),
                ),
          ),
          const SizedBox(height: 16),
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: _reflexColor(),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFD9E3F1)),
            ),
          ),
          const SizedBox(height: 14),
          Text('Hue: ${hue.toStringAsFixed(0)}°'),
          Text('Brightness: ${(brightness * 100).toStringAsFixed(0)}%'),
          const SizedBox(height: 10),
          Text(
            reflexType.toUpperCase(),
            style: TextStyle(
              color: _reflexColor() == Colors.white
                  ? Colors.black
                  : Colors.black87,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Color _reflexColor() {
    switch (reflexType) {
      case 'Normal':
        return const Color(0xFFE65100);
      case 'Absent':
        return Colors.black;
      case 'White':
        return Colors.white;
      case 'Dull':
        return const Color(0xFF616161);
      default:
        return const Color(0xFF90A4AE);
    }
  }
}
