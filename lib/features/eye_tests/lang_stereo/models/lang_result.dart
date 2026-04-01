class LangResult {
  final bool pattern1Passed;
  final bool pattern2Passed;
  final bool pattern3Passed;
  final int patternsDetected;
  final String stereopsisLevel;
  final bool leftEyeConverged;
  final bool rightEyeConverged;
  final bool isNormal;
  final bool requiresReferral;
  final String clinicalNote;
  final double normalityScore;

  const LangResult({
    required this.pattern1Passed,
    required this.pattern2Passed,
    required this.pattern3Passed,
    required this.patternsDetected,
    required this.stereopsisLevel,
    required this.leftEyeConverged,
    required this.rightEyeConverged,
    required this.isNormal,
    required this.requiresReferral,
    required this.clinicalNote,
    required this.normalityScore,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'pattern1_passed': pattern1Passed,
        'pattern2_passed': pattern2Passed,
        'pattern3_passed': pattern3Passed,
        'patterns_detected': patternsDetected,
        'stereopsis_level': stereopsisLevel,
        'left_eye_converged': leftEyeConverged,
        'right_eye_converged': rightEyeConverged,
        'is_normal': isNormal,
        'requires_referral': requiresReferral,
        'normality_score': normalityScore,
        'clinical_note': clinicalNote,
      };
}

