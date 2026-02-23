import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import 'api_service.dart';

class AuthService {
  final ApiService _api = ApiService();

  Future<Map<String, dynamic>?> login(String phone, String password, String deviceId) async {
    final response = await _api.post(ApiConfig.nurseLogin, {
      'phone_number': phone,
      'password': password,
      'device_id': deviceId,
    });

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('access_token', data['data']['access_token']);
      await prefs.setString('nurse_id', data['data']['nurse_profile']['id']);
      _api.setToken(data['data']['access_token']);
      return data['data'];
    }
    return null;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('nurse_id');
    _api.setToken("");
  }

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('access_token');
  }
}
