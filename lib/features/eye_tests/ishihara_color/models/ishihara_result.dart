class PlateAttempt {
  final int plateIndex;
  final String correctAnswer;
  final String patientAnswer;
  final bool isCorrect;

  const PlateAttempt({
    required this.plateIndex,
    required this.correctAnswer,
    required this.patientAnswer,
    required this.isCorrect,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'plate_index': plateIndex,
        'correct_answer': correctAnswer,
        'patient_answer': patientAnswer,
        'is_correct': isCorrect,
      };
}

class IshiharaResult {
  final List<PlateAttempt> attempts;
  final int correctAnswers;
  final int totalTestPlates;
  final String colorVisionStatus;
  final bool isNormal;
  final bool requiresReferral;
  final String clinicalNote;
  final double normalityScore;
  /// True when test was skipped (e.g. Profile A age 3-4).
  final bool notApplicable;

  const IshiharaResult({
    required this.attempts,
    required this.correctAnswers,
    required this.totalTestPlates,
    required this.colorVisionStatus,
    required this.isNormal,
    required this.requiresReferral,
    required this.clinicalNote,
    required this.normalityScore,
    this.notApplicable = false,
  });

  /// Factory for Profile A skip: mark as not applicable.
  factory IshiharaResult.notApplicableResult() {
    return const IshiharaResult(
      attempts: [],
      correctAnswers: 0,
      totalTestPlates: 0,
      colorVisionStatus: 'Not applicable (age 3-4)',
      isNormal: true,
      requiresReferral: false,
      clinicalNote: 'Color vision test not performed for this age group.',
      normalityScore: 1.0,
      notApplicable: true,
    );
  }

  static String classify(int correct, int total) {
    if (total <= 0) return 'Inconclusive';
    final pct = correct / total;
    if (pct >= 0.85) return 'Normal';
    if (pct >= 0.57) return 'Mild Deficiency';
    if (pct >= 0.28) return 'Moderate Deficiency';
    return 'Severe Red-Green Deficiency';
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'correct_answers': correctAnswers,
        'total_plates': totalTestPlates,
        'color_vision_status': colorVisionStatus,
        'is_normal': isNormal,
        'requires_referral': requiresReferral,
        'normality_score': normalityScore,
        'attempts': attempts.map((a) => a.toJson()).toList(growable: false),
        'clinical_note': clinicalNote,
        'not_applicable': notApplicable,
      };
}

