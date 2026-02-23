import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  bool isLoggedIn = false;
  bool isLoading = false;
  String nurseName = '';
  String nurseId = '';
  String? errorMessage;

  Future<void> checkLogin() async {
    final auth = await DatabaseService.getToken();
    if (auth != null) {
      ApiService.setToken(auth['token'] as String);
      nurseName = auth['nurse_name']?.toString() ?? 'Nurse';
      nurseId = auth['nurse_id']?.toString() ?? '';
      isLoggedIn = true;
      notifyListeners();
    }
  }

  Future<bool> login(String phone, String password) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    final res = await AuthService.login(
      phone: phone,
      password: password,
    );

    isLoading = false;

    if (res['success'] == true) {
      nurseName = res['name']?.toString() ?? 'Nurse';
      isLoggedIn = true;
      errorMessage = null;
      notifyListeners();
      return true;
    } else {
      errorMessage = res['error']?.toString() ?? 'Login failed';
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await AuthService.logout();
    isLoggedIn = false;
    nurseName = '';
    nurseId = '';
    notifyListeners();
  }
}
