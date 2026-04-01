import 'package:flutter/material.dart';

import '../../core/theme/ambyoai_design_system.dart';

/// Quality score per test. >= 0.8 Good, 0.6-0.8 Acceptable, < 0.6 Poor (consider repeating).
class TestQuality {
  const TestQuality({
    required this.score,
    required this.warnings,
    required this.isAcceptable,
  });

  final double score;
  final List<String> warnings;
  final bool isAcceptable;

  static TestQuality forGaze({
    required int directionsDetected,
    required int totalDirections,
    required double avgConfidence,
  }) {
    final detectionRate = totalDirections > 0 ? directionsDetected / totalDirections : 0.0;
    final warnings = <String>[];
    if (detectionRate < 0.8) warnings.add('Face not detected in all directions');
    if (avgConfidence < 0.7) warnings.add('Low tracking confidence');
    final score = (detectionRate * 0.7) + (avgConfidence * 0.3);
    return TestQuality(
      score: score.clamp(0.0, 1.0),
      warnings: warnings,
      isAcceptable: score >= 0.6,
    );
  }

  static TestQuality forVoice({
    required int responsesReceived,
    required int totalExpected,
    required int unknownResponses,
  }) {
    final responseRate = totalExpected > 0 ? responsesReceived / totalExpected : 0.0;
    final knownRate = responsesReceived > 0
        ? (responsesReceived - unknownResponses) / responsesReceived
        : 0.0;
    final warnings = <String>[];
    if (responseRate < 0.8) warnings.add('Some responses not received');
    if (knownRate < 0.7) {
      warnings.add(
        'Voice not recognized clearly. Check microphone or background noise.',
      );
    }
    final score = (responseRate * 0.5) + (knownRate * 0.5);
    return TestQuality(
      score: score.clamp(0.0, 1.0),
      warnings: warnings,
      isAcceptable: score >= 0.6,
    );
  }

  static TestQuality forCamera({
    required bool faceDetected,
    required bool flashWorked,
    required double imageQuality,
  }) {
    final warnings = <String>[];
    double score = 1.0;
    if (!faceDetected) {
      warnings.add('Face not detected');
      score -= 0.5;
    }
    if (!flashWorked) {
      warnings.add('Flash did not activate');
      score -= 0.2;
    }
    if (imageQuality < 0.3) {
      warnings.add('Low light conditions');
      score -= 0.3;
    }
    return TestQuality(
      score: score.clamp(0.0, 1.0),
      warnings: warnings,
      isAcceptable: score >= 0.6,
    );
  }

  String get label {
    if (score >= 0.8) return 'Good';
    if (score >= 0.6) return 'Acceptable';
    return 'Poor — Consider Repeating';
  }

  Color get color {
    if (score >= 0.8) return AmbyoColors.tealMedical;
    if (score >= 0.6) return AmbyoColors.mildAmber;
    return AmbyoColors.urgentRed;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'score': score,
        'label': label,
        'warnings': warnings,
        'is_acceptable': isAcceptable,
      };
}
