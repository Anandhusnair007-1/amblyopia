import '../ai_prediction/models/prediction_result.dart';
import '../eye_tests/gaze_detection/models/gaze_result.dart';
import '../eye_tests/hirschberg_test/models/hirschberg_result.dart';
import '../eye_tests/prism_diopter/models/prism_result.dart';
import '../eye_tests/red_reflex/models/red_reflex_result.dart';
import '../eye_tests/suppression_test/models/suppression_result.dart';
import '../eye_tests/depth_perception/models/depth_result.dart';
import '../eye_tests/titmus_stereo/models/titmus_result.dart';
import '../eye_tests/lang_stereo/models/lang_result.dart';
import '../eye_tests/ishihara_color/models/ishihara_result.dart';
import '../eye_tests/snellen_chart/models/snellen_result.dart';
import '../eye_tests/worth_four_dot/models/worth_four_dot_result.dart';

class ReportData {
  final String sessionId;
  final String patientId;
  final String patientName;
  final int patientAge;
  final String patientGender;
  final DateTime reportDate;
  final String screenedBy;
  final GazeTestResult? gazeResult;
  final HirschbergResult? hirschbergResult;
  final PrismDiopterResult? prismResult;
  final double? redReflexScore;
  final double? suppressionScore;
  final double? depthScore;
  final RedReflexResult? redReflexResult;
  final SuppressionResult? suppressionResult;
  final DepthPerceptionResult? depthResult;
  final TitmusResult? titmusResult;
  final LangResult? langResult;
  final IshiharaResult? ishiharaResult;
  final SnellenResult? snellenResult;
  final WorthFourDotResult? worthFourDotResult;
  final double? colorVisionScore;
  final double? visualAcuityScore;
  final double? worthFourDotScore;
  final PredictionResult? aiPrediction;
  final String reportId;
  final String modelVersion;

  /// For clinical audit: consent obtained date, guardian name, and signature image (page 1).
  final DateTime? consentObtainedDate;
  final String? consentGuardianName;
  final List<int>? signatureImageBytes;

  /// Per-test quality label e.g. {'gaze_detection': 'Good (0.92)', 'snellen_chart': 'Poor — Consider repeating (0.45)'}.
  final Map<String, String>? qualityByTest;

  const ReportData({
    required this.sessionId,
    required this.patientId,
    required this.patientName,
    required this.patientAge,
    required this.patientGender,
    required this.reportDate,
    required this.screenedBy,
    this.gazeResult,
    this.hirschbergResult,
    this.prismResult,
    this.redReflexScore,
    this.suppressionScore,
    this.depthScore,
    this.redReflexResult,
    this.suppressionResult,
    this.depthResult,
    this.titmusResult,
    this.langResult,
    this.ishiharaResult,
    this.snellenResult,
    this.worthFourDotResult,
    this.colorVisionScore,
    this.visualAcuityScore,
    this.worthFourDotScore,
    this.aiPrediction,
    required this.reportId,
    required this.modelVersion,
    this.consentObtainedDate,
    this.consentGuardianName,
    this.signatureImageBytes,
    this.qualityByTest,
  });
}
