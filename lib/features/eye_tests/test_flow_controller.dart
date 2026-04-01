import 'dart:io';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../ai_prediction/models/prediction_result.dart';
import '../ai_prediction/tflite_runner.dart';
import '../offline/database_tables.dart';
import '../offline/local_database.dart';
import '../../core/services/audit_logger.dart';
import '../reports/models/urgent_finding.dart';
import '../reports/pdf_generator.dart';
import '../reports/report_model.dart';
import 'titmus_stereo/models/titmus_result.dart';
import 'lang_stereo/models/lang_result.dart';
import 'ishihara_color/models/ishihara_result.dart';
import 'snellen_chart/models/snellen_result.dart';
import 'depth_perception/models/depth_result.dart';
import 'gaze_detection/models/gaze_result.dart';
import 'hirschberg_test/models/hirschberg_result.dart';
import 'prism_diopter/models/prism_result.dart';
import 'red_reflex/models/red_reflex_result.dart';
import 'suppression_test/models/suppression_result.dart';
import 'worth_four_dot/models/worth_four_dot_result.dart';
import 'age_profile.dart';
import '../../core/router/app_router.dart';
import '../patient_portal/widgets/single_test_result_sheet.dart';

class TestFlowController {
  factory TestFlowController({
    LocalDatabase? database,
  }) {
    if (database != null) {
      _instance = TestFlowController._internal(database: database);
    }
    return _instance;
  }

  TestFlowController._internal({
    LocalDatabase? database,
  }) : _database = database ?? LocalDatabase.instance;

  static TestFlowController _instance = TestFlowController._internal();

  final LocalDatabase _database;
  final Uuid _uuid = const Uuid();

  static String? currentSessionId;
  static String? currentPatientId;
  static String? currentPatientName;
  static int? currentPatientAge;
  static String? patientGender;
  static String? workerName;

  final Map<String, dynamic> testScores = <String, dynamic>{};
  bool urgentFlowTriggered = false;

  static bool isSingleTestMode = false;
  static String? singleTestName;

  /// Override auto-selected age profile when child is more/less developed than age suggests.
  /// Set via "Change Profile" on test start screen; cleared when session ends.
  static AgeProfile? profileOverride;

  /// Shared "next test" preview duration between test screens.
  static const Duration transitionPreview = Duration(seconds: 2);

  /// Age-based profile: A (3-4), B (5-7), C (8+). Uses [profileOverride] when set.
  static AgeProfile get currentProfile =>
      profileOverride ?? AgeProfile.fromAge(currentPatientAge ?? 8);

  /// Route name for the next test after [currentKey], or null if next is final_prediction.
  String? getNextRoute(String currentKey) {
    final next = getNextTest(currentKey);
    if (next == 'final_prediction') return null;
    return _testKeyToRoute[next];
  }

  static const Map<String, String> _testKeyToRoute = <String, String>{
    'eye_scan': AppRouter.worthFourDot,
    'worth_four_dot': AppRouter.titmusStereo,
    'titmus_stereo': AppRouter.langStereo,
    'lang_stereo': AppRouter.ishiharaColor,
    'ishihara_color': AppRouter.suppression,
    'suppression_test': AppRouter.depthPerception,
    'depth_perception': AppRouter.gaze,
    'gaze_detection': AppRouter.prismDiopter,
    'prism_diopter': AppRouter.hirschberg,
    'hirschberg': AppRouter.redReflex,
    'red_reflex': AppRouter.snellenChart,
  };

  /// Call when screening begins (e.g. user taps Start Full Screening).
  static Future<void> startTestSession() async {
    if (currentSessionId != null) {
      await AuditLogger.log(
        AuditAction.sessionStarted,
        targetId: currentSessionId,
        targetType: 'session',
      );
    }
    await WakelockPlus.enable();
  }

  /// Call when all tests complete (PDF generated), urgent report shown, or user exits screening.
  static Future<void> endTestSession() async {
    profileOverride = null;
    await WakelockPlus.disable();
  }

