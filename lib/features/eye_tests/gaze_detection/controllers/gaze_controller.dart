import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

import '../../../image_processing/eye_image_capture.dart';
import '../../../jarvis_scanner/services/iris_tracking_service.dart';
import '../../../offline/database_tables.dart';
import '../../../offline/local_database.dart';
import '../models/gaze_result.dart';

class GazeController extends ChangeNotifier {
  GazeController({
    required this.currentSessionId,
    IrisTrackingService? irisTrackingService,
    LocalDatabase? database,
  })  : _iris = irisTrackingService ?? IrisTrackingService(),
        _database = database ?? LocalDatabase.instance;

  final IrisTrackingService _iris;
  final LocalDatabase _database;
  final String currentSessionId;
  final Uuid _uuid = const Uuid();

  CameraController? _camera;
  CameraImage? _latestCameraImage;

  static const List<String> directions = <String>[
    'center',
    'up',
    'down',
    'left',
    'right',
    'upLeft',
    'upRight',
    'downLeft',
    'downRight',
  ];

  static const Map<String, Offset> dotPositions = <String, Offset>{
    'center': Offset(0.5, 0.5),
    'up': Offset(0.5, 0.15),
    'down': Offset(0.5, 0.85),
    'left': Offset(0.1, 0.5),
    'right': Offset(0.9, 0.5),
    'upLeft': Offset(0.1, 0.15),
    'upRight': Offset(0.9, 0.15),
    'downLeft': Offset(0.1, 0.85),
    'downRight': Offset(0.9, 0.85),
  };

  int _currentIndex = 0;
  String _currentDirection = 'center';
  Offset _dotPosition = const Offset(0.5, 0.5);
  GazeTestState _state = GazeTestState.notStarted;
  final List<GazeDirectionResult> _results = <GazeDirectionResult>[];
  GazeTestResult? _finalResult;
  IrisData? _currentIrisData;
  String _statusMessage = 'Follow the dot with your eyes';
  bool _isCapturing = false;
  String? _errorMessage;

  int get currentIndex => _currentIndex;
  String get currentDirection => _currentDirection;
  Offset get dotPosition => _dotPosition;
  GazeTestState get state => _state;
  List<GazeDirectionResult> get results => List<GazeDirectionResult>.unmodifiable(_results);
  GazeTestResult? get finalResult => _finalResult;
  IrisData? get irisData => _currentIrisData;
  String get statusMessage => _statusMessage;
  int get totalDirections => directions.length;
  bool get isCapturing => _isCapturing;
  CameraController? get camera => _camera;
  String? get errorMessage => _errorMessage;

  Future<void> initialize() async {
    final permission = await Permission.camera.request();
    if (!permission.isGranted) {
      _state = GazeTestState.error;
      _errorMessage = 'Camera permission denied';
      notifyListeners();
      return;
    }

    try {
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
      _state = GazeTestState.ready;
    } catch (e) {
      _state = GazeTestState.error;
      _errorMessage = 'Failed to initialize gaze camera: $e';
    }
    notifyListeners();
  }

  Future<void> _processFrame(CameraImage image) async {
    _latestCameraImage = image;
    final data = await _iris.processFrame(image);
    if (data != null) {
      _currentIrisData = data;
      notifyListeners();
    }
  }

  Future<void> startTest() async {
    _currentIndex = 0;
    _results.clear();
    _finalResult = null;
    _state = GazeTestState.running;
    _currentDirection = directions[_currentIndex];
    _dotPosition = dotPositions[_currentDirection]!;
    _statusMessage = 'Follow the dot with your eyes';
    notifyListeners();
    await _runNextDirection();
  }

