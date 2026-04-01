import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_mesh_detection/google_mlkit_face_mesh_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

import '../../../offline/database_tables.dart';
import '../../../offline/local_database.dart';
import '../../../offline/vosk_service.dart';
import '../../test_flow_controller.dart';
import '../models/lang_result.dart';

enum LangState {
  notStarted,
  ready,
  running,
  completed,
  error,
}

class LangController extends ChangeNotifier {
  LangController({
    LocalDatabase? database,
  }) : _database = database ?? LocalDatabase.instance;

  final LocalDatabase _database;
  final Uuid _uuid = const Uuid();

  LangState _state = LangState.notStarted;
  LangResult? _result;
  String _statusMessage = '';
  int _currentPattern = 0;
  Offset _headPosition = const Offset(0.5, 0.5);
  bool _isListening = false;

  bool _pattern1 = false;
  bool _pattern2 = false;
  bool _pattern3 = false;

  final List<String> _patternNames = const <String>['star', 'car', 'cat'];
  final List<String> _instructions = const <String>[
    'Do you see a STAR shape? Say STAR or NOTHING',
    'Do you see a CAR? Say CAR or NOTHING',
    'Do you see a CAT face? Say CAT or NOTHING',
  ];

  CameraController? _camera;
  bool _trackBusy = false;
  bool _inPatternWindow = false;

  // Convergence signal collected while pattern is displayed.
  final List<double> _leftVergence = <double>[];
  final List<double> _rightVergence = <double>[];
  final List<bool> _leftConvergedByPattern = <bool>[false, false, false];
  final List<bool> _rightConvergedByPattern = <bool>[false, false, false];

  final FaceMeshDetector _meshDetector = FaceMeshDetector(
    option: FaceMeshDetectorOptions.faceMesh,
  );

  int get currentPattern => _currentPattern;
  LangState get state => _state;
  LangResult? get result => _result;
  String get statusMessage => _statusMessage;
  Offset get headPosition => _headPosition;
  bool get isListening => _isListening;
  CameraController? get camera => _camera;

  Future<void> initialize() async {
    final permission = await Permission.camera.request();
    if (!permission.isGranted) {
      _state = LangState.error;
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
      await _camera!.startImageStream(_trackFace);

      if (!VoskService.isReady) {
        await VoskService.initialize('en');
      }

      _state = LangState.ready;
      _statusMessage = 'Get ready for the Lang random-dot test';
    } catch (e) {
      _state = LangState.error;
      _statusMessage = 'Failed to initialize: $e';
    }
    notifyListeners();
  }

  Future<void> _trackFace(CameraImage image) async {
    if (_trackBusy || !_inPatternWindow || _state != LangState.running) {
      return;
    }
    _trackBusy = true;
    try {
      final meshes = await _meshDetector.processImage(_convertImage(image));
      if (meshes.isEmpty) {
        return;
      }

      final mesh = meshes.first;
      final points = mesh.points;
      if (points.length < 387) {
        return;
      }

      // Head position from face mesh bounds (approx): center of eye corners.
      final leftOuter = points[33];
      final leftInner = points[133];
      final rightOuter = points[362];
      final rightInner = points[263];
      final cx = ((leftOuter.x + rightInner.x) / 2).clamp(0.0, image.width.toDouble());
      final cy = ((leftOuter.y + rightOuter.y) / 2).clamp(0.0, image.height.toDouble());
      _headPosition = Offset(
        (cx / image.width.toDouble()).clamp(0.0, 1.0),
        (cy / image.height.toDouble()).clamp(0.0, 1.0),
      );

      // Vergence estimate using iris centers relative to eye centers.
      final leftIris = _avg(points, const <int>[33, 133, 159, 145, 153]);
      final rightIris = _avg(points, const <int>[362, 263, 386, 374, 380]);

      final leftWidth = (leftInner.x - leftOuter.x).abs().clamp(1.0, 9999.0);
      final rightWidth = (rightInner.x - rightOuter.x).abs().clamp(1.0, 9999.0);
      final leftCenterX = (leftOuter.x + leftInner.x) / 2;
      final rightCenterX = (rightOuter.x + rightInner.x) / 2;

      final leftNorm = (leftIris.dx - leftCenterX) / leftWidth; // + -> toward inner (nasal)
      final rightNorm = (rightIris.dx - rightCenterX) / rightWidth; // - -> toward inner (nasal)
      _leftVergence.add(leftNorm);
      _rightVergence.add(rightNorm);

      if (_leftVergence.length >= 10) {
        final leftAvg = _avgScalar(_leftVergence);
        final rightAvg = _avgScalar(_rightVergence);
        _leftVergence.clear();
        _rightVergence.clear();

        // Convergence when both eyes move nasally beyond a small threshold.
        if (leftAvg > 0.05) {
          _leftConvergedByPattern[_currentPattern] = true;
        }
        if (rightAvg < -0.05) {
          _rightConvergedByPattern[_currentPattern] = true;
        }
      }

      notifyListeners();
    } catch (_) {
      // Keep running even if tracking fails for a frame.
    } finally {
      _trackBusy = false;
    }
  }

