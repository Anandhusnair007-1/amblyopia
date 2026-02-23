import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../providers/sync_provider.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';
import '../services/tts_service.dart';

class SyncScreen extends StatefulWidget {
  const SyncScreen({super.key});

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  bool _isOnline = false;
  bool _autoSync = true;
  List<Map<String, dynamic>> _pendingItems = [];
  DateTime? _lastSyncTime;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    _isOnline = await ApiService.checkOnline();
    final pending = await DatabaseService.getPendingSync();
    final prefs = await SharedPreferences.getInstance();
    _autoSync = prefs.getBool('auto_sync') ?? true;

    final lastStr = prefs.getString('last_sync_time');
    if (lastStr != null) {
      _lastSyncTime = DateTime.tryParse(lastStr);
    }

    if (mounted) {
      setState(() {
        _pendingItems = pending;
      });
    }
  }

  Future<void> _syncNow() async {
    final prov = context.read<SyncProvider>();
    await prov.syncNow();

    final prefs = await SharedPreferences.getInstance();
    _lastSyncTime = DateTime.now();
    await prefs.setString('last_sync_time', _lastSyncTime!.toIso8601String());

    await _loadData();
    await TtsService.speak('Sync complete');
  }

  Future<void> _toggleAutoSync(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_sync', val);
    setState(() => _autoSync = val);
  }

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1B2A),
        title: const Text('Sync Status',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        automaticallyImplyLeading: false,
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Connectivity card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1B2A),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _isOnline
                      ? Colors.green.withOpacity(0.4)
                      : Colors.red.withOpacity(0.4),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isOnline ? Colors.green : Colors.red,
                      boxShadow: [
                        BoxShadow(
                          color: (_isOnline ? Colors.green : Colors.red)
                              .withOpacity(0.5),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isOnline ? 'Online' : 'Offline',
                          style: TextStyle(
                            color: _isOnline ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          _isOnline
                              ? 'Connected to Aravind Server'
                              : 'Working in offline mode',
                          style: const TextStyle(
                              color: Color(0xFF546E7A), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Color(0xFF90CAF9)),
                    onPressed: _loadData,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Pending items card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1B2A),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF1A2A3A)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_pendingItems.length} screenings waiting',
                        style: TextStyle(
                          color: _pendingItems.isEmpty
                              ? Colors.green
                              : Colors.orange,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      if (_pendingItems.isEmpty)
                        const Icon(Icons.check_circle, color: Colors.green),
                    ],
                  ),
                  if (_pendingItems.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text('All data synced ✅',
                          style: TextStyle(
                              color: Color(0xFF546E7A), fontSize: 13)),
                    )
                  else ...[
                    const SizedBox(height: 12),
                    ..._pendingItems.take(5).map((item) {
                      final path = item['api_path']?.toString() ?? '';
                      final created = item['created_at']?.toString() ?? '';
                      String timeStr = '';
                      try {
                        final dt = DateTime.parse(created);
                        timeStr = DateFormat('HH:mm').format(dt);
                      } catch (_) {}
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            const Icon(Icons.cloud_upload_outlined,
                                color: Colors.orange, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                path.split('/').last.toUpperCase(),
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 13),
                              ),
                            ),
                            Text(timeStr,
                                style: const TextStyle(
                                    color: Color(0xFF546E7A), fontSize: 12)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text('pending',
                                  style: TextStyle(
                                      color: Colors.orange, fontSize: 10)),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    if (_pendingItems.length > 5)
                      Text(
                        '+ ${_pendingItems.length - 5} more...',
                        style: const TextStyle(
                            color: Color(0xFF546E7A), fontSize: 12),
                      ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Sync Now button
            if (_isOnline && _pendingItems.isNotEmpty)
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: sync.isSyncing ? null : _syncNow,
                  icon: sync.isSyncing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.sync),
                  label: Text(
                    sync.isSyncing ? 'Syncing...' : 'SYNC NOW',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            // Last sync time
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1B2A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF1A2A3A)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.history,
                      color: Color(0xFF546E7A), size: 18),
                  const SizedBox(width: 10),
                  Text(
                    _lastSyncTime != null
                        ? 'Last sync: ${DateFormat("d MMM 'at' HH:mm").format(_lastSyncTime!)}'
                        : 'Never synced',
                    style: const TextStyle(
                        color: Color(0xFF546E7A), fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Auto-sync toggle
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1B2A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF1A2A3A)),
              ),
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Auto-sync when connected',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
                subtitle: const Text(
                  'Uploads data automatically when online',
                  style: TextStyle(color: Color(0xFF546E7A), fontSize: 12),
                ),
                value: _autoSync,
                onChanged: _toggleAutoSync,
                activeColor: const Color(0xFF00E5FF),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