  Future<void> _runNextDirection() async {
    if (_currentIndex >= directions.length) {
      await _completeTest();
      return;
    }

    _currentDirection = directions[_currentIndex];
    _dotPosition = dotPositions[_currentDirection]!;
    _statusMessage = 'Look at the dot...';
    notifyListeners();

    await Future<void>.delayed(const Duration(milliseconds: 1500));

    _isCapturing = true;
    _statusMessage = 'Capturing...';
    notifyListeners();

    final captures = <IrisData>[];
    CameraImage? bestFrame;
    for (var i = 0; i < 10; i++) {
      if (_currentIrisData != null) {
        captures.add(_currentIrisData!);
        bestFrame ??= _latestCameraImage;
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    _isCapturing = false;

    if (captures.isNotEmpty) {
      final result = _analyzeCaptures(captures, _currentDirection);
      _results.add(result);
      if (bestFrame != null) {
        await EyeImageCapture.captureAndSave(
          image: bestFrame,
          sessionId: currentSessionId,
          imageType: 'gaze_${_currentDirection}',
          database: _database,
        );
      }
    }

    _currentIndex++;
    notifyListeners();

    await Future<void>.delayed(const Duration(milliseconds: 500));
    await _runNextDirection();
  }

  GazeDirectionResult _analyzeCaptures(List<IrisData> captures, String direction) {
    var leftX = 0.0;
    var leftY = 0.0;
    var rightX = 0.0;
    var rightY = 0.0;
    var dev = 0.0;

    for (final capture in captures) {
      leftX += capture.leftGazeVector.dx;
      leftY += capture.leftGazeVector.dy;
      rightX += capture.rightGazeVector.dx;
      rightY += capture.rightGazeVector.dy;
      dev += capture.gazeDeviation;
    }

    final n = captures.length.toDouble();
    final avgLeft = Offset(leftX / n, leftY / n);
    final avgRight = Offset(rightX / n, rightY / n);
    final avgDev = dev / n;
    final degreeDev = avgDev * (180 / math.pi);
    final prism = 100 * math.tan(avgDev.clamp(0.0, math.pi / 2));

    return GazeDirectionResult(
      direction: direction,
      leftEyeGaze: avgLeft,
      rightEyeGaze: avgRight,
      deviationAngleDegrees: degreeDev,
      prismDiopters: prism,
      isAbnormal: degreeDev > 5.0,
      capturedAt: DateTime.now(),
    );
  }

  Future<void> _completeTest() async {
    _state = GazeTestState.completed;
    _finalResult = GazeTestResult.fromDirections(_results);

    if (_finalResult!.prismDiopterValue > 20) {
      _statusMessage = 'Significant misalignment detected. Please refer to doctor.';
    } else if (_finalResult!.prismDiopterValue > 10) {
      _statusMessage = 'Some eye misalignment detected.';
    } else {
      _statusMessage = 'Gaze test complete';
    }

    await _database.saveTestResult(
      TestResult(
        id: _uuid.v4(),
        sessionId: currentSessionId,
        testName: 'gaze_detection',
        rawScore: _finalResult!.prismDiopterValue,
        normalizedScore: _normalizeScore(_finalResult!.prismDiopterValue),
        details: <String, dynamic>{
          'directions': _results.map((r) => r.toJson()).toList(),
          'maxDeviation': _finalResult!.maxDeviation,
          'avgDeviation': _finalResult!.avgDeviation,
          'abnormalDirections': _finalResult!.abnormalDirections,
          'strabismusType': _finalResult!.strabismusType,
          'prismDiopterValue': _finalResult!.prismDiopterValue,
          'requiresUrgentReferral': _finalResult!.requiresUrgentReferral,
          'rawJson': jsonEncode(_results.map((r) => r.toJson()).toList()),
        },
        createdAt: DateTime.now(),
      ),
    );

    notifyListeners();
  }

  double _normalizeScore(double prismDiopters) {
    return (prismDiopters / 30).clamp(0.0, 1.0);
  }

  Future<void> shutdown() async {
    if (_camera != null) {
      if (_camera!.value.isStreamingImages) {
        await _camera!.stopImageStream();
      }
      await _camera!.dispose();
      _camera = null;
    }
    await _iris.dispose();
  }

  @override
  void dispose() {
    unawaited(shutdown());
    super.dispose();
  }
}

enum GazeTestState {
  notStarted,
  ready,
  running,
  completed,
  error,
}