  Offset _avg(List<FaceMeshPoint> points, List<int> indices) {
    var x = 0.0;
    var y = 0.0;
    for (final idx in indices) {
      final p = points[idx];
      x += p.x;
      y += p.y;
    }
    return Offset(x / indices.length, y / indices.length);
  }

  double _avgScalar(List<double> values) {
    if (values.isEmpty) return 0.0;
    var sum = 0.0;
    for (final v in values) {
      sum += v;
    }
    return sum / values.length;
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
    _state = LangState.running;
    _result = null;
    _currentPattern = 0;
    _pattern1 = false;
    _pattern2 = false;
    _pattern3 = false;
    _leftConvergedByPattern.setAll(0, <bool>[false, false, false]);
    _rightConvergedByPattern.setAll(0, <bool>[false, false, false]);
    notifyListeners();

    for (var i = 0; i < 3; i++) {
      _currentPattern = i;
      _statusMessage = _instructions[i];
      _inPatternWindow = true;
      notifyListeners();

      await Future<void>.delayed(const Duration(seconds: 4));

      final response = await _listenOnce(timeout: const Duration(seconds: 6));
      final detected = _parseResponse(response, _patternNames[i]);

      switch (i) {
        case 0:
          _pattern1 = detected;
          break;
        case 1:
          _pattern2 = detected;
          break;
        case 2:
          _pattern3 = detected;
          break;
      }

      _inPatternWindow = false;
      await Future<void>.delayed(const Duration(milliseconds: 650));
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

  bool _parseResponse(String voice, String target) {
    final v = voice.toLowerCase();
    if (v.contains('nothing') || v.contains('none') || v.contains("don't")) {
      return false;
    }

    if (target == 'star') {
      return v.contains('star') || v.contains('yes') || v.contains('see');
    }
    if (target == 'car') {
      return v.contains('car') || v.contains('vehicle') || v.contains('auto') || v.contains('yes');
    }
    if (target == 'cat') {
      return v.contains('cat') || v.contains('face') || v.contains('yes');
    }
    return false;
  }

  Future<void> _completeTest() async {
    final detected = <bool>[_pattern1, _pattern2, _pattern3].where((p) => p).length;
    final level = detected >= 2 ? 'Present' : (detected == 1 ? 'Partial' : 'Absent');

    final leftConv = _leftConvergedByPattern.where((v) => v).length >= 2;
    final rightConv = _rightConvergedByPattern.where((v) => v).length >= 2;

    final note = _buildNote(detected);
    final score = detected / 3.0;

    _result = LangResult(
      pattern1Passed: _pattern1,
      pattern2Passed: _pattern2,
      pattern3Passed: _pattern3,
      patternsDetected: detected,
      stereopsisLevel: level,
      leftEyeConverged: leftConv,
      rightEyeConverged: rightConv,
      isNormal: detected >= 2,
      requiresReferral: detected < 2,
      clinicalNote: note,
      normalityScore: score,
    );

    _state = LangState.completed;
    _statusMessage = 'Lang test complete ✓';

    await _saveResult(_result!);
    notifyListeners();
  }

  String _buildNote(int detected) {
    if (detected == 3) {
      return 'All 3 Lang patterns identified. Normal stereopsis present.';
    }
    if (detected == 2) {
      return '2 of 3 patterns identified. Stereopsis present. Minor follow-up suggested.';
    }
    if (detected == 1) {
      return 'Only 1 pattern identified. Reduced stereopsis. Referral recommended.';
    }
    return 'No patterns identified. Absent stereopsis. Consistent with suppression or amblyopia. Referral required.';
  }

  Future<void> _saveResult(LangResult result) async {
    final flow = TestFlowController();
    flow.onTestComplete('lang_stereo', result);

    await _database.saveTestResult(
      TestResult(
        id: _uuid.v4(),
        sessionId: TestFlowController.currentSessionId ?? '',
        testName: 'lang_stereo',
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
    await _meshDetector.close();
  }

  @override
  void dispose() {
    unawaited(shutdown());
    super.dispose();
  }
}

