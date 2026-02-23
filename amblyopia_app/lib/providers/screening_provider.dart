import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';
import '../config/api_config.dart';
import 'dart:convert';

class ScreeningProvider with ChangeNotifier {
  final ApiService _api = ApiService();
  final DatabaseService _db = DatabaseService();

  String? _currentPatientId;
  String? _currentSessionId;
  int _currentStep = 0;
  
  // Results
  Map<String, dynamic>? _snellenResult;
  Map<String, dynamic>? _gazeResult;
  Map<String, dynamic>? _redGreenResult;
  Map<String, dynamic>? _finalDiagnosis;

  String? get currentPatientId => _currentPatientId;
  String? get currentSessionId => _currentSessionId;
  int get currentStep => _currentStep;
  Map<String, dynamic>? get finalDiagnosis => _finalDiagnosis;

  void nextStep() {
    _currentStep++;
    notifyListeners();
  }

  void reset() {
    _currentPatientId = null;
    _currentSessionId = null;
    _currentStep = 0;
    _snellenResult = null;
    _gazeResult = null;
    _redGreenResult = null;
    _finalDiagnosis = null;
    notifyListeners();
  }

  Future<bool> createPatient(String ageGroup, String villageId) async {
    final payload = {'age_group': ageGroup, 'village_id': villageId};
    if (await _api.isOnline()) {
      final response = await _api.post(ApiConfig.createPatient, payload);
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        _currentPatientId = data['data']['id'];
        notifyListeners();
        return true;
      }
    } else {
      _currentPatientId = "OFFLINE_${DateTime.now().millisecondsSinceEpoch}";
      await _db.queueRequest(ApiConfig.createPatient, payload);
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<bool> startSession(String nurseId, String villageId, double lat, double lng) async {
    final payload = {
      'patient_id': _currentPatientId,
      'nurse_id': nurseId,
      'village_id': villageId,
      'device_id': 'MOBILE_APP',
      'gps_lat': lat,
      'gps_lng': lng,
      'lighting_condition': 'good',
      'battery_level': 85,
      'internet_available': await _api.isOnline()
    };

    if (await _api.isOnline()) {
      final response = await _api.post(ApiConfig.startScreening, payload);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _currentSessionId = data['data']['session_id'];
        notifyListeners();
        return true;
      }
    } else {
      _currentSessionId = "OFFLINE_SESS_${DateTime.now().millisecondsSinceEpoch}";
      await _db.queueRequest(ApiConfig.startScreening, payload);
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<void> submitSnellen(Map<String, dynamic> result) async {
    _snellenResult = result;
    result['session_id'] = _currentSessionId;
    if (await _api.isOnline()) {
      await _api.post(ApiConfig.snellenResult, result);
    } else {
      await _db.queueRequest(ApiConfig.snellenResult, result);
    }
    notifyListeners();
  }

  Future<void> submitGaze(Map<String, dynamic> result) async {
    _gazeResult = result;
    result['session_id'] = _currentSessionId;
    if (await _api.isOnline()) {
      await _api.post(ApiConfig.gazeResult, result);
    } else {
      await _db.queueRequest(ApiConfig.gazeResult, result);
    }
    notifyListeners();
  }

  Future<void> submitRedGreen(Map<String, dynamic> result) async {
    _redGreenResult = result;
    result['session_id'] = _currentSessionId;
    if (await _api.isOnline()) {
      await _api.post(ApiConfig.redGreenResult, result);
    } else {
      await _db.queueRequest(ApiConfig.redGreenResult, result);
    }
    notifyListeners();
  }

  Future<bool> completeSession() async {
    final payload = {'session_id': _currentSessionId};
    if (await _api.isOnline()) {
      final response = await _api.post(ApiConfig.completeScreening, payload);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _finalDiagnosis = data['data'];
        notifyListeners();
        return true;
      }
    } else {
      await _db.queueRequest(ApiConfig.completeScreening, payload);
      _finalDiagnosis = {
        'risk_level': 'Pending Sync',
        'severity_grade': 0,
        'recommendation': 'Waiting for server sync...'
      };
      notifyListeners();
      return true;
    }
    return false;
  }
}
