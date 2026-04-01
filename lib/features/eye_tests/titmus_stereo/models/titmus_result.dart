class TitmusResult {
  final bool flyTestPassed;
  final bool animalTestPassed;
  final int circlesCorrect;
  final int circlesTotal;
  final double stereoAcuityArcSeconds;
  final String stereoGrade;
  final bool isNormal;
  final bool requiresReferral;
  final String clinicalNote;
  final double normalityScore;

  const TitmusResult({
    required this.flyTestPassed,
    required this.animalTestPassed,
    required this.circlesCorrect,
    required this.circlesTotal,
    required this.stereoAcuityArcSeconds,
    required this.stereoGrade,
    required this.isNormal,
    required this.requiresReferral,
    required this.clinicalNote,
    required this.normalityScore,
  });

  static double getArcSeconds(
    bool flyPassed,
    bool animalPassed,
    int circlesCorrect,
  ) {
    if (!flyPassed) {
      return 9999;
    }
    if (!animalPassed) {
      return 3000;
    }

    switch (circlesCorrect) {
      case 0:
        return 800;
      case 1:
        return 800;
      case 2:
        return 400;
      case 3:
        return 200;
      case 4:
        return 140;
      case 5:
        return 100;
      default:
        return 800;
    }
  }

  static String getGrade(double arcSeconds) {
    if (arcSeconds >= 9999) {
      return 'Absent';
    }
    if (arcSeconds >= 3000) {
      return 'Gross Only';
    }
    if (arcSeconds >= 400) {
      return 'Moderate';
    }
    if (arcSeconds >= 200) {
      return 'Fine';
    }
    return 'Excellent';
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'fly_test_passed': flyTestPassed,
        'animal_test_passed': animalTestPassed,
        'circles_correct': circlesCorrect,
        'circles_total': circlesTotal,
        'stereo_acuity_arc_seconds': stereoAcuityArcSeconds,
        'stereo_grade': stereoGrade,
        'is_normal': isNormal,
        'requires_referral': requiresReferral,
        'normality_score': normalityScore,
        'clinical_note': clinicalNote,
      };
}

