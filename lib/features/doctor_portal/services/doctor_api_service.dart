import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';

class DoctorApiService {
  static const _storage = FlutterSecureStorage();
  static Dio _dio() => ApiClient.create();

  static Future<String?> login({
    required String username,
    required String password,
  }) async {
    if (!AppConfig.hasSecureBackend) {
      return null;
    }
    final response = await _dio().post(
      '/api/doctor/login',
      data: <String, dynamic>{
        'username': username,
        'password': password,
      },
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
      ),
    );
    final data = ApiClient.unwrap<Map<String, dynamic>>(response.data);
    final token = data['access_token']?.toString();
    if (token != null && token.isNotEmpty) {
      await saveToken(token);
    }
    return token;
  }

  static Future<void> saveToken(String token) async {
    await _storage.write(key: 'doctor_jwt', value: token);
  }

  static Future<void> clearToken() async {
    await _storage.delete(key: 'doctor_jwt');
  }

  static Future<List<Map<String, dynamic>>> getPatients(
      {bool allowCache = true}) async {
    if (!AppConfig.hasSecureBackend) {
      return <Map<String, dynamic>>[];
    }
    final response = await _dio().get('/api/doctor/patients');
    final rows = ApiClient.unwrap<List<dynamic>>(response.data);
    return rows.cast<Map<String, dynamic>>();
  }

  static Future<List<Map<String, dynamic>>> getUrgentCases(
      {bool allowCache = true}) async {
    if (!AppConfig.hasSecureBackend) {
      return <Map<String, dynamic>>[];
    }
    final response = await _dio().get('/api/doctor/urgent');
    final rows = ApiClient.unwrap<List<dynamic>>(response.data);
    return rows.cast<Map<String, dynamic>>();
  }

  static Future<Map<String, dynamic>?> getReport(String sessionId) async {
    if (!AppConfig.hasSecureBackend) {
      return null;
    }
    final response = await _dio().get('/api/doctor/reports/$sessionId');
    return ApiClient.unwrap<Map<String, dynamic>>(response.data);
  }

  static Future<Map<String, dynamic>?> getStats() async {
    if (!AppConfig.hasSecureBackend) {
      return null;
    }
    final response = await _dio().get('/api/doctor/stats');
    return ApiClient.unwrap<Map<String, dynamic>>(response.data);
  }

  static Future<bool> saveDiagnosis({
    required String sessionId,
    required int label,
    required String doctorNotes,
  }) async {
    if (!AppConfig.hasSecureBackend) {
      return false;
    }
    await _dio().post(
      '/api/doctor/diagnosis',
      data: <String, dynamic>{
        'session_id': sessionId,
        'label': label,
        'doctor_notes': doctorNotes,
      },
    );
    return true;
  }
}
