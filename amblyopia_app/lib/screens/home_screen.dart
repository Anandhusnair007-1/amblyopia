import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/sync_provider.dart';
import '../services/database_service.dart';
import '../services/api_service.dart';
import '../widgets/sync_status_badge.dart';
import '../widgets/grade_badge.dart';
import 'village_screen.dart';
import 'sync_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  bool _isOnline = false;
  List<Map<String, dynamic>> _recentSessions = [];
  int _screenedToday = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    _isOnline = await ApiService.checkOnline();
    final sessions = await DatabaseService.getRecentSessions(limit: 5);
    final syncProv = context.read<SyncProvider>();
    await syncProv.loadPendingCount();

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    int todayCount = 0;
    for (final s in sessions) {
      final started = s['started_at']?.toString() ?? '';
      if (started.startsWith(today)) todayCount++;
    }

    if (mounted) {
      setState(() {
        _recentSessions = sessions;
        _screenedToday = todayCount;
        if (_isOnline) syncProv.syncNow();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final sync = context.watch<SyncProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      body: IndexedStack(
        index: _tab,
        children: [
          _buildHomeTab(auth, sync),
          _buildScreenTab(),
          const SyncScreen(),
          _buildSettingsTab(auth),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: const Color(0xFF0D1B2A),
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          const NavigationDestination(
            icon: Icon(Icons.camera_alt_outlined),
            selectedIcon: Icon(Icons.camera_alt),
            label: 'Screen',
          ),
          NavigationDestination(
            icon: Badge(
              label: sync.pendingCount > 0
                  ? Text('${sync.pendingCount}')
                  : null,
              child: const Icon(Icons.sync_outlined),
            ),
            selectedIcon: const Icon(Icons.sync),
            label: 'Sync',
          ),
          const NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  Widget _buildHomeTab(AuthProvider auth, SyncProvider sync) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          backgroundColor: const Color(0xFF0D1B2A),
          title: const Text('Amblyopia Care',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          floating: true,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Icon(
                _isOnline ? Icons.wifi : Icons.wifi_off,
                color: _isOnline ? Colors.green : Colors.red,
              ),
            ),
          ],
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Greeting card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.account_circle, color: Colors.white70, size: 48),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome, ${auth.nurseName}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              DateFormat('EEEE, d MMMM yyyy').format(DateTime.now()),
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 13),
                            ),
                            const Text(
                              'Coimbatore, Tamil Nadu',
                              style: TextStyle(color: Colors.white60, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Stats row
                Row(
                  children: [
                    Expanded(
                      child: _statCard(
                          'Screened Today', '$_screenedToday', Icons.check_circle_outline),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _statCard(
                          'Pending Sync', '${sync.pendingCount}', Icons.cloud_upload_outlined,
                          color: sync.pendingCount > 0 ? Colors.orange : Colors.green),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Main action button
                SizedBox(
                  height: 64,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const VillageScreen()),
                      );
                    },
                    icon: const Icon(Icons.camera_alt, size: 28),
                    label: const Text(
                      'START NEW SCREENING',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1565C0),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 6,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Recent screenings
                const Text(
                  'Recent Screenings',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                if (_recentSessions.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D1B2A),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text(
                        'No screenings yet.\nTap START NEW SCREENING above.',
                        style: TextStyle(color: Color(0xFF546E7A), fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else
                  ...(_recentSessions.map((s) => _sessionCard(s))),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon,
      {Color color = const Color(0xFF00E5FF)}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1A2A3A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(color: Color(0xFF90CAF9), fontSize: 12)),
        ],
      ),
    );
  }

  Widget _sessionCard(Map<String, dynamic> s) {
    final ageGroup = s['age_group']?.toString() ?? 'child';
    final synced = (s['synced'] as int? ?? 0) == 1;
    final startedAt = s['started_at']?.toString() ?? '';
    String timeStr = '';
    try {
      final dt = DateTime.parse(startedAt);
      timeStr = DateFormat('HH:mm').format(dt);
    } catch (_) {}

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1A2A3A)),
      ),
      child: Row(
        children: [
          const Icon(Icons.person_outline, color: Color(0xFF90CAF9)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ageGroup.toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                Text(timeStr,
                    style: const TextStyle(color: Color(0xFF546E7A), fontSize: 12)),
              ],
            ),
          ),
          Icon(
            synced ? Icons.cloud_done : Icons.cloud_upload_outlined,
            color: synced ? Colors.green : Colors.orange,
            size: 18,
          ),
        ],
      ),
    );
  }

  Widget _buildScreenTab() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.camera_alt, color: Color(0xFF1565C0), size: 80),
            const SizedBox(height: 24),
            const Text(
              'Ready to Screen',
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Start a new patient screening session',
              style: TextStyle(color: Color(0xFF90CAF9), fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const VillageScreen()),
                  );
                },
                icon: const Icon(Icons.play_arrow),
                label: const Text('START NEW SCREENING',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsTab(AuthProvider auth) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1B2A),
        title: const Text('Settings', style: TextStyle(color: Colors.white)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Language
          _settingsTile('Language', Icons.language, subtitle: 'English'),
          _settingsTile('Nurse Profile', Icons.person, subtitle: auth.nurseName),
          const Divider(color: Color(0xFF1A2A3A)),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Logout', style: TextStyle(color: Colors.red)),
            onTap: () async {
              await auth.logout();
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (_) => false,
                );
              }
            },
          ),
          const Divider(color: Color(0xFF1A2A3A)),
          ListTile(
            leading: const Icon(Icons.info_outline, color: Color(0xFF546E7A)),
            title: const Text('App Version',
                style: TextStyle(color: Color(0xFF546E7A))),
            subtitle: const Text('v1.0.0',
                style: TextStyle(color: Color(0xFF546E7A))),
          ),
        ],
      ),
    );
  }

  Widget _settingsTile(String title, IconData icon, {String? subtitle}) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF90CAF9)),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      subtitle: subtitle != null
          ? Text(subtitle, style: const TextStyle(color: Color(0xFF546E7A)))
          : null,
      trailing: const Icon(Icons.chevron_right, color: Color(0xFF546E7A)),
    );
  }
}
