import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/app_config.dart';
import '../../core/network/api_client.dart';
import '../ai_prediction/tflite_runner.dart';
import '../offline/database_tables.dart';
import '../offline/local_database.dart';

class ModelUpdater {
  ModelUpdater({
    Dio? dio,
    LocalDatabase? database,
    TFLiteRunner? runner,
    FlutterLocalNotificationsPlugin? notifications,
  })  : _dio = dio ?? ApiClient.create(),
        _database = database ?? LocalDatabase.instance,
        _runner = runner ?? TFLiteRunner(),
        _notifications = notifications ?? FlutterLocalNotificationsPlugin();

  final Dio _dio;
  final LocalDatabase _database;
  final TFLiteRunner _runner;
  final FlutterLocalNotificationsPlugin _notifications;

  Future<bool> checkForUpdate() async {
    if (!AppConfig.hasSecureBackend) {
      debugPrint('Model update skipped: no secure backend configured');
      return false;
    }
    final latest = await fetchLatestModelInfo();
    final version = latest['version']?.toString();
    if (version == null || version.isEmpty || version == '0.0.0') {
      return false;
    }
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getString(TFLiteRunner.prefsVersionKey) ?? '0.0.0';
    return _isNewerVersion(version, current);
  }

  Future<Map<String, dynamic>> fetchLatestModelInfo() async {
    if (!AppConfig.hasSecureBackend) {
      return <String, dynamic>{};
    }
    final response = await _dio.get('/api/models/latest');
    return ApiClient.unwrap<Map<String, dynamic>>(response.data);
  }

  Future<void> downloadNewModel(
    String downloadUrl,
    String version,
    String checksum,
  ) async {
    final resolvedUrl = _resolveDownloadUrl(downloadUrl);
    final uri = Uri.tryParse(resolvedUrl);
    if (uri == null || uri.scheme != 'https') {
      throw StateError('Model download URL must use HTTPS');
    }

    final tempFile =
        await _runner.getModelStorageFile(fileName: 'ambyo_model_new.tflite');
    final activeFile = await _runner.getModelStorageFile();
    final backupFile = await _runner.getModelStorageFile(
        fileName: 'ambyo_model_backup.tflite');

    await _dio.download(resolvedUrl, tempFile.path);
    final digest = await _checksumForFile(tempFile);
    if (digest != checksum) {
      if (tempFile.existsSync()) {
        tempFile.deleteSync();
      }
      throw StateError('Downloaded model checksum mismatch');
    }

    final isValid = await _runner.validateModelFile(tempFile);
    if (!isValid) {
      if (tempFile.existsSync()) {
        tempFile.deleteSync();
      }
      throw StateError('Downloaded model failed validation inference');
    }

    if (activeFile.existsSync()) {
      if (backupFile.existsSync()) {
        backupFile.deleteSync();
      }
      activeFile.renameSync(backupFile.path);
    }

    tempFile.renameSync(activeFile.path);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(TFLiteRunner.prefsVersionKey, version);
    await _runner.reloadModel();

    await _database.logModelUpdate(
      ModelUpdateRecord(
        version: version,
        downloadUrl: downloadUrl,
        downloaded: true,
        applied: true,
        createdAt: DateTime.now().toUtc(),
      ),
    );
    await _database.markModelUpdateApplied(version);
    await _showSilentNotification(version);
  }

  Future<void> rollbackModel() async {
    final activeFile = await _runner.getModelStorageFile();
    final backupFile = await _runner.getModelStorageFile(
        fileName: 'ambyo_model_backup.tflite');
    if (!backupFile.existsSync()) {
      return;
    }

    final rolledBack =
        File(p.join(activeFile.parent.path, 'ambyo_model_rollback.tflite'));
    if (activeFile.existsSync()) {
      activeFile.renameSync(rolledBack.path);
    }
    backupFile.renameSync(activeFile.path);
    await _runner.reloadModel();
  }

  Future<String> _checksumForFile(File file) async {
    final bytes = await file.readAsBytes();
    return sha256.convert(bytes).toString();
  }

  Future<void> _showSilentNotification(String version) async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _notifications
        .initialize(const InitializationSettings(android: android));
    await _notifications.show(
      1001,
      'AmbyoAI model updated to v$version',
      'Screening accuracy improved.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'ambyoai_model_updates',
          'Model Updates',
          channelDescription: 'Silent notifications for OTA model refreshes',
          importance: Importance.low,
          priority: Priority.low,
          playSound: false,
        ),
      ),
    );
  }

  // ignore: unused_element
  bool _isNewerVersion(String incoming, String current) {
    final incomingParts =
        incoming.split('.').map(int.tryParse).map((v) => v ?? 0).toList();
    final currentParts =
        current.split('.').map(int.tryParse).map((v) => v ?? 0).toList();
    final maxLength = incomingParts.length > currentParts.length
        ? incomingParts.length
        : currentParts.length;

    for (var i = 0; i < maxLength; i++) {
      final left = i < incomingParts.length ? incomingParts[i] : 0;
      final right = i < currentParts.length ? currentParts[i] : 0;
      if (left > right) {
        return true;
      }
      if (left < right) {
        return false;
      }
    }
    return false;
  }

  String _resolveDownloadUrl(String downloadUrl) {
    if (downloadUrl.startsWith('https://')) {
      return downloadUrl;
    }
    return '${AppConfig.backendBaseUrl}$downloadUrl';
  }
}
