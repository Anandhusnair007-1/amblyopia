class RedGreenResultModel {
  final double leftPupilDiameter;
  final double rightPupilDiameter;
  final double asymmetryRatio;
  final bool suppressionFlag;
  final String dominantEye;
  final int binocularScore;
  final double constrictionSpeedLeft;
  final double constrictionSpeedRight;
  final double confidenceScore;

  const RedGreenResultModel({
    required this.leftPupilDiameter,
    required this.rightPupilDiameter,
    required this.asymmetryRatio,
    required this.suppressionFlag,
    required this.dominantEye,
    required this.binocularScore,
    required this.constrictionSpeedLeft,
    required this.constrictionSpeedRight,
    required this.confidenceScore,
  });

  Map<String, dynamic> toJson() => {
        'left_pupil_diameter': leftPupilDiameter,
        'right_pupil_diameter': rightPupilDiameter,
        'asymmetry_ratio': asymmetryRatio,
        'suppression_flag': suppressionFlag,
        'dominant_eye': dominantEye,
        'binocular_score': binocularScore,
        'constriction_speed_left': constrictionSpeedLeft,
        'constriction_speed_right': constrictionSpeedRight,
        'confidence_score': confidenceScore,
      };

  factory RedGreenResultModel.fromJson(Map<String, dynamic> json) {
    return RedGreenResultModel(
      leftPupilDiameter: (json['left_pupil_diameter'] as num?)?.toDouble() ?? 4.0,
      rightPupilDiameter: (json['right_pupil_diameter'] as num?)?.toDouble() ?? 4.0,
      asymmetryRatio: (json['asymmetry_ratio'] as num?)?.toDouble() ?? 0.0,
      suppressionFlag: json['suppression_flag'] as bool? ?? false,
      dominantEye: json['dominant_eye']?.toString() ?? 'right',
      binocularScore: (json['binocular_score'] as int?) ?? 2,
      constrictionSpeedLeft: (json['constriction_speed_left'] as num?)?.toDouble() ?? 0.5,
      constrictionSpeedRight: (json['constriction_speed_right'] as num?)?.toDouble() ?? 0.5,
      confidenceScore: (json['confidence_score'] as num?)?.toDouble() ?? 0.8,
    );
  }
}
