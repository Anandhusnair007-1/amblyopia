import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/providers/language_provider.dart';
import '../../../core/services/distance_calculator.dart';
import '../../../core/widgets/ambyoai_error_state.dart';
import '../../../core/widgets/distance_indicator.dart';
import '../../../core/widgets/test_back_guard.dart';
import '../../../core/router/app_router.dart';
import '../../eye_tests/test_flow_controller.dart';
import '../services/iris_tracking_service.dart'
    show IrisData, IrisTrackingService, irisToScreen;

// HUD palette per spec: dark theme, cyan accent
const _kBackgroundBlack = Color(0xFF000000);
const _kCyanHud = Color(0xFF00B4D8);
const _kCyanHud50 = Color(0x8000B4D8);

class JarvisScanScreen extends ConsumerStatefulWidget {
  const JarvisScanScreen({
    super.key,
    required this.sessionId,
  });

  final String sessionId;

  @override
  ConsumerState<JarvisScanScreen> createState() => _JarvisScanScreenState();
}

class _JarvisScanScreenState extends ConsumerState<JarvisScanScreen>
    with TickerProviderStateMixin {
  final IrisTrackingService _irisTracking = IrisTrackingService();
  CameraController? _camera;
  IrisData? _irisData;
  int _phase = 0;
  bool _navigated = false;
  String? _cameraError;
  bool _faceNotDetectedError = false;
  Timer? _faceCheckTimer;
  Timer? _distanceCheckTimer;
  Timer? _countdownTimer;
  late final AnimationController _reticleController;
  late final AnimationController _pulseController;
  late final AnimationController _cornerController;
  double _distanceCm = 0.0;
  bool _waitingForDistance = false;
  int? _countdownValue;
  static const _eyeScanZone = DistanceZone.eyeScan;
  final DistanceCalculator _distanceCalc =
      DistanceCalculator(horizontalFovDeg: 60.0);

  List<String> get _phaseTexts {
    final langCode = context.read<LanguageProvider>().code;
    return [
      AppStrings.get('eyescan_phase_init', langCode),
      AppStrings.get('eyescan_phase_detect', langCode),
      AppStrings.get('eyescan_phase_lock', langCode),
      AppStrings.get('eyescan_phase_ready', langCode),
    ];
  }

  @override
  void initState() {
    super.initState();
    _reticleController =
        AnimationController(vsync: this, duration: const Duration(seconds: 26))
          ..repeat();
    _pulseController =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat(reverse: true);
    _cornerController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    try {
      final permission = await Permission.camera.request();
      if (!permission.isGranted) {
        if (mounted) {
          setState(() {
            _cameraError = 'Camera permission is required for eye scan.';
          });
        }
        return;
      }

      final cameras = await availableCameras();
      final front = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      _camera = CameraController(
        front,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      await _camera!.initialize();
      await _camera!.startImageStream(_processFrame);
      if (mounted) {
        setState(() => _cameraError = null);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _cameraError = e.toString());
      }
      return;
    }

    if (!mounted) return;
    setState(() {});

    _faceCheckTimer?.cancel();
    _faceCheckTimer = Timer(const Duration(seconds: 10), () {
      if (!mounted || _navigated || _irisData != null) return;
      setState(() => _faceNotDetectedError = true);
    });

    for (var i = 0; i < 4; i++) {
      if (!mounted) return;
      setState(() => _phase = i);
      await Future<void>.delayed(const Duration(seconds: 3));
    }

    if (mounted && !_navigated && !_faceNotDetectedError) {
      setState(() => _waitingForDistance = true);
      _distanceCheckTimer?.cancel();
      _distanceCheckTimer =
          Timer.periodic(const Duration(milliseconds: 400), (_) {
        if (!mounted || !_waitingForDistance || _navigated) return;
        final inZone = isInOptimalZone(_distanceCm, _eyeScanZone);
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
            if (!mounted || !_waitingForDistance || _navigated) return;
            if (!isInOptimalZone(_distanceCm, _eyeScanZone)) {
              _countdownTimer?.cancel();
              setState(() => _countdownValue = null);
              return;
            }
            setState(() => _countdownValue = (_countdownValue ?? 3) - 1);
            if (_countdownValue == 0) {
              _countdownTimer?.cancel();
              _distanceCheckTimer?.cancel();
              if (!mounted || _navigated) return;
              _navigated = true;
              final nextRoute = TestFlowController().getNextRoute('eye_scan') ??
                  AppRouter.worthFourDot;
              Navigator.of(context).pushReplacementNamed(nextRoute);
            }
          });
        }
      });
    }
  }

  Future<void> _processFrame(CameraImage image) async {
    final data = await _irisTracking.processFrame(image);
    if (data != null && mounted) {
      _faceCheckTimer?.cancel();
      _faceCheckTimer = null;
      final cm = (data.faceBoxWidthPx != null &&
              data.imageWidthPx != null &&
              data.faceBoxWidthPx! > 0)
          ? _distanceCalc.distanceCm(
              faceBoxWidthPx: data.faceBoxWidthPx!,
              imageWidthPx: data.imageWidthPx!,
            )
          : 0.0;
      setState(() {
        _irisData = data;
        _distanceCm = cm;
      });
      if (_cornerController.status != AnimationStatus.completed) {
        _cornerController.forward();
      }
    } else if (mounted) {
      if (_cornerController.status != AnimationStatus.dismissed) {
        _cornerController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _faceCheckTimer?.cancel();
    _distanceCheckTimer?.cancel();
    _countdownTimer?.cancel();
    unawaited(_camera?.stopImageStream());
    unawaited(_camera?.dispose());
    unawaited(_irisTracking.dispose());
    _reticleController.dispose();
    _pulseController.dispose();
    _cornerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final previewSize = _camera?.value.previewSize;
    final locked = _phase == 3 && _irisData != null;
    final faceDetected = _irisData != null;
    final testInProgress = !_navigated;

    if (_cameraError != null) {
      final isPermission = _cameraError!.toLowerCase().contains('permission');
      return TestBackGuard(
        testName: 'Eye Scan',
        testInProgress: true,
        child: Scaffold(
          backgroundColor: _kBackgroundBlack,
          body: AmbyoErrorState(
            message:
                'Camera could not start. Check camera permission and try again.',
            isPermissionError: isPermission,
            dark: true,
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

    if (_faceNotDetectedError) {
      return TestBackGuard(
        testName: 'Eye Scan',
        testInProgress: true,
        child: Scaffold(
          backgroundColor: _kBackgroundBlack,
          body: AmbyoErrorState(
            message:
                'Face not detected. Ensure good lighting and hold phone at eye level.',
            isPermissionError: false,
            dark: true,
            onRetry: () {
              setState(() => _faceNotDetectedError = false);
              unawaited(_initialize());
            },
          ),
        ),
      );
    }

    return TestBackGuard(
        testName: 'Eye Scan',
        testInProgress: testInProgress,
        child: Scaffold(
          backgroundColor: _kBackgroundBlack,
          body: LayoutBuilder(
            builder: (context, constraints) {
              final isCompact =
                  constraints.maxWidth < 420 || constraints.maxHeight < 760;
              final topInset = media.padding.top + 10;
              final bottomInset = media.padding.bottom + 18;
              return Stack(
                children: [
                  if (_camera != null &&
                      _camera!.value.isInitialized &&
                      previewSize != null)
                    SizedBox.expand(
                      child: FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: previewSize.height,
                          height: previewSize.width,
                          child: CameraPreview(_camera!),
                        ),
                      ),
                    )
                  else
                    const ColoredBox(color: _kBackgroundBlack),
                  Positioned.fill(child: _VignetteOverlay()),
                  const Positioned.fill(child: _TechGridOverlay()),
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _ProgressArcPainter(progress: (_phase + 1) / 4),
                    ),
                  ),
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: _cornerController,
                      builder: (context, _) {
                        return CustomPaint(
                          painter:
                              _CornerBracketPainter(t: _cornerController.value),
                        );
                      },
                    ),
                  ),
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: _reticleController,
                      builder: (context, _) {
                        return Transform.rotate(
                          angle: _reticleController.value * 2 * 3.1415926,
                          child: const CustomPaint(
                            painter: _ReticlePainter(),
                          ),
                        );
                      },
                    ),
                  ),
                  if (!faceDetected)
                    const Positioned.fill(
                      child: _FaceGuideOverlay(),
                    ),
                  if (_irisData != null)
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _EyeScanIrisPainter(
                          irisData: _irisData!,
                          pulse: _pulseController,
                          scan: _reticleController,
                        ),
                      ),
                    ),
                  if (_camera == null || !_camera!.value.isInitialized)
                    const Positioned.fill(
                      child: _ScannerBootOverlay(),
                    ),
                  Positioned(
                    top: topInset,
                    left: 18,
                    right: 18,
                    child: _TopHudBar(
                      phaseText: _phaseTexts[_phase],
                      locked: locked,
                      faceDetected: faceDetected,
                    ),
                  ),
                  Positioned(
                    left: 12,
                    top: constraints.maxHeight * 0.16,
                    bottom: constraints.maxHeight * (isCompact ? 0.27 : 0.22),
                    child: const _HudVerticalScale(
                      alignRight: false,
                    ),
                  ),
                  Positioned(
                    right: 12,
                    top: constraints.maxHeight * 0.16,
                    bottom: constraints.maxHeight * (isCompact ? 0.27 : 0.22),
                    child: const _HudVerticalScale(
                      alignRight: true,
                    ),
                  ),
                  Positioned(
                    left: 18,
                    right: 18,
                    bottom: isCompact ? 154 + bottomInset : 148 + bottomInset,
                    child: _ScanAssistPanel(
                      faceDetected: faceDetected,
                      locked: locked,
                      waitingForDistance: _waitingForDistance,
                      countdownValue: _countdownValue,
                      distanceCm: _distanceCm,
                    ),
                  ),
                  if (_irisData != null)
                    Positioned(
                      left: 18,
                      right: 18,
                      bottom: isCompact ? 88 + bottomInset : 92 + bottomInset,
                      child: _ScanTelemetryStrip(
                        irisData: _irisData!,
                        distanceCm: _distanceCm,
                        locked: locked,
                        compact: isCompact,
                      ),
                    ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: bottomInset,
                    child: _PhaseIndicator(
                      text: _waitingForDistance
                          ? (_countdownValue != null && _countdownValue! > 0
                              ? 'Hold still... $_countdownValue...'
                              : _phaseTexts[_phase])
                          : _phaseTexts[_phase],
                      locked: locked,
                    ),
                  ),
                  if (_waitingForDistance) ...[
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: isCompact ? 114 + bottomInset : 76 + bottomInset,
                      child: Center(
                        child: DistanceIndicator(
                          distanceCm: _distanceCm,
                          zone: _eyeScanZone,
                          compact: false,
                        ),
                      ),
                    ),
                    if (_countdownValue == null)
                      const Positioned(
                        left: 0,
                        right: 0,
                        bottom: 92,
                        child: Center(
                          child: Text(
                            'Get to 30–50 cm',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  ],
                ],
              );
            },
          ),
        ));
  }
}

