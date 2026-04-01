class PrismDiopterResult {
  final Map<String, double> prismPerDirection;
  final double maxHorizontalPrism;
  final double maxVerticalPrism;
  final double totalDeviation;
  final double distancePrism;
  final double nearPrism;
  final String baseDirection;
  final String deviationType;
  final String severity;
  final bool requiresCorrection;

  const PrismDiopterResult({
    required this.prismPerDirection,
    required this.maxHorizontalPrism,
    required this.maxVerticalPrism,
    required this.totalDeviation,
    required this.distancePrism,
    required this.nearPrism,
    required this.baseDirection,
    required this.deviationType,
    required this.severity,
    required this.requiresCorrection,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'max_horizontal_prism': maxHorizontalPrism,
        'max_vertical_prism': maxVerticalPrism,
        'total_deviation': totalDeviation,
        'distance_prism': distancePrism,
        'near_prism': nearPrism,
        'base_direction': baseDirection,
        'deviation_type': deviationType,
        'severity': severity,
        'requires_correction': requiresCorrection,
        'prism_per_direction': prismPerDirection,
      };
}
