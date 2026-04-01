import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:google_mlkit_face_mesh_detection/google_mlkit_face_mesh_detection.dart';

class IrisTrackingService {
  IrisTrackingService()
      : _detector = FaceMeshDetector(option: FaceMeshDetectorOptions.faceMesh);

  final FaceMeshDetector _detector;
  bool _isRunning = false;

  static const List<int> leftIrisIdx = <int>[33, 133, 159, 145, 153];
  static const List<int> rightIrisIdx = <int>[362, 263, 386, 374, 380];

  Future<IrisData?> processFrame(CameraImage image) async {
    if (_isRunning) {
      return null;
    }
    _isRunning = true;

    try {
      final imageSize = Size(
        image.width.toDouble(),
        image.height.toDouble(),
      );
      final inputImage = _convertCameraImage(image);
      final meshes = await _detector.processImage(inputImage);
      if (meshes.isEmpty) {
        return null;
      }

      final mesh = meshes.first;
      final leftIris = _getIrisCenter(mesh, leftIrisIdx, imageSize);
      final rightIris = _getIrisCenter(mesh, rightIrisIdx, imageSize);
      final gazeData = _calculateGaze(leftIris, rightIris, mesh, imageSize);
      final (faceW, faceH) = _faceBoundingBox(mesh.points);

      return IrisData(
        leftIrisCenter: leftIris,
        rightIrisCenter: rightIris,
        leftGazeVector: gazeData.left,
        rightGazeVector: gazeData.right,
        gazeDeviation: gazeData.deviation,
        timestamp: DateTime.now(),
        faceBoxWidthPx: faceW,
        imageWidthPx: imageSize.width,
      );
    } catch (e) {
      return null;
    } finally {
      _isRunning = false;
    }
  }

  /// Returns iris center in normalized coordinates (0.0–1.0) for overlay scaling.
  Offset _getIrisCenter(FaceMesh mesh, List<int> indices, Size imageSize) {
    final points = mesh.points;
    var x = 0.0;
    var y = 0.0;
    for (final idx in indices) {
      if (idx < points.length) {
        x += points[idx].x;
        y += points[idx].y;
      }
    }
    final count = indices.length.toDouble();
    return Offset(
      (x / count) / imageSize.width,
      (y / count) / imageSize.height,
    );
  }

  GazeVectors _calculateGaze(
    Offset left,
    Offset right,
    FaceMesh mesh,
    Size imageSize,
  ) {
    final points = mesh.points;
    final leftOuter = points[33];
    final leftInner = points[133];
    final rightOuter = points[362];
    final rightInner = points[263];

    final leftEyeCenter = Offset(
      ((leftOuter.x + leftInner.x) / 2) / imageSize.width,
      ((leftOuter.y + leftInner.y) / 2) / imageSize.height,
    );
    final rightEyeCenter = Offset(
      ((rightOuter.x + rightInner.x) / 2) / imageSize.width,
      ((rightOuter.y + rightInner.y) / 2) / imageSize.height,
    );

    final leftEyeWidth =
        (leftInner.x - leftOuter.x).abs().clamp(1.0, 9999.0) / imageSize.width;
    final rightEyeWidth =
        (rightInner.x - rightOuter.x).abs().clamp(1.0, 9999.0) / imageSize.width;

    final leftGaze = Offset(
      (left.dx - leftEyeCenter.dx) / leftEyeWidth,
      (left.dy - leftEyeCenter.dy) / leftEyeWidth,
    );
    final rightGaze = Offset(
      (right.dx - rightEyeCenter.dx) / rightEyeWidth,
      (right.dy - rightEyeCenter.dy) / rightEyeWidth,
    );

    final deviation = _calculateDeviation(leftGaze, rightGaze);
    return GazeVectors(left: leftGaze, right: rightGaze, deviation: deviation);
  }

  (double, double) _faceBoundingBox(Iterable<dynamic> points) {
    if (points.isEmpty) return (0.0, 0.0);
    final first = points.first;
    var minX = (first.x as num).toDouble();
    var maxX = minX;
    var minY = (first.y as num).toDouble();
    var maxY = minY;
    for (final p in points) {
      final x = (p.x as num).toDouble();
      final y = (p.y as num).toDouble();
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }
    return (maxX - minX, maxY - minY);
  }

  double _calculateDeviation(Offset left, Offset right) {
    final dot = left.dx * right.dx + left.dy * right.dy;
    final magL = math.sqrt(left.dx * left.dx + left.dy * left.dy).clamp(0.001, 999.0);
    final magR = math.sqrt(right.dx * right.dx + right.dy * right.dy).clamp(0.001, 999.0);
    final cosTheta = (dot / (magL * magR)).clamp(-1.0, 1.0);
    final theta = math.acos(cosTheta);
    return 100 * math.tan(theta);
  }

  InputImage _convertCameraImage(CameraImage image) {
    final allBytes = BytesBuilder(copy: false);
    for (final plane in image.planes) {
      allBytes.add(plane.bytes);
    }
    final bytes = allBytes.toBytes();

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

  Future<void> dispose() async {
    await _detector.close();
  }
}

class IrisData {
  /// Normalized (0.0–1.0) iris centers for overlay. Multiply by screen size for pixel position.
  final Offset leftIrisCenter;
  final Offset rightIrisCenter;
  final Offset leftGazeVector;
  final Offset rightGazeVector;
  final double gazeDeviation;
  final DateTime timestamp;
  /// Face mesh bounding box width in image pixels (for distance calculation).
  final double? faceBoxWidthPx;
  final double? imageWidthPx;

  const IrisData({
    required this.leftIrisCenter,
    required this.rightIrisCenter,
    required this.leftGazeVector,
    required this.rightGazeVector,
    required this.gazeDeviation,
    required this.timestamp,
    this.faceBoxWidthPx,
    this.imageWidthPx,
  });
}

/// Convert normalized iris offset to screen coordinates.
Offset irisToScreen(Offset normalizedIris, Size screenSize) {
  return Offset(
    normalizedIris.dx * screenSize.width,
    normalizedIris.dy * screenSize.height,
  );
}

class GazeVectors {
  final Offset left;
  final Offset right;
  final double deviation;

  const GazeVectors({
    required this.left,
    required this.right,
    required this.deviation,
  });
}
