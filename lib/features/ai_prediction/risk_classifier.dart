import 'models/prediction_result.dart';
import 'tflite_runner.dart';

class RiskClassifier {
  final TFLiteRunner runner;

  RiskClassifier({required this.runner});

  Future<PredictionResult> classify(Map<String, dynamic> metrics) {
    return runner.runInference(<double>[
      (metrics['visual_acuity'] ?? metrics['visualAcuity'] ?? 0.0).toDouble(),
      (metrics['gaze_deviation'] ?? metrics['gazeDeviation'] ?? 0.0).toDouble(),
      (metrics['prism_diopter'] ?? metrics['prismDiopter'] ?? 0.0).toDouble(),
      (metrics['suppression_level'] ?? metrics['suppressionLevel'] ?? 0.0).toDouble(),
      (metrics['depth_perception'] ?? metrics['depthPerception'] ?? 0.0).toDouble(),
      (metrics['stereo_acuity'] ?? metrics['stereoAcuity'] ?? 0.0).toDouble(),
      (metrics['color_vision'] ?? metrics['colorVision'] ?? 0.0).toDouble(),
      (metrics['red_reflex'] ?? metrics['redReflex'] ?? 0.0).toDouble(),
      (metrics['patient_age'] ?? metrics['patientAge'] ?? 0).toDouble(),
      (metrics['hirschberg_deviation'] ?? metrics['hirschbergDeviation'] ?? 0.0).toDouble(),
    ]);
  }
}
