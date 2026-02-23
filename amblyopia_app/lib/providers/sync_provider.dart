import 'package:flutter/foundation.dart';
import '../services/sync_service.dart';
import '../services/database_service.dart';
import '../services/api_service.dart';

class SyncProvider extends ChangeNotifier {
  bool isSyncing = false;
  int pendingCount = 0;
  DateTime? lastSyncTime;
  String syncStatus = 'idle';

  Future<void> loadPendingCount() async {
    pendingCount = await DatabaseService.getPendingCount();
    notifyListeners();
  }

  Future<void> syncNow() async {
    final online = await ApiService.checkOnline();
    if (!online) {
      syncStatus = 'offline';
      notifyListeners();
      return;
    }

    isSyncing = true;
    syncStatus = 'syncing';
    notifyListeners();

    final result = await SyncService.syncAll();
    lastSyncTime = DateTime.now();
    pendingCount = result.failed;
    isSyncing = false;
    syncStatus = result.failed == 0 ? 'synced' : 'partial';
    notifyListeners();
  }
}
