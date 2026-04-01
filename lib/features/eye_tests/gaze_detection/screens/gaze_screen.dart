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
import '../../prism_diopter/screens/prism_screen.dart';
import '../controllers/gaze_controller.dart';
import '../models/gaze_result.dart';
import '../widgets/gaze_dot_widget.dart';
import '../../test_flow_controller.dart';
import '../../../jarvis_scanner/widgets/iris_hud_overlay.dart';
import '../../widgets/test_pattern_scaffold.dart';

class GazeScreen extends StatefulWidget {
  const GazeScreen({
    super.key,
    required this.sessionId,
  });

  final String sessionId;

  @override
  State<GazeScreen> createState() => _GazeScreenState();
}

class _GazeScreenState extends State<GazeScreen> {
  late final GazeController _controller;
  String? _cameraError;
  int _countdown = 3;
  bool _navigated = false;
  bool _showInstruction = true;
  bool _showTransition = false;
  bool _testStarted = false;

  @override
  void initState() {
    super.initState();
    _controller = GazeController(currentSessionId: widget.sessionId)
      ..addListener(_onControllerChanged);
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    await _controller.initialize();
    if (!mounted || _controller.state == GazeTestState.error) {
      return;
    }
    setState(() => _showInstruction = true);
  }

  Future<void> _startTest() async {
    if (_testStarted) return;
    _testStarted = true;

    for (var i = 3; i >= 1; i--) {
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

  void _onControllerChanged() {
    if (!mounted || _navigated) return;
    if (_controller.state == GazeTestState.completed) {
      setState(() {});
    }
  }

  Future<void> _handleCompletion() async {
    if (!mounted || _navigated) return;
    _navigated = true;
    final result = _controller.finalResult;
    if (result != null) {
      TestFlowController().onTestComplete('gaze_detection', result);
    }

    if (result != null && result.requiresUrgentReferral) {
      final flow = TestFlowController();
      flow.navigateToUrgentReport(
        context,
        flow.buildUrgentReport(
          findings: <UrgentFinding>[
            UrgentFinding(
              testName: 'gaze_detection',
              findingName: 'Gaze Deviation',
              measuredValue: '${result.prismDiopterValue.toStringAsFixed(1)}Δ',
              normalRange: '<10Δ',
              severity: 'critical',
            ),
          ],
        ),
      );
      return;
    }

    if (TestFlowController.isSingleTestMode &&
        TestFlowController.singleTestName == 'gaze_detection') {
      if (result != null) {
        await TestFlowController.onSingleTestComplete(
          context,
          testName: 'gaze_detection',
          result: result,
        );
      }
      return;
    }

    setState(() => _showTransition = true);
    await Future<void>.delayed(TestFlowController.transitionPreview);
    if (!mounted) return;

    final nextRoute = TestFlowController().getNextRoute('gaze_detection');
    if (nextRoute != null) {
      Navigator.of(context).pushReplacementNamed(
        nextRoute,
        arguments: PrismScreenArgs(
          sessionId: widget.sessionId,
          gazeResult: result,
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
    if (_cameraError != null || _controller.state == GazeTestState.error) {
      final msg =
          _cameraError ?? _controller.errorMessage ?? 'Camera could not start.';
      final isPermission = msg.toLowerCase().contains('permission');
      return TestBackGuard(
        testName: 'Gaze Detection',
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

    final result = _controller.finalResult;
    final camera = _controller.camera;
    final previewSize = camera?.value.previewSize;
    final nextKey = TestFlowController().getNextTest('gaze_detection');
    final nextLabel = '▶ Next: ${TestUiMeta.displayName(nextKey)}';

    return TestBackGuard(
      testName: 'Gaze Detection',
      testInProgress: _controller.state == GazeTestState.running,
      child: TestPatternScaffold(
        testKey: 'gaze_detection',
        testName: 'Gaze Detection',
        isCameraActive: camera?.value.isInitialized ?? false,
        statusText: _controller.statusMessage.isEmpty
            ? 'Follow the moving dot with only your eyes.'
            : _controller.statusMessage,
        isListening: false,
        instruction: const TestInstructionData(
          title: 'Gaze Detection',
          body: 'Keep your head still and track the dot with your eyes only.',
          whatThisChecks:
              'What this test checks: eye alignment and gaze stability.',
        ),
        showInstruction: _showInstruction,
        onInstructionDismiss: () {
          setState(() => _showInstruction = false);
          unawaited(_startTest());
        },
        result: result == null
            ? null
            : TestResultData(
                title: 'Gaze deviation',
                message: '${result.prismDiopterValue.toStringAsFixed(1)}Δ',
                detail: result.strabismusType,
                borderColor: _resultColor(result),
                riskLevel: result.requiresUrgentReferral ? 'URGENT' : 'NORMAL',
              ),
        nextTestLabel: nextLabel,
        onResultAdvance: () => unawaited(_handleCompletion()),
        showTransition: _showTransition,
        transitionLabel: nextLabel,
        content: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final irisData = _controller.irisData;
            return LayoutBuilder(
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
                                  child: ColoredBox(color: Color(0xFF050B10))),
                            const Positioned.fill(
                                child: ColoredBox(color: Color(0x66000000))),
                            const Positioned.fill(child: IrisHudOverlay()),
                            if (irisData != null)
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: _IrisOverlayPainter(
                                    irisData: irisData,
                                    previewSize:
                                        previewSize ?? constraints.biggest,
                                  ),
                                ),
                              ),
                            GazeDotWidget(
                              position: _controller.dotPosition,
                              isCapturing: _controller.isCapturing,
                              screenSize:
                                  Size(constraints.maxWidth, previewHeight),
                            ),
                            Positioned(
                              top: 12,
                              left: 12,
                              right: 12,
                              child: _ProgressPanel(controller: _controller),
                            ),
                            Positioned(
                              left: 12,
                              top: 88,
                              child: _InstructionBadge(
                                  direction: _controller.currentDirection),
                            ),
                            if (_countdown > 0)
                              Positioned.fill(
                                child: ColoredBox(
                                  color: const Color(0x99000000),
                                  child: Center(
                                    child: Text(
                                      'Test starting in $_countdown...',
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
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: SingleChildScrollView(
                        child: _GazeSummary(result: result),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Color _resultColor(GazeTestResult result) {
    if (result.requiresUrgentReferral) return const Color(0xFFC62828);
    if (result.prismDiopterValue > 10) return const Color(0xFFF9A825);
    return const Color(0xFF2E7D32);
  }
}

class _GazeSummary extends StatelessWidget {
  const _GazeSummary({required this.result});

  final GazeTestResult? result;

  @override
  Widget build(BuildContext context) {
    if (result == null) {
      return GlassCard(
        radius: 24,
        backgroundColor: const Color(0xC9151C2B),
        borderColor: Colors.white.withValues(alpha: 0.10),
        glowColor: const Color(0xFF00B4D8),
        padding: const EdgeInsets.all(16),
        child: const Text(
          'Keep your head still and follow the dot. The test captures your eye position at each direction.',
          style: TextStyle(
            fontSize: 13,
            height: 1.4,
            color: Colors.white70,
          ),
        ),
      );
    }

    return GlassCard(
      radius: 24,
      backgroundColor: const Color(0xC9151C2B),
      borderColor: Colors.white.withValues(alpha: 0.10),
      glowColor: const Color(0xFF00B4D8),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Gaze summary',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
          ),
          const SizedBox(height: 10),
          _MetricRow(
              label: 'Max deviation',
              value: '${result!.maxDeviation.toStringAsFixed(1)}°'),
          _MetricRow(
              label: 'Average deviation',
              value: '${result!.avgDeviation.toStringAsFixed(1)}°'),
          _MetricRow(
              label: 'Prism diopters',
              value: '${result!.prismDiopterValue.toStringAsFixed(1)}Δ'),
          _MetricRow(
            label: 'Strabismus type',
            value: result!.strabismusType,
          ),
          if (result!.abnormalDirections.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Abnormal directions: ${result!.abnormalDirections.join(', ')}',
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressPanel extends StatelessWidget {
  const _ProgressPanel({required this.controller});

  final GazeController controller;

  @override
  Widget build(BuildContext context) {
    final progress = controller.currentIndex / controller.totalDirections;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xDD101B2C), Color(0xC7081221)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x664DD0E1)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Direction ${math.min(controller.currentIndex + 1, controller.totalDirections)} of ${controller.totalDirections}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: const Color(0x3329B6F6),
              color: const Color(0xFFFFB300),
            ),
          ],
        ),
      ),
    );
  }
}

class _InstructionBadge extends StatelessWidget {
  const _InstructionBadge({required this.direction});

  final String direction;

  @override
  Widget build(BuildContext context) {
    final label = switch (direction) {
      'upLeft' => 'Track upper-left',
      'upRight' => 'Track upper-right',
      'downLeft' => 'Track lower-left',
      'downRight' => 'Track lower-right',
      _ => 'Track $direction',
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xB0121D2B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x334DD0E1)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _IrisOverlayPainter extends CustomPainter {
  const _IrisOverlayPainter({
    required this.irisData,
    required this.previewSize,
  });

  final dynamic irisData;
  final Size previewSize;

  @override
  void paint(Canvas canvas, Size size) {
    final left = Offset(
      irisData.leftIrisCenter.dx / previewSize.width * size.width,
      irisData.leftIrisCenter.dy / previewSize.height * size.height,
    );
    final right = Offset(
      irisData.rightIrisCenter.dx / previewSize.width * size.width,
      irisData.rightIrisCenter.dy / previewSize.height * size.height,
    );

    final paint = Paint()
      ..color = const Color(0xFF4DD0E1)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    final fill = Paint()..color = const Color(0xFF4DD0E1);

    canvas.drawCircle(left, 8, fill);
    canvas.drawCircle(right, 8, fill);
    canvas.drawLine(left, right, paint);

    final center = Offset.lerp(left, right, 0.5)!;
    final arcRect = Rect.fromCircle(center: center, radius: 36);
    final deviation =
        (irisData.gazeDeviation as double).clamp(0.0, math.pi / 2);
    canvas.drawArc(arcRect, -math.pi / 2, deviation, false, paint);
  }

  @override
  bool shouldRepaint(covariant _IrisOverlayPainter oldDelegate) {
    return oldDelegate.irisData != irisData ||
        oldDelegate.previewSize != previewSize;
  }
}
