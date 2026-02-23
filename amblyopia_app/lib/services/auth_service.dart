import 'api_service.dart';
import 'database_service.dart';
import '../config/api_config.dart';

class AuthService {
  static Future<Map<String, dynamic>> login({
    required String phone,
    required String password,
    String deviceId = 'device_001',
  }) async {
    final body = {
      'phone_number': '+91$phone',
      'password': password,
      'device_id': deviceId,
    };

    final res = await ApiService.post(
      ApiConfig.nurseLogin,
      body,
      saveOfflineIfFailed: false,
    );

    if (res.containsKey('token') || res['data']?['token'] != null) {
      final token = res['token']?.toString() ??
          res['data']?['token']?.toString() ?? '';
      final nurseId = res['nurse_id']?.toString() ??
          res['data']?['nurse_id']?.toString() ?? '';
      final nurseName = res['name']?.toString() ??
          res['data']?['name']?.toString() ?? 'Nurse';

      await DatabaseService.saveToken(token, nurseId, nurseName);
      ApiService.setToken(token);

      return {'success': true, 'token': token, 'name': nurseName};
    }

    // Try offline cached token
    final cached = await DatabaseService.getToken();
    if (cached != null) {
      ApiService.setToken(cached['token'] as String);
      return {
        'success': true,
        'offline': true,
        'token': cached['token'],
        'name': cached['nurse_name'],
      };
    }

    return {'success': false, 'error': res['detail'] ?? res['error'] ?? 'Login failed'};
  }

  static Future<void> logout() async {
    await DatabaseService.clearToken();
  }
}
