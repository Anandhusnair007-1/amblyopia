import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'package:ambyo_ai/features/ai_prediction/tflite_runner.dart';
import 'package:ambyo_ai/features/offline/database_tables.dart';
import 'package:ambyo_ai/features/offline/local_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
  const secureStorageChannel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final secureStorage = <String, String>{};
  final tempRoot = Directory.systemTemp.createTempSync('ambyoai_test_');

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
      return tempRoot.path;
    });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, (call) async {
      switch (call.method) {
        case 'read':
          return secureStorage[call.arguments['key']];
        case 'write':
          secureStorage[call.arguments['key'] as String] = call.arguments['value'] as String;
          return null;
        default:
          return null;
      }
    });
  });

  tearDownAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, null);
    if (tempRoot.existsSync()) {
      tempRoot.deleteSync(recursive: true);
    }
  });

  test('TFLite runner returns valid fallback prediction when model asset is absent', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final runner = TFLiteRunner();

    final result = await runner.runInference(<double>[0.5, 0.3, 2.0, 0.1, 0.8, 0.9, 1.0, 0.9, 8.0, 1.5]);

    expect(result.riskScore, inInclusiveRange(0.0, 1.0));
    expect(result.recommendation, isNotEmpty);
    expect(result.riskLevel, isNotEmpty);
  });

  test('TFLite fallback works when model missing', () {
    final runner = TFLiteRunner();
    final result = runner.fallbackRules(<double>[
      0.5,
      0.3,
      2.0,
      0.1,
      0.8,
      0.9,
      1.0,
      0.9,
      8.0,
      1.5,
    ]);
    expect(result.riskScore, isNotNull);
    expect(result.riskLevel, isNotEmpty);
  });

  test(
    'Local database can create, save, and retrieve a patient offline',
    () async {
      await LocalDatabase.initialize();
      final database = LocalDatabase.instance;
      final patientId = const Uuid().v4();

      await database.savePatient(
        Patient(
          id: patientId,
          name: 'Test Patient',
          age: 8,
          gender: 'female',
          phone: '9999999999',
          createdAt: DateTime.now().toUtc(),
        ),
      );

      final patient = await database.getPatient(patientId);
      expect(patient, isNotNull);
      expect(patient!.name, 'Test Patient');
      expect(patient.phone, '9999999999');
    },
    skip: Platform.isLinux
        ? 'SQLCipher host library is not available in the Linux Flutter test runner.'
        : false,
  );
}
