class SnellenResultModel {
  final String visualAcuityRight;
  final String visualAcuityLeft;
  final String visualAcuityBoth;
  final List<Map<String, dynamic>> perLetterResults;
  final List<double> responseTimes;
  final double hesitationScore;
  final double gazeComplianceScore;
  final String testMode;
  final double confidenceScore;

  const SnellenResultModel({
    required this.visualAcuityRight,
    required this.visualAcuityLeft,
    required this.visualAcuityBoth,
    required this.perLetterResults,
    required this.responseTimes,
    required this.hesitationScore,
    required this.gazeComplianceScore,
    required this.testMode,
    required this.confidenceScore,
  });

  static double vaToNumeric(String va) {
    const map = {
      '6/60': 0.10, '6/36': 0.17, '6/24': 0.25,
      '6/18': 0.33, '6/12': 0.50, '6/9': 0.67,
      '6/6': 1.00, '6/5': 1.20,
    };
    return map[va] ?? 0.10;
  }

  Map<String, dynamic> toJson() => {
        'visual_acuity_right': visualAcuityRight,
        'visual_acuity_left': visualAcuityLeft,
        'visual_acuity_both': visualAcuityBoth,
        'per_letter_results': perLetterResults,
        'response_times': responseTimes,
        'hesitation_score': hesitationScore,
        'gaze_compliance_score': gazeComplianceScore,
        'test_mode': testMode,
        'confidence_score': confidenceScore,
      };

  factory SnellenResultModel.fromJson(Map<String, dynamic> json) {
    return SnellenResultModel(
      visualAcuityRight: json['visual_acuity_right']?.toString() ?? '6/60',
      visualAcuityLeft: json['visual_acuity_left']?.toString() ?? '6/60',
      visualAcuityBoth: json['visual_acuity_both']?.toString() ?? '6/60',
      perLetterResults: (json['per_letter_results'] as List<dynamic>?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ??
          [],
      responseTimes: (json['response_times'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          [],
      hesitationScore: (json['hesitation_score'] as num?)?.toDouble() ?? 0.0,
      gazeComplianceScore: (json['gaze_compliance_score'] as num?)?.toDouble() ?? 0.8,
      testMode: json['test_mode']?.toString() ?? 'letter',
      confidenceScore: (json['confidence_score'] as num?)?.toDouble() ?? 0.8,
    );
  }
}
