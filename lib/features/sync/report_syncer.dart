import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../../core/config/app_config.dart';
import '../../core/network/api_client.dart';
import '../ai_prediction/tflite_runner.dart';
import '../offline/database_tables.dart';
import '../offline/local_database.dart';
import 'image_uploader.dart';
import 'model_updater.dart';

const String ambyoSyncTask = 'syncData';
const String ambyoSyncUniqueName = 'ambyoai_sync';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      WidgetsFlutterBinding.ensureInitialized();
      await LocalDatabase.initialize();
      if (task == ambyoSyncTask) {
        await runFullSync();
      }
    } catch (e, st) {
      debugPrint('Sync task error: $e $st');
    }
    return true;
  });
}

Future<void> initializeBackgroundSync() async {
  await Workmanager().initialize(callbackDispatcher);
  await Workmanager().registerPeriodicTask(
    ambyoSyncUniqueName,
    ambyoSyncTask,
    frequency: const Duration(hours: 24),
    constraints: Constraints(
      networkType: NetworkType.connected,
      requiresCharging: false,
    ),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
  );
}

Future<void> runFullSync() async {
  try {
    final baseUri = Uri.tryParse(AppConfig.backendBaseUrl);
    if (baseUri == null ||
        baseUri.scheme != 'https' ||
        AppConfig.backendBaseUrl.isEmpty) {
      debugPrint('Sync skipped: no valid secure backend URL');
      return;
    }

    final results = await Connectivity().checkConnectivity();
    final offline = results.contains(ConnectivityResult.none);
    if (offline) {
      return;
    }

    final database = LocalDatabase.instance;
    final uploader = ImageUploader(database: database);
    final updater = ModelUpdater(database: database, runner: TFLiteRunner());
    final dio = ApiClient.create();

    final unsyncedSessions = await database.getUnsyncedSessions();
    for (final session in unsyncedSessions) {
      await _syncSession(session, database, dio, uploader);
    }

    final latest = await updater.fetchLatestModelInfo();
    final version = latest['version']?.toString();
    final downloadUrl = latest['download_url']?.toString();
    final checksum = latest['checksum']?.toString();
    if (version != null &&
        downloadUrl != null &&
        checksum != null &&
        await updater.checkForUpdate()) {
      await updater.downloadNewModel(downloadUrl, version, checksum);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'last_sync_timestamp', DateTime.now().toUtc().toIso8601String());
  } catch (e, st) {
    debugPrint('runFullSync error: $e $st');
  }
}

Future<void> syncNow() async {
  await runFullSync();
}

Future<void> _syncSession(
  TestSession session,
  LocalDatabase database,
  Dio dio,
  ImageUploader uploader,
) async {
  final prediction = await database.getPredictionForSession(session.id);
  final results = await database.getSessionResults(session.id);
  final images = await database.getSessionImages(session.id);
  final patient = await database.getPatient(session.patientId);

  final payload = _resultsPayload(results);
  if (patient != null) {
    payload['patient_name'] = patient.name;
    payload['patient_age'] = patient.age;
    payload['patient_phone'] = patient.phone;
  }
  payload['test_count'] = results.length;
  payload['tests'] = results
      .map(
        (r) => <String, Object?>{
          'test_name': r.testName,
          'raw_score': r.rawScore,
          'normalized_score': r.normalizedScore,
          'details': r.details,
          'created_at': r.createdAt.toUtc().toIso8601String(),
        },
      )
      .toList(growable: false);

  final body = <String, Object?>{
    'device_id': session.deviceId,
    'session_id': session.id,
    'test_date': session.testDate.toIso8601String(),
    'results': payload,
    'ai_prediction': prediction == null
        ? null
        : <String, Object?>{
            'risk_score': prediction.riskScore,
            'risk_level': prediction.riskLevel,
            'model_version': prediction.modelVersion,
          },
    'label': null,
  };

  await dio.post(
    '/api/sync/results',
    data: jsonEncode(body),
    options:
        Options(headers: <String, String>{'Content-Type': 'application/json'}),
  );

  for (final image in images.where((item) => !item.uploaded)) {
    await uploader.uploadImage(image);
  }

  await database.markSessionSynced(session.id);
}

Map<String, Object?> _resultsPayload(List<TestResult> results) {
  final payload = <String, Object?>{
    'gaze_deviation': 0.0,
    'prism_diopter': 0.0,
    'suppression_level': 0.0,
    'depth_score': 0.0,
    'stereo_score': 0.0,
    'color_score': 0.0,
    'visual_acuity': 0.0,
    'red_reflex': 0.0,
    'hirschberg': 0.0,
    'age_group': 'unknown',
  };

  for (final result in results) {
    switch (result.testName) {
      case 'gaze':
      case 'gaze_detection':
        payload['gaze_deviation'] = result.normalizedScore;
        break;
      case 'prism':
      case 'prism_diopter':
        payload['prism_diopter'] = result.normalizedScore;
        break;
      case 'suppression':
        payload['suppression_level'] = result.normalizedScore;
        break;
      case 'depth':
        payload['depth_score'] = result.normalizedScore;
        break;
      case 'stereo':
      case 'titmus_stereo':
        payload['stereo_score'] = result.normalizedScore;
        break;
      case 'color':
      case 'ishihara_color':
        payload['color_score'] = result.normalizedScore;
        break;
      case 'visual_acuity':
      case 'snellen_chart':
        payload['visual_acuity'] = result.normalizedScore;
        break;
      case 'red_reflex':
        payload['red_reflex'] = result.normalizedScore;
        break;
      case 'hirschberg':
        payload['hirschberg'] = result.normalizedScore;
        break;
      case 'age_group':
        payload['age_group'] = result.details['value']?.toString() ?? 'unknown';
        break;
      default:
        break;
    }
  }

  return payload;
}
