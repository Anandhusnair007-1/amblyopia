import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

import '../../../image_processing/clahe_processor.dart';
import '../../../offline/database_tables.dart';
import '../../../offline/local_database.dart';
import '../../test_flow_controller.dart';
import '../models/red_reflex_result.dart';

class RedReflexController extends ChangeNotifier {
  RedReflexController({
    LocalDatabase? database,
  }) : _database = database ?? LocalDatabase.instance;

  final LocalDatabase _database;
  final Uuid _uuid = const Uuid();
  final ClaheProcessor _clahe = ClaheProcessor();

  CameraController? _camera;
  RedReflexState _state = RedReflexState.notStarted;
  RedReflexResult? _result;
  String _statusMessage = 'Hold phone 25-35cm from face';
  String? _capturedPath;

  CameraController? get camera => _camera;
  RedReflexState get state => _state;
  RedReflexResult? get result => _result;
  String get statusMessage => _statusMessage;
  String? get capturedPath => _capturedPath;

  Future<void> initialize() async {
    final permission = await Permission.camera.request();
    if (!permission.isGranted) {
      _state = RedReflexState.error;
      _statusMessage = 'Camera permission denied';
      notifyListeners();
      return;
    }

    final cameras = await availableCameras();
    final rear = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    _camera = CameraController(
      rear,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    await _camera!.initialize();
    _state = RedReflexState.ready;
    notifyListeners();
  }

  Future<void> runTest() async {
    if (_camera == null) {
      return;
    }

    _state = RedReflexState.running;
    _statusMessage = 'Screen will turn white briefly';
    notifyListeners();

    for (var i = 3; i > 0; i--) {
      _statusMessage = 'Capturing in $i...';
      notifyListeners();
      await Future<void>.delayed(const Duration(seconds: 1));
    }

    _statusMessage = 'Keep child\'s eyes open and looking at the bright screen';
    notifyListeners();
    await Future<void>.delayed(const Duration(milliseconds: 250));

    final imageFile = await _camera!.takePicture();
    _capturedPath = imageFile.path;

    _statusMessage = 'Analyzing...';
    notifyListeners();

    final result = await _analyzeRedReflex(imageFile.path);
    _result = result;
    _state = result.overallResult == 'Inconclusive'
        ? RedReflexState.inconclusive
        : RedReflexState.completed;

    if (result.requiresUrgentReferral) {
      _statusMessage = 'Urgent finding detected';
    } else if (result.isNormal) {
      _statusMessage = 'Red reflex test complete';
    } else {
      _statusMessage = 'Abnormal finding - referral recommended';
    }

    await _saveResult(result);
    notifyListeners();
  }

  Future<RedReflexResult> _analyzeRedReflex(String imagePath) async {
    final bytes = await File(imagePath).readAsBytes();
    final image = img.decodeImage(bytes);
    if (image == null) {
      return _inconclusiveResult();
    }

    final detector = FaceDetector(
      options: FaceDetectorOptions(
        enableLandmarks: true,
        performanceMode: FaceDetectorMode.accurate,
      ),
    );

    final inputImage = InputImage.fromFilePath(imagePath);
    final faces = await detector.processImage(inputImage);
    await detector.close();

    if (faces.isEmpty) {
      return _inconclusiveResult();
    }

    final face = faces.first;
    final leftEye = face.landmarks[FaceLandmarkType.leftEye];
    final rightEye = face.landmarks[FaceLandmarkType.rightEye];
    if (leftEye == null || rightEye == null) {
      return _inconclusiveResult();
    }

    final leftHsv = _extractPupilHSV(
      image,
      leftEye.position.x.toInt(),
      leftEye.position.y.toInt(),
      20,
    );
    final rightHsv = _extractPupilHSV(
      image,
      rightEye.position.x.toInt(),
      rightEye.position.y.toInt(),
      20,
    );

    final leftType =
        RedReflexResult.classifyReflex(leftHsv[0], leftHsv[1], leftHsv[2]);
    final rightType =
        RedReflexResult.classifyReflex(rightHsv[0], rightHsv[1], rightHsv[2]);
    final asymmetry = (leftHsv[2] - rightHsv[2]).abs();
    final note =
        RedReflexResult.getClinicalNote(leftType, rightType, asymmetry);
    final isNormal =
        leftType == 'Normal' && rightType == 'Normal' && asymmetry < 0.3;
    final isUrgent = leftType == 'White' || rightType == 'White';

    return RedReflexResult(
      leftReflexHue: leftHsv[0],
      leftReflexSaturation: leftHsv[1],
      leftReflexBrightness: leftHsv[2],
      rightReflexHue: rightHsv[0],
      rightReflexSaturation: rightHsv[1],
      rightReflexBrightness: rightHsv[2],
      brightnessDifference: asymmetry,
      leftReflexType: leftType,
      rightReflexType: rightType,
      overallResult: isNormal ? 'Normal' : (isUrgent ? 'Urgent' : 'Abnormal'),
      isNormal: isNormal,
      requiresUrgentReferral: isUrgent,
      requiresReferral: !isNormal,
      clinicalNote: note,
      normalityScore:
          RedReflexResult.calculateNormalityScore(leftType, rightType),
    );
  }

  List<double> _extractPupilHSV(
    img.Image image,
    int centerX,
    int centerY,
    int radius,
  ) {
    var totalH = 0.0;
    var totalS = 0.0;
    final redValues = <int>[];
    var count = 0;

    final startX = (centerX - radius).clamp(0, image.width - 1);
    final endX = (centerX + radius).clamp(0, image.width - 1);
    final startY = (centerY - radius).clamp(0, image.height - 1);
    final endY = (centerY + radius).clamp(0, image.height - 1);

    for (var x = startX; x <= endX; x++) {
      for (var y = startY; y <= endY; y++) {
        final dx = x - centerX;
        final dy = y - centerY;
        if (dx * dx + dy * dy > radius * radius) {
          continue;
        }

        final pixel = image.getPixel(x, y);
        final hsv =
            _rgbToHsv(pixel.r / 255.0, pixel.g / 255.0, pixel.b / 255.0);
        totalH += hsv[0];
        totalS += hsv[1];
        redValues.add(pixel.r.clamp(0, 255).toInt());
        count++;
      }
    }

    if (count == 0) {
      return <double>[0, 0, 0];
    }

    final enhancedRed = _clahe.apply(redValues, clipLimit: 18);
    final totalV =
        enhancedRed.fold<double>(0.0, (sum, value) => sum + value) / 255.0;
    return <double>[totalH / count, totalS / count, totalV / count];
  }

  List<double> _rgbToHsv(double r, double g, double b) {
    final maxVal = <double>[r, g, b].reduce(math.max);
    final minVal = <double>[r, g, b].reduce(math.min);
    final delta = maxVal - minVal;

    var h = 0.0;
    var s = 0.0;
    final v = maxVal;

    if (delta > 0) {
      s = delta / maxVal;
      if (maxVal == r) {
        h = 60 * (((g - b) / delta) % 6);
      } else if (maxVal == g) {
        h = 60 * (((b - r) / delta) + 2);
      } else {
        h = 60 * (((r - g) / delta) + 4);
      }
      if (h < 0) {
        h += 360;
      }
    }

    return <double>[h, s, v];
  }

  RedReflexResult _inconclusiveResult() {
    return const RedReflexResult(
      leftReflexHue: 0,
      leftReflexSaturation: 0,
      leftReflexBrightness: 0,
      rightReflexHue: 0,
      rightReflexSaturation: 0,
      rightReflexBrightness: 0,
      brightnessDifference: 0,
      leftReflexType: 'Inconclusive',
      rightReflexType: 'Inconclusive',
      overallResult: 'Inconclusive',
      isNormal: false,
      requiresUrgentReferral: false,
      requiresReferral: false,
      clinicalNote:
          'Face not detected clearly. Please repeat test in better lighting.',
      normalityScore: 0.5,
    );
  }

  Future<void> _saveResult(RedReflexResult result) async {
    await _database.saveTestResult(
      TestResult(
        id: _uuid.v4(),
        sessionId: TestFlowController.currentSessionId ?? '',
        testName: 'red_reflex',
        rawScore: result.normalityScore,
        normalizedScore: result.normalityScore,
        details: <String, dynamic>{
          ...result.toJson(),
          'capturedPath': _capturedPath,
          'rawJson': jsonEncode(result.toJson()),
        },
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> shutdown() async {
    await _camera?.dispose();
  }

  @override
  void dispose() {
    unawaited(shutdown());
    super.dispose();
  }
}

enum RedReflexState {
  notStarted,
  ready,
  running,
  completed,
  inconclusive,
  error,
}
