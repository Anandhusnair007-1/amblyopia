import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';
import '../config/api_config.dart';
import 'new_patient_screen.dart';

class VillageScreen extends StatefulWidget {
  const VillageScreen({super.key});

  @override
  State<VillageScreen> createState() => _VillageScreenState();
}

class _VillageScreenState extends State<VillageScreen> {
  List<Map<String, dynamic>> _villages = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadVillages();
    _searchCtrl.addListener(_onSearch);
  }

  Future<void> _loadVillages() async {
    setState(() => _loading = true);

    final isOnline = await ApiService.checkOnline();
    List<Map<String, dynamic>> villages = [];

    if (isOnline) {
      final res = await ApiService.get(ApiConfig.villageHeatmap);
      if (res['data'] is List) {
        villages = (res['data'] as List)
            .map((e) => e as Map<String, dynamic>)
            .toList();
        await DatabaseService.cacheVillages(villages);
      } else if (res['villages'] is List) {
        villages = (res['villages'] as List)
            .map((e) => e as Map<String, dynamic>)
            .toList();
        await DatabaseService.cacheVillages(villages);
      }
    }

    if (villages.isEmpty) {
      villages = await DatabaseService.getCachedVillages();
    }

    // If still empty, show demonstration data
    if (villages.isEmpty) {
      villages = _demoVillages();
    }

    if (mounted) {
      setState(() {
        _villages = villages;
        _filtered = villages;
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> _demoVillages() {
    return [
      {
        'id': 'v1',
        'name': 'Sulur',
        'district': 'Coimbatore',
        'status': 'green',
        'last_screened': DateTime.now()
            .subtract(const Duration(days: 5))
            .toIso8601String(),
        'children_count': 48,
      },
      {
        'id': 'v2',
        'name': 'Pollachi',
        'district': 'Coimbatore',
        'status': 'yellow',
        'last_screened': DateTime.now()
            .subtract(const Duration(days: 45))
            .toIso8601String(),
        'children_count': 63,
      },
      {
        'id': 'v3',
        'name': 'Mettupalayam',
        'district': 'Coimbatore',
        'status': 'red',
        'last_screened': null,
        'children_count': 31,
      },
      {
        'id': 'v4',
        'name': 'Kinathukadavu',
        'district': 'Coimbatore',
        'status': 'green',
        'last_screened': DateTime.now()
            .subtract(const Duration(days: 12))
            .toIso8601String(),
        'children_count': 27,
      },
    ];
  }

  void _onSearch() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = _villages
          .where((v) =>
              (v['name']?.toString() ?? '').toLowerCase().contains(q) ||
              (v['district']?.toString() ?? '').toLowerCase().contains(q))
          .toList();
    });
  }

  Color _statusColor(Map<String, dynamic> village) {
    final lastStr = village['last_screened']?.toString();
    if (lastStr == null || lastStr.isEmpty) return Colors.red;
    try {
      final last = DateTime.parse(lastStr);
      final diff = DateTime.now().difference(last).inDays;
      if (diff <= 30) return Colors.green;
      if (diff <= 90) return Colors.amber;
      return Colors.red;
    } catch (_) {
      return Colors.red;
    }
  }

  String _lastScreenedLabel(Map<String, dynamic> village) {
    final lastStr = village['last_screened']?.toString();
    if (lastStr == null || lastStr.isEmpty) return 'Never screened';
    try {
      final last = DateTime.parse(lastStr);
      final diff = DateTime.now().difference(last).inDays;
      if (diff == 0) return 'Screened today';
      if (diff == 1) return '1 day ago';
      return '$diff days ago';
    } catch (_) {
      return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1B2A),
        title: const Text('Select Village',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search village...',
                hintStyle: const TextStyle(color: Color(0xFF546E7A)),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF546E7A)),
                filled: true,
                fillColor: const Color(0xFF0D1B2A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF263238)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF263238)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF00E5FF)),
                ),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF00E5FF)))
                : _filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.location_off,
                                color: Color(0xFF546E7A), size: 48),
                            SizedBox(height: 16),
                            Text(
                              'No villages found.\nContact your coordinator.',
                              style: TextStyle(
                                  color: Color(0xFF546E7A), fontSize: 14),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadVillages,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _filtered.length,
                          itemBuilder: (context, i) {
                            final v = _filtered[i];
                            final statusColor = _statusColor(v);
                            return Card(
                              color: const Color(0xFF0D1B2A),
                              margin: const EdgeInsets.only(bottom: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                    color: statusColor.withOpacity(0.3)),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                leading: Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: statusColor,
                                    boxShadow: [
                                      BoxShadow(
                                        color: statusColor.withOpacity(0.5),
                                        blurRadius: 6,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                ),
                                title: Text(
                                  v['name']?.toString() ?? '',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      v['district']?.toString() ?? '',
                                      style: const TextStyle(
                                          color: Color(0xFF90CAF9), fontSize: 12),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _lastScreenedLabel(v),
                                      style: TextStyle(
                                          color: statusColor, fontSize: 11),
                                    ),
                                    if (v['children_count'] != null)
                                      Text(
                                        '${v['children_count']} children',
                                        style: const TextStyle(
                                            color: Color(0xFF546E7A),
                                            fontSize: 11),
                                      ),
                                  ],
                                ),
                                trailing: const Icon(Icons.chevron_right,
                                    color: Color(0xFF90CAF9)),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => NewPatientScreen(
                                        villageId: v['id']?.toString() ?? 'v1',
                                        villageName: v['name']?.toString() ?? 'Village',
                                      ),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }
}
