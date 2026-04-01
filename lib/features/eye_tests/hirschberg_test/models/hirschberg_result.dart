import 'dart:ui';

class HirschbergResult {
  final Offset leftPupilCenter;
  final Offset rightPupilCenter;
  final Offset leftReflexPosition;
  final Offset rightReflexPosition;
  final double leftDisplacementPixels;
  final double rightDisplacementPixels;
  final double leftDisplacementMM;
  final double rightDisplacementMM;
  final double leftDeviationDegrees;
  final double rightDeviationDegrees;
  final double leftPrismDiopters;
  final double rightPrismDiopters;
  final String strabismusType;
  final String severity;
  final bool isAbnormal;
  final bool requiresUrgentReferral;

  const HirschbergResult({
    required this.leftPupilCenter,
    required this.rightPupilCenter,
    required this.leftReflexPosition,
    required this.rightReflexPosition,
    required this.leftDisplacementPixels,
    required this.rightDisplacementPixels,
    required this.leftDisplacementMM,
    required this.rightDisplacementMM,
    required this.leftDeviationDegrees,
    required this.rightDeviationDegrees,
    required this.leftPrismDiopters,
    required this.rightPrismDiopters,
    required this.strabismusType,
    required this.severity,
    required this.isAbnormal,
    required this.requiresUrgentReferral,
  });

  static String classifyStrabismus(Offset displacement) {
    final dx = displacement.dx;
    final dy = displacement.dy;
    final mag = displacement.distance;

    if (mag < 0.5) {
      return 'Normal';
    }

    if (dx.abs() > dy.abs()) {
      return dx > 0 ? 'Esotropia' : 'Exotropia';
    }
    return dy < 0 ? 'Hypertropia' : 'Hypotropia';
  }

  static String classifySeverity(double mm) {
    if (mm < 1.0) {
      return 'Normal';
    }
    if (mm < 2.0) {
      return 'Mild';
    }
    if (mm < 4.0) {
      return 'Moderate';
    }
    return 'Severe';
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'left_displacement_mm': leftDisplacementMM,
        'right_displacement_mm': rightDisplacementMM,
        'left_prism_diopters': leftPrismDiopters,
        'right_prism_diopters': rightPrismDiopters,
        'strabismus_type': strabismusType,
        'severity': severity,
        'is_abnormal': isAbnormal,
      };
}
