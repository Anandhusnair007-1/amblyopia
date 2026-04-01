import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart'
    show openAppSettings;

import '../../../../core/widgets/ambyoai_widgets.dart';
import '../../../../core/widgets/ambyoai_error_state.dart';
import '../../../../core/widgets/test_back_guard.dart';
import '../../../reports/models/urgent_finding.dart';
import '../../gaze_detection/models/gaze_result.dart';
import '../../red_reflex/screens/red_reflex_screen.dart';
import '../../test_flow_controller.dart';
import '../../widgets/test_pattern_scaffold.dart';
import '../controllers/hirschberg_controller.dart';
import '../models/hirschberg_result.dart';

class HirschbergScreenArgs {
  const HirschbergScreenArgs({
    this.sessionId,
    this.gazeResult,
  });

  final String? sessionId;
  final GazeTestResult? gazeResult;
}

class HirschbergScreen extends StatefulWidget {
  const HirschbergScreen({
    super.key,
    required this.args,
  });

  final HirschbergScreenArgs args;

  @override
  State<HirschbergScreen> createState() => _HirschbergScreenState();
}

class _HirschbergScreenState extends State<HirschbergScreen> {
  late final HirschbergController _controller;
  String? _cameraError;
  int _countdown = 3;
  bool _flashOverlay = false;
  bool _navigated = false;
  bool _showInstruction = true;
  bool _showTransition = false;
  bool _testStarted = false;

  @override
  void initState() {
    super.initState();
    _controller = HirschbergController(
      sessionId:
          widget.args.sessionId ?? TestFlowController.currentSessionId ?? '',
    )..addListener(_onControllerChanged);
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
    if (_controller.state == HirschbergState.error) {
      setState(() => _cameraError = _controller.statusMessage);
      return;
    }
    setState(() {
      _cameraError = null;
      _showInstruction = true;
    });
  }

  Future<void> _startSequence() async {
    if (_testStarted) return;
    _testStarted = true;
    for (var i = 3; i >= 1; i--) {
      if (!mounted) {
        return;
      }
      setState(() => _countdown = i);
      await Future<void>.delayed(const Duration(seconds: 1));
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _countdown = 0;
      _flashOverlay = true;
    });
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (mounted) {
      setState(() => _flashOverlay = false);
    }
    await _controller.runTest();
  }

  void _onControllerChanged() {
    if (!mounted || _navigated) {
      setState(() {});
      return;
    }

    final result = _controller.result;
    if ((_controller.state == HirschbergState.completed ||
            _controller.state == HirschbergState.inconclusive) &&
        result != null) {
      TestFlowController().onTestComplete('hirschberg', result);
    }
    setState(() {});
  }

  Future<void> _handleCompletion(
      TestFlowController flow, HirschbergResult result) async {
    if (!mounted) return;

    if (result.requiresUrgentReferral) {
      flow.navigateToUrgentReport(
        context,
        flow.buildUrgentReport(
          findings: <UrgentFinding>[
            UrgentFinding(
              testName: 'hirschberg',
              findingName: 'Hirschberg Displacement',
              measuredValue:
                  '${math.max(result.leftDisplacementMM, result.rightDisplacementMM).toStringAsFixed(1)}mm',
              normalRange: '<2mm',
              severity: 'critical',
            ),
          ],
        ),
      );
      return;
    }

    if (TestFlowController.isSingleTestMode &&
        TestFlowController.singleTestName == 'hirschberg') {
      await TestFlowController.onSingleTestComplete(
        context,
        testName: 'hirschberg',
        result: result,
      );
      return;
    }

    setState(() => _showTransition = true);
    await Future<void>.delayed(TestFlowController.transitionPreview);
    if (!mounted) return;

    final nextRoute = TestFlowController().getNextRoute('hirschberg');
    if (nextRoute != null) {
      Navigator.of(context).pushReplacementNamed(
        nextRoute,
        arguments: RedReflexScreenArgs(
          sessionId: widget.args.sessionId ??
              TestFlowController.currentSessionId ??
              '',
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onControllerChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraError != null || _controller.state == HirschbergState.error) {
      final msg = _cameraError ?? _controller.statusMessage;
      final isPermission = msg.toLowerCase().contains('permission');
      return TestBackGuard(
        testName: 'Hirschberg Test',
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
    final nextKey = TestFlowController().getNextTest('hirschberg');
    final nextLabel = '▶ Next: ${TestUiMeta.displayName(nextKey)}';

    return TestBackGuard(
      testName: 'Hirschberg Test',
      testInProgress: _controller.state == HirschbergState.running,
      child: TestPatternScaffold(
        testKey: 'hirschberg',
        testName: 'Hirschberg Test',
        isCameraActive: camera?.value.isInitialized ?? false,
        statusText: _controller.statusMessage.isEmpty
            ? 'Place the face inside the guide and look at the center crosshair.'
            : _controller.statusMessage,
        isListening: false,
        instruction: const TestInstructionData(
          title: 'Hirschberg Test',
          body:
              'Keep the face centered inside the guide. The flash will activate briefly.',
          whatThisChecks:
              'What this test checks: corneal light reflex alignment.',
        ),
        showInstruction: _showInstruction,
        onInstructionDismiss: () {
          setState(() => _showInstruction = false);
          unawaited(_startSequence());
        },
        result: result == null
            ? null
            : TestResultData(
                title: 'Alignment',
                message: result.strabismusType,
                detail: result.severity,
                borderColor: _severityColor(result.severity),
                riskLevel: _severityToRiskLevel(result.severity),
              ),
        nextTestLabel: nextLabel,
        onResultAdvance: () {
          if (_navigated || result == null) return;
          _navigated = true;
          unawaited(_handleCompletion(TestFlowController(), result));
        },
        showTransition: _showTransition,
        transitionLabel: nextLabel,
        content: LayoutBuilder(
          builder: (context, constraints) {
            final previewHeight = constraints.maxHeight * 0.54;
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
                            child: ColoredBox(color: Color(0x77040A0F))),
                        const _FaceGuideOverlay(),
                        Positioned(
                          top: 12,
                          left: 12,
                          right: 12,
                          child: _TopPanel(
                            statusMessage: _controller.statusMessage,
                            countdown: _countdown,
                          ),
                        ),
                        if (_controller.state == HirschbergState.running)
                          const Positioned(
                            left: 16,
                            right: 16,
                            bottom: 16,
                            child: LinearProgressIndicator(
                              minHeight: 6,
                              backgroundColor: Color(0x33000000),
                              color: Color(0xFFFFB300),
                            ),
                          ),
                        if (_flashOverlay)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: AnimatedOpacity(
                                opacity: _flashOverlay ? 1 : 0,
                                duration: const Duration(milliseconds: 120),
                                child: const ColoredBox(color: Colors.white),
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
                        ? GlassCard(
                            radius: 24,
                            backgroundColor: const Color(0xC9151C2B),
                            borderColor: Colors.white.withValues(alpha: 0.10),
                            glowColor: const Color(0xFF00B4D8),
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Flash will activate briefly',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _controller.statusMessage.isEmpty
                                      ? 'Hold steady and keep gaze on the center crosshair.'
                                      : _controller.statusMessage,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: Colors.white70,
                                      ),
                                ),
                              ],
                            ),
                          )
                        : _ResultCard(result: result),
                  ),
                ),
              ],
            );
          },
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

