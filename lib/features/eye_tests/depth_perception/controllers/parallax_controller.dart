import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

import '../../../offline/database_tables.dart';
import '../../../offline/local_database.dart';
import '../../../offline/vosk_service.dart';
import '../../test_flow_controller.dart';
import '../models/depth_result.dart';

class ParallaxController extends ChangeNotifier {
  ParallaxController({
    LocalDatabase? database,
  }) : _database = database ?? LocalDatabase.instance;

  final LocalDatabase _database;
  final Uuid _uuid = const Uuid();
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableLandmarks: true,
      performanceMode: FaceDetectorMode.fast,
    ),
  );

  CameraController? _camera;
  ParallaxState _state = ParallaxState.notStarted;
  DepthPerceptionResult? _result;
  String _statusMessage = '';
  Offset _headPosition = const Offset(0.5, 0.5);
  int _currentTrial = 0;
  final List<DepthTrialResult> _trialResults = <DepthTrialResult>[];
  double _currentDisparity = 0;
  String _correctAnswer = 'front';
  bool _waitingForResponse = false;

  static const List<double> trialDisparities = <double>[40, 35, 20, 15, 8, 4];

  Offset get headPosition => _headPosition;
  ParallaxState get state => _state;
  DepthPerceptionResult? get result => _result;
  int get currentTrial => _currentTrial;
  double get currentDisparity => _currentDisparity;
  bool get waitingForResponse => _waitingForResponse;
  String get statusMessage => _statusMessage;
  String get correctAnswer => _correctAnswer;
  CameraController? get camera => _camera;

  Future<void> initialize() async {
    final permission = await Permission.camera.request();
    if (!permission.isGranted) {
      _state = ParallaxState.error;
      _statusMessage = 'Camera permission denied';
      notifyListeners();
      return;
    }

    final cameras = await availableCameras();
    final front = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
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
      await VoskService.initialize();
    }

    _state = ParallaxState.ready;
    _statusMessage = 'Sit still and look at the screen';
    notifyListeners();
  }

  Future<void> _trackHead(CameraImage image) async {
    final faces = await _faceDetector.processImage(_convertImage(image));
    if (faces.isEmpty) {
      return;
    }
    final face = faces.first;
    final bounds = face.boundingBox;
    _headPosition = Offset(
      (bounds.center.dx / image.width.toDouble()).clamp(0.0, 1.0),
      (bounds.center.dy / image.height.toDouble()).clamp(0.0, 1.0),
    );
    notifyListeners();
  }

  Future<void> startTest() async {
    _state = ParallaxState.running;
    _currentTrial = 0;
    _trialResults.clear();
    _statusMessage = 'Say "front" or "back"';
    notifyListeners();
    await _runNextTrial();
  }

  Future<void> _runNextTrial() async {
    if (_currentTrial >= trialDisparities.length) {
      await _completeTest();
      return;
    }

    _currentDisparity = trialDisparities[_currentTrial];
    _correctAnswer = math.Random().nextBool() ? 'front' : 'back';
    _waitingForResponse = true;
    _statusMessage =
        'Trial ${_currentTrial + 1} of ${trialDisparities.length}: say FRONT or BACK';
    notifyListeners();

    final start = DateTime.now();
    final response = await VoskService.listenOnce(timeout: const Duration(seconds: 8));
    final responseTime = DateTime.now().difference(start);

    _waitingForResponse = false;
    final patientAnswer = _parseDepthResponse(response);
    final isCorrect = patientAnswer == _correctAnswer;

    _trialResults.add(
      DepthTrialResult(
        trialNumber: _currentTrial + 1,
        disparityPixels: _currentDisparity,
        correctAnswer: _correctAnswer,
        patientAnswer: patientAnswer,
        isCorrect: isCorrect,
        responseTime: responseTime,
      ),
    );
    _currentTrial++;
    notifyListeners();

    await Future<void>.delayed(const Duration(milliseconds: 800));
    await _runNextTrial();
  }

  String _parseDepthResponse(String voiceInput) {
    final v = voiceInput.toLowerCase().trim();
    // #region agent log H-B
    debugPrint('AMBYODEBUG:9f653c:H-B:parseDepth|input="$voiceInput"|lang=${VoskService.currentLanguage}');
    // #endregion

    if (v.contains('front') ||
        v.contains('forward') ||
        v.contains('close') ||
        v.contains('near') ||
        v.contains('closer') ||
        v.contains('coming') ||
        v.contains('munde') ||
        v.contains('munnil') ||
        v.contains('aduth') ||
        v.contains('munpe') ||
        v.contains('മുൻ') ||
        v.contains('അടുത്ത്') ||
        v.contains('മുൻദേ') ||
        v.contains('aage') ||
        v.contains('saamne') ||
        v.contains('paas') ||
        v.contains('nazdeek') ||
        v.contains('आगे') ||
        v.contains('सामने') ||
        v.contains('पास') ||
        v.contains('munnal') ||
        v.contains('muthal') ||
        v.contains('munbu') ||
        v.contains('முன்னால்') ||
        v.contains('முன்பு')) {
      return 'front';
    }

    if (v.contains('back') ||
        v.contains('behind') ||
        v.contains('far') ||
        v.contains('away') ||
        v.contains('further') ||
        v.contains('pinnil') ||
        v.contains('akale') ||
        v.contains('pirakilam') ||
        v.contains('പിന്ന') ||
        v.contains('അകലെ') ||
        v.contains('പിന്നിൽ') ||
        v.contains('peeche') ||
        v.contains('door') ||
        v.contains('peechhe') ||
        v.contains('पीछे') ||
        v.contains('दूर') ||
        v.contains('pinnnal') ||
        v.contains('tholaivil') ||
        v.contains('pinbu') ||
        v.contains('பின்னால்') ||
        v.contains('தொலைவில்')) {
      return 'back';
    }

    return 'unknown';
  }

  Future<void> _completeTest() async {
    final correct = _trialResults.where((trial) => trial.isCorrect).length;
    final total = _trialResults.length;
    final accuracy = total == 0 ? 0.0 : correct / total * 100;
    final grade = DepthPerceptionResult.classifyGrade(correct, total);

    var stereoAcuity = 400.0;
    for (final trial in _trialResults.reversed) {
      if (trial.isCorrect) {
        stereoAcuity = trial.disparityPixels * 8;
        break;
      }
    }

    _result = DepthPerceptionResult(
      totalTrials: total,
      correctAnswers: correct,
      accuracyPercent: accuracy,
      stereoAcuityArcSeconds: stereoAcuity,
      stereoGrade: grade,
      isNormal: grade == 'Excellent' || grade == 'Good',
      requiresReferral: grade == 'Reduced' || grade == 'Absent',
      trials: List<DepthTrialResult>.unmodifiable(_trialResults),
      clinicalNote: _buildNote(grade),
      normalityScore: total == 0 ? 0 : correct / total,
    );

    _state = ParallaxState.completed;
    _statusMessage = 'Depth perception test complete';
    await _saveResult(_result!);
    notifyListeners();
  }

  String _buildNote(String grade) {
    switch (grade) {
      case 'Excellent':
        return 'Excellent depth perception. Normal binocular vision depth processing.';
      case 'Good':
        return 'Good depth perception within normal range.';
      case 'Reduced':
        return 'Reduced depth perception detected. Possible binocular vision issue. Follow-up recommended.';
      case 'Absent':
        return 'Absent or severely reduced depth perception. Consistent with amblyopia or strabismus. Ophthalmologist referral recommended.';
      default:
        return 'Test inconclusive.';
    }
  }

  Future<void> _saveResult(DepthPerceptionResult result) async {
    await _database.saveTestResult(
      TestResult(
        id: _uuid.v4(),
        sessionId: TestFlowController.currentSessionId ?? '',
        testName: 'depth_perception',
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

enum ParallaxState {
  notStarted,
  ready,
  running,
  completed,
  error,
}
