class SuppressionResult {
  const SuppressionResult({
    required this.responses,
    required this.switchCount,
    required this.dominantPattern,
    required this.suppressedEye,
    required this.suppressionScore,
    required this.result,
    required this.isAbnormal,
    required this.requiresReferral,
    required this.clinicalNote,
    required this.normalityScore,
  });

  final List<String> responses;
  final int switchCount;
  final String dominantPattern;
  final String suppressedEye;
  final double suppressionScore;
  final String result;
  final bool isAbnormal;
  final bool requiresReferral;
  final String clinicalNote;
  final double normalityScore;

  static String classifyResult(int switches, int totalReadings) {
    if (totalReadings <= 0) return 'Inconclusive';
    final switchRate = switches / totalReadings;
    if (switchRate >= 0.5) return 'Normal Binocular Vision';
    if (switchRate >= 0.3) return 'Mild Suppression';
    if (switchRate >= 0.15) return 'Moderate Suppression';
    return 'Severe Suppression';
  }

  static double calcScore(int switches, int total) {
    if (total <= 0) return 0.0;
    return (switches / total).clamp(0.0, 1.0);
  }

  static String inferSuppressedEye(
    String dominantPattern,
    int horizontalCount,
    int verticalCount,
  ) {
    if ((horizontalCount - verticalCount).abs() < 2) return 'None';
    if (horizontalCount > verticalCount + 2) return 'Right';
    if (verticalCount > horizontalCount + 2) return 'Left';
    return 'None';
  }

  /// Profile A (age 3-4): worker reports "Both eyes blinked" or "Only one eye blinked".
  factory SuppressionResult.forSimplifiedFlash({required bool bothEyesBlinked}) {
    if (bothEyesBlinked) {
      return const SuppressionResult(
        responses: ['both_eyes_blinked'],
        switchCount: 0,
        dominantPattern: 'N/A',
        suppressedEye: 'None',
        suppressionScore: 1.0,
        result: 'Normal (both eyes blinked)',
        isAbnormal: false,
        requiresReferral: false,
        clinicalNote: 'Simplified flash test: both eyes responded. Normal for age 3-4.',
        normalityScore: 1.0,
      );
    }
    return const SuppressionResult(
      responses: ['one_eye_blinked'],
      switchCount: 0,
      dominantPattern: 'N/A',
      suppressedEye: 'Unknown',
      suppressionScore: 0.3,
      result: 'Possible suppression (one eye only)',
      isAbnormal: true,
      requiresReferral: false,
      clinicalNote: 'Simplified flash test: only one eye blinked. Follow-up recommended.',
      normalityScore: 0.3,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'responses': responses,
        'switch_count': switchCount,
        'dominant_pattern': dominantPattern,
        'suppressed_eye': suppressedEye,
        'suppression_score': suppressionScore,
        'result': result,
        'is_abnormal': isAbnormal,
        'requires_referral': requiresReferral,
        'normality_score': normalityScore,
        'clinical_note': clinicalNote,
      };
}