class _TopPanel extends StatelessWidget {
  const _TopPanel({
    required this.statusMessage,
    required this.countdown,
  });

  final String statusMessage;
  final int countdown;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      radius: 24,
      backgroundColor: const Color(0xCC101B2C),
      borderColor: const Color(0x554DD0E1),
      glowColor: const Color(0xFF00B4D8),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hirschberg Corneal Reflex',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            countdown > 0 ? 'Starting in $countdown...' : statusMessage,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                ),
          ),
        ],
      ),
    );
  }
}

class _FaceGuideOverlay extends StatelessWidget {
  const _FaceGuideOverlay();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: CustomPaint(
        painter: _GuidePainter(),
        child: const Center(
          child: Padding(
            padding: EdgeInsets.only(top: 260),
            child: Text(
              'Place face in circle',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GuidePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 - 40);
    final radius = math.min(size.width, size.height) * 0.24;
    final ringPaint = Paint()
      ..color = const Color(0x80FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final crossPaint = Paint()
      ..color = const Color(0xFFFFB300)
      ..strokeWidth = 2;

    canvas.drawCircle(center, radius, ringPaint);
    canvas.drawLine(
        center.translate(-18, 0), center.translate(18, 0), crossPaint);
    canvas.drawLine(
        center.translate(0, -18), center.translate(0, 18), crossPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});

  final HirschbergResult result;

  @override
  Widget build(BuildContext context) {
    final color = switch (result.severity) {
      'Severe' => const Color(0xFFC62828),
      'Moderate' => const Color(0xFFEF6C00),
      'Mild' => const Color(0xFFF9A825),
      _ => const Color(0xFF2E7D32),
    };

    return GlassCard(
      radius: 26,
      backgroundColor: const Color(0xCC15131D),
      borderColor: color.withValues(alpha: 0.35),
      glowColor: color,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _EyeMetrics(
                  title: 'Left Eye',
                  mm: result.leftDisplacementMM,
                  degrees: result.leftDeviationDegrees,
                  prism: result.leftPrismDiopters,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _EyeMetrics(
                  title: 'Right Eye',
                  mm: result.rightDisplacementMM,
                  degrees: result.rightDeviationDegrees,
                  prism: result.rightPrismDiopters,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    result.strabismusType,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  result.severity,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EyeMetrics extends StatelessWidget {
  const _EyeMetrics({
    required this.title,
    required this.mm,
    required this.degrees,
    required this.prism,
  });

  final String title;
  final double mm;
  final double degrees;
  final double prism;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      radius: 18,
      backgroundColor: const Color(0xCC101B2C),
      borderColor: Colors.white.withValues(alpha: 0.08),
      glowColor: const Color(0xFF00B4D8),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 12),
          _MetricLine(
              label: 'Displacement', value: '${mm.toStringAsFixed(1)} mm'),
          _MetricLine(
              label: 'Deviation', value: '${degrees.toStringAsFixed(1)}°'),
          _MetricLine(label: 'Prism', value: '${prism.toStringAsFixed(1)}Δ'),
        ],
      ),
    );
  }
}

class _MetricLine extends StatelessWidget {
  const _MetricLine({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white60,
                ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}
