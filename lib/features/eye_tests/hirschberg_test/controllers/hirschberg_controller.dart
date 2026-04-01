import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

import '../../../image_processing/clahe_processor.dart';
import '../../../offline/database_tables.dart';
import '../../../offline/local_database.dart';
import '../models/hirschberg_result.dart';

class HirschbergController extends ChangeNotifier {
  HirschbergController({
    required this.sessionId,
    LocalDatabase? database,
  }) : _database = database ?? LocalDatabase.instance;

  final String sessionId;
  final LocalDatabase _database;
  final Uuid _uuid = const Uuid();
  final ClaheProcessor _clahe = ClaheProcessor();

  CameraController? _camera;
  HirschbergState _state = HirschbergState.notStarted;
  HirschbergResult? _result;
  String _statusMessage = '';
  String? _capturedPath;

  static const double pixelsPerMM = 38.5;

  CameraController? get camera => _camera;
  HirschbergState get state => _state;
  HirschbergResult? get result => _result;
  String get statusMessage => _statusMessage;
  String? get capturedPath => _capturedPath;

  Future<void> initialize() async {
    final permission = await Permission.camera.request();
    if (!permission.isGranted) {
      _state = HirschbergState.error;
      _statusMessage = 'Camera permission denied';
      notifyListeners();
      return;
    }

    final cameras = await availableCameras();
    final front = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );
    _camera = CameraController(
      front,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    await _camera!.initialize();
    _state = HirschbergState.ready;
    _statusMessage = 'Flash will activate briefly';
    notifyListeners();
  }

  Future<void> runTest() async {
    if (_camera == null) return;

    _state = HirschbergState.running;
    _statusMessage = 'Look directly at the camera...';
    notifyListeners();
    await Future<void>.delayed(const Duration(seconds: 2));

    _statusMessage = 'Activating light...';
    notifyListeners();

    bool torchSuccess = false;
    try {
      await _camera!.setFlashMode(FlashMode.torch);
      torchSuccess = true;
      await Future<void>.delayed(const Duration(milliseconds: 500));
    } catch (e) {
      debugPrint('Torch mode failed: $e — trying flash mode');
    }

    XFile imageFile;
    if (torchSuccess) {
      try {
        imageFile = await _camera!.takePicture();
      } catch (e) {
        debugPrint('Capture failed: $e');
        _state = HirschbergState.inconclusive;
        notifyListeners();
        return;
      }
      try {
        await _camera!.setFlashMode(FlashMode.off);
      } catch (_) {}
    } else {
      try {
        await _camera!.setFlashMode(FlashMode.always);
        imageFile = await _camera!.takePicture();
        await _camera!.setFlashMode(FlashMode.off);
      } catch (e) {
        debugPrint('Flash capture failed: $e');
        try {
          imageFile = await _camera!.takePicture();
        } catch (e2) {
          _state = HirschbergState.error;
          _statusMessage = 'Camera error. Please retry.';
          notifyListeners();
          return;
        }
      }
    }

    _capturedPath = imageFile.path;
    _statusMessage = 'Analyzing...';
    notifyListeners();

    final result = await _processHirschbergImage(imageFile.path);

    try {
      await File(imageFile.path).delete();
    } catch (_) {}

    _result = result;
    _state = result.strabismusType == 'Inconclusive'
        ? HirschbergState.inconclusive
        : HirschbergState.completed;
    await _saveResult(result);
    _statusMessage = result.requiresUrgentReferral
        ? 'Significant finding detected'
        : 'Hirschberg test complete';
    notifyListeners();
  }

