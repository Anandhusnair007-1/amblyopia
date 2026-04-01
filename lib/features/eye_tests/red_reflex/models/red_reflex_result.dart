class RedReflexResult {
  const RedReflexResult({
    required this.leftReflexHue,
    required this.leftReflexSaturation,
    required this.leftReflexBrightness,
    required this.rightReflexHue,
    required this.rightReflexSaturation,
    required this.rightReflexBrightness,
    required this.brightnessDifference,
    required this.leftReflexType,
    required this.rightReflexType,
    required this.overallResult,
    required this.isNormal,
    required this.requiresUrgentReferral,
    required this.requiresReferral,
    required this.clinicalNote,
    required this.normalityScore,
  });

  final double leftReflexHue;
  final double leftReflexSaturation;
  final double leftReflexBrightness;
  final double rightReflexHue;
  final double rightReflexSaturation;
  final double rightReflexBrightness;
  final double brightnessDifference;
  final String leftReflexType;
  final String rightReflexType;
  final String overallResult;
  final bool isNormal;
  final bool requiresUrgentReferral;
  final bool requiresReferral;
  final String clinicalNote;
  final double normalityScore;

  static String classifyReflex(
    double hue,
    double saturation,
    double brightness,
  ) {
    if (brightness < 0.1) {
      return 'Absent';
    }
    if (brightness > 0.85 && saturation < 0.2) {
      return 'White';
    }
    if (hue >= 0 && hue <= 30 && saturation > 0.4 && brightness > 0.3) {
      return 'Normal';
    }
    if (brightness > 0.1 && brightness < 0.3) {
      return 'Dull';
    }
    return 'Inconclusive';
  }

  static String getClinicalNote(
    String leftType,
    String rightType,
    double asymmetry,
  ) {
    if (leftType == 'White' || rightType == 'White') {
      return 'URGENT: White reflex detected. Immediate referral required. Rule out retinoblastoma.';
    }
    if (leftType == 'Absent' || rightType == 'Absent') {
      return 'Absent red reflex in one eye. Possible cataract or corneal opacity. Ophthalmologist referral recommended.';
    }
    if (asymmetry > 0.3) {
      return 'Significant asymmetry between eyes. Possible refractive difference or media opacity.';
    }
    if (leftType == 'Dull' || rightType == 'Dull') {
      return 'Reduced red reflex brightness. Possible media opacity. Follow-up recommended.';
    }
    return 'Red reflex appears normal in both eyes. No obvious media opacity detected.';
  }

  static double calculateNormalityScore(String left, String right) {
    if (left == 'White' || right == 'White') {
      return 0.0;
    }
    if (left == 'Absent' || right == 'Absent') {
      return 0.1;
    }
    if (left == 'Dull' || right == 'Dull') {
      return 0.5;
    }
    if (left == 'Asymmetric' || right == 'Asymmetric') {
      return 0.6;
    }
    if (left == 'Normal' && right == 'Normal') {
      return 1.0;
    }
    return 0.7;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'left_reflex_hue': leftReflexHue,
        'left_reflex_saturation': leftReflexSaturation,
        'left_reflex_brightness': leftReflexBrightness,
        'right_reflex_hue': rightReflexHue,
        'right_reflex_saturation': rightReflexSaturation,
        'right_reflex_brightness': rightReflexBrightness,
        'left_reflex_type': leftReflexType,
        'right_reflex_type': rightReflexType,
        'brightness_difference': brightnessDifference,
        'overall_result': overallResult,
        'is_normal': isNormal,
        'requires_urgent_referral': requiresUrgentReferral,
        'requires_referral': requiresReferral,
        'normality_score': normalityScore,
        'clinical_note': clinicalNote,
      };
}
