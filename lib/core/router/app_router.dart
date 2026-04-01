import 'package:flutter/material.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/patient_login_screen.dart';
import '../../features/eye_tests/depth_perception/screens/depth_screen.dart';
import '../../features/doctor_portal/screens/doctor_change_password_screen.dart';
import '../../features/doctor_portal/screens/doctor_dashboard_screen.dart';
import '../../features/doctor_portal/screens/doctor_diagnosis_screen.dart';
import '../../features/doctor_portal/screens/doctor_patient_detail_screen.dart';
import '../../features/doctor_portal/screens/doctor_patient_list_screen.dart';
import '../../features/doctor_portal/screens/doctor_report_viewer_screen.dart';
import '../../features/eye_tests/hirschberg_test/screens/hirschberg_screen.dart';
import '../../features/eye_tests/gaze_detection/screens/gaze_screen.dart';
import '../../features/eye_tests/prism_diopter/screens/prism_screen.dart';
import '../../features/eye_tests/red_reflex/screens/red_reflex_screen.dart';
import '../../features/eye_tests/suppression_test/screens/suppression_screen.dart';
import '../../features/eye_tests/titmus_stereo/screens/titmus_screen.dart';
import '../../features/eye_tests/lang_stereo/screens/lang_screen.dart';
import '../../features/eye_tests/ishihara_color/screens/ishihara_screen.dart';
import '../../features/eye_tests/snellen_chart/screens/snellen_screen.dart';
import '../../features/eye_tests/worth_four_dot/screens/worth_four_dot_screen.dart';
import '../../features/health_worker/screens/add_patient_screen.dart';
import '../../features/health_worker/screens/screening_queue_screen.dart';
import '../../features/health_worker/screens/worker_home_screen.dart';
import '../../features/settings/distance_calibration_screen.dart';
import '../../features/patient_portal/screens/patient_home_screen.dart';
import '../../features/patient_portal/screens/my_reports_screen.dart';
import '../../features/patient_portal/screens/patient_profile_screen.dart';
import '../../features/patient_portal/screens/test_history_screen.dart';
import '../../features/reports/models/urgent_finding.dart';
import '../../features/reports/report_model.dart';
import '../../features/reports/screens/report_preview_screen.dart';
import '../../features/reports/screens/urgent_report_screen.dart';

class AppRouter {
  static const gaze = '/gaze';
  static const urgentReport = '/urgent-report';
  static const hirschberg = '/hirschberg';
  static const prismDiopter = '/prism-diopter';
  static const redReflex = '/red-reflex';
  static const suppression = '/suppression';
  static const depthPerception = '/depth-perception';
  static const titmusStereo = '/titmus';
  static const langStereo = '/lang';
  static const ishiharaColor = '/ishihara';
  static const snellenChart = '/snellen';
  static const worthFourDot = '/worth-four-dot';
  static const reportPreview = '/report-preview';

  static const patientHome = '/patient-home';
  static const patientTestHistory = '/patient-test-history';
  static const myReports = '/my-reports';
  static const patientProfile = '/patient-profile';

  static const doctorPatientList = '/doctor-patients';
  static const doctorPatientDetail = '/doctor-patient-detail';
  static const doctorReportViewer = '/doctor-report-viewer';
  static const doctorDiagnosis = '/doctor-diagnosis';
  static const doctorChangePassword = '/doctor-change-password';

  static const addPatient = '/add-patient';
  static const screeningQueue = '/screening-queue';
  static const distanceCalibration = '/distance-calibration';

  static Widget homeForRole(UserRole role) {
    switch (role) {
      case UserRole.patient:
        return const PatientHomeScreen();
      case UserRole.doctor:
        return const DoctorDashboardScreen();
      case UserRole.worker:
        return const WorkerHomeScreen();
      case UserRole.none:
        return const PatientLoginScreen();
    }
  }

