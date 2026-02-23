import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'database_service.dart';

class ApiService {
  static String? _token;
  static bool _isOnline = true;

  static void setToken(String token) {
    _token = token;
  }

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  static Future<bool> checkOnline() async {
    try {
      final r = await http
          .get(Uri.parse('${ApiConfig.baseUrl}/health'))
          .timeout(const Duration(seconds: 3));
      _isOnline = r.statusCode == 200;
    } catch (_) {
      _isOnline = false;
    }
    return _isOnline;
  }

  static Future<Map<String, dynamic>> get(String path) async {
    if (!await checkOnline()) {
      return {'error': 'offline', 'offline': true};
    }
    try {
      final r = await http
          .get(Uri.parse('${ApiConfig.baseUrl}$path'), headers: _headers)
          .timeout(ApiConfig.timeout);
      return jsonDecode(r.body) as Map<String, dynamic>;
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    bool saveOfflineIfFailed = true,
  }) async {
    final isOnline = await checkOnline();

    if (!isOnline && saveOfflineIfFailed) {
      await DatabaseService.saveToSyncQueue(path: path, payload: body);
      return {'queued': true, 'message': 'Saved offline — will sync later'};
    }

    try {
      final r = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}$path'),
            headers: _headers,
            body: jsonEncode(body),
          )
          .timeout(ApiConfig.timeout);

      final data = jsonDecode(r.body) as Map<String, dynamic>;

      if (r.statusCode == 200 || r.statusCode == 201) {
        return data;
      } else if (saveOfflineIfFailed) {
        await DatabaseService.saveToSyncQueue(path: path, payload: body);
        return {'queued': true, 'original_error': r.statusCode};
      }
      return data;
    } catch (e) {
      if (saveOfflineIfFailed) {
        await DatabaseService.saveToSyncQueue(path: path, payload: body);
        return {'queued': true, 'error': e.toString()};
      }
      return {'error': e.toString()};
    }
  }
}
