import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  bool _isAuthenticated = false;
  Map<String, dynamic>? _nurseProfile;
  bool _isLoading = false;

  bool get isAuthenticated => _isAuthenticated;
  Map<String, dynamic>? get nurseProfile => _nurseProfile;
  bool get isLoading => _isLoading;

  Future<void> checkAuth() async {
    _isAuthenticated = await _authService.isLoggedIn();
    notifyListeners();
  }

  Future<bool> login(String phone, String password, String deviceId) async {
    _isLoading = true;
    notifyListeners();

    final result = await _authService.login(phone, password, deviceId);
    _isLoading = false;

    if (result != null) {
      _isAuthenticated = true;
      _nurseProfile = result['nurse_profile'];
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<void> logout() async {
    await _authService.logout();
    _isAuthenticated = false;
    _nurseProfile = null;
    notifyListeners();
  }
}
