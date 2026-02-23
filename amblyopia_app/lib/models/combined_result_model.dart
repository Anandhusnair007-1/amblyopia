import 'package:flutter/material.dart';

class CombinedResultModel {
  final double gazeScore;
  final double redgreenScore;
  final double snellenScore;
  final double overallRiskScore;
  final int severityGrade;
  final String riskLevel;
  final String recommendation;
  final bool referralNeeded;

  const CombinedResultModel({
    required this.gazeScore,
    required this.redgreenScore,
    required this.snellenScore,
    required this.overallRiskScore,
    required this.severityGrade,
    required this.riskLevel,
    required this.recommendation,
    required this.referralNeeded,
  });

  String get gradeLabel {
    switch (severityGrade) {
      case 0: return 'NORMAL';
      case 1: return 'MILD';
      case 2: return 'MODERATE';
      case 3: return 'CRITICAL';
      default: return 'UNKNOWN';
    }
  }

  Color get gradeColor {
    switch (severityGrade) {
      case 0: return Colors.green;
      case 1: return Colors.amber;
      case 2: return Colors.orange;
      case 3: return Colors.red;
      default: return Colors.grey;
    }
  }

  factory CombinedResultModel.fromJson(Map<String, dynamic> json) {
    return CombinedResultModel(
      gazeScore: (json['gaze_score'] as num?)?.toDouble() ??
          (json['gaze_result']?['confidence_score'] as num?)?.toDouble() ?? 0.75,
      redgreenScore: (json['redgreen_score'] as num?)?.toDouble() ??
          (json['redgreen_result']?['confidence_score'] as num?)?.toDouble() ?? 0.75,
      snellenScore: (json['snellen_score'] as num?)?.toDouble() ??
          (json['snellen_result']?['confidence_score'] as num?)?.toDouble() ?? 0.75,
      overallRiskScore: (json['overall_risk_score'] as num?)?.toDouble() ??
          (json['risk_score'] as num?)?.toDouble() ?? 0.5,
      severityGrade: (json['severity_grade'] as int?) ??
          (json['grade'] as int?) ?? 1,
      riskLevel: json['risk_level']?.toString() ??
          json['risk']?.toString() ?? 'mild',
      recommendation: json['recommendation']?.toString() ??
          json['recommendations']?.toString() ?? 'Monitor monthly.',
      referralNeeded: json['referral_needed'] as bool? ??
          json['referral'] as bool? ?? false,
    );
  }

  factory CombinedResultModel.defaultResult() {
    return const CombinedResultModel(
      gazeScore: 0.75,
      redgreenScore: 0.75,
      snellenScore: 0.75,
      overallRiskScore: 0.3,
      severityGrade: 1,
      riskLevel: 'mild',
      recommendation: 'Monitor monthly. Visit Aravind Eye Hospital for detailed examination.',
      referralNeeded: false,
    );
  }
}
