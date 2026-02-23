import 'dart:convert';
import 'api_service.dart';
import 'database_service.dart';

class SyncService {
  final ApiService _api = ApiService();
  final DatabaseService _db = DatabaseService();

  Future<void> syncOfflineData() async {
    if (!await _api.isOnline()) return;

    final queue = await _db.getQueue();
    for (var item in queue) {
      try {
        final response = await _api.post(
          item['endpoint'],
          jsonDecode(item['payload']),
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          await _db.removeFromQueue(item['id']);
        }
      } catch (e) {
        // Log error and continue to next item
        print("Sync failed for ${item['id']}: $e");
      }
    }
  }
}