  /// Standard slide+fade transition used for all non-report routes.
  static PageRouteBuilder<void> _route(Widget screen, RouteSettings settings) {
    return PageRouteBuilder<void>(
      settings: settings,
      pageBuilder: (_, __, ___) => screen,
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 240),
      transitionsBuilder: (_, animation, __, child) {
        return FadeTransition(
          opacity: CurvedAnimation(
              parent: animation,
              curve: const Interval(0.0, 0.7, curve: Curves.easeOut)),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.0, 0.05),
              end: Offset.zero,
            ).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
            child: child,
          ),
        );
      },
    );
  }

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case gaze:
        final sessionId = settings.arguments as String;
        return _route(GazeScreen(sessionId: sessionId), settings);
      case urgentReport:
        final data = settings.arguments! as UrgentReportData;
        return _route(UrgentReportScreen(data: data), settings);
      case hirschberg:
        final args = settings.arguments;
        return _route(
          HirschbergScreen(
            args: args is HirschbergScreenArgs
                ? args
                : HirschbergScreenArgs(sessionId: args as String?),
          ),
          settings,
        );
      case prismDiopter:
        final rawArgs = settings.arguments;
        final args = rawArgs is PrismScreenArgs
            ? rawArgs
            : PrismScreenArgs(
                sessionId: rawArgs as String? ?? '', gazeResult: null);
        return _route(PrismScreen(args: args), settings);
      case redReflex:
        final args = settings.arguments;
        return _route(
          RedReflexScreen(
            args: args is RedReflexScreenArgs
                ? args
                : RedReflexScreenArgs(sessionId: args as String?),
          ),
          settings,
        );
      case suppression:
        final args = settings.arguments;
        return _route(
          SuppressionScreen(
            args: args is SuppressionScreenArgs
                ? args
                : SuppressionScreenArgs(sessionId: args as String?),
          ),
          settings,
        );
      case depthPerception:
        final args = settings.arguments;
        return _route(
          DepthScreen(
            args: args is DepthScreenArgs
                ? args
                : DepthScreenArgs(sessionId: args as String?),
          ),
          settings,
        );
      case titmusStereo:
        return _route(const TitmusScreen(), settings);
      case langStereo:
        return _route(const LangScreen(), settings);
      case ishiharaColor:
        return _route(const IshiharaScreen(), settings);
      case snellenChart:
        return _route(const SnellenScreen(), settings);
      case worthFourDot:
        return _route(const WorthFourDotScreen(), settings);
      case reportPreview:
        final args = settings.arguments as Map<String, dynamic>?;
        return _route(
          ReportPreviewScreen(
            pdfPath: args?['pdfPath'] as String?,
            reportData: args?['reportData'] as ReportData?,
          ),
          settings,
        );
      case patientHome:
        return _route(const PatientHomeScreen(), settings);
      case patientTestHistory:
        return _route(const TestHistoryScreen(), settings);
      case myReports:
        return _route(const MyReportsScreen(), settings);
      case patientProfile:
        return _route(const PatientProfileScreen(), settings);
      case doctorPatientList:
        return _route(const DoctorPatientListScreen(), settings);
      case doctorPatientDetail:
        final args = settings.arguments is Map
            ? settings.arguments! as Map<String, dynamic>
            : <String, dynamic>{
                'patientId': settings.arguments?.toString() ?? ''
              };
        return _route(
          DoctorPatientDetailScreen(
            patientId: (args['patientId'] ?? '').toString(),
            patientName: args['patientName']?.toString(),
          ),
          settings,
        );
      case doctorReportViewer:
        final sessionId = settings.arguments as String;
        return _route(DoctorReportViewerScreen(sessionId: sessionId), settings);
      case doctorDiagnosis:
        final diagArgs = settings.arguments;
        final diagSessionId = diagArgs is Map
            ? (diagArgs['sessionId'] ?? diagArgs['session_id'] ?? '').toString()
            : (diagArgs as String? ?? '');
        final diagPatientName =
            diagArgs is Map ? diagArgs['patientName']?.toString() : null;
        return _route(
          DoctorDiagnosisScreen(
              sessionId: diagSessionId, patientName: diagPatientName),
          settings,
        );
      case doctorChangePassword:
        return _route(const DoctorChangePasswordScreen(), settings);
      case addPatient:
        return _route(const AddPatientScreen(), settings);
      case screeningQueue:
        return _route(const ScreeningQueueScreen(), settings);
      case distanceCalibration:
        return _route(const DistanceCalibrationScreen(), settings);
      default:
        return null;
    }
  }
}
