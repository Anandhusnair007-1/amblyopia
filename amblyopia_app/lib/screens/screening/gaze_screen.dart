import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../../models/gaze_result_model.dart';
import '../../services/tts_service.dart';
import '../../widgets/gaze_overlay.dart';

class GazeScreen extends StatefulWidget {
  final String ageGroup;
  final void Function(GazeResultModel) onComplete;

  const GazeScreen({
    super.key,
    required this.ageGroup,
    required this.onComplete,
  });

  @override
  State<GazeScreen> createState() => _GazeScreenState();
}

class _GazeScreenState extends State<GazeScreen>
    with SingleTickerProviderStateMixin {
  CameraController? _camera;
  late AnimationController _ballCtrl;
  late Animation<double> _ballX;
  late Animation<double> _ballY;

  Timer? _countdownTimer;
  int _secondsLeft = 30;
  bool _isProcessing = false;
  bool _cameraReady = false;
  bool _testDone = false;

  // Hirschberg infant mode
  bool _showHirschberg = false;

  // Gaze tracking data
  final List<double> _leftXHistory = [];
  final List<double> _rightXHistory = [];
  final List<double> _leftYHistory = [];
  final List<double> _rightYHistory = [];
  double _gazeAsymmetry = 0.0;
  double _confidence = 0.0;

  Rect? _leftEyeRect;
  Rect? _rightEyeRect;

  late FaceDetector _faceDetector;
  bool _detecting = false;

  @override
  void initState() {
    super.initState();

    _showHirschberg = widget.ageGroup == 'infant';

    // Ball animation — figure-8 path
    _ballCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();

    _ballX = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.2, end: 0.8), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 0.8, end: 0.5), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 0.5, end: 0.2), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 0.2, end: 0.5), weight: 25),
    ]).animate(_ballCtrl);

    _ballY = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.5, end: 0.3), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 0.3, end: 0.7), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 0.7, end: 0.5), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 0.5, end: 0.5), weight: 25),
    ]).animate(_ballCtrl);

    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableLandmarks: true,
        enableClassification: true,
        performanceMode: FaceDetectorMode.fast,
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) => _startTest());
  }

  Future<void> _startTest() async {
    await TtsService.sayLookAtBall();

    // Init camera
    try {
      final cameras = await availableCameras();
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      _camera = CameraController(
        front,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      await _camera!.initialize();

      if (mounted) {
        setState(() => _cameraReady = true);
        _startCountdown();
        _camera!.startImageStream(_processFrame);
      }
    } catch (e) {
      // Camera unavailable — run test without camera
      if (mounted) {
        setState(() => _cameraReady = false);
        _startCountdown();
      }
    }
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) {
        t.cancel();
        _finishTest();
      }
    });
  }

  Future<void> _processFrame(CameraImage image) async {
    if (_detecting || _testDone) return;
    _detecting = true;
    try {
      final WriteBuffer allBytes = WriteBuffer();
      for (final Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      final inputImage = InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: InputImageRotation.rotation270deg,
          format: InputImageFormat.yuv420,
          bytesPerRow: image.planes[0].bytesPerRow,
        ),
      );

      final faces = await _faceDetector.processImage(inputImage);

      if (faces.isNotEmpty && mounted) {
        final face = faces.first;
        final leftEye = face.landmarks[FaceLandmarkType.leftEye];
        final rightEye = face.landmarks[FaceLandmarkType.rightEye];

        if (leftEye != null && rightEye != null) {
          final screenW = image.width.toDouble();
          final screenH = image.height.toDouble();
          final lx = leftEye.position.x / screenW;
          final ly = leftEye.position.y / screenH;
          final rx = rightEye.position.x / screenW;
          final ry = rightEye.position.y / screenH;

          _leftXHistory.add(lx);
          _leftYHistory.add(ly);
          _rightXHistory.add(rx);
          _rightYHistory.add(ry);

          final asymmetry = (lx - rx).abs();
          final conf = math.min(1.0, _leftXHistory.length / 150.0);

          if (mounted) {
            setState(() {
              _gazeAsymmetry = asymmetry;
              _confidence = conf;
              _leftEyeRect = Rect.fromCenter(
                center: Offset(lx, ly),
                width: 0.08,
                height: 0.05,
              );
              _rightEyeRect = Rect.fromCenter(
                center: Offset(rx, ry),
                width: 0.08,
                height: 0.05,
              );
            });
          }
        }
      }
    } catch (_) {}
    _detecting = false;
  }

  Future<void> _finishTest() async {
    if (_testDone) return;
    _testDone = true;

    await _camera?.stopImageStream();

    final result = GazeResultModel.calculate(
      leftXHistory: _leftXHistory,
      rightXHistory: _rightXHistory,
      leftYHistory: _leftYHistory,
      rightYHistory: _rightYHistory,
      leftBlinks: [],
      rightBlinks: [],
    );

    await TtsService.speak('Gaze test complete.');
    await Future.delayed(const Duration(seconds: 1));

    if (mounted) widget.onComplete(result);
  }

  void _onHirschbergTap(bool centered) {
    _testDone = true;
    _countdownTimer?.cancel();
    final result = GazeResultModel(
      leftGazeX: 0.5, leftGazeY: 0.5,
      rightGazeX: centered ? 0.5 : 0.65, rightGazeY: 0.5,
      gazeAsymmetryScore: centered ? 0.02 : 0.20,
      leftFixationStability: 0.05,
      rightFixationStability: centered ? 0.05 : 0.15,
      leftBlinkRatio: 0.15, rightBlinkRatio: 0.15,
      blinkAsymmetry: 0.0, framesAnalyzed: 1,
      confidenceScore: 0.75,
      result: centered ? 'symmetric' : 'asymmetry_detected',
      needsDoctorReview: !centered,
    );
    widget.onComplete(result);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Stack(
      children: [
        // Camera preview or dark background
        if (_cameraReady && _camera != null && _camera!.value.isInitialized)
          SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _camera!.value.previewSize!.height,
                height: _camera!.value.previewSize!.width,
                child: CameraPreview(_camera!),
              ),
            ),
          )
        else
          Container(color: Colors.black),

        // Gaze overlay
        if (_leftEyeRect != null || _rightEyeRect != null)
          GazeOverlay(
            leftEyeRect: _leftEyeRect,
            rightEyeRect: _rightEyeRect,
            asymmetryScore: _gazeAsymmetry,
          ),

        // Animated stimulus ball
        if (!_showHirschberg)
          AnimatedBuilder(
            animation: _ballCtrl,
            builder: (context, _) {
              return Positioned(
                left: _ballX.value * size.width - 40,
                top: _ballY.value * size.height - 40,
                child: _StimulusBall(ageGroup: widget.ageGroup),
              );
            },
          ),

        // Timer overlay (top right)
        Positioned(
          top: MediaQuery.of(context).padding.top + 52,
          right: 16,
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black54,
              border: Border.all(
                color: _secondsLeft <= 5 ? Colors.red : const Color(0xFF00E5FF),
                width: 2,
              ),
            ),
            child: Center(
              child: Text(
                '$_secondsLeft',
                style: TextStyle(
                  color: _secondsLeft <= 5 ? Colors.red : const Color(0xFF00E5FF),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),

        // Live metrics bar (bottom)
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Colors.black.withOpacity(0.8), Colors.transparent],
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _MetricChip(
                  label: 'Asymmetry',
                  value: _gazeAsymmetry.toStringAsFixed(2),
                  ok: _gazeAsymmetry < 0.15,
                ),
                _MetricChip(
                  label: 'Confidence',
                  value: '${(_confidence * 100).toInt()}%',
                  ok: _confidence > 0.5,
                ),
                _MetricChip(
                  label: 'Frames',
                  value: '${_leftXHistory.length}',
                  ok: true,
                ),
              ],
            ),
          ),
        ),

        // Instruction text (top, below progress dots)
        Positioned(
          top: MediaQuery.of(context).padding.top + 52,
          left: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _showHirschberg ? 'Torch Light Test' : 'Follow the ball',
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ),

        // Hirschberg buttons (infant only)
        if (_showHirschberg)
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Column(
              children: [
                const Text(
                  'Nurse: Is the light reflection centered in BOTH eyes?',
                  style: TextStyle(color: Colors.white, fontSize: 15),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _HirschbergBtn(
                      label: '✅ Centered',
                      color: Colors.green,
                      onTap: () => _onHirschbergTap(true),
                    ),
                    _HirschbergBtn(
                      label: '⚠️ Off-center',
                      color: Colors.orange,
                      onTap: () => _onHirschbergTap(false),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _ballCtrl.dispose();
    _countdownTimer?.cancel();
    _camera?.stopImageStream();
    _camera?.dispose();
    _faceDetector.close();
    super.dispose();
  }
}

class _StimulusBall extends StatelessWidget {
  final String ageGroup;
  const _StimulusBall({required this.ageGroup});

  @override
  Widget build(BuildContext context) {
    if (ageGroup == 'infant') {
      return Container(
        width: 80, height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const RadialGradient(
            colors: [Colors.yellow, Colors.orange],
          ),
          boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.6), blurRadius: 20, spreadRadius: 5)],
        ),
        child: const Center(child: Text('😊', style: TextStyle(fontSize: 36))),
      );
    } else if (ageGroup == 'child') {
      return Container(
        width: 70, height: 70,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const RadialGradient(colors: [Colors.lightBlue, Colors.blue]),
          boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.5), blurRadius: 16, spreadRadius: 3)],
        ),
        child: const Center(child: Text('⭐', style: TextStyle(fontSize: 30))),
      );
    } else {
      return Container(
        width: 60, height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.white.withOpacity(0.4), blurRadius: 12, spreadRadius: 2)],
        ),
      );
    }
  }
}

class _MetricChip extends StatelessWidget {
  final String label;
  final String value;
  final bool ok;

  const _MetricChip({required this.label, required this.value, required this.ok});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ok ? Colors.green.withOpacity(0.5) : Colors.orange.withOpacity(0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF90CAF9), fontSize: 10)),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(width: 4),
              Icon(ok ? Icons.check : Icons.warning_amber,
                  color: ok ? Colors.green : Colors.orange, size: 12),
            ],
          ),
        ],
      ),
    );
  }
}

class _HirschbergBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _HirschbergBtn({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.3),
        side: BorderSide(color: color),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
    );
  }
}
