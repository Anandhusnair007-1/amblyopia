import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' as riverpod;
import 'package:provider/provider.dart';
import 'package:workmanager/workmanager.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'core/providers/language_provider.dart';
import 'core/router/app_router.dart';
import 'core/services/audit_logger.dart';
import 'core/services/distance_calibration_service.dart';
import 'core/theme/ambyo_theme.dart';
import 'features/about/about_screen.dart';
import 'features/auth/providers/patient_provider.dart' as patient_provider;
import 'features/auth/screens/doctor_login_screen.dart';
import 'features/auth/screens/patient_login_screen.dart';
import 'features/auth/screens/role_selection_screen.dart';
import 'features/offline/local_database.dart';
import 'features/offline/vosk_service.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/patient_portal/screens/my_reports_screen.dart';
import 'features/patient_portal/screens/patient_home_screen.dart';
import 'features/patient_portal/screens/patient_profile_screen.dart';
import 'features/patient_portal/screens/test_history_screen.dart';
import 'features/splash/splash_screen.dart';
import 'features/sync/report_syncer.dart';
import 'features/doctor_portal/screens/doctor_dashboard_screen.dart';
import 'features/doctor_portal/screens/doctor_patient_list_screen.dart';
import 'features/health_worker/screens/add_patient_screen.dart';
import 'features/health_worker/screens/screening_queue_screen.dart';
import 'features/health_worker/screens/worker_home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    debugPrint('Skipping .env load during startup.');
  }

  await LocalDatabase.initialize();
  await LocalDatabase.instance.seedDefaultDoctor();
  await LocalDatabase.instance.seedDefaultWorker();

  // Seed default worker PIN on first launch
  final prefs = await SharedPreferences.getInstance();
  final workerPin = prefs.getString('worker_pin');
  if (workerPin == null || workerPin == '7391') {
    await prefs.setString('worker_pin', '5816');
  }
  await AuditLogger.initialize();
  await DistanceCalibrationService.instance.load();

  final langProvider = LanguageProvider();
  await langProvider.loadSaved();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<LanguageProvider>(create: (_) => langProvider),
        ChangeNotifierProvider<patient_provider.PatientProvider>(
          create: (_) => patient_provider.PatientProvider(),
        ),
      ],
      child: const riverpod.ProviderScope(child: AmbyoAIApp()),
    ),
  );

  unawaited(_bootstrapServices(langProvider.code));
}

Future<void> _bootstrapServices(String languageCode) async {
  try {
    await VoskService.initialize(languageCode);
  } catch (e, st) {
    debugPrint('Vosk bootstrap failed: $e');
    debugPrintStack(stackTrace: st);
  }

  try {
    // Background sync is optional in full-offline mode, so it should never block launch.
    await Workmanager().initialize(callbackDispatcher);
  } catch (e, st) {
    debugPrint('Workmanager bootstrap failed: $e');
    debugPrintStack(stackTrace: st);
  }
}

class AmbyoAIApp extends StatelessWidget {
  const AmbyoAIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AmbyoAI',
      debugShowCheckedModeBanner: false,
      theme: AmbyoTheme.lightTheme,
      darkTheme: AmbyoTheme.lightTheme,
      themeMode: ThemeMode.light,
      initialRoute: '/',
      routes: {
        '/': (_) => const SplashScreen(),
        '/onboarding': (_) => const OnboardingScreen(),
        '/role-select': (_) => const RoleSelectionScreen(),
        '/patient-login': (_) => const PatientLoginScreen(),
        AppRouter.patientHome: (_) => const PatientHomeScreen(),
        AppRouter.patientTestHistory: (_) => const TestHistoryScreen(),
        AppRouter.myReports: (_) => const MyReportsScreen(),
        AppRouter.patientProfile: (_) => const PatientProfileScreen(),
        '/doctor-login': (_) => const DoctorLoginScreen(),
        '/doctor-dashboard': (_) => const DoctorDashboardScreen(),
        AppRouter.doctorPatientList: (_) => const DoctorPatientListScreen(),
        '/worker-home': (_) => const WorkerHomeScreen(),
        AppRouter.addPatient: (_) => const AddPatientScreen(),
        AppRouter.screeningQueue: (_) => const ScreeningQueueScreen(),
        '/about': (_) => const AboutScreen(),
      },
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}
