class SnellenLineResult {
  final String snellenFraction;
  final List<String> displayedLetters;
  final List<String> spokenLetters;
  final int correctCount;
  final int totalCount;
  final bool linePassed;

  const SnellenLineResult({
    required this.snellenFraction,
    required this.displayedLetters,
    required this.spokenLetters,
    required this.correctCount,
    required this.totalCount,
    required this.linePassed,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'snellen_fraction': snellenFraction,
        'displayed_letters': displayedLetters,
        'spoken_letters': spokenLetters,
        'correct_count': correctCount,
        'total_count': totalCount,
        'line_passed': linePassed,
      };
}

class SnellenResult {
  final List<SnellenLineResult> lines;
  final String visualAcuity;
  final String? rightEyeAcuity;
  final String? leftEyeAcuity;
  final String bothEyesAcuity;
  final double acuityScore;
  final bool isNormal;
  final bool requiresReferral;
  final String clinicalNote;
  final double normalityScore;

  const SnellenResult({
    required this.lines,
    required this.visualAcuity,
    required this.bothEyesAcuity,
    required this.acuityScore,
    required this.isNormal,
    required this.requiresReferral,
    required this.clinicalNote,
    required this.normalityScore,
    this.rightEyeAcuity,
    this.leftEyeAcuity,
  });

  static double acuityToScore(String acuity) {
    final parts = acuity.split('/');
    final denominator = int.tryParse(parts.isNotEmpty ? parts.last : '') ?? 60;
    switch (denominator) {
      case 6:
        return 1.0;
      case 9:
        return 0.9;
      case 12:
        return 0.7;
      case 18:
        return 0.5;
      case 24:
        return 0.3;
      case 36:
        return 0.15;
      case 60:
      default:
        return 0.0;
    }
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'visual_acuity': visualAcuity,
        'both_eyes': bothEyesAcuity,
        'acuity_score': acuityScore,
        'is_normal': isNormal,
        'requires_referral': requiresReferral,
        'normality_score': normalityScore,
        'clinical_note': clinicalNote,
        'lines': lines.map((l) => l.toJson()).toList(growable: false),
      };
}

