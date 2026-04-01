import 'dart:math' as math;

import '../../features/eye_tests/test_flow_controller.dart';
import 'distance_calibration_service.dart';

/// Real-time distance (cm) from camera using face bounding box width.
/// Uses calibration (A4 paper at arm's length) when available; otherwise FOV formula.
class DistanceCalculator {
  DistanceCalculator({
    this.horizontalFovDeg = 60.0,
  });

  /// Horizontal field of view in degrees. Used only when device is not calibrated.
  final double horizontalFovDeg;

  /// Face width in cm by age (child adjustment).
  /// Age 3-4: 11cm, 5-7: 12cm, 8+: 14cm.
  static double faceWidthCmForAge(int age) {
    if (age <= 4) return 11.0;
    if (age <= 7) return 12.0;
    return 14.0;
  }

  /// Current patient age from TestFlowController, fallback 8.
  static int get _patientAge => TestFlowController.currentPatientAge ?? 8;

  /// Distance in cm from camera.
  /// When calibration exists: uses (face_width_cm / face_width_px) * (ref_paper_px / 21) * ref_distance_cm.
  /// Otherwise: FOV-based formula.
  double distanceCm({
    required double faceBoxWidthPx,
    required double imageWidthPx,
    int? age,
  }) {
    if (faceBoxWidthPx <= 0 || imageWidthPx <= 0) return 0.0;
    final faceWidthCm = age != null ? faceWidthCmForAge(age) : faceWidthCmForAge(_patientAge);

    final cal = DistanceCalibrationService.instance;
    if (cal.hasCalibration && cal.refPaperWidthPx != null) {
      final refPx = cal.refPaperWidthPx!;
      final d = (faceWidthCm / faceBoxWidthPx) *
          (refPx / DistanceCalibrationService.refPaperWidthCm) *
          cal.refDistanceCm;
      return d.clamp(10.0, 120.0);
    }

    final fovRad = horizontalFovDeg * math.pi / 180.0;
    final tanHalfFov = math.tan(fovRad / 2.0);
    final d = (faceWidthCm * imageWidthPx) / (faceBoxWidthPx * 2.0 * tanHalfFov);
    return d.clamp(10.0, 120.0);
  }
}

/// Optimal distance range (cm) per test.
class DistanceZone {
  const DistanceZone({
    required this.minCm,
    required this.maxCm,
    required this.label,
  });

  final double minCm;
  final double maxCm;
  final String label;

  bool contains(double distanceCm) =>
      distanceCm >= minCm && distanceCm <= maxCm;

  /// Eye Scan (Jarvis): 30-50cm
  static const eyeScan = DistanceZone(minCm: 30, maxCm: 50, label: 'Eye Scan');

  /// Snellen: 35-45cm (40cm standard)
  static const snellen = DistanceZone(minCm: 35, maxCm: 45, label: 'Snellen');

  /// Red Reflex: 25-40cm
  static const redReflex = DistanceZone(minCm: 25, maxCm: 40, label: 'Red Reflex');

  /// Suppression: 35-50cm
  static const suppression = DistanceZone(minCm: 35, maxCm: 50, label: 'Suppression');

  /// Titmus / Lang: 40-60cm
  static const titmusLang = DistanceZone(minCm: 40, maxCm: 60, label: 'Stereo');
}

/// Status for UI: too close, good, or too far.
enum DistanceStatus {
  tooClose,
  good,
  tooFar,
  noFace,
}

DistanceStatus distanceStatus(double distanceCm, DistanceZone zone) {
  if (distanceCm <= 0) return DistanceStatus.noFace;
  if (distanceCm < zone.minCm) return DistanceStatus.tooClose;
  if (distanceCm > zone.maxCm) return DistanceStatus.tooFar;
  return DistanceStatus.good;
}
