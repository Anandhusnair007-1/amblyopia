class WorthFourDotResult {
  const WorthFourDotResult({
    required this.bothEyesCount,
    required this.leftEyeCoveredCount,
    required this.rightEyeCoveredCount,
    required this.correctAnswers,
    required this.totalTrials,
    required this.fusionStatus,
    required this.requiresReferral,
    required this.clinicalNote,
    required this.normalityScore,
  });

  final int bothEyesCount;
  final int leftEyeCoveredCount;
  final int rightEyeCoveredCount;
  final int correctAnswers;
  final int totalTrials;
  final String fusionStatus;
  final bool requiresReferral;
  final String clinicalNote;
  final double normalityScore;

  static WorthFourDotResult fromAnswers({
    required int bothEyesCount,
    required int leftEyeCoveredCount,
    required int rightEyeCoveredCount,
  }) {
    const expected = <int>[4, 2, 3];
    final actual = <int>[
      bothEyesCount,
      leftEyeCoveredCount,
      rightEyeCoveredCount
    ];
    var correct = 0;
    for (var i = 0; i < expected.length; i++) {
      if (expected[i] == actual[i]) {
        correct++;
      }
    }

    final status = classifyFusion(
      bothEyesCount: bothEyesCount,
      leftEyeCoveredCount: leftEyeCoveredCount,
      rightEyeCoveredCount: rightEyeCoveredCount,
    );
    final referral = status != 'Normal Fusion';
    return WorthFourDotResult(
      bothEyesCount: bothEyesCount,
      leftEyeCoveredCount: leftEyeCoveredCount,
      rightEyeCoveredCount: rightEyeCoveredCount,
      correctAnswers: correct,
      totalTrials: expected.length,
      fusionStatus: status,
      requiresReferral: referral,
      clinicalNote: clinicalNoteFor(status),
      normalityScore: correct / expected.length,
    );
  }

  static String classifyFusion({
    required int bothEyesCount,
    required int leftEyeCoveredCount,
    required int rightEyeCoveredCount,
  }) {
    if (bothEyesCount == 4 &&
        leftEyeCoveredCount == 2 &&
        rightEyeCoveredCount == 3) {
      return 'Normal Fusion';
    }
    if (bothEyesCount >= 5) {
      return 'Diplopia Suspected';
    }
    if (bothEyesCount == 2 || rightEyeCoveredCount <= 2) {
      return 'Right Eye Suppression';
    }
    if (bothEyesCount == 3 || leftEyeCoveredCount >= 3) {
      return 'Left Eye Suppression';
    }
    return 'Inconclusive';
  }

  static String clinicalNoteFor(String status) {
    switch (status) {
      case 'Normal Fusion':
        return 'Worth 4 Dot response is consistent with binocular fusion.';
      case 'Left Eye Suppression':
        return 'Worth 4 Dot suggests suppression of the left eye. Clinical follow-up is recommended.';
      case 'Right Eye Suppression':
        return 'Worth 4 Dot suggests suppression of the right eye. Clinical follow-up is recommended.';
      case 'Diplopia Suspected':
        return 'Seeing five or more lights may indicate diplopia. Clinical review is recommended.';
      default:
        return 'Worth 4 Dot response was inconsistent. Repeat test if clinically needed.';
    }
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'both_eyes_count': bothEyesCount,
        'left_eye_covered_count': leftEyeCoveredCount,
        'right_eye_covered_count': rightEyeCoveredCount,
        'correct_answers': correctAnswers,
        'total_trials': totalTrials,
        'fusion_status': fusionStatus,
        'requires_referral': requiresReferral,
        'clinical_note': clinicalNote,
        'normality_score': normalityScore,
      };
}
