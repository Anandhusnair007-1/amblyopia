import 'dart:convert';
import 'api_service.dart';
import 'database_service.dart';

class SyncService {
  static Future<SyncResult> syncAll() async {
    final pending = await DatabaseService.getPendingSync();
    int success = 0;
    int failed = 0;

    for (final item in pending) {
      try {
        final payload = jsonDecode(item['payload'] as String) as Map<String, dynamic>;
        final path = item['api_path'] as String;
        final id = item['id'] as int;

        final res = await ApiService.post(path, payload, saveOfflineIfFailed: false);

        if (res['error'] == null && res['queued'] != true) {
          await DatabaseService.markSynced(id);
          success++;
        } else {
          failed++;
        }
      } catch (_) {
        failed++;
      }
    }

    return SyncResult(success: success, failed: failed, total: pending.length);
  }
}

class SyncResult {
  final int success;
  final int failed;
  final int total;

  const SyncResult({
    required this.success,
    required this.failed,
    required this.total,
  });
}
