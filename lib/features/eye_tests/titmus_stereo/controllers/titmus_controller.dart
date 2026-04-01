import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

import '../../../offline/database_tables.dart';
import '../../../offline/local_database.dart';
import '../../../offline/vosk_service.dart';
import '../../age_profile.dart';
import '../../test_flow_controller.dart';
import '../models/titmus_result.dart';

enum TitmusState {
  notStarted,
  ready,
  running,
  completed,
  error,
}

enum TitmusSubTest {
  fly,
  animal,
  circles,
}

class TitmusController extends ChangeNotifier {
  TitmusController({
    LocalDatabase? database,
  }) : _database = database ?? LocalDatabase.instance;

  final LocalDatabase _database;
  final Uuid _uuid = const Uuid();

  TitmusState _state = TitmusState.notStarted;
  TitmusSubTest _currentSubTest = TitmusSubTest.fly;
  TitmusResult? _result;
  String _statusMessage = '';
  bool _isListening = false;

  CameraController? _camera;
  Offset _headPosition = const Offset(0.5, 0.5);
  bool _trackBusy = false;

  bool _flyPassed = false;
  bool _animalPassed = false;
  int _circlesCorrect = 0;
  int _currentCircle = 0;

  static const int totalCircles = 5;
  static const List<String> circleAnswers = <String>[
    'bottom',
    'right',
    'top',
    'left',
    'middle',
  ];
  static const String animalAnswer = 'cat';

  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.fast,
      enableLandmarks: false,
      enableClassification: false,
    ),
  );

  TitmusState get state => _state;
  TitmusSubTest get currentSubTest => _currentSubTest;
  TitmusResult? get result => _result;
  String get statusMessage => _statusMessage;
  Offset get headPosition => _headPosition;
  int get currentCircle => _currentCircle;
  bool get isListening => _isListening;
  CameraController? get camera => _camera;

  String? get currentCircleTarget =>
      _currentSubTest == TitmusSubTest.circles && _currentCircle < circleAnswers.length
          ? circleAnswers[_currentCircle]
          : null;

  Future<void> initialize() async {
    final permission = await Permission.camera.request();
    if (!permission.isGranted) {
      _state = TitmusState.error;
      _statusMessage = 'Camera permission denied';
      notifyListeners();
      return;
    }

    try {
      final cameras = await availableCameras();
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _camera = CameraController(
        front,
        ResolutionPreset.low,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      await _camera!.initialize();
      await _camera!.startImageStream(_trackHead);

      if (!VoskService.isReady) {
        await VoskService.initialize('en');
      }

      _state = TitmusState.ready;
      _statusMessage = 'Get ready for the Titmus stereo test';
    } catch (e) {
      _state = TitmusState.error;
      _statusMessage = 'Failed to initialize camera: $e';
    }
    notifyListeners();
  }

  Future<void> _trackHead(CameraImage image) async {
    if (_trackBusy || _state != TitmusState.running) {
      return;
    }
    _trackBusy = true;
    try {
      final inputImage = _convertImage(image);
      final faces = await _faceDetector.processImage(inputImage);
      if (faces.isEmpty) {
        return;
      }
      final bounds = faces.first.boundingBox;
      _headPosition = Offset(
        (bounds.center.dx / image.width.toDouble()).clamp(0.0, 1.0),
        (bounds.center.dy / image.height.toDouble()).clamp(0.0, 1.0),
      );
      notifyListeners();
    } catch (_) {
      // Ignore tracking failures; the test remains usable.
    } finally {
      _trackBusy = false;
    }
  }

  InputImage _convertImage(CameraImage image) {
    final allBytes = WriteBuffer();
    for (final plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();
    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: InputImageRotation.rotation0deg,
        format: InputImageFormat.yuv420,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  Future<void> startTest() async {
    _state = TitmusState.running;
    _result = null;
    _flyPassed = false;
    _animalPassed = false;
    _circlesCorrect = 0;
    _currentCircle = 0;
    _currentSubTest = TitmusSubTest.fly;
    notifyListeners();

    await _runFlyTest();
  }

  Future<void> _runFlyTest() async {
    _currentSubTest = TitmusSubTest.fly;
    _statusMessage = 'Do you see the wings of the fly lifting up? Say YES or NO';
    notifyListeners();

    await Future<void>.delayed(const Duration(seconds: 3));
    final response = await _listenOnce(timeout: const Duration(seconds: 7));
    final v = response.toLowerCase();
    _flyPassed = v.contains('yes') || v.contains('yeah') || v.contains('see') || v.contains('lift');

    await Future<void>.delayed(const Duration(milliseconds: 800));
    final variant = titmusVariantForProfile(TestFlowController.currentProfile);
    if (variant == TitmusVariant.flyOnly) {
      await _completeTest();
      return;
    }
    await _runAnimalTest();
  }

  Future<void> _runAnimalTest() async {
    _currentSubTest = TitmusSubTest.animal;
    _statusMessage = 'Which animal is closest to you? Say CAT, DUCK, or RABBIT';
    notifyListeners();

    await Future<void>.delayed(const Duration(seconds: 3));
    final response = await _listenOnce(timeout: const Duration(seconds: 7));
    _animalPassed = response.toLowerCase().contains(animalAnswer);

    await Future<void>.delayed(const Duration(milliseconds: 800));
    final variant = titmusVariantForProfile(TestFlowController.currentProfile);
    if (variant != TitmusVariant.full) {
      await _completeTest();
      return;
    }
    await _runCircleTest();
  }

  Future<void> _runCircleTest() async {
    _currentSubTest = TitmusSubTest.circles;
    _circlesCorrect = 0;
    notifyListeners();

    for (var i = 0; i < totalCircles; i++) {
      _currentCircle = i;
      _statusMessage =
          'Circle ${i + 1} of $totalCircles: Which circle pops forward? Say LEFT, RIGHT, TOP, BOTTOM, or MIDDLE';
      notifyListeners();

      await Future<void>.delayed(const Duration(seconds: 3));
      final response = await _listenOnce(timeout: const Duration(seconds: 7));
      final answer = _parseCircleResponse(response);
      if (answer == circleAnswers[i]) {
        _circlesCorrect++;
      }
      await Future<void>.delayed(const Duration(milliseconds: 450));
    }

    await _completeTest();
  }

  Future<String> _listenOnce({required Duration timeout}) async {
    _isListening = true;
    notifyListeners();
    final response = await VoskService.listenOnce(timeout: timeout);
    if (response == 'MIC_PERMISSION_DENIED') {
      _statusMessage = 'Microphone permission denied';
    }
    _isListening = false;
    notifyListeners();
    return response;
  }

  String _parseCircleResponse(String voice) {
    final v = voice.toLowerCase();
    if (v.contains('left')) return 'left';
    if (v.contains('right')) return 'right';
    if (v.contains('top') || v.contains('up')) return 'top';
    if (v.contains('bottom') || v.contains('down')) return 'bottom';
    if (v.contains('middle') || v.contains('center')) return 'middle';
    return 'unknown';
  }

  Future<void> _completeTest() async {
    final arcSeconds = TitmusResult.getArcSeconds(_flyPassed, _animalPassed, _circlesCorrect);
    final grade = TitmusResult.getGrade(arcSeconds);
    final normalityScore = _calcScore(arcSeconds);

    _result = TitmusResult(
      flyTestPassed: _flyPassed,
      animalTestPassed: _animalPassed,
      circlesCorrect: _circlesCorrect,
      circlesTotal: totalCircles,
      stereoAcuityArcSeconds: arcSeconds,
      stereoGrade: grade,
      isNormal: arcSeconds <= 200,
      requiresReferral: arcSeconds > 400,
      clinicalNote: _buildNote(grade, arcSeconds),
      normalityScore: normalityScore,
    );

    _state = TitmusState.completed;
    _statusMessage = 'Titmus test complete ✓';

    await _saveResult(_result!);
    notifyListeners();
  }

  String _buildNote(String grade, double arcSeconds) {
    switch (grade) {
      case 'Excellent':
        return 'Excellent stereopsis. Normal binocular depth perception (${arcSeconds.toStringAsFixed(0)}").';
      case 'Fine':
        return 'Fine stereopsis present (${arcSeconds.toStringAsFixed(0)}"). Within acceptable range.';
      case 'Moderate':
        return 'Moderate stereopsis only (${arcSeconds.toStringAsFixed(0)}"). Reduced depth perception. Follow-up recommended.';
      case 'Gross Only':
        return 'Only gross stereopsis detected. Significantly reduced depth perception. Referral recommended.';
      case 'Absent':
        return 'No stereopsis detected. Absent depth perception. Consistent with amblyopia or suppression. Ophthalmologist referral required.';
      default:
        return 'Test inconclusive.';
    }
  }

  double _calcScore(double arcSeconds) {
    if (arcSeconds >= 9999) return 0.0;
    if (arcSeconds >= 3000) return 0.1;
    if (arcSeconds >= 800) return 0.4;
    if (arcSeconds >= 400) return 0.6;
    if (arcSeconds >= 200) return 0.8;
    return 1.0;
  }

  Future<void> _saveResult(TitmusResult result) async {
    final flow = TestFlowController();
    flow.onTestComplete('titmus_stereo', result);

    await _database.saveTestResult(
      TestResult(
        id: _uuid.v4(),
        sessionId: TestFlowController.currentSessionId ?? '',
        testName: 'titmus_stereo',
        rawScore: result.normalityScore,
        normalizedScore: result.normalityScore,
        details: <String, dynamic>{
          ...result.toJson(),
          'rawJson': jsonEncode(result.toJson()),
        },
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> shutdown() async {
    if (_camera?.value.isStreamingImages ?? false) {
      await _camera?.stopImageStream();
    }
    await _camera?.dispose();
    await _faceDetector.close();
  }

  @override
  void dispose() {
    unawaited(shutdown());
    super.dispose();
  }
}
