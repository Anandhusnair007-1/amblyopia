import 'package:flutter/material.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/ambyo_theme.dart';
import '../../../core/theme/ambyoai_design_system.dart';
import '../../../core/widgets/ambyoai_empty_state.dart';
import '../../../core/widgets/ambyoai_list_item.dart';
import '../../../core/widgets/ambyoai_widgets.dart';
import '../../../core/widgets/enterprise_ui.dart';
import '../../../core/widgets/offline_banner.dart';
import '../../../features/offline/local_database.dart';

class DoctorPatientListScreen extends StatefulWidget {
  const DoctorPatientListScreen({super.key});

  @override
  State<DoctorPatientListScreen> createState() =>
      _DoctorPatientListScreenState();
}

class _DoctorPatientListScreenState extends State<DoctorPatientListScreen> {
  Future<List<Map<String, dynamic>>>? _loader;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  _DoctorFilter _filter = _DoctorFilter.all;

  @override
  void initState() {
    super.initState();
    _loader = _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    return LocalDatabase.instance.getAllPatientsWithRisk();
  }

  @override
  Widget build(BuildContext context) {
    return OfflineBanner(
      child: EnterpriseScaffold(
        title: 'All Patients',
        subtitle: 'Local sessions',
        appBarStyle: EnterpriseAppBarStyle.light,
        surfaceStyle: EnterpriseSurfaceStyle.plain,
        backgroundColor: AmbyoColors.darkBg,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _loader,
          builder: (context, snapshot) {
            final patients = snapshot.data;
            if (snapshot.connectionState != ConnectionState.done ||
                patients == null) {
              return const _DoctorListLoading();
            }

            final filtered = _apply(patients);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search_rounded),
                    hintText: 'Search by name or phone...',
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                          ),
                  ),
                  onChanged: (v) => setState(() => _query = v.trim()),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _DoctorFilter.values.map((f) {
                      final selected = _filter == f;
                      return Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: ChoiceChip(
                          label: Text(f.label),
                          selected: selected,
                          onSelected: (_) => setState(() => _filter = f),
                          backgroundColor: AmbyoColors.darkCard,
                          selectedColor:
                              AmbyoTheme.primaryColor.withValues(alpha: 0.24),
                          side: BorderSide(
                            color: selected
                                ? AmbyoTheme.primaryColor
                                : AmbyoColors.darkBorder,
                          ),
                          labelStyle: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: selected ? Colors.white : Colors.white70,
                          ),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999)),
                        ),
                      );
                    }).toList(growable: false),
                  ),
                ),
                const SizedBox(height: 14),
                if (filtered.isEmpty)
                  const Expanded(
                    child: AmbyoEmptyState(
                      icon: Icons.people_outline,
                      title: 'No Patients Yet',
                      subtitle:
                          'Patients appear here after their first screening.',
                    ),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final p = filtered[index];
                        final patientId = (p['id'] ?? '').toString();
                        final name = (p['name'] ?? 'Child').toString();
                        final age = (p['age'] ?? '').toString();
                        final phone = (p['phone'] ?? '').toString();
                        final date = DateTime.tryParse(
                                (p['last_session_date'] ?? '').toString())
                            ?.toLocal();
                        final riskLevel = (p['latest_risk'] ?? '').toString();
                        final pill = _riskPill(riskLevel);

                        final riskColor = AmbyoColors.riskColor(pill.label);
                        final initials =
                            name.isNotEmpty ? name.substring(0, 1) : '?';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: AmbyoListItem(
                            leading: ambyoAvatar(
                                initials: initials, color: riskColor),
                            title: name,
                            subtitle: [
                              if (age.isNotEmpty) 'Age: $age',
                              if (phone.isNotEmpty) 'Phone: $phone'
                            ].join('  ·  '),
                            caption:
                                'Last screened: ${date == null ? '-' : _fmtDate(date)}',
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AmbyoRiskBadge(level: pill.label),
                                const SizedBox(width: 4),
                                const Icon(Icons.chevron_right_rounded,
                                    color: AmbyoColors.textSecondary,
                                    size: AmbyoSpacing.iconMd),
                              ],
                            ),
                            borderLeftColor: riskColor,
                            onTap: patientId.isEmpty
                                ? null
                                : () => Navigator.of(context).pushNamed(
                                        AppRouter.doctorPatientDetail,
                                        arguments: {
                                          'patientId': patientId,
                                          'patientName': name
                                        }),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _apply(List<Map<String, dynamic>> list) {
    final q = _query.toLowerCase();
    return list.where((row) {
      final name = (row['name'] ?? '').toString().toLowerCase();
      final phone = (row['phone'] ?? '').toString().toLowerCase();
      final risk = (row['latest_risk'] ?? row['risk_level'] ?? '').toString();
      final pending = row['pending_diagnoses'] as int? ?? 0;
      final diagnosed = pending == 0;

      if (q.isNotEmpty && !name.contains(q) && !phone.contains(q)) return false;
      return _filter.accepts(risk: risk, diagnosed: diagnosed);
    }).toList(growable: false);
  }
}

class _DoctorListLoading extends StatelessWidget {
  const _DoctorListLoading();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      itemCount: 5,
      itemBuilder: (_, __) => const Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: AmbyoShimmer(height: 72),
      ),
    );
  }
}

enum _DoctorFilter {
  all,
  urgent,
  high,
  mild,
  normal,
  undiagnosed;

  String get label {
    switch (this) {
      case _DoctorFilter.all:
        return 'All';
      case _DoctorFilter.urgent:
        return 'Urgent';
      case _DoctorFilter.high:
        return 'High';
      case _DoctorFilter.mild:
        return 'Mild';
      case _DoctorFilter.normal:
        return 'Normal';
      case _DoctorFilter.undiagnosed:
        return 'Undiagnosed';
    }
  }

  bool accepts({required String risk, required bool diagnosed}) {
    final upper = risk.toUpperCase();
    switch (this) {
      case _DoctorFilter.all:
        return true;
      case _DoctorFilter.urgent:
        return upper.contains('URGENT');
      case _DoctorFilter.high:
        return upper.contains('HIGH') ||
            upper.contains('SEVERE') ||
            upper.contains('MODERATE');
      case _DoctorFilter.mild:
        return upper.contains('MILD') || upper.contains('MEDIUM');
      case _DoctorFilter.normal:
        return upper.contains('NORMAL') || upper.contains('LOW');
      case _DoctorFilter.undiagnosed:
        return !diagnosed;
    }
  }
}

({String label, Color color}) _riskPill(String riskLevel) {
  final upper = riskLevel.toUpperCase();
  if (upper.contains('URGENT')) {
    return (label: 'URGENT', color: AmbyoTheme.dangerColor);
  }
  if (upper.contains('HIGH') ||
      upper.contains('SEVERE') ||
      upper.contains('MODERATE')) {
    return (label: 'HIGH', color: AmbyoColors.highOrange);
  }
  if (upper.contains('MILD') || upper.contains('MEDIUM')) {
    return (label: 'MILD', color: AmbyoTheme.warningColor);
  }
  if (upper.contains('NORMAL') || upper.contains('LOW')) {
    return (label: 'NORMAL', color: AmbyoTheme.successColor);
  }
  return (label: 'PENDING', color: AmbyoColors.unscreened);
}

String _fmtDate(DateTime dt) {
  return '${dt.day.toString().padLeft(2, '0')} ${_month(dt.month)} ${dt.year}';
}

String _month(int m) {
  const names = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];
  return names[(m - 1).clamp(0, 11)];
}
