class PredictionResult {
  final double riskScore;
  final int riskClass;
  final String riskLevel;
  final String recommendation;
  final String modelVersion;
  final bool usedFallback;
  final String? warning;
  final List<double> rawOutput;

  const PredictionResult({
    required this.riskScore,
    required this.riskClass,
    required this.riskLevel,
    required this.recommendation,
    this.modelVersion = '0.0.0',
    this.usedFallback = false,
    this.warning,
    this.rawOutput = const <double>[],
  });
}