  Future<HirschbergResult> _processHirschbergImage(String imagePath) async {
    final imageBytes = await File(imagePath).readAsBytes();
    final faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableLandmarks: true,
        performanceMode: FaceDetectorMode.accurate,
      ),
    );

    final inputImage = InputImage.fromFilePath(imagePath);
    final faces = await faceDetector.processImage(inputImage);
    await faceDetector.close();

    if (faces.isEmpty) {
      return _fallbackResult();
    }

    final face = faces.first;
    final leftEye = face.landmarks[FaceLandmarkType.leftEye];
    final rightEye = face.landmarks[FaceLandmarkType.rightEye];
    if (leftEye == null || rightEye == null) {
      return _fallbackResult();
    }

    final leftPupil =
        Offset(leftEye.position.x.toDouble(), leftEye.position.y.toDouble());
    final rightPupil =
        Offset(rightEye.position.x.toDouble(), rightEye.position.y.toDouble());

    final leftReflex = await _findCornealReflex(imageBytes, leftPupil, 30);
    final rightReflex = await _findCornealReflex(imageBytes, rightPupil, 30);

    final leftDisp = leftReflex - leftPupil;
    final rightDisp = rightReflex - rightPupil;
    final leftDispMM = leftDisp.distance / pixelsPerMM;
    final rightDispMM = rightDisp.distance / pixelsPerMM;
    final leftDeg = leftDispMM * 7;
    final rightDeg = rightDispMM * 7;
    final leftPrism = 100 * math.tan(leftDeg * math.pi / 180);
    final rightPrism = 100 * math.tan(rightDeg * math.pi / 180);
    final combined = Offset(
      (leftDisp.dx + rightDisp.dx) / 2,
      (leftDisp.dy + rightDisp.dy) / 2,
    );
    final maxMm = math.max(leftDispMM, rightDispMM);

    return HirschbergResult(
      leftPupilCenter: leftPupil,
      rightPupilCenter: rightPupil,
      leftReflexPosition: leftReflex,
      rightReflexPosition: rightReflex,
      leftDisplacementPixels: leftDisp.distance,
      rightDisplacementPixels: rightDisp.distance,
      leftDisplacementMM: leftDispMM,
      rightDisplacementMM: rightDispMM,
      leftDeviationDegrees: leftDeg,
      rightDeviationDegrees: rightDeg,
      leftPrismDiopters: leftPrism,
      rightPrismDiopters: rightPrism,
      strabismusType: HirschbergResult.classifyStrabismus(combined),
      severity: HirschbergResult.classifySeverity(maxMm),
      isAbnormal: leftDispMM > 1.0 || rightDispMM > 1.0,
      requiresUrgentReferral: leftDispMM > 4.0 || rightDispMM > 4.0,
    );
  }

  Future<Offset> _findCornealReflex(
    Uint8List imageBytes,
    Offset pupilCenter,
    int searchRadius,
  ) async {
    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) {
      return pupilCenter;
    }

    final coords = <Offset>[];
    final greenValues = <int>[];
    var brightest = pupilCenter;
    final startX =
        (pupilCenter.dx - searchRadius).clamp(0, decoded.width - 1).toInt();
    final endX =
        (pupilCenter.dx + searchRadius).clamp(0, decoded.width - 1).toInt();
    final startY =
        (pupilCenter.dy - searchRadius).clamp(0, decoded.height - 1).toInt();
    final endY =
        (pupilCenter.dy + searchRadius).clamp(0, decoded.height - 1).toInt();

    for (var x = startX; x <= endX; x++) {
      for (var y = startY; y <= endY; y++) {
        final pixel = decoded.getPixel(x, y);
        coords.add(Offset(x.toDouble(), y.toDouble()));
        greenValues.add(pixel.g.clamp(0, 255).toInt());
      }
    }

    final enhanced = _clahe.apply(greenValues);
    var maxBrightness = -1.0;
    for (var i = 0; i < coords.length; i++) {
      final brightness = enhanced[i].toDouble();
      final distancePenalty = (coords[i] - pupilCenter).distance * 0.35;
      final score = brightness - distancePenalty;
      if (score > maxBrightness) {
        maxBrightness = score;
        brightest = coords[i];
      }
    }
    return brightest;
  }

  HirschbergResult _fallbackResult() {
    return const HirschbergResult(
      leftPupilCenter: Offset.zero,
      rightPupilCenter: Offset.zero,
      leftReflexPosition: Offset.zero,
      rightReflexPosition: Offset.zero,
      leftDisplacementPixels: 0,
      rightDisplacementPixels: 0,
      leftDisplacementMM: 0,
      rightDisplacementMM: 0,
      leftDeviationDegrees: 0,
      rightDeviationDegrees: 0,
      leftPrismDiopters: 0,
      rightPrismDiopters: 0,
      strabismusType: 'Inconclusive',
      severity: 'Inconclusive',
      isAbnormal: false,
      requiresUrgentReferral: false,
    );
  }

  Future<void> _saveResult(HirschbergResult result) async {
    await _database.saveTestResult(
      TestResult(
        id: _uuid.v4(),
        sessionId: sessionId,
        testName: 'hirschberg',
        rawScore:
            math.max(result.leftDisplacementMM, result.rightDisplacementMM),
        normalizedScore: _normalizeDisplacement(
            result.leftDisplacementMM, result.rightDisplacementMM),
        details: <String, dynamic>{
          ...result.toJson(),
          'capturedPath': _capturedPath,
        },
        createdAt: DateTime.now(),
      ),
    );
  }

  double _normalizeDisplacement(double left, double right) {
    final maxValue = math.max(left, right);
    return (1 - (maxValue / 6)).clamp(0.0, 1.0);
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

enum HirschbergState {
  notStarted,
  ready,
  running,
  completed,
  error,
  inconclusive,
}
