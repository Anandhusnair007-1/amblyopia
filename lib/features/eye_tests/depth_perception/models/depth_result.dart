class DepthPerceptionResult {
  const DepthPerceptionResult({
    required this.totalTrials,
    required this.correctAnswers,
    required this.accuracyPercent,
    required this.stereoAcuityArcSeconds,
    required this.stereoGrade,
    required this.isNormal,
    required this.requiresReferral,
    required this.trials,
    required this.clinicalNote,
    required this.normalityScore,
  });

  final int totalTrials;
  final int correctAnswers;
  final double accuracyPercent;
  final double stereoAcuityArcSeconds;
  final String stereoGrade;
  final bool isNormal;
  final bool requiresReferral;
  final List<DepthTrialResult> trials;
  final String clinicalNote;
  final double normalityScore;

  static String classifyGrade(int correct, int total) {
    final pct = total == 0 ? 0.0 : correct / total;
    if (pct >= 0.83) {
      return 'Excellent';
    }
    if (pct >= 0.67) {
      return 'Good';
    }
    if (pct >= 0.33) {
      return 'Reduced';
    }
    return 'Absent';
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'correct_answers': correctAnswers,
        'total_trials': totalTrials,
        'accuracy_percent': accuracyPercent,
        'stereo_acuity_arc_seconds': stereoAcuityArcSeconds,
        'stereo_grade': stereoGrade,
        'is_normal': isNormal,
        'requires_referral': requiresReferral,
        'normality_score': normalityScore,
        'trials': trials.map((trial) => trial.toJson()).toList(),
        'clinical_note': clinicalNote,
      };
}

class DepthTrialResult {
  const DepthTrialResult({
    required this.trialNumber,
    required this.disparityPixels,
    required this.correctAnswer,
    required this.patientAnswer,
    required this.isCorrect,
    required this.responseTime,
  });

  final int trialNumber;
  final double disparityPixels;
  final String correctAnswer;
  final String patientAnswer;
  final bool isCorrect;
  final Duration responseTime;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'trial_number': trialNumber,
        'disparity_pixels': disparityPixels,
        'correct_answer': correctAnswer,
        'patient_answer': patientAnswer,
        'is_correct': isCorrect,
        'response_time_ms': responseTime.inMilliseconds,
      };
}
