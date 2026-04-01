class UrgentFinding {
  final String testName;
  final String findingName;
  final String measuredValue;
  final String normalRange;
  final String severity;

  const UrgentFinding({
    required this.testName,
    required this.findingName,
    required this.measuredValue,
    required this.normalRange,
    required this.severity,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'test_name': testName,
        'finding_name': findingName,
        'measured_value': measuredValue,
        'normal_range': normalRange,
        'severity': severity,
      };
}

class UrgentReportData {
  final String sessionId;
  final String patientName;
  final int patientAge;
  final DateTime testDate;
  final List<UrgentFinding> findings;
  final double riskScore;
  final String riskLevel;
  final String recommendation;
  final String screenedBy;

  const UrgentReportData({
    required this.sessionId,
    required this.patientName,
    required this.patientAge,
    required this.testDate,
    required this.findings,
    required this.riskScore,
    required this.riskLevel,
    required this.recommendation,
    this.screenedBy = 'AmbyoAI App',
  });
}