  /// Show retry dialog when a test fails or is inconclusive.
  /// Returns true if user chose Retry, false if Skip.
  static Future<bool> showRetryDialog(
    BuildContext context,
    String testName, {
    String? message,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Test Inconclusive',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          message ??
              '$testName could not be completed. Would you like to retry?',
          style: const TextStyle(fontFamily: 'Poppins'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Skip Test'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  static void initializeSessionContext({
    required String sessionId,
    required String patientId,
    required String patientName,
    required int patientAge,
    required String gender,
    String? screener,
  }) {
    currentSessionId = sessionId;
    currentPatientId = patientId;
    currentPatientName = patientName;
    currentPatientAge = patientAge;
    patientGender = gender;
    workerName = screener;
  }

  void onTestComplete(String testName, dynamic result) {
    testScores[testName] = result;
    if (currentSessionId != null) {
      final riskLevel = _riskLevelFromResult(result);
      AuditLogger.log(
        AuditAction.testCompleted,
        targetId: currentSessionId,
        targetType: 'session',
        details: <String, dynamic>{
          'test_name': testName,
          'risk_level': riskLevel
        },
      );
    }

    if (testName == 'gaze_detection') {
      final gazeResult = result as GazeTestResult;
      testScores['gaze_deviation'] = gazeResult.maxDeviation;
      testScores['gaze_prism_diopter'] = gazeResult.prismDiopterValue;
      if (gazeResult.requiresUrgentReferral) {
        urgentFlowTriggered = true;
      }
    } else if (testName == 'hirschberg') {
      final hirschberg = result as HirschbergResult;
      testScores['hirschberg'] =
          hirschberg.leftDisplacementMM > hirschberg.rightDisplacementMM
              ? hirschberg.leftDisplacementMM
              : hirschberg.rightDisplacementMM;
      testScores['hirschberg_result'] = hirschberg;
      if (hirschberg.requiresUrgentReferral) {
        urgentFlowTriggered = true;
      }
    } else if (testName == 'prism_diopter') {
      final prism = result as PrismDiopterResult;
      testScores['prism_diopter'] = prism.totalDeviation;
      testScores['prism_result'] = prism;
    } else if (testName == 'red_reflex') {
      final redReflex = result as RedReflexResult;
      testScores['red_reflex'] = redReflex.normalityScore;
      testScores['red_reflex_result'] = redReflex;
      if (redReflex.requiresUrgentReferral) {
        urgentFlowTriggered = true;
      }
    } else if (testName == 'suppression_test') {
      final suppression = result as SuppressionResult;
      testScores['suppression'] = suppression.suppressionScore;
      testScores['suppression_result'] = suppression;
    } else if (testName == 'depth_perception') {
      final depth = result as DepthPerceptionResult;
      testScores['depth_score'] = depth.normalityScore;
      testScores['depth_result'] = depth;
    } else if (testName == 'titmus_stereo') {
      final titmus = result as TitmusResult;
      testScores['stereo_score'] = titmus.normalityScore;
      testScores['titmus_result'] = titmus;
    } else if (testName == 'lang_stereo') {
      final lang = result as LangResult;
      testScores['lang_result'] = lang;
    } else if (testName == 'ishihara_color') {
      final ishihara = result as IshiharaResult;
      testScores['color_score'] = ishihara.normalityScore;
      testScores['ishihara_result'] = ishihara;
    } else if (testName == 'snellen_chart') {
      final snellen = result as SnellenResult;
      testScores['visual_acuity'] = snellen.normalityScore;
      testScores['snellen_result'] = snellen;
    } else if (testName == 'worth_four_dot') {
      final worth = result as WorthFourDotResult;
      testScores['worth_four_dot_score'] = worth.normalityScore;
      testScores['worth_four_dot_result'] = worth;
    }
  }

  static String _riskLevelFromResult(dynamic result) {
    if (result == null) return 'unknown';
    try {
      if (result is GazeTestResult && result.requiresUrgentReferral) {
        return 'URGENT';
      }
      if (result is HirschbergResult && result.requiresUrgentReferral) {
        return 'URGENT';
      }
      if (result is RedReflexResult && result.requiresUrgentReferral) {
        return 'URGENT';
      }
    } catch (_) {}
    return 'NORMAL';
  }

  static Future<void> runSingleTest(
    BuildContext context,
    String testName,
    String sessionId,
  ) async {
    currentSessionId = sessionId;
    isSingleTestMode = true;
    singleTestName = testName;

    final route = _routeForTest(testName);
    if (route == null) {
      isSingleTestMode = false;
      singleTestName = null;
      throw StateError('No route configured for test: $testName');
    }
    Navigator.pushNamed(context, route, arguments: sessionId);
  }

  static String? _routeForTest(String testName) {
    switch (testName) {
      case 'gaze_detection':
        return AppRouter.gaze;
      case 'hirschberg':
        return AppRouter.hirschberg;
      case 'prism_diopter':
        return AppRouter.prismDiopter;
      case 'red_reflex':
        return AppRouter.redReflex;
      case 'suppression_test':
        return AppRouter.suppression;
      case 'depth_perception':
        return AppRouter.depthPerception;
      case 'titmus_stereo':
        return AppRouter.titmusStereo;
      case 'lang_stereo':
        return AppRouter.langStereo;
      case 'ishihara_color':
        return AppRouter.ishiharaColor;
      case 'snellen_chart':
        return AppRouter.snellenChart;
      case 'worth_four_dot':
        return AppRouter.worthFourDot;
      default:
        return null;
    }
  }

  static Future<void> onSingleTestComplete(
    BuildContext context, {
    required String testName,
    required dynamic result,
  }) async {
    if (!isSingleTestMode || singleTestName != testName) {
      return;
    }

    isSingleTestMode = false;
    singleTestName = null;

    if (!context.mounted) return;
    // Navigate to full-screen result page — replace the test screen so back
    // goes directly to patient home, not back into the test.
    await Navigator.pushReplacement<void, void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => SingleTestResultSheet(
          testName: testName,
          result: result,
        ),
      ),
    );
  }

  String getNextTest(String current) {
    const order = <String>[
      'eye_scan',
      'worth_four_dot',
      'titmus_stereo',
      'lang_stereo',
      'ishihara_color',
      'suppression_test',
      'depth_perception',
      'gaze_detection',
      'prism_diopter',
      'hirschberg',
      'red_reflex',
      'snellen_chart',
      'final_prediction',
    ];

    final idx = order.indexOf(current);
    if (idx < 0 || idx >= order.length - 1) {
      return 'final_prediction';
    }
    return order[idx + 1];
  }

  void navigateToUrgentReport(BuildContext context, UrgentReportData data) {
    endTestSession();
    Navigator.pushNamed(
      context,
      AppRouter.urgentReport,
      arguments: data,
    );
  }

  Future<PredictionResult> runFinalPrediction() async {
    final runner = TFLiteRunner();
    await runner.loadModel();
    final prediction = await runner.runInference(<double>[
      (testScores['visual_acuity'] ?? 0.5).toDouble(),
      (testScores['gaze_deviation'] ?? 0.0).toDouble(),
      (testScores['prism_diopter'] ?? testScores['gaze_prism_diopter'] ?? 0.0)
          .toDouble(),
      (testScores['suppression'] ?? 0.0).toDouble(),
      (testScores['depth_score'] ?? 0.8).toDouble(),
      (testScores['stereo_score'] ?? 0.8).toDouble(),
      (testScores['color_score'] ?? 1.0).toDouble(),
      (testScores['red_reflex'] ?? 0.9).toDouble(),
      (testScores['age'] ?? (currentPatientAge ?? 8).toDouble()).toDouble(),
      (testScores['hirschberg'] ?? 0.0).toDouble(),
    ]);

    testScores['final_prediction'] = prediction;
    if (currentSessionId != null) {
      await _database.savePrediction(
        AIPrediction(
          id: _uuid.v4(),
          sessionId: currentSessionId!,
          riskScore: prediction.riskScore,
          riskLevel: prediction.riskLevel,
          recommendation: prediction.recommendation,
          modelVersion: prediction.modelVersion,
          createdAt: DateTime.now(),
        ),
      );
      await AuditLogger.log(
        AuditAction.aiPredictionGenerated,
        targetId: currentSessionId,
        targetType: 'session',
        details: <String, dynamic>{
          'risk_level': prediction.riskLevel,
          'risk_score': prediction.riskScore,
          'model_version': prediction.modelVersion,
        },
      );
    }
    return prediction;
  }

  Future<void> generateAndShowReport(BuildContext context) async {
    await endTestSession();
    final prediction = await runFinalPrediction();
    ConsentRecord? consent;
    List<int>? signatureBytes;
    if (currentPatientId != null) {
      consent = await _database.getConsent(currentPatientId!);
      if (consent != null &&
          consent.signaturePngPath.isNotEmpty &&
          await File(consent.signaturePngPath).exists()) {
        signatureBytes = await File(consent.signaturePngPath).readAsBytes();
      }
    }
    final reportData = ReportData(
      sessionId: currentSessionId!,
      patientId: currentPatientId!,
      patientName: currentPatientName!,
      patientAge: currentPatientAge!,
      patientGender: patientGender ?? 'unknown',
      reportDate: DateTime.now(),
      screenedBy: workerName ?? 'AmbyoAI App',
      gazeResult: testScores['gaze_detection'] as GazeTestResult?,
      hirschbergResult: testScores['hirschberg_result'] as HirschbergResult?,
      prismResult: testScores['prism_result'] as PrismDiopterResult?,
      redReflexScore: (testScores['red_reflex'] as num?)?.toDouble(),
      suppressionScore: (testScores['suppression'] as num?)?.toDouble(),
      depthScore: (testScores['depth_score'] as num?)?.toDouble(),
      redReflexResult: testScores['red_reflex_result'] as RedReflexResult?,
      suppressionResult: testScores['suppression_result'] as SuppressionResult?,
      depthResult: testScores['depth_result'] as DepthPerceptionResult?,
      titmusResult: testScores['titmus_result'] as TitmusResult?,
      langResult: testScores['lang_result'] as LangResult?,
      ishiharaResult: testScores['ishihara_result'] as IshiharaResult?,
      snellenResult: testScores['snellen_result'] as SnellenResult?,
      worthFourDotResult:
          testScores['worth_four_dot_result'] as WorthFourDotResult?,
      colorVisionScore: (testScores['color_score'] as num?)?.toDouble(),
      visualAcuityScore: (testScores['visual_acuity'] as num?)?.toDouble(),
      worthFourDotScore:
          (testScores['worth_four_dot_score'] as num?)?.toDouble(),
      aiPrediction: prediction,
      reportId: _uuid.v4(),
      modelVersion: prediction.modelVersion,
      consentObtainedDate: consent?.consentDate,
      consentGuardianName: consent?.guardianName,
      signatureImageBytes: signatureBytes,
    );

    final pdfPath = await PDFGenerator.generateReport(reportData);
    if (currentSessionId != null) {
      await AuditLogger.log(
        AuditAction.pdfGenerated,
        targetId: currentSessionId,
        targetType: 'session',
      );
    }
    if (!context.mounted) {
      return;
    }
    Navigator.pushNamed(
      context,
      AppRouter.reportPreview,
      arguments: <String, dynamic>{
        'pdfPath': pdfPath,
        'reportData': reportData,
      },
    );
  }

  UrgentReportData buildUrgentReport({
    required List<UrgentFinding> findings,
    double riskScore = 0.95,
    String riskLevel = 'URGENT',
    String recommendation =
        'This child should be seen by a paediatric ophthalmologist at Aravind Eye Hospital within 24-48 hours.',
  }) {
    return UrgentReportData(
      sessionId: currentSessionId ?? '',
      patientName: currentPatientName ?? 'Unknown Patient',
      patientAge: currentPatientAge ?? 0,
      testDate: DateTime.now(),
      findings: findings,
      riskScore: riskScore,
      riskLevel: riskLevel,
      recommendation: recommendation,
      screenedBy: workerName ?? 'AmbyoAI App',
    );
  }
}
