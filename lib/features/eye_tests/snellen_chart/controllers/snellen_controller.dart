import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/services/distance_calculator.dart';
import '../../../offline/database_tables.dart';
import '../../../offline/local_database.dart';
import '../../../offline/vosk_service.dart';
import '../../age_profile.dart';
import '../../test_flow_controller.dart';
import '../models/snellen_result.dart';
import '../widgets/tumbling_e_widget.dart';

class SnellenLine {
  final String fraction;
  final List<String> letters;
  final bool isTumbling;

  const SnellenLine(this.fraction, this.letters, {this.isTumbling = false});
}

enum SnellenState {
  notStarted,
  ready,
  running,
  completed,
  error,
}

class SnellenController extends ChangeNotifier {
  SnellenController({
    LocalDatabase? database,
  }) : _database = database ?? LocalDatabase.instance;

  final LocalDatabase _database;
  final Uuid _uuid = const Uuid();

  SnellenState _state = SnellenState.notStarted;
  SnellenResult? _result;
  String _statusMessage = '';
  bool _isListening = false;

  int _currentLineIndex = 0;
  int _currentLetterIndex = 0;
  String _currentLetter = '';

  List<SnellenLine> _activeLines = lines;
  bool _isTumblingMode = false;
  TumblingEDirection? _currentTumblingDirection;
  final List<String> _expectedTumblingDirections = <String>[];

  final List<SnellenLineResult> _lineResults = <SnellenLineResult>[];

  // Front camera + face sizing heuristic for distance reminder.
  CameraController? _camera;
  bool _trackBusy = false;
  double _faceWidthRatio = 0.0;
  double _distanceCm = 0.0;