class _VignetteOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 0.85,
          colors: [
            Color(0x00000000),
            Color(0x7A000000),
          ],
        ),
      ),
    );
  }
}

class _TechGridOverlay extends StatelessWidget {
  const _TechGridOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _TechGridPainter(),
      ),
    );
  }
}

class _TopHudBar extends StatelessWidget {
  const _TopHudBar({
    required this.phaseText,
    required this.locked,
    required this.faceDetected,
  });

  final String phaseText;
  final bool locked;
  final bool faceDetected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _HudChip(
            title: 'IRIS SCAN',
            value: faceDetected ? 'TARGET ACQUIRED' : 'SEARCHING',
            accent: faceDetected
                ? const Color(0xFF55E6FF)
                : const Color(0xFFFFC857),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _HudChip(
            title: 'LOCK STATE',
            value: locked ? 'LOCKED' : phaseText.toUpperCase(),
            accent: locked ? const Color(0xFF7CFFB2) : const Color(0xFF55E6FF),
          ),
        ),
      ],
    );
  }
}

class _HudChip extends StatelessWidget {
  const _HudChip({
    required this.title,
    required this.value,
    required this.accent,
  });

  final String title;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xCC08111C),
                Color(0xB2102136),
              ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: accent.withValues(alpha: 0.32)),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.16),
                blurRadius: 18,
                spreadRadius: -8,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  color: Colors.white70,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12,
                  color: accent,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HudVerticalScale extends StatelessWidget {
  const _HudVerticalScale({
    required this.alignRight,
  });

  final bool alignRight;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          '100',
          style: GoogleFonts.jetBrainsMono(
            fontSize: 10,
            color: Colors.white54,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: CustomPaint(
            painter: _HudScalePainter(alignRight: alignRight),
            size: const Size(28, double.infinity),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '000',
          style: GoogleFonts.jetBrainsMono(
            fontSize: 10,
            color: Colors.white54,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ScanTelemetryStrip extends StatelessWidget {
  const _ScanTelemetryStrip({
    required this.irisData,
    required this.distanceCm,
    required this.locked,
    required this.compact,
  });

  final IrisData irisData;
  final double distanceCm;
  final bool locked;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final leftMag = irisData.leftGazeVector.distance;
    final rightMag = irisData.rightGazeVector.distance;
    final items = <Widget>[
      _TelemetryCard(
        label: 'DISTANCE',
        value: distanceCm > 0 ? '${distanceCm.toStringAsFixed(0)} cm' : '--',
      ),
      _TelemetryCard(
        label: 'DEVIATION',
        value: irisData.gazeDeviation.toStringAsFixed(1),
      ),
      _TelemetryCard(
        label: 'EYE VECTOR',
        value: '${((leftMag + rightMag) / 2 * 100).toStringAsFixed(0)}%',
      ),
      _TelemetryCard(
        label: 'STATUS',
        value: locked ? 'READY' : 'TRACKING',
      ),
    ];

    if (compact) {
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: items
            .map(
              (card) => SizedBox(
                width: (MediaQuery.of(context).size.width - 46) / 2,
                child: card,
              ),
            )
            .toList(),
      );
    }

    return Row(
      children: [
        Expanded(
          child: items[0],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: items[1],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: items[2],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: items[3],
        ),
      ],
    );
  }
}

class _TelemetryCard extends StatelessWidget {
  const _TelemetryCard({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0x8F09111A),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _kCyanHud.withValues(alpha: 0.18)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 9,
                  color: Colors.white54,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12,
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScanAssistPanel extends StatelessWidget {
  const _ScanAssistPanel({
    required this.faceDetected,
    required this.locked,
    required this.waitingForDistance,
    required this.countdownValue,
    required this.distanceCm,
  });

  final bool faceDetected;
  final bool locked;
  final bool waitingForDistance;
  final int? countdownValue;
  final double distanceCm;

  @override
  Widget build(BuildContext context) {
    final tone = locked
        ? const Color(0xFF7CFFB2)
        : faceDetected
            ? const Color(0xFF55E6FF)
            : const Color(0xFFFFC857);
    final headline = locked
        ? 'Eye lock stable'
        : faceDetected
            ? 'Face acquired'
            : 'Searching for face';
    final detail = waitingForDistance
        ? countdownValue != null && countdownValue! > 0
            ? 'Hold still. Auto-confirming in $countdownValue seconds.'
            : distanceCm > 0
                ? 'Move into the optimal capture zone and keep the phone steady.'
                : 'Bring the device into the optimal capture zone.'
        : 'Align the child’s face at eye level and wait for lock.';

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xA309111A),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: tone.withValues(alpha: 0.26)),
          ),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: tone,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: tone.withValues(alpha: 0.45),
                      blurRadius: 12,
                      spreadRadius: -2,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      headline,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      detail,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        color: Colors.white70,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScannerBootOverlay extends StatelessWidget {
  const _ScannerBootOverlay();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          colors: [
            Color(0x6600B4D8),
            Color(0x00000000),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 54,
              height: 54,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(_kCyanHud),
                backgroundColor: Colors.white12,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Initializing camera scanner',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 12,
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhaseIndicator extends StatefulWidget {
  const _PhaseIndicator({required this.text, required this.locked});

  final String text;
  final bool locked;

  @override
  State<_PhaseIndicator> createState() => _PhaseIndicatorState();
}

class _PhaseIndicatorState extends State<_PhaseIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 1))
          ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xD9101C31),
                  Color(0xC4071223),
                ],
              ),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: _kCyanHud.withValues(alpha: 0.28)),
              boxShadow: [
                BoxShadow(
                  color: _kCyanHud.withValues(alpha: 0.16),
                  blurRadius: 24,
                  spreadRadius: -10,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final dots = widget.locked
                    ? ''
                    : '.' * ((_controller.value * 3).floor() + 1).clamp(1, 3);
                return Text(
                  '${widget.text}$dots',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _EyeScanIrisPainter extends CustomPainter {
  _EyeScanIrisPainter({
    required this.irisData,
    required this.pulse,
    required this.scan,
  }) : super(repaint: Listenable.merge(<Listenable>[pulse, scan]));

  final IrisData irisData;
  final Animation<double> pulse;
  final Animation<double> scan;

  @override
  void paint(Canvas canvas, Size size) {
    final screenSize = Size(size.width.toDouble(), size.height.toDouble());
    final left = irisToScreen(irisData.leftIrisCenter, screenSize);
    final right = irisToScreen(irisData.rightIrisCenter, screenSize);
    final ringScale = 0.94 + (pulse.value * 0.12);
    final sweepAngle = (scan.value * math.pi * 2) - (math.pi / 2);
    final linePaint = Paint()
      ..color = const Color(0xFF7BE7FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (final eye in <Offset>[left, right]) {
      final haloPaint = Paint()
        ..shader = const RadialGradient(
          colors: <Color>[
            Color(0x6632D9FF),
            Color(0x0012A2D3),
          ],
        ).createShader(Rect.fromCircle(center: eye, radius: 62));
      final corePaint = Paint()
        ..shader = const RadialGradient(
          colors: <Color>[
            Color(0xAA6CEBFF),
            Color(0x0000B4D8),
          ],
        ).createShader(Rect.fromCircle(center: eye, radius: 40));

      canvas.drawCircle(eye, 62, haloPaint);
      canvas.drawCircle(eye, 34, corePaint);
      _drawSegmentRing(canvas, eye, 52 * ringScale, sweepAngle, linePaint);
      _drawSegmentRing(
        canvas,
        eye,
        34 * ringScale,
        -sweepAngle * 0.7,
        linePaint,
      );
      canvas.drawCircle(
        eye,
        22 * ringScale,
        Paint()
          ..color = const Color(0xFFB9F3FF).withValues(alpha: 0.92)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
      canvas.drawLine(
        eye.translate(-18, 0),
        eye.translate(18, 0),
        linePaint..strokeWidth = 1.2,
      );
      canvas.drawLine(
        eye.translate(0, -18),
        eye.translate(0, 18),
        linePaint,
      );
      final sweepPoint = eye +
          Offset(math.cos(sweepAngle), math.sin(sweepAngle)) * (52 * ringScale);
      canvas.drawCircle(
        sweepPoint,
        3.5,
        Paint()..color = const Color(0xFF9CF4FF),
      );
    }

    final bridgePaint = Paint()
      ..color = const Color(0x66A8F4FF)
      ..strokeWidth = 1.1;
    canvas.drawLine(
      left.translate(54, 0),
      right.translate(-54, 0),
      bridgePaint,
    );
  }

  void _drawSegmentRing(
    Canvas canvas,
    Offset center,
    double radius,
    double rotation,
    Paint paint,
  ) {
    for (var i = 0; i < 12; i++) {
      final start = rotation + (i * (math.pi * 2 / 12));
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        math.pi / 8,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _EyeScanIrisPainter oldDelegate) {
    return oldDelegate.irisData != irisData ||
        oldDelegate.pulse != pulse ||
        oldDelegate.scan != scan;
  }
}

class _CornerBracketPainter extends CustomPainter {
  _CornerBracketPainter({required this.t});

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final inset = 24 + (1 - t) * 26;
    const len = 40.0;
    final paint = Paint()
      ..color = _kCyanHud
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Top-left
    canvas.drawLine(Offset(inset, inset), Offset(inset + len, inset), paint);
    canvas.drawLine(Offset(inset, inset), Offset(inset, inset + len), paint);
    // Top-right
    canvas.drawLine(Offset(size.width - inset, inset),
        Offset(size.width - inset - len, inset), paint);
    canvas.drawLine(Offset(size.width - inset, inset),
        Offset(size.width - inset, inset + len), paint);
    // Bottom-left
    canvas.drawLine(Offset(inset, size.height - inset),
        Offset(inset + len, size.height - inset), paint);
    canvas.drawLine(Offset(inset, size.height - inset),
        Offset(inset, size.height - inset - len), paint);
    // Bottom-right
    canvas.drawLine(
      Offset(size.width - inset, size.height - inset),
      Offset(size.width - inset - len, size.height - inset),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - inset, size.height - inset),
      Offset(size.width - inset, size.height - inset - len),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _CornerBracketPainter oldDelegate) =>
      oldDelegate.t != t;
}

class _ReticlePainter extends CustomPainter {
  const _ReticlePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = _kCyanHud50
      ..strokeWidth = 1.2;
    canvas.drawLine(center.translate(-30, 0), center.translate(-6, 0), paint);
    canvas.drawLine(center.translate(6, 0), center.translate(30, 0), paint);
    canvas.drawLine(center.translate(0, -30), center.translate(0, -6), paint);
    canvas.drawLine(center.translate(0, 6), center.translate(0, 30), paint);
    canvas.drawCircle(
      center,
      6,
      paint..style = PaintingStyle.stroke,
    );
    canvas.drawCircle(
      center,
      26,
      Paint()
        ..color = _kCyanHud.withValues(alpha: 0.16)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _ReticlePainter oldDelegate) => false;
}

class _ProgressArcPainter extends CustomPainter {
  const _ProgressArcPainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      size.width * 0.06,
      20,
      size.width * 0.88,
      size.height * 0.92,
    );
    final paint = Paint()
      ..color = _kCyanHud.withValues(alpha: 0.52)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawArc(
      rect,
      -math.pi * 0.82,
      math.pi * 1.64 * progress.clamp(0.0, 1.0),
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _ProgressArcPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _FaceGuideOverlay extends StatelessWidget {
  const _FaceGuideOverlay();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _FaceGuidePainter(),
    );
  }
}

class _FaceGuidePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final usableHeight = size.height - 210;
    final center = Offset(size.width / 2, usableHeight * 0.56);
    final oval = Rect.fromCenter(
      center: center,
      width: size.width * 0.48,
      height: usableHeight * 0.42,
    );
    final paint = Paint()
      ..color = _kCyanHud.withValues(alpha: 0.48)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7;
    const dash = 10.0;
    const gap = 6.0;
    final path = Path()..addOval(oval);
    final metrics = path.computeMetrics().first;
    double distance = 0;
    while (distance < metrics.length) {
      final segment = metrics.extractPath(distance, distance + dash);
      canvas.drawPath(segment, paint);
      distance += dash + gap;
    }
    final faceGuideColor = _kCyanHud.withValues(alpha: 0.53);
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'Position face here',
        style: TextStyle(
          color: faceGuideColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(center.dx - textPainter.width / 2, oval.bottom + 16),
    );
  }

  @override
  bool shouldRepaint(covariant _FaceGuidePainter oldDelegate) => false;
}

class _TechGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final major = Paint()
      ..color = const Color(0x18FFFFFF)
      ..strokeWidth = 1;
    final minor = Paint()
      ..color = const Color(0x0F86E8FF)
      ..strokeWidth = 0.7;

    const majorGap = 56.0;
    const minorGap = 18.0;

    for (double x = 0; x <= size.width; x += minorGap) {
      final isMajor = ((x / majorGap) - (x / majorGap).round()).abs() < 0.05;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        isMajor ? major : minor,
      );
    }

    for (double y = 0; y <= size.height; y += minorGap) {
      final isMajor = ((y / majorGap) - (y / majorGap).round()).abs() < 0.05;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        isMajor ? major : minor,
      );
    }

    final rulerPaint = Paint()
      ..color = const Color(0x4DFFFFFF)
      ..strokeWidth = 1.2;
    const topY = 18.0;
    final startX = size.width * 0.18;
    final endX = size.width * 0.82;
    canvas.drawLine(Offset(startX, topY), Offset(endX, topY), rulerPaint);
    for (double x = startX; x <= endX; x += 12) {
      final longTick = ((x - startX) / 12).round() % 5 == 0;
      canvas.drawLine(
        Offset(x, topY - (longTick ? 8 : 4)),
        Offset(x, topY + (longTick ? 8 : 4)),
        rulerPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TechGridPainter oldDelegate) => false;
}

class _HudScalePainter extends CustomPainter {
  const _HudScalePainter({
    required this.alignRight,
  });

  final bool alignRight;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x70A3EEFF)
      ..strokeWidth = 1.2;
    final x1 = alignRight ? 0.0 : size.width;
    final x2Long = alignRight ? size.width : 0.0;
    final x2Short = alignRight ? size.width * 0.55 : size.width * 0.45;

    for (double y = 0; y <= size.height; y += 14) {
      final longTick = (y / 14).round() % 4 == 0;
      canvas.drawLine(
        Offset(x1, y),
        Offset(longTick ? x2Long : x2Short, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HudScalePainter oldDelegate) =>
      oldDelegate.alignRight != alignRight;
}
