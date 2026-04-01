// ignore_for_file: unused_element

import 'dart:async';
import 'dart:io';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/ambyo_theme.dart';
import '../../../core/theme/ambyoai_design_system.dart';
import '../../../core/widgets/ambyoai_snackbar.dart';
import '../../../core/widgets/ambyoai_widgets.dart';
import '../../../core/widgets/enterprise_ui.dart';
import '../../../core/widgets/language_selector_widget.dart';
import '../../../core/widgets/offline_banner.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/patient_provider.dart';
import '../../auth/screens/patient_login_screen.dart';
import '../../offline/database_tables.dart';
import '../../offline/local_database.dart';
import '../../../core/providers/language_provider.dart';
import '../widgets/patient_bottom_nav.dart';

class PatientProfileScreen extends ConsumerStatefulWidget {
  const PatientProfileScreen({super.key});

  @override
  ConsumerState<PatientProfileScreen> createState() =>
      _PatientProfileScreenState();
}

class _PatientProfileScreenState extends ConsumerState<PatientProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  Future<_ProfileData>? _loader;

  final _name = TextEditingController();
  final _age = TextEditingController();
  String _gender = 'Unknown';
  String _language = 'en';

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loader = _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _age.dispose();
    super.dispose();
  }

  Future<_ProfileData> _load() async {
    final langProvider = context.read<LanguageProvider>();
    _language = langProvider.code;
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString('patient_phone') ??
        prefs.getString('ambyoai_user_phone');
    final patientId = prefs.getString('patient_id');

    if (phone == null || phone.isEmpty) {
      return _ProfileData.notLoggedIn();
    }

    await ref.read(patientProvider).loadPatient(phone);
    final patient = ref.read(patientProvider).current;
    if (patient == null) {
      return _ProfileData.notLoggedIn();
    }

    final resolvedId = patientId ?? patient.id;
    await prefs.setString('patient_id', resolvedId);

    _name.text = patient.name;
    _age.text = patient.age.toString();
    _gender = patient.gender;

    final db = LocalDatabase.instance;
    final sessions = await db.getSessionsForPatient(resolvedId);
    final predictions =
        await db.recentPredictionsForPatient(resolvedId, limit: 7);

    DateTime? first;
    DateTime? last;
    if (sessions.isNotEmpty) {
      last = sessions.first.testDate.toLocal();
      first = sessions.last.testDate.toLocal();
    }

    final trend = _riskTrend(predictions);
    return _ProfileData(
      patientId: resolvedId,
      phone: patient.phone,
      patient: patient,
      totalSessions: sessions.length,
      firstScreening: first,
      lastScreening: last,
      riskTrendLabel: trend,
      recentPredictionScores:
          predictions.map((p) => p.riskScore).toList(growable: false),
    );
  }

  String _riskTrend(List<AIPrediction> preds) {
    if (preds.length < 2) return '—';
    final latest = preds[0].riskScore;
    final prev = preds[1].riskScore;
    final delta = latest - prev;
    if (delta.abs() < 0.02) return 'Stable →';
    if (delta < 0) return 'Improving ↓';
    return 'Worsening ↑';
  }

  Future<void> _save(_ProfileData data) async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;
    final current = ref.read(patientProvider).current;
    if (current == null) return;

    final name = _name.text.trim();
    final age = int.tryParse(_age.text.trim()) ?? 0;

    final langProvider = context.read<LanguageProvider>();
    setState(() => _saving = true);
    final updated = current.copyWith(
      name: name,
      age: age,
      gender: _gender,
    );
    await ref.read(patientProvider).updatePatient(updated);
    await langProvider.setLanguage(_languageFromCode(_language));

    if (!mounted) return;
    setState(() {
      _saving = false;
      _loader = _load();
    });
    AmbyoSnackbar.show(context,
        message: 'Profile saved.', type: SnackbarType.success);
  }

  AppLanguage _languageFromCode(String code) {
    switch (code) {
      case 'ml':
        return AppLanguage.malayalam;
      case 'hi':
        return AppLanguage.hindi;
      case 'ta':
        return AppLanguage.tamil;
      default:
        return AppLanguage.english;
    }
  }

  Future<void> _logout() async {
    await RoleStorage.clearSession();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('patient_phone');
    await prefs.remove('patient_id');
    if (!mounted) return;
    ref.read(patientProvider).clear();
    ref.read(roleProvider.notifier).state = UserRole.none;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const PatientLoginScreen()),
      (_) => false,
    );
  }

  Future<void> _deleteAllData(_ProfileData data) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete All Local Data?'),
        content: const Text(
          'This will delete all sessions, test results, and PDF reports for this patient on this device. This cannot be undone.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style:
                FilledButton.styleFrom(backgroundColor: AmbyoTheme.dangerColor),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final paths =
        await LocalDatabase.instance.pdfPathsForPatient(data.patientId);
    await LocalDatabase.instance.deletePatientData(data.patientId);
    for (final p in paths) {
      try {
        final f = File(p);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
    await _logout();
  }

  @override
  Widget build(BuildContext context) {
    return OfflineBanner(
      child: EnterpriseScaffold(
        title: 'My Profile',
        subtitle: 'Patient details',
        appBarStyle: EnterpriseAppBarStyle.light,
        surfaceStyle: EnterpriseSurfaceStyle.plain,
        backgroundColor: AmbyoColors.backgroundColor,
        actions: [
          const LanguageSelectorWidget(),
          IconButton(
            tooltip: 'About',
            icon: const Icon(Icons.settings_rounded),
            onPressed: () => Navigator.of(context).pushNamed('/about'),
          ),
        ],
        bottomNavigationBar: const PatientBottomNav(
          currentRoute: AppRouter.patientProfile,
          light: true,
        ),
        child: FutureBuilder<_ProfileData>(
          future: _loader,
          builder: (context, snapshot) {
            final data = snapshot.data;
            if (snapshot.connectionState != ConnectionState.done ||
                data == null) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!data.isLoggedIn) {
              return EnterpriseEmptyState(
                icon: Icons.person_outline_rounded,
                title: 'Sign in required',
                message: 'Log in with your phone number to edit your profile.',
                buttonLabel: 'Go to Login',
                onPressed: _logout,
              );
            }

            return ListView(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: const BoxDecoration(
                          color: Colors.white24,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            data.patient.name.isNotEmpty
                                ? data.patient.name[0].toUpperCase()
                                : 'P',
                            style: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'Poppins',
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data.patient.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'Poppins',
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '+91 ${data.phone}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontFamily: 'Poppins',
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                EnterprisePanel(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const EnterpriseSectionHeader(
                          title: 'Profile',
                          subtitle:
                              'Update your details used in reports and screening summaries.',
                        ),
                        const SizedBox(height: 16),
                        AmbyoTextField(
                          controller: _name,
                          label: 'Full Name',
                          hint: 'Your full name',
                          prefixIcon: Icons.badge_rounded,
                          textInputAction: TextInputAction.next,
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Name is required.'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        AmbyoTextField(
                          controller: _age,
                          label: 'Age',
                          hint: 'Years',
                          prefixIcon: Icons.cake_rounded,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.next,
                          validator: (v) {
                            final n = int.tryParse((v ?? '').trim());
                            if (n == null || n < 1 || n > 120) {
                              return 'Enter a valid age (1–120).';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Gender',
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFF13213A),
                                  ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children:
                              ['Male', 'Female', 'Other', 'Unknown'].map((g) {
                            final selected = _gender == g;
                            return ChoiceChip(
                              label: Text(g),
                              selected: selected,
                              onSelected: (_) => setState(() => _gender = g),
                              selectedColor: AmbyoTheme.primaryColor
                                  .withValues(alpha: 0.14),
                              labelStyle: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: selected
                                    ? AmbyoTheme.primaryColor
                                    : const Color(0xFF334155),
                              ),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(999)),
                            );
                          }).toList(growable: false),
                        ),
                        const SizedBox(height: 12),
                        AmbyoTextField(
                          label: 'Phone',
                          hint: data.phone,
                          prefixIcon: Icons.phone_iphone_rounded,
                          readOnly: true,
                          textInputAction: TextInputAction.done,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Language preference',
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFF13213A),
                                  ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: const <(String, String)>[
                            ('English', 'en'),
                            ('Malayalam', 'ml'),
                            ('Hindi', 'hi'),
                            ('Tamil', 'ta'),
                          ].map((pair) {
                            final label = pair.$1;
                            final code = pair.$2;
                            final selected = _language == code;
                            return ChoiceChip(
                              label: Text(label),
                              selected: selected,
                              onSelected: (_) =>
                                  setState(() => _language = code),
                              selectedColor: AmbyoTheme.primaryColor
                                  .withValues(alpha: 0.14),
                              labelStyle: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: selected
                                    ? AmbyoTheme.primaryColor
                                    : const Color(0xFF334155),
                              ),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(999)),
                            );
                          }).toList(growable: false),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _saving ? null : () => _save(data),
                            child: Text(_saving ? 'Saving...' : 'Save Changes'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                EnterprisePanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const EnterpriseSectionHeader(
                        title: 'Screening Stats',
                        subtitle:
                            'Local records for this patient on this device.',
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: EnterpriseMetricCard(
                              title: 'Total Sessions',
                              value: '${data.totalSessions}',
                              icon: Icons.fact_check_rounded,
                              tint: AmbyoTheme.primaryColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: EnterpriseMetricCard(
                              title: 'Last Screening',
                              value: data.lastScreening == null
                                  ? '—'
                                  : _fmtDate(data.lastScreening!),
                              icon: Icons.schedule_rounded,
                              tint: AmbyoTheme.secondaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: EnterpriseMetricCard(
                              title: 'First Screening',
                              value: data.firstScreening == null
                                  ? '—'
                                  : _fmtDate(data.firstScreening!),
                              icon: Icons.history_rounded,
                              tint: AmbyoTheme.accentColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: EnterpriseMetricCard(
                              title: 'Risk Trend',
                              value: data.riskTrendLabel,
                              icon: Icons.trending_down_rounded,
                              tint: const Color(0xFF1565C0),
                            ),
                          ),
                        ],
                      ),
                      if (data.recentPredictionScores.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        SizedBox(
                          height: 160,
                          child:
                              _RiskChart(scores: data.recentPredictionScores),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                EnterprisePanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Danger Zone',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: AmbyoTheme.dangerColor,
                                  fontWeight: FontWeight.w900,
                                ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Delete all local data for this patient. This logs you out and removes PDFs.',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: const Color(0xFF66748B)),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                              backgroundColor: AmbyoTheme.dangerColor),
                          onPressed: () => _deleteAllData(data),
                          icon: const Icon(Icons.delete_forever_rounded),
                          label: const Text('Delete All My Data'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _logout,
                          icon: const Icon(Icons.logout_rounded),
                          label: const Text('Log Out'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.initial});

  final String initial;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: AmbyoTheme.primaryColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: AmbyoTheme.primaryColor,
          ),
        ),
      ),
    );
  }
}

class _RiskChart extends StatelessWidget {
  const _RiskChart({required this.scores});

  final List<double> scores;

  @override
  Widget build(BuildContext context) {
    final points = <FlSpot>[];
    for (var i = 0; i < scores.length; i++) {
      points.add(FlSpot(i.toDouble(), scores[i].clamp(0.0, 1.0)));
    }

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: points,
            isCurved: true,
            barWidth: 4,
            color: AmbyoTheme.primaryColor,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: AmbyoTheme.primaryColor.withValues(alpha: 0.14),
            ),
          ),
        ],
        minY: 0,
        maxY: 1,
      ),
    );
  }
}

class _ProfileData {
  const _ProfileData({
    required this.patientId,
    required this.phone,
    required this.patient,
    required this.totalSessions,
    required this.firstScreening,
    required this.lastScreening,
    required this.riskTrendLabel,
    required this.recentPredictionScores,
  });

  _ProfileData.notLoggedIn()
      : patientId = '',
        phone = '',
        patient = Patient(
          id: '',
          name: '',
          age: 0,
          gender: '',
          phone: '',
          createdAt: DateTime.fromMillisecondsSinceEpoch(0).toUtc(),
        ),
        totalSessions = 0,
        firstScreening = null,
        lastScreening = null,
        riskTrendLabel = '—',
        recentPredictionScores = const <double>[];

  final String patientId;
  final String phone;
  final Patient patient;
  final int totalSessions;
  final DateTime? firstScreening;
  final DateTime? lastScreening;
  final String riskTrendLabel;
  final List<double> recentPredictionScores;

  bool get isLoggedIn => patientId.isNotEmpty;
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
