import 'dart:math' as math;

class GazeResultModel {
  final double leftGazeX;
  final double leftGazeY;
  final double rightGazeX;
  final double rightGazeY;
  final double gazeAsymmetryScore;
  final double leftFixationStability;
  final double rightFixationStability;
  final double leftBlinkRatio;
  final double rightBlinkRatio;
  final double blinkAsymmetry;
  final int framesAnalyzed;
  final double confidenceScore;
  final String result;
  final bool needsDoctorReview;

  const GazeResultModel({
    required this.leftGazeX,
    required this.leftGazeY,
    required this.rightGazeX,
    required this.rightGazeY,
    required this.gazeAsymmetryScore,
    required this.leftFixationStability,
    required this.rightFixationStability,
    required this.leftBlinkRatio,
    required this.rightBlinkRatio,
    required this.blinkAsymmetry,
    required this.framesAnalyzed,
    required this.confidenceScore,
    required this.result,
    required this.needsDoctorReview,
  });

  factory GazeResultModel.calculate({
    required List<double> leftXHistory,
    required List<double> rightXHistory,
    required List<double> leftYHistory,
    required List<double> rightYHistory,
    required List<int> leftBlinks,
    required List<int> rightBlinks,
  }) {
    if (leftXHistory.isEmpty) {
      return const GazeResultModel(
        leftGazeX: 0.5, leftGazeY: 0.5,
        rightGazeX: 0.5, rightGazeY: 0.5,
        gazeAsymmetryScore: 0.0,
        leftFixationStability: 0.8, rightFixationStability: 0.8,
        leftBlinkRatio: 0.15, rightBlinkRatio: 0.15,
        blinkAsymmetry: 0.0, framesAnalyzed: 0,
        confidenceScore: 0.5, result: 'insufficient_data',
        needsDoctorReview: true,
      );
    }
    
    double avgLX = leftXHistory.reduce((a, b) => a + b) / leftXHistory.length;
    double avgRX = rightXHistory.isNotEmpty
        ? rightXHistory.reduce((a, b) => a + b) / rightXHistory.length
        : avgLX;
    double avgLY = leftYHistory.isNotEmpty
        ? leftYHistory.reduce((a, b) => a + b) / leftYHistory.length
        : 0.5;
    double avgRY = rightYHistory.isNotEmpty
        ? rightYHistory.reduce((a, b) => a + b) / rightYHistory.length
        : 0.5;

    double asymmetry = (avgLX - avgRX).abs();

    double fixLeft = _stdDev(leftXHistory);
    double fixRight = rightXHistory.isNotEmpty ? _stdDev(rightXHistory) : fixLeft;

    double blinkL = leftBlinks.isNotEmpty
        ? leftBlinks.reduce((a, b) => a + b) / leftXHistory.length
        : 0.15;
    double blinkR = rightBlinks.isNotEmpty
        ? rightBlinks.reduce((a, b) => a + b) / (rightXHistory.isNotEmpty ? rightXHistory.length : leftXHistory.length)
        : blinkL;

    double confidence = leftXHistory.length > 100 ? 0.87 : 0.65;
    String res = asymmetry > 0.15 ? 'asymmetry_detected' : 'symmetric';

    return GazeResultModel(
      leftGazeX: avgLX, leftGazeY: avgLY,
      rightGazeX: avgRX, rightGazeY: avgRY,
      gazeAsymmetryScore: asymmetry,
      leftFixationStability: fixLeft,
      rightFixationStability: fixRight,
      leftBlinkRatio: blinkL,
      rightBlinkRatio: blinkR,
      blinkAsymmetry: (blinkL - blinkR).abs(),
      framesAnalyzed: leftXHistory.length,
      confidenceScore: confidence,
      result: res,
      needsDoctorReview: asymmetry > 0.25 || confidence < 0.7,
    );
  }

  static double _stdDev(List<double> values) {
    if (values.length < 2) return 0.0;
    double mean = values.reduce((a, b) => a + b) / values.length;
    double variance = values.map((v) => math.pow(v - mean, 2).toDouble())
        .reduce((a, b) => a + b) / values.length;
    return math.sqrt(variance);
  }

  Map<String, dynamic> toJson() => {
        'left_gaze_x': leftGazeX,
        'left_gaze_y': leftGazeY,
        'right_gaze_x': rightGazeX,
        'right_gaze_y': rightGazeY,
        'gaze_asymmetry_score': gazeAsymmetryScore,
        'left_fixation_stability': leftFixationStability,
        'right_fixation_stability': rightFixationStability,
        'left_blink_ratio': leftBlinkRatio,
        'right_blink_ratio': rightBlinkRatio,
        'blink_asymmetry': blinkAsymmetry,
        'frames_analyzed': framesAnalyzed,
        'confidence_score': confidenceScore,
        'result': result,
        'needs_doctor_review': needsDoctorReview,
      };

  factory GazeResultModel.fromJson(Map<String, dynamic> json) {
    return GazeResultModel(
      leftGazeX: (json['left_gaze_x'] as num?)?.toDouble() ?? 0.5,
      leftGazeY: (json['left_gaze_y'] as num?)?.toDouble() ?? 0.5,
      rightGazeX: (json['right_gaze_x'] as num?)?.toDouble() ?? 0.5,
      rightGazeY: (json['right_gaze_y'] as num?)?.toDouble() ?? 0.5,
      gazeAsymmetryScore: (json['gaze_asymmetry_score'] as num?)?.toDouble() ?? 0.0,
      leftFixationStability: (json['left_fixation_stability'] as num?)?.toDouble() ?? 0.8,
      rightFixationStability: (json['right_fixation_stability'] as num?)?.toDouble() ?? 0.8,
      leftBlinkRatio: (json['left_blink_ratio'] as num?)?.toDouble() ?? 0.15,
      rightBlinkRatio: (json['right_blink_ratio'] as num?)?.toDouble() ?? 0.15,
      blinkAsymmetry: (json['blink_asymmetry'] as num?)?.toDouble() ?? 0.0,
      framesAnalyzed: (json['frames_analyzed'] as int?) ?? 0,
      confidenceScore: (json['confidence_score'] as num?)?.toDouble() ?? 0.8,
      result: json['result']?.toString() ?? 'symmetric',
      needsDoctorReview: json['needs_doctor_review'] as bool? ?? false,
    );
  }
}