  final DistanceCalculator _distanceCalc = DistanceCalculator(horizontalFovDeg: 60.0);

  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.fast,
      enableLandmarks: false,
      enableTracking: false,
      enableClassification: false,
    ),
  );

  static const List<SnellenLine> lines = <SnellenLine>[
    SnellenLine('6/60', <String>['E']),
    SnellenLine('6/36', <String>['F', 'P']),
    SnellenLine('6/24', <String>['T', 'O', 'Z']),
    SnellenLine('6/18', <String>['L', 'P', 'E', 'D']),
    SnellenLine('6/12', <String>['P', 'E', 'C', 'F', 'D']),
    SnellenLine('6/9', <String>['E', 'D', 'F', 'C', 'Z', 'P']),
    SnellenLine('6/6', <String>['F', 'E', 'L', 'O', 'P', 'Z', 'D']),
  ];

  /// Tumbling E lines for Profile B (Age 5-7). One E per line, random direction per presentation.
  static const List<SnellenLine> tumblingELines = <SnellenLine>[
    SnellenLine('6/60', <String>['E'], isTumbling: true),
    SnellenLine('6/36', <String>['E', 'E'], isTumbling: true),
    SnellenLine('6/24', <String>['E', 'E', 'E'], isTumbling: true),
    SnellenLine('6/18', <String>['E', 'E', 'E', 'E'], isTumbling: true),
    SnellenLine('6/12', <String>['E', 'E', 'E', 'E', 'E'], isTumbling: true),
    SnellenLine('6/9', <String>['E', 'E', 'E', 'E', 'E', 'E'], isTumbling: true),
  ];

  SnellenState get state => _state;
  SnellenResult? get result => _result;
  String get statusMessage => _statusMessage;
  bool get isListening => _isListening;
  int get currentLineIndex => _currentLineIndex;
  int get currentLetterIndex => _currentLetterIndex;
  String get currentLetter => _currentLetter;
  SnellenLine? get currentLine => _currentLineIndex < _activeLines.length ? _activeLines[_currentLineIndex] : null;
  bool get isTumblingMode => _isTumblingMode;
  TumblingEDirection? get currentTumblingDirection => _currentTumblingDirection;
  List<SnellenLine> get activeLines => List<SnellenLine>.unmodifiable(_activeLines);
  List<SnellenLineResult> get lineResults => List<SnellenLineResult>.unmodifiable(_lineResults);
  double get faceWidthRatio => _faceWidthRatio;
  /// Real-time distance in cm (0 = no face). Used for distance indicator and gate.
  double get distanceCm => _distanceCm;

  Future<void> initialize() async {
    final permission = await Permission.camera.request();
    if (!permission.isGranted) {
      _state = SnellenState.error;
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

      _state = SnellenState.ready;
      _statusMessage = 'Sit about 40cm from screen. Read each letter aloud.';
    } catch (e) {
      _state = SnellenState.error;
      _statusMessage = 'Failed to initialize: $e';
    }
    notifyListeners();
  }

  Future<void> _trackFace(CameraImage image) async {
    if (_trackBusy) return;
    if (_state != SnellenState.running && _state != SnellenState.ready) return;
    _trackBusy = true;
    try {
      final faces = await _faceDetector.processImage(_convertImage(image));
      if (faces.isEmpty) {
        _faceWidthRatio = 0.0;
        _distanceCm = 0.0;
        notifyListeners();
        return;
      }
      final bounds = faces.first.boundingBox;
      final w = image.width.toDouble();
      _faceWidthRatio = (bounds.width / w).clamp(0.0, 1.0);
      _distanceCm = _distanceCalc.distanceCm(
        faceBoxWidthPx: bounds.width.toDouble(),
        imageWidthPx: w,
      );
      notifyListeners();
    } catch (_) {
      // ignore
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

  // Approximate PPI (Android baseline = 160 dpi) * devicePixelRatio.
  double letterHeightPxForLine({
    required double devicePixelRatio,
    required int denominator,
    int viewingDistanceMm = 400,
  }) {
    final ppi = devicePixelRatio * 160.0;
    return (denominator / 6.0) * (6000.0 / viewingDistanceMm) * (ppi / 25.4);
  }

  String distanceHint() {
    // Heuristic thresholds:
    // too far if face occupies small width; too close if large width.
    final r = _faceWidthRatio;
    if (r == 0.0) return '';
    if (r < 0.22) return 'Please move closer (target ~40cm)';
    if (r > 0.44) return 'Please move a bit further (target ~40cm)';
    return '';
  }

  Future<void> startTest() async {
    _state = SnellenState.running;
    _result = null;
    _currentLineIndex = 0;
    _currentLetterIndex = 0;
    _currentLetter = '';
    _lineResults.clear();

    final profile = TestFlowController.currentProfile;
    if (profile == AgeProfile.b) {
      _activeLines = List<SnellenLine>.from(tumblingELines);
      _isTumblingMode = true;
    } else if (profile == AgeProfile.a) {
      _activeLines = List<SnellenLine>.from(lines);
      _isTumblingMode = false;
    } else {
      _activeLines = List<SnellenLine>.from(lines);
      _isTumblingMode = false;
    }
    notifyListeners();

    await _runCurrentLine();
  }

  static TumblingEDirection _getRandomDirection() {
    const directions = TumblingEDirection.values;
    return directions[math.Random().nextInt(directions.length)];
  }

  static String _parseTumblingResponse(String voice) {
    final v = voice.toLowerCase();
    if (v.contains('up') || v.contains('top') || v.contains('above')) return 'up';
    if (v.contains('down') || v.contains('bottom') || v.contains('below')) return 'down';
    if (v.contains('left')) return 'left';
    if (v.contains('right')) return 'right';
    return 'unknown';
  }

  Future<void> _runCurrentLine() async {
    if (_currentLineIndex >= _activeLines.length) {
      await _completeTest();
      return;
    }

    final line = _activeLines[_currentLineIndex];
    final spoken = <String>[];
    _expectedTumblingDirections.clear();
    _statusMessage = _isTumblingMode
        ? 'Which way does the E point? Say UP, DOWN, LEFT, or RIGHT.'
        : 'Read the letters you see. Line ${_currentLineIndex + 1} of ${_activeLines.length}.';
    notifyListeners();

    for (var i = 0; i < line.letters.length; i++) {
      _currentLetterIndex = i;
      _currentLetter = line.letters[i];
      if (_isTumblingMode) {
        _currentTumblingDirection = _getRandomDirection();
        _expectedTumblingDirections.add(_currentTumblingDirection!.name.toLowerCase());
        _statusMessage = 'Say UP, DOWN, LEFT, or RIGHT';
      } else {
        _currentTumblingDirection = null;
        _statusMessage = 'Say this letter aloud';
      }
      notifyListeners();

      SystemSound.play(SystemSoundType.click);
      await Future<void>.delayed(const Duration(milliseconds: 550));

      final response = await _listenOnce(timeout: const Duration(seconds: 5));
      if (_isTumblingMode) {
        spoken.add(_parseTumblingResponse(response));
      } else {
        spoken.add(_parseLetterResponse(response));
      }

      await Future<void>.delayed(const Duration(milliseconds: 220));
    }

    var correct = 0;
    if (_isTumblingMode) {
      for (var i = 0; i < line.letters.length; i++) {
        if (i < spoken.length && i < _expectedTumblingDirections.length &&
            spoken[i] == _expectedTumblingDirections[i]) {
          correct++;
        }
      }
    } else {
      for (var i = 0; i < line.letters.length; i++) {
        if (i < spoken.length && spoken[i].toUpperCase() == line.letters[i]) {
          correct++;
        }
      }
    }

    final passed = correct >= (line.letters.length * 0.6).ceil();
    _lineResults.add(
      SnellenLineResult(
        snellenFraction: line.fraction,
        displayedLetters: List<String>.from(line.letters),
        spokenLetters: spoken,
        correctCount: correct,
        totalCount: line.letters.length,
        linePassed: passed,
      ),
    );

    if (!passed) {
      await _completeTest();
      return;
    }

    _currentLineIndex++;
    await _runCurrentLine();
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

  String _parseLetterResponse(String voice) {
    final upper = voice.toUpperCase();
    final phoneticMap = <String, String>{
      'AY': 'A',
      'BEE': 'B',
      'SEE': 'C',
      'CEE': 'C',
      'DEE': 'D',
      'EE': 'E',
      'E': 'E',
      'EFF': 'F',
      'F': 'F',
      'ELL': 'L',
      'L': 'L',
      'OH': 'O',
      'O': 'O',
      'PEE': 'P',
      'P': 'P',
      'TEE': 'T',
      'T': 'T',
      'ZED': 'Z',
      'ZEE': 'Z',
      'Z': 'Z',
    };
    for (final entry in phoneticMap.entries) {
      if (upper.contains(entry.key)) {
        return entry.value;
      }
    }

    final letters = upper.replaceAll(RegExp(r'[^A-Z]'), '');
    return letters.isNotEmpty ? letters[0] : '';
  }

  Future<void> _completeTest() async {
    var best = '6/60';
    for (final line in _lineResults) {
      if (line.linePassed) {
        best = line.snellenFraction;
      }
    }

    final score = SnellenResult.acuityToScore(best);
    final note = _buildNote(best, score);
    _result = SnellenResult(
      lines: List<SnellenLineResult>.unmodifiable(_lineResults),
      visualAcuity: best,
      bothEyesAcuity: best,
      acuityScore: score,
      isNormal: best == '6/6' || best == '6/9',
      requiresReferral: score < 0.5,
      clinicalNote: note,
      normalityScore: score,
    );

    _state = SnellenState.completed;
    _statusMessage = 'Visual acuity test complete ✓';
    await _saveResult(_result!);
    notifyListeners();
  }

  String _buildNote(String acuity, double score) {
    if (score >= 0.9) {
      return 'Normal visual acuity ($acuity). No significant refractive error detected.';
    }
    if (score >= 0.7) {
      return 'Mildly reduced visual acuity ($acuity). Refraction check recommended.';
    }
    if (score >= 0.5) {
      return 'Moderately reduced visual acuity ($acuity). Ophthalmologist referral recommended.';
    }
    return 'Significantly reduced visual acuity ($acuity). Urgent referral recommended.';
  }

  Future<void> _saveResult(SnellenResult result) async {
    final flow = TestFlowController();
    flow.onTestComplete('snellen_chart', result);

    await _database.saveTestResult(
      TestResult(
        id: _uuid.v4(),
        sessionId: TestFlowController.currentSessionId ?? '',
        testName: 'snellen_chart',
        rawScore: result.acuityScore,
        normalizedScore: result.acuityScore,
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
