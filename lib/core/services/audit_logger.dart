import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../features/ai_prediction/tflite_runner.dart';
import '../../features/offline/database_tables.dart';
import '../../features/offline/local_database.dart';

class AuditLogger {
  static String? _currentUserRole;
  static String? _currentUserId;
  static String? _deviceId;

  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _deviceId = prefs.getString('device_id') ?? const Uuid().v4();
    await prefs.setString('device_id', _deviceId!);
  }

  static void setUser(String role, String? userId) {
    _currentUserRole = role;
    _currentUserId = userId;
  }

  static Future<void> log(
    AuditAction action, {
    String? targetId,
    String? targetType,
    Map<String, dynamic>? details,
  }) async {
    try {
      final entry = AuditLog(
        id: const Uuid().v4(),
        action: action.name,
        userRole: _currentUserRole ?? 'system',
        userId: _currentUserId,
        targetId: targetId,
        targetType: targetType,
        timestamp: DateTime.now(),
        deviceId: _deviceId ?? 'unknown',
        modelVersion: TFLiteRunner.currentVersion,
        details: details != null ? jsonEncode(details) : null,
      );
      await LocalDatabase.instance.saveAuditLog(entry);
    } catch (e) {
      debugPrint('Audit log failed: $e');
    }
  }
}
