import 'package:flutter/material.dart';

import '../eye_tests/test_flow_controller.dart';
import '../jarvis_scanner/screens/jarvis_scan_screen.dart';
import '../offline/database_tables.dart';
import '../offline/local_database.dart';
import 'screens/informed_consent_screen.dart';

/// Checks consent for [patient]. If valid consent exists, starts screening (creates session, navigates to Jarvis).
/// If no consent or consent > 12 months, shows [InformedConsentScreen]; on consent saved, then starts screening.
/// Returns true if screening was started (navigated to Jarvis), false otherwise.
Future<bool> ensureConsentThenStartScreening(
  BuildContext context,
  Patient patient, {
  required String screener,
}) async {
  final db = LocalDatabase.instance;
  final hasValid = await db.hasValidConsent(patient.id);
  if (hasValid) {
    if (!context.mounted) return false;
    return _startScreening(context, patient, screener);
  }
  final needsRenewal = await db.consentNeedsRenewal(patient.id);
  final existingConsent = needsRenewal ? await db.getConsent(patient.id) : null;
  if (!context.mounted) return false;
  final result = await Navigator.of(context).push<bool>(
    MaterialPageRoute<bool>(
      builder: (_) => InformedConsentScreen(
        patient: patient,
        isRenewal: needsRenewal,
        previousConsentDate: existingConsent?.consentDate,
      ),
    ),
  );
  if (result != true || !context.mounted) return false;
  return _startScreening(context, patient, screener);
}

/// Ensures consent then runs a single test (for patient portal). Returns true if test was started.
Future<bool> ensureConsentThenRunSingleTest(
  BuildContext context,
  Patient patient,
  String testName, {
  required String screener,
}) async {
  final db = LocalDatabase.instance;
  final hasValid = await db.hasValidConsent(patient.id);
  if (!hasValid) {
    final needsRenewal = await db.consentNeedsRenewal(patient.id);
    final existingConsent =
        needsRenewal ? await db.getConsent(patient.id) : null;
    if (!context.mounted) return false;
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => InformedConsentScreen(
          patient: patient,
          isRenewal: needsRenewal,
          previousConsentDate: existingConsent?.consentDate,
        ),
      ),
    );
    if (result != true || !context.mounted) return false;
  }
  final sessionId = await LocalDatabase.instance.createSession(patient.id);
  TestFlowController.initializeSessionContext(
    sessionId: sessionId,
    patientId: patient.id,
    patientName: patient.name,
    patientAge: patient.age,
    gender: patient.gender,
    screener: screener,
  );
  if (!context.mounted) return false;
  await TestFlowController.runSingleTest(context, testName, sessionId);
  return true;
}

Future<bool> _startScreening(
    BuildContext context, Patient patient, String screener) async {
  final sessionId = await LocalDatabase.instance.createSession(patient.id);
  TestFlowController.initializeSessionContext(
    sessionId: sessionId,
    patientId: patient.id,
    patientName: patient.name,
    patientAge: patient.age,
    gender: patient.gender,
    screener: screener,
  );
  if (!context.mounted) return false;
  await TestFlowController.startTestSession();
  if (!context.mounted) return false;
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
        builder: (_) => JarvisScanScreen(sessionId: sessionId)),
  );
  return true;
}
