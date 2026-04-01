import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum UserRole { none, patient, doctor, worker }

final roleProvider = StateProvider<UserRole>((ref) => UserRole.none);
final phoneProvider = StateProvider<String?>((ref) => null);

class RoleStorage {
  static const _key = 'ambyoai_user_role';
  static const _phoneKey = 'ambyoai_user_phone';

  static Future<UserRole?> getSavedRole() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_key);
    return _stringToRole(value);
  }

  static Future<void> saveRole(UserRole role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, role.name);
    await prefs.setString('user_role', role.name);
  }

  static Future<void> savePhone(String phoneNumber) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_phoneKey, phoneNumber);
  }

  static Future<String?> getSavedPhone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_phoneKey);
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    await prefs.remove(_phoneKey);
    await prefs.remove('user_role');
  }

  static UserRole? _stringToRole(String? value) {
    switch (value) {
      case 'patient':
        return UserRole.patient;
      case 'doctor':
        return UserRole.doctor;
      case 'worker':
        return UserRole.worker;
      default:
        return null;
    }
  }
}
