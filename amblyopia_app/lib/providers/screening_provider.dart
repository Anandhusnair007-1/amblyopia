import 'package:flutter/foundation.dart';
import '../models/session_model.dart';
import '../models/gaze_result_model.dart';
import '../models/snellen_result_model.dart';
import '../models/redgreen_result_model.dart';
import '../models/combined_result_model.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';
import '../config/api_config.dart';

enum ScreeningStep { notStarted, gaze, snellen, redGreen, complete }

class ScreeningProvider extends ChangeNotifier {
  String? sessionId;
  String? patientId;
  String? villageId;
  String ageGroup = 'child';
  ScreeningStep currentStep = ScreeningStep.notStarted;

  GazeResultModel? gazeResult;
  SnellenResultModel? snellenResult;
  RedGreenResultModel? redGreenResult;
  CombinedResultModel? combinedResult;

  bool isLoading = false;
  String? errorMessage;
  bool isOffline = false;

  Future<bool> startSession({
    required String ageGroup,
    required String villageId,
    required double lat,
    required double lng,
  }) async {
    isLoading = true;
    this.ageGroup = ageGroup;
    this.villageId = villageId;
    notifyListeners();

    final patientRes = await ApiService.post(
      ApiConfig.createPatient,
      {'age_group': ageGroup, 'village_id': villageId},
    );

    patientId = patientRes['data']?['id']?.toString() ??
        patientRes['id']?.toString() ??
        _generateLocalId();

    final sessionRes = await ApiService.post(
      ApiConfig.startSession,
      {
        'patient_id': patientId,
        'village_id': villageId,
        'device_id': 'device_001',
        'gps_lat': lat,
        'gps_lng': lng,
        'lighting_condition': 'good',
        'battery_level': 85,
        'internet_available': !isOffline,
      },
    );

    sessionId = sessionRes['data']?['session_id']?.toString() ??
        sessionRes['session_id']?.toString() ??
        _generateLocalId();

    await DatabaseService.saveSession({
      'id': sessionId,
      'patient_id': patientId,
      'village_id': villageId,
      'age_group': ageGroup,
      'started_at': DateTime.now().toIso8601String(),
      'synced': sessionRes['queued'] == true ? 0 : 1,
    });

    currentStep = ScreeningStep.gaze;
    isLoading = false;
    notifyListeners();
    return true;
  }

  Future<void> saveGazeResult(GazeResultModel result) async {
    gazeResult = result;
    final payload = result.toJson();
    payload['session_id'] = sessionId;
    await ApiService.post(ApiConfig.gazeResult, payload);
    await DatabaseService.saveResult(sessionId!, 'gaze', payload);
    currentStep = ScreeningStep.snellen;
    notifyListeners();
  }

  Future<void> saveSnellenResult(SnellenResultModel result) async {
    snellenResult = result;
    final payload = result.toJson();
    payload['session_id'] = sessionId;
    await ApiService.post(ApiConfig.snellenResult, payload);
    await DatabaseService.saveResult(sessionId!, 'snellen', payload);
    currentStep = ScreeningStep.redGreen;
    notifyListeners();
  }

  Future<void> saveRedGreenResult(RedGreenResultModel result) async {
    redGreenResult = result;
    final payload = result.toJson();
    payload['session_id'] = sessionId;
    await ApiService.post(ApiConfig.redgreenResult, payload);
    await DatabaseService.saveResult(sessionId!, 'redgreen', payload);
    await _completeScreening();
  }

  Future<void> _completeScreening() async {
    isLoading = true;
    notifyListeners();

    final res = await ApiService.post(
      ApiConfig.completeScreening,
      {'session_id': sessionId},
    );

    if (res['queued'] == true || res['error'] != null) {
      combinedResult = CombinedResultModel.defaultResult();
    } else {
      combinedResult = CombinedResultModel.fromJson(res['data'] ?? res);
    }

    currentStep = ScreeningStep.complete;
    isLoading = false;
    notifyListeners();
  }

  void reset() {
    sessionId = null;
    patientId = null;
    villageId = null;
    gazeResult = null;
    snellenResult = null;
    redGreenResult = null;
    combinedResult = null;
    currentStep = ScreeningStep.notStarted;
    errorMessage = null;
    notifyListeners();
  }

  String _generateLocalId() =>
      'local_${DateTime.now().millisecondsSinceEpoch}';
}
