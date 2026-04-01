// ignore_for_file: unused_element

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/ambyo_theme.dart';
import '../../../core/theme/ambyoai_design_system.dart';
import '../../../core/widgets/ambyoai_widgets.dart';
import '../../../core/widgets/offline_banner.dart';
import '../../../core/services/permission_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/patient_provider.dart';
import '../../auth/screens/patient_login_screen.dart';
import '../../consent/consent_flow.dart';
import '../../offline/database_tables.dart';
import '../../offline/local_database.dart';
import '../widgets/patient_bottom_nav.dart';

class PatientHomeScreen extends ConsumerStatefulWidget {
  const PatientHomeScreen({super.key});

  @override
  ConsumerState<PatientHomeScreen> createState() => _PatientHomeScreenState();
}

class _PatientHomeScreenState extends ConsumerState<PatientHomeScreen> {
  Future<_PatientHomeData>? _loader;

  String _displayName(String? raw) {
    final n = (raw ?? '').trim();
    if (n.isEmpty || n == 'Patient' || RegExp(r'^\d{8,12}$').hasMatch(n))
      return 'there';
    return n.split(' ').first;
  }

  bool _needsSetupBanner(String? raw) {
    final n = (raw ?? '').trim();
    return n.isEmpty || n == 'Patient' || RegExp(r'^\d{8,12}$').hasMatch(n);
  }

  (String value, String risk) _resultInfo(String test, TestResult? result) {
    if (result == null) return ('', 'UNSCREENED');
    final d = result.details;
    switch (test) {
      case 'gaze_detection':
        final v =
            (d['prismDiopterValue'] ?? d['prism_diopter'] ?? '').toString();
        return (
          v.isEmpty ? 'Done' : '$v Δ',
          ((d['requiresUrgentReferral'] ?? false) == true) ? 'URGENT' : 'NORMAL'
        );
      case 'red_reflex':
        final normal = (d['isNormal'] ?? d['is_normal'] ?? false) == true;
        return (normal ? 'Normal' : 'Review', normal ? 'NORMAL' : 'HIGH');
      case 'snellen_chart':
        final v = (d['visual_acuity'] ?? d['visualAcuity'] ?? '').toString();
        final ref = (d['requires_referral'] ?? false) == true;
        return (v.isEmpty ? 'Done' : v, ref ? 'MILD' : 'NORMAL');
      default:
        final ref =
            ((d['requires_referral'] ?? d['requiresReferral'] ?? false) ==
                    true) ||
                ((d['isAbnormal'] ?? d['is_abnormal'] ?? false) == true);
        return ('Done', ref ? 'MILD' : 'NORMAL');
    }
  }

  String _dateText(TestResult? result) {
    if (result == null) return '';
    final delta = DateTime.now().toUtc().difference(result.createdAt.toUtc());
    if (delta.inDays >= 1) return '${delta.inDays}d ago';
    if (delta.inHours >= 1) return '${delta.inHours}h ago';
    return '${delta.inMinutes}m ago';
  }

  @override
  void initState() {
    super.initState();
    _loader = _load();
  }

  Future<_PatientHomeData> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString('patient_phone') ??
        prefs.getString('ambyoai_user_phone') ??
        '';
    final patientId = prefs.getString('patient_id');

    if (phone.isNotEmpty) {
      await ref.read(patientProvider).loadPatient(phone);
      if (ref.read(patientProvider).current == null) {
        await ref.read(patientProvider).createPatient(phone);
      }
    }

    final patient = ref.read(patientProvider).current;
    final resolvedPatientId = patientId ?? patient?.id;
    if (resolvedPatientId == null) {
      return const _PatientHomeData.empty();
    }

    final db = LocalDatabase.instance;
    final totalSessions = await db.countSessionsForPatient(resolvedPatientId);
    final lastSessionDate =
        await db.latestSessionDateForPatient(resolvedPatientId);
    final reportsReady = await db.countReportsForPatient(resolvedPatientId);
    final prediction = await db.latestPredictionForPatient(resolvedPatientId);

    const tests = <String>[
      'gaze_detection',
      'hirschberg',
      'prism_diopter',
      'red_reflex',
      'suppression_test',
      'depth_perception',
      'titmus_stereo',
      'lang_stereo',
      'ishihara_color',
      'snellen_chart',
      'worth_four_dot',
    ];

    final latestResults = <String, TestResult?>{};
    for (final t in tests) {
      final r = await db.latestResultForTest(resolvedPatientId, t);
      latestResults[t] = r;
    }

    final recentReports =
        await db.recentReportsForPatient(resolvedPatientId, limit: 3);

    return _PatientHomeData(
      patientId: resolvedPatientId,
      phone: phone,
      totalSessions: totalSessions,
      lastSessionDate: lastSessionDate,
      reportsReady: reportsReady,
      latestPrediction: prediction,
      latestResults: latestResults,
      recentReports: recentReports,
    );
  }

  Future<void> _startFullScreening(_PatientHomeData data) async {
    final patient = ref.read(patientProvider).current;
    if (patient == null) return;
    final ok = await PermissionService.checkCameraAndMic(context);
    if (!ok) return;
    if (!mounted) return;

    final started = await ensureConsentThenStartScreening(
      context,
      patient,
      screener: 'AmbyoAI App',
    );
    if (mounted && started) setState(() => _loader = _load());
  }

  Future<void> _runSingleTest(_PatientHomeData data, String testName) async {
    final patient = ref.read(patientProvider).current;
    if (patient == null) return;
    final ok = await PermissionService.checkCameraAndMic(context);
    if (!ok) return;
    if (!mounted) return;

    await ensureConsentThenRunSingleTest(
      context,
      patient,
      testName,
      screener: 'AmbyoAI App',
    );
    if (mounted) setState(() => _loader = _load());
  }

  Future<void> _openIndividualTestPicker(_PatientHomeData data) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _IndividualTestPickerSheet(
          latestResults: data.latestResults,
          onRun: (testName) async {
            Navigator.of(context).pop();
            await _runSingleTest(data, testName);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final patient = ref.watch(patientProvider).current;

    return OfflineBanner(
      child: Scaffold(
        backgroundColor: AmbyoColors.darkBg,
        bottomNavigationBar:
            const PatientBottomNav(currentRoute: AppRouter.patientHome),
        body: SafeArea(
          child: FutureBuilder<_PatientHomeData>(
            future: _loader,
            builder: (context, snapshot) {
              final data = snapshot.data;
              if (snapshot.connectionState != ConnectionState.done ||
                  data == null) {
                return _LoadingState(
                  onLogout: () async {
                    await RoleStorage.clearSession();
                    if (!context.mounted) return;
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute<void>(
                          builder: (_) => const PatientLoginScreen()),
                      (route) => false,
                    );
                  },
                );
              }

              final (riskLabel, _) = () {
                final pred = data.latestPrediction;
                if (pred == null) return ('UNSCREENED', AmbyoColors.unscreened);
                final level = (pred.riskLevel ?? '').toString().toUpperCase();
                if (level.contains('URGENT'))
                  return ('URGENT', AmbyoColors.urgentRed);
                if (level.contains('HIGH'))
                  return ('HIGH', AmbyoColors.highOrange);
                if (level.contains('MILD') || level.contains('MEDIUM'))
                  return ('MILD', AmbyoColors.mildAmber);
                return ('NORMAL', AmbyoColors.normalGreen);
              }();
              final score = () {
                final pred = data.latestPrediction;
                if (pred == null) return 0.0;
                final s = pred.riskScore;
                if (s is num)
                  return ((1 - s.toDouble()) * 100).clamp(0.0, 100.0);
                return 0.0;
              }();
              final displayName = _displayName(patient?.name);
              final needsSetup = _needsSetupBanner(patient?.name);

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AmbyoGradients.primaryBtn,
                        ),
                        child: Center(
                          child: Text(
                            displayName.substring(0, 1).toUpperCase(),
                            style: const TextStyle(
                                fontFamily: 'Poppins',
                                color: Colors.white,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Welcome back,',
                              style: TextStyle(
                                  fontFamily: 'Poppins',
                                  color: Colors.white54,
                                  fontSize: 12)),
                          Text(displayName,
                              style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const Spacer(),
                      IconButton(
                          onPressed: () {},
                          icon: const Icon(Icons.notifications_outlined,
                              color: Colors.white54)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (needsSetup)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AmbyoColors.electricBlue.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AmbyoColors.electricBlue.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.person_outline,
                              color: AmbyoColors.cyanAccent, size: 18),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text('Add your name to personalize reports',
                                style: TextStyle(
                                    color: Colors.white70,
                                    fontFamily: 'Poppins',
                                    fontSize: 13)),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.of(context)
                                .pushNamed(AppRouter.patientProfile),
                            child: const Text('Setup →',
                                style: TextStyle(
                                    color: AmbyoColors.cyanAccent,
                                    fontFamily: 'Poppins',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ),
                  GlassCard(
                    radius: 20,
                    borderColor: AmbyoColors.darkBorder,
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Eye Health Score',
                                  style: TextStyle(
                                      fontFamily: 'Poppins',
                                      color: Colors.white60,
                                      fontSize: 13)),
                              const SizedBox(height: 8),
                              TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0, end: score),
                                duration: const Duration(milliseconds: 800),
                                builder: (context, val, _) => Text(
                                  score == 0 ? '–' : '${val.round()}',
                                  style: const TextStyle(
                                      fontFamily: 'JetBrainsMono',
                                      fontSize: 48,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      height: 1),
                                ),
                              ),
                              const SizedBox(height: 8),
                              NeonRiskBadge(level: riskLabel),
                            ],
                          ),
                        ),
                        const SizedBox(width: 20),
                        ScoreRing3D(
                            score: score, size: 100, riskLevel: riskLabel),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      FloatingStatCard(
                          value: '${data.totalSessions}',
                          label: 'Tests',
                          icon: Icons.science_outlined,
                          color: AmbyoColors.testGaze,
                          index: 0),
                      const SizedBox(width: 8),
                      FloatingStatCard(
                        value: data.lastSessionDate == null
                            ? '—'
                            : '${DateTime.now().toUtc().difference(data.lastSessionDate!.toUtc()).inDays}d',
                        label: 'Last Scan',
                        icon: Icons.schedule_outlined,
                        color: AmbyoColors.testBlue,
                        index: 1,
                      ),
                      const SizedBox(width: 8),
                      FloatingStatCard(
                          value: '${data.reportsReady}',
                          label: 'Reports',
                          icon: Icons.description_outlined,
                          color: AmbyoColors.testPurple,
                          index: 2),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const _PatientActionHeader(),
                  const SizedBox(height: 14),
                  _ActionModeCard(
                    title: 'Full Test',
                    subtitle:
                        'Run the complete guided screening workflow with consent, scan, all tests, and final report.',
                    meta: '11 tests  ·  guided flow  ·  report included',
                    accent: const Color(0xFF00B4D8),
                    icon: Icons.monitor_heart_outlined,
                    cta: 'Start Full Test',
                    onTap: () => _startFullScreening(data),
                  ),
                  const SizedBox(height: 12),
                  _ActionModeCard(
                    title: 'Individual Test',
                    subtitle:
                        'Choose one clinical test only. Best for repeat checks, targeted review, or quick follow-up.',
                    meta: 'single module  ·  consent checked  ·  faster run',
                    accent: const Color(0xFF7C3AED),
                    icon: Icons.tune_rounded,
                    cta: 'Choose Individual Test',
                    onTap: () => _openIndividualTestPicker(data),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      const Text(
                        'Recent Reports',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => Navigator.of(context)
                            .pushReplacementNamed(AppRouter.myReports),
                        child: const Text(
                          'View All →',
                          style: TextStyle(
                            color: Color(0xFF00B4D8),
                            fontFamily: 'Poppins',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _RecentReportsList(
                    reports: data.recentReports,
                    onView: (path) => Navigator.of(context).pushNamed(
                      AppRouter.reportPreview,
                      arguments: <String, dynamic>{
                        'pdfPath': path,
                        'reportData': null
                      },
                    ),
                    onShare: (path) => Share.shareXFiles([XFile(path)]),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _PatientHomeData {
  const _PatientHomeData({
    required this.patientId,
    required this.phone,
    required this.totalSessions,
    required this.lastSessionDate,
    required this.reportsReady,
    required this.latestPrediction,
    required this.latestResults,
    required this.recentReports,
  });

  final String patientId;
  final String phone;
  final int totalSessions;
  final DateTime? lastSessionDate;
  final int reportsReady;
  final dynamic latestPrediction;
  final Map<String, TestResult?> latestResults;
  final List<Map<String, Object?>> recentReports;

  const _PatientHomeData.empty()
      : patientId = '',
        phone = '',
        totalSessions = 0,
        lastSessionDate = null,
        reportsReady = 0,
        latestPrediction = null,
        latestResults = const <String, TestResult?>{},
        recentReports = const <Map<String, Object?>>[];
}

class _PatientActionHeader extends StatelessWidget {
  const _PatientActionHeader();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Text(
          'Screening Modes',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            fontFamily: 'Poppins',
          ),
        ),
        Spacer(),
        Text(
          'Choose one of two paths',
          style: TextStyle(
            color: Colors.white38,
            fontFamily: 'Poppins',
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _ActionModeCard extends StatelessWidget {
  const _ActionModeCard({
    required this.title,
    required this.subtitle,
    required this.meta,
    required this.accent,
    required this.icon,
    required this.cta,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String meta;
  final Color accent;
  final IconData icon;
  final String cta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      radius: 22,
      borderColor: accent.withValues(alpha: 0.28),
      glowColor: accent,
      backgroundColor: const Color(0xE8141E2C),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: accent.withValues(alpha: 0.28)),
                ),
                child: Icon(icon, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      meta,
                      style: TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.56),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              height: 1.5,
              color: Colors.white.withValues(alpha: 0.76),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onTap,
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                cta,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IndividualTestPickerSheet extends StatelessWidget {
  const _IndividualTestPickerSheet({
    required this.latestResults,
    required this.onRun,
  });

  final Map<String, TestResult?> latestResults;
  final Future<void> Function(String testName) onRun;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.56,
      maxChildSize: 0.92,
      builder: (context, controller) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0C1421),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Choose Individual Test',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Run one test only. Each selection still uses the same guided enterprise workflow.',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        height: 1.5,
                        color: Colors.white.withValues(alpha: 0.68),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  itemCount: _TestGrid._tests.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final def = _TestGrid._tests[index];
                    final result = latestResults[def.testName];
                    final subtitle = result == null
                        ? 'Not run yet'
                        : 'Last run: ${result.createdAt.toLocal().day.toString().padLeft(2, '0')}/${result.createdAt.toLocal().month.toString().padLeft(2, '0')}';
                    return InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => onRun(def.testName),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF131E2E),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: def.accentColor.withValues(alpha: 0.22),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: def.accentColor.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(def.icon, color: def.accentColor),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    def.title,
                                    style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    subtitle,
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 12,
                                      color:
                                          Colors.white.withValues(alpha: 0.56),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 16,
                              color: Colors.white54,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState({required this.onLogout});

  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      children: [
        const SizedBox(height: 16),
        const AmbyoShimmer(height: 56, dark: true),
        const SizedBox(height: 14),
        const AmbyoShimmer(height: 140, dark: true),
        const SizedBox(height: 12),
        const Row(
          children: [
            Expanded(child: AmbyoShimmer(height: 80, dark: true)),
            SizedBox(width: 10),
            Expanded(child: AmbyoShimmer(height: 80, dark: true)),
            SizedBox(width: 10),
            Expanded(child: AmbyoShimmer(height: 80, dark: true)),
          ],
        ),
        const SizedBox(height: 16),
        const AmbyoShimmer(height: 60, dark: true),
        const SizedBox(height: 20),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.05,
          ),
          itemCount: 10,
          itemBuilder: (_, __) => const AmbyoShimmer(height: 140, dark: true),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onLogout,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white54,
              side: const BorderSide(color: Color(0xFF2C2C2C)),
            ),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Log Out'),
          ),
        ),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.name});

  final String name;

  /// Returns display name — hides default 'Patient' placeholder and raw phone numbers.
  String _displayName() {
    final n = name.trim();
    if (n.isEmpty || n == 'Patient' || RegExp(r'^\d{7,}$').hasMatch(n))
      return '';
    return n;
  }

  String _initials(String display) {
    if (display.isEmpty) return '👁';
    final parts = display.split(' ');
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return parts.first[0].toUpperCase() + parts.last[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final display = _displayName();
    final initials = display.isEmpty ? null : _initials(display);

    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [Color(0xFF1565C0), Color(0xFF00B4D8)],
            ),
          ),
          child: Center(
            child: initials != null
                ? Text(
                    initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Poppins',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                : const Icon(Icons.remove_red_eye_outlined,
                    color: Colors.white, size: 18),
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              display.isNotEmpty ? 'Welcome back,' : 'AmbyoAI',
              style: const TextStyle(
                color: Colors.white54,
                fontFamily: 'Poppins',
                fontSize: 12,
              ),
            ),
            Text(
              display.isNotEmpty ? display : 'Eye Screening',
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'Poppins',
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.notifications_outlined, color: Colors.white54),
          onPressed: () {},
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            fontFamily: 'Poppins',
          ),
        ),
        const Spacer(),
        if (subtitle.isNotEmpty)
          Text(
            subtitle,
            style: const TextStyle(
              color: Colors.white38,
              fontFamily: 'Poppins',
              fontSize: 12,
            ),
          ),
      ],
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.name,
    required this.age,
    required this.phone,
    required this.lastScreened,
    required this.prediction,
  });

  final String name;
  final int age;
  final String phone;
  final DateTime? lastScreened;
  final dynamic prediction;

  @override
  Widget build(BuildContext context) {
    final (riskLabel, riskColor) = _riskForPrediction(prediction);
    final healthScore = _healthScore(prediction);
    final last = lastScreened == null
        ? 'Not screened yet'
        : 'Last screened ${_relative(lastScreened!)}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF2C2C2C)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Eye Health Score',
                  style: TextStyle(
                    color: Colors.white70,
                    fontFamily: 'Poppins',
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                _AnimatedScore(score: healthScore),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: riskColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    riskLabel,
                    style: TextStyle(
                      color: riskColor,
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  last,
                  style: const TextStyle(
                    color: Colors.white38,
                    fontFamily: 'Poppins',
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          _CircularScoreRing(score: healthScore, size: 100, color: riskColor),
        ],
      ),
    );
  }

  (String, Color) _riskForPrediction(dynamic prediction) {
    if (prediction == null) return ('UNSCREENED', Colors.white38);
    final level = (prediction.riskLevel ?? '').toString().toUpperCase();
    if (level.contains('URGENT')) return ('URGENT', const Color(0xFFD50000));
    if (level.contains('HIGH')) return ('HIGH RISK', const Color(0xFFFF6D00));
    if (level.contains('MEDIUM') || level.contains('MILD'))
      return ('MILD', const Color(0xFFFFB300));
    if (level.contains('LOW') || level.contains('NORMAL'))
      return ('NORMAL', const Color(0xFF00E676));
    return ('SCREENED', const Color(0xFF00B4D8));
  }

  double _healthScore(dynamic prediction) {
    if (prediction == null) return 0;
    final riskScore = prediction.riskScore;
    if (riskScore is num) {
      return ((1 - riskScore.toDouble()) * 100).clamp(0.0, 100.0);
    }
    return 50;
  }

  String _relative(DateTime dt) {
    final delta = DateTime.now().toUtc().difference(dt.toUtc());
    if (delta.inDays >= 1) return '${delta.inDays} days ago';
    if (delta.inHours >= 1) return '${delta.inHours} hours ago';
    return '${delta.inMinutes} min ago';
  }
}

class _CircularScoreRing extends StatelessWidget {
  const _CircularScoreRing({
    required this.score,
    required this.size,
    required this.color,
  });

  final double score;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (score == 0) {
      return _UnscreenedRing(size: size);
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: score / 100),
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeOut,
      builder: (ctx, value, _) => Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: value,
              strokeWidth: 8,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation(color),
              strokeCap: StrokeCap.round,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${(value * 100).round()}',
                style: const TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const Text(
                '/100',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  color: Colors.white38,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UnscreenedRing extends StatefulWidget {
  const _UnscreenedRing({required this.size});

  final double size;

  @override
  State<_UnscreenedRing> createState() => _UnscreenedRingState();
}

class _UnscreenedRingState extends State<_UnscreenedRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) => Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: widget.size,
            height: widget.size,
            child: CircularProgressIndicator(
              value: 1.0,
              strokeWidth: 2,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation(
                Colors.white.withOpacity(0.08 + _pulse.value * 0.12),
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.remove_red_eye_outlined,
                size: 24,
                color: Colors.white.withOpacity(0.2 + _pulse.value * 0.2),
              ),
              const SizedBox(height: 4),
              Text(
                'Tap\nto screen',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 10,
                  color: Colors.white.withOpacity(0.2 + _pulse.value * 0.2),
                  height: 1.2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AnimatedScore extends StatelessWidget {
  const _AnimatedScore({required this.score});

  final double score;

  @override
  Widget build(BuildContext context) {
    if (score == 0) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '–',
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 48,
              fontWeight: FontWeight.w700,
              color: Colors.white38,
              height: 1.0,
            ),
          ),
          Text(
            'No data yet',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11,
              color: Colors.white24,
            ),
          ),
        ],
      );
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: score),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOut,
      builder: (ctx, val, _) => Text(
        '${val.round()}',
        style: const TextStyle(
          fontFamily: 'JetBrainsMono',
          fontSize: 48,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          height: 1.0,
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.total,
    required this.last,
    required this.reports,
  });

  final int total;
  final DateTime? last;
  final int reports;

  @override
  Widget build(BuildContext context) {
    String lastText() {
      final dt = last;
      if (dt == null) return '—';
      final delta = DateTime.now().toUtc().difference(dt.toUtc());
      if (delta.inDays >= 1) return '${delta.inDays}d ago';
      if (delta.inHours >= 1) return '${delta.inHours}h ago';
      return '${delta.inMinutes}m ago';
    }

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.science_outlined,
            iconColor: const Color(0xFF00B4D8),
            value: '$total',
            label: 'Tests',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            icon: Icons.schedule_outlined,
            iconColor: const Color(0xFF1565C0),
            value: lastText(),
            label: 'Last Scan',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            icon: Icons.description_outlined,
            iconColor: const Color(0xFF7C3AED),
            value: '$reports',
            label: 'Reports',
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2C2C2C)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 14, color: iconColor),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 10,
              color: Colors.white38,
            ),
          ),
        ],
      ),
    );
  }
}

class _FullScreeningButton extends StatefulWidget {
  const _FullScreeningButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_FullScreeningButton> createState() => _FullScreeningButtonState();
}

class _FullScreeningButtonState extends State<_FullScreeningButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressController;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          height: 60,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1565C0), Color(0xFF00B4D8)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1565C0).withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              const SizedBox(width: 20),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.remove_red_eye,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Start Full Eye Screening',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '10 tests  ·  ~8 minutes',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios,
                  color: Colors.white60, size: 14),
              const SizedBox(width: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _TestGrid extends StatelessWidget {
  const _TestGrid({
    required this.latestResults,
    required this.onRun,
  });

  final Map<String, TestResult?> latestResults;
  final void Function(String testName) onRun;

  static const _tests = <_TestCardDef>[
    _TestCardDef('gaze_detection', 'Gaze Detection',
        Icons.remove_red_eye_outlined, Color(0xFF00B4D8)),
    _TestCardDef('hirschberg', 'Hirschberg', Icons.highlight_outlined,
        Color(0xFFFFB300)),
    _TestCardDef('prism_diopter', 'Prism Diopter', Icons.straighten_outlined,
        Color(0xFFFFB300)),
    _TestCardDef(
        'red_reflex', 'Red Reflex', Icons.lens_outlined, Color(0xFFFF1744)),
    _TestCardDef('suppression_test', 'Suppression',
        Icons.visibility_off_outlined, Color(0xFFFF6D00)),
    _TestCardDef('depth_perception', 'Depth Perception',
        Icons.view_in_ar_outlined, Color(0xFF7C3AED)),
    _TestCardDef('titmus_stereo', 'Titmus Stereo', Icons.blur_on_outlined,
        Color(0xFF7C3AED)),
    _TestCardDef(
        'lang_stereo', 'Lang Stereo', Icons.grain_outlined, Color(0xFF7C3AED)),
    _TestCardDef('ishihara_color', 'Color Vision', Icons.palette_outlined,
        Color(0xFF00E676)),
    _TestCardDef('snellen_chart', 'Visual Acuity', Icons.format_size_outlined,
        Color(0xFF1565C0)),
    _TestCardDef('worth_four_dot', 'Worth 4 Dot', Icons.visibility_outlined,
        Color(0xFF22C55E)),
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.05,
      ),
      itemCount: _tests.length,
      itemBuilder: (context, index) {
        final def = _tests[index];
        final result = latestResults[def.testName];
        final details = result?.details;
        final date = result?.createdAt;
        final (summary, statusColor) = _summarize(def.testName, details);
        final dateText = date == null ? 'Not tested' : _relative(date);

        return _DarkTestCard(
          def: def,
          summary: summary,
          statusColor: statusColor,
          dateText: dateText,
          onTap: () => onRun(def.testName),
        );
      },
    );
  }

  /// Translates clinical test details into a patient-friendly label + color.
  /// Zest principle: never show raw numbers (5.3Δ, 0.3mm) — show Normal / Mild / Urgent.
  (String, Color) _summarize(String testName, Map<String, dynamic>? details) {
    if (details == null) return ('—', AmbyoColors.textDisabled);

    bool urgent = false;
    bool abnormal = false;

    switch (testName) {
      case 'gaze_detection':
        urgent = (details['requiresUrgentReferral'] ?? false) == true;
        abnormal = urgent ||
            _toDouble(
                    details['prismDiopterValue'] ?? details['prism_diopter']) >
                10;
      case 'hirschberg':
        urgent = (details['requiresUrgentReferral'] ?? false) == true;
        abnormal =
            (details['isAbnormal'] ?? details['is_abnormal'] ?? false) == true;
      case 'prism_diopter':
        final dev =
            _toDouble(details['totalDeviation'] ?? details['total_deviation']);
        urgent = dev >= 20;
        abnormal = dev >= 10;
      case 'red_reflex':
        urgent = (details['requiresUrgentReferral'] ??
                details['requires_urgent_referral'] ??
                false) ==
            true;
        abnormal = !(details['isNormal'] ?? details['is_normal'] ?? false);
      case 'suppression_test':
        abnormal =
            (details['isAbnormal'] ?? details['is_abnormal'] ?? false) == true;
      case 'depth_perception':
        abnormal = (details['requiresReferral'] ??
                details['requires_referral'] ??
                false) ==
            true;
      case 'titmus_stereo':
        abnormal = (details['requires_referral'] ?? false) == true;
      case 'lang_stereo':
        abnormal = (details['requires_referral'] ?? false) == true;
      case 'ishihara_color':
        abnormal = !(details['is_normal'] ?? details['isNormal'] ?? false);
      case 'snellen_chart':
        abnormal = (details['requires_referral'] ?? false) == true;
      case 'worth_four_dot':
        abnormal = (details['requires_referral'] ??
                details['requiresReferral'] ??
                false) ==
            true;
    }

    if (urgent) return ('Urgent', AmbyoTheme.dangerColor);
    if (abnormal) return ('Mild Risk', AmbyoColors.mildAmber);
    return ('Normal', AmbyoColors.tealMedical);
  }

  double _toDouble(Object? v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0.0;
  }

  String _relative(DateTime dt) {
    final delta = DateTime.now().toUtc().difference(dt.toUtc());
    if (delta.inDays >= 1) return '${delta.inDays} days ago';
    if (delta.inHours >= 1) return '${delta.inHours} hours ago';
    return '${delta.inMinutes} min ago';
  }
}

class _TestCardDef {
  const _TestCardDef(this.testName, this.title, this.icon, this.accentColor);
  final String testName;
  final String title;
  final IconData icon;
  final Color accentColor;
}

class _DarkTestCard extends StatefulWidget {
  const _DarkTestCard({
    required this.def,
    required this.summary,
    required this.statusColor,
    required this.dateText,
    required this.onTap,
  });

  final _TestCardDef def;
  final String summary;
  final Color statusColor;
  final String dateText;
  final VoidCallback onTap;

  @override
  State<_DarkTestCard> createState() => _DarkTestCardState();
}

class _DarkTestCardState extends State<_DarkTestCard> {
  bool _pressed = false;

  Color _dotColor(Color statusColor) {
    if (statusColor == AmbyoTheme.dangerColor) return const Color(0xFFD50000);
    if (statusColor == AmbyoColors.mildAmber) return const Color(0xFFFFB300);
    if (statusColor == AmbyoColors.tealMedical) return const Color(0xFF00E676);
    return Colors.white24;
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.def.accentColor;
    final dot = _dotColor(widget.statusColor);

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        transform: Matrix4.identity()..scale(_pressed ? 0.96 : 1.0),
        child: GlassCard(
          radius: 22,
          blurSigma: 16,
          backgroundColor: const Color(0xCC131B2B),
          borderColor: accent.withValues(alpha: 0.30),
          glowColor: accent,
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: accent.withValues(alpha: 0.22)),
                    ),
                    child: Icon(widget.def.icon, size: 18, color: accent),
                  ),
                  const Spacer(),
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: dot,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: dot.withValues(alpha: 0.45),
                          blurRadius: 10,
                          spreadRadius: -2,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                widget.summary,
                style: const TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.def.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.dateText,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 10,
                  color: Colors.white38,
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Text(
                    'Run Test',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      color: accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward, size: 11, color: accent),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentReportsList extends StatelessWidget {
  const _RecentReportsList({
    required this.reports,
    required this.onView,
    required this.onShare,
  });

  final List<Map<String, Object?>> reports;
  final void Function(String pdfPath) onView;
  final void Function(String pdfPath) onShare;

  @override
  Widget build(BuildContext context) {
    if (reports.isEmpty) {
      return GlassCard(
        radius: 20,
        backgroundColor: const Color(0xC9151C2B),
        borderColor: Colors.white.withValues(alpha: 0.08),
        glowColor: AmbyoColors.testBlue,
        child: const Text(
          'No reports yet. Complete a full screening to generate your first PDF.',
          style: TextStyle(
              color: Colors.white54, fontFamily: 'Poppins', fontSize: 13),
        ),
      );
    }

    return Column(
      children: reports.map((row) {
        final path = (row['pdf_path'] as String?) ?? '';
        final date =
            DateTime.tryParse((row['test_date'] as String?) ?? '')?.toLocal();
        final score = row['risk_score'] is num
            ? (row['risk_score'] as num).toDouble()
            : null;
        final level = (row['risk_level'] ?? '').toString();
        final riskText =
            score == null ? level : 'AI: ${score.toStringAsFixed(2)} · $level';

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GlassCard(
            radius: 20,
            backgroundColor: const Color(0xC9151C2B),
            borderColor: Colors.white.withValues(alpha: 0.08),
            glowColor: AmbyoColors.testBlue,
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1565C0).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.description_outlined,
                      color: Color(0xFF1565C0), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Full Screening',
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        date == null
                            ? '-'
                            : '${date.day.toString().padLeft(2, '0')} ${_month(date.month)} ${date.year}',
                        style: const TextStyle(
                          color: Colors.white38,
                          fontFamily: 'Poppins',
                          fontSize: 12,
                        ),
                      ),
                      if (riskText.isNotEmpty)
                        Text(
                          riskText,
                          style: const TextStyle(
                            fontFamily: 'JetBrainsMono',
                            fontSize: 11,
                            color: Colors.white54,
                          ),
                        ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.picture_as_pdf_outlined,
                          color: Colors.white38, size: 18),
                      onPressed: path.isEmpty ? null : () => onView(path),
                      tooltip: 'View PDF',
                    ),
                    IconButton(
                      icon: const Icon(Icons.share_outlined,
                          color: Colors.white38, size: 18),
                      onPressed: path.isEmpty ? null : () => onShare(path),
                      tooltip: 'Share',
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(growable: false),
    );
  }

  static String _month(int m) {
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
}

// ─────────────────────────────────────────────────────────────────────────────
// ZEST-STYLE WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

/// Large hero score card — equivalent to Zest's "Daily Score" yellow card.
/// Accent cyan on dark, ring, risk badge and sub-caption.
class _ZestScoreCard extends StatelessWidget {
  const _ZestScoreCard({
    required this.prediction,
    required this.totalSessions,
    required this.onTap,
  });

  final dynamic prediction;
  final int totalSessions;
  final VoidCallback onTap;

  static const _kCard = Color(0xFF1A1A1E);
  static const _kAccentBg = Color(0xFF00B4D8);

  (String, Color) _risk() {
    if (prediction == null) return ('UNSCREENED', Colors.white24);
    final level = (prediction.riskLevel ?? '').toString().toUpperCase();
    if (level.contains('URGENT')) return ('URGENT', const Color(0xFFD50000));
    if (level.contains('HIGH')) return ('HIGH RISK', const Color(0xFFFF6D00));
    if (level.contains('MILD') || level.contains('MEDIUM'))
      return ('MILD RISK', const Color(0xFFFFB300));
    if (level.contains('NORMAL') || level.contains('LOW'))
      return ('ALL CLEAR', const Color(0xFF00E676));
    return ('SCREENED', _kAccentBg);
  }

  double _score() {
    if (prediction == null) return 0;
    final s = prediction.riskScore;
    if (s is num) return ((1 - s.toDouble()) * 100).clamp(0.0, 100.0);
    return 50;
  }

  @override
  Widget build(BuildContext context) {
    final (riskLabel, riskColor) = _risk();
    final score = _score();
    final screened = prediction != null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF2A2A2E), width: 1),
          boxShadow: [
            BoxShadow(
              color: _kAccentBg.withValues(alpha: screened ? 0.08 : 0.04),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            // Left side: label, score, risk badge
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top label like "Daily Score"
                  Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: _kAccentBg.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.remove_red_eye_outlined,
                            size: 14, color: _kAccentBg),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Eye Health Score',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Big animated score number
                  _AnimatedScore(score: score),
                  const SizedBox(height: 10),
                  // Risk badge pill
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: riskColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border:
                          Border.all(color: riskColor.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      riskLabel,
                      style: TextStyle(
                        color: riskColor,
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    screened
                        ? '$totalSessions session${totalSessions == 1 ? '' : 's'} completed'
                        : 'Tap to start your first screening',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      color: Colors.white38,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20),
            // Right side: circular ring (like Zest's 90% ring)
            _CircularScoreRing(
                score: score,
                size: 96,
                color: riskColor == Colors.white24 ? _kAccentBg : riskColor),
          ],
        ),
      ),
    );
  }
}

/// Zest-style stats row — 3 mini bento widgets side by side.
/// Each has an icon + BIG value + small caption "Good start, don't stop".
class _ZestStatsRow extends StatelessWidget {
  const _ZestStatsRow({
    required this.total,
    required this.last,
    required this.reports,
  });

  final int total;
  final DateTime? last;
  final int reports;

  String _lastText() {
    final dt = last;
    if (dt == null) return '—';
    final delta = DateTime.now().toUtc().difference(dt.toUtc());
    if (delta.inDays >= 1) return '${delta.inDays}d';
    if (delta.inHours >= 1) return '${delta.inHours}h';
    return '${delta.inMinutes}m';
  }

  String _lastCaption() {
    if (last == null) return 'Never scanned';
    return 'Last session';
  }

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        children: [
          Expanded(
            child: _ZestMiniWidget(
              icon: Icons.science_outlined,
              iconColor: const Color(0xFF00B4D8),
              value: '$total',
              label: 'Tests',
              caption: total == 0 ? 'Start now!' : 'Good progress',
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _ZestMiniWidget(
              icon: Icons.schedule_outlined,
              iconColor: const Color(0xFF7C3AED),
              value: _lastText(),
              label: 'Last Scan',
              caption: _lastCaption(),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _ZestMiniWidget(
              icon: Icons.description_outlined,
              iconColor: const Color(0xFF1565C0),
              value: '$reports',
              label: 'Reports',
              caption: reports == 0 ? 'None yet' : 'Available',
            ),
          ),
        ],
      ),
    );
  }
}

/// Single Zest mini widget card — icon + BIG number + label + caption.
class _ZestMiniWidget extends StatelessWidget {
  const _ZestMiniWidget({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
    required this.caption,
  });

  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2A2E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            caption,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 10,
              color: Colors.white30,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Zest-style primary CTA button.
/// Solid accent fill, bold label — equivalent to Zest's yellow "Sign Up" button.
class _ZestCtaButton extends StatefulWidget {
  const _ZestCtaButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_ZestCtaButton> createState() => _ZestCtaButtonState();
}

class _ZestCtaButtonState extends State<_ZestCtaButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          height: 58,
          decoration: BoxDecoration(
            color: const Color(0xFF00B4D8),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00B4D8).withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.remove_red_eye,
                    color: Colors.white, size: 16),
              ),
              const SizedBox(width: 12),
              const Text(
                'Start Full Eye Screening',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_rounded,
                  color: Colors.white, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

/// Zest bento test grid — Zest-style varied layout.
/// Row 1: [wide test card spanning ~1.5] [narrow test card]
/// Remaining tests: uniform 2-col grid
/// Each card: icon top-left, status dot top-right, BIG label, test name, "Good start, don't stop", "Run →"
class _ZestTestBento extends StatelessWidget {
  const _ZestTestBento({
    required this.latestResults,
    required this.onRun,
  });

  final Map<String, TestResult?> latestResults;
  final void Function(String testName) onRun;

  static const _tests = <_TestCardDef>[
    _TestCardDef('gaze_detection', 'Gaze Detection',
        Icons.remove_red_eye_outlined, Color(0xFF00B4D8)),
    _TestCardDef('snellen_chart', 'Visual Acuity', Icons.format_size_outlined,
        Color(0xFF1565C0)),
    _TestCardDef('hirschberg', 'Hirschberg', Icons.highlight_outlined,
        Color(0xFFFFB300)),
    _TestCardDef('ishihara_color', 'Color Vision', Icons.palette_outlined,
        Color(0xFF00E676)),
    _TestCardDef(
        'red_reflex', 'Red Reflex', Icons.lens_outlined, Color(0xFFFF1744)),
    _TestCardDef('suppression_test', 'Suppression',
        Icons.visibility_off_outlined, Color(0xFFFF6D00)),
    _TestCardDef('depth_perception', 'Depth', Icons.view_in_ar_outlined,
        Color(0xFF7C3AED)),
    _TestCardDef('titmus_stereo', 'Titmus Stereo', Icons.blur_on_outlined,
        Color(0xFF7C3AED)),
    _TestCardDef('prism_diopter', 'Prism Diopter', Icons.straighten_outlined,
        Color(0xFFFFB300)),
    _TestCardDef('worth_four_dot', 'Worth 4 Dot', Icons.visibility_outlined,
        Color(0xFF22C55E)),
    _TestCardDef(
        'lang_stereo', 'Lang Stereo', Icons.grain_outlined, Color(0xFF00B4D8)),
  ];

  (String, Color) _summarize(String testName, Map<String, dynamic>? details) {
    if (details == null) return ('—', Colors.white24);
    bool urgent = false;
    bool abnormal = false;
    switch (testName) {
      case 'gaze_detection':
        urgent = (details['requiresUrgentReferral'] ?? false) == true;
        abnormal = urgent ||
            _d(details['prismDiopterValue'] ?? details['prism_diopter']) > 10;
      case 'hirschberg':
        urgent = (details['requiresUrgentReferral'] ?? false) == true;
        abnormal =
            (details['isAbnormal'] ?? details['is_abnormal'] ?? false) == true;
      case 'prism_diopter':
        final dev = _d(details['totalDeviation'] ?? details['total_deviation']);
        urgent = dev >= 20;
        abnormal = dev >= 10;
      case 'red_reflex':
        urgent = (details['requiresUrgentReferral'] ??
                details['requires_urgent_referral'] ??
                false) ==
            true;
        abnormal = !(details['isNormal'] ?? details['is_normal'] ?? false);
      case 'suppression_test':
        abnormal =
            (details['isAbnormal'] ?? details['is_abnormal'] ?? false) == true;
      case 'depth_perception':
        abnormal = (details['requiresReferral'] ??
                details['requires_referral'] ??
                false) ==
            true;
      case 'titmus_stereo':
        abnormal = (details['requires_referral'] ?? false) == true;
      case 'lang_stereo':
        abnormal = (details['requires_referral'] ?? false) == true;
      case 'ishihara_color':
        abnormal = !(details['is_normal'] ?? details['isNormal'] ?? false);
      case 'snellen_chart':
        abnormal = (details['requires_referral'] ?? false) == true;
      case 'worth_four_dot':
        abnormal = (details['requires_referral'] ??
                details['requiresReferral'] ??
                false) ==
            true;
    }
    if (urgent) return ('Urgent', const Color(0xFFD50000));
    if (abnormal) return ('Mild Risk', const Color(0xFFFFB300));
    return ('Normal', const Color(0xFF00E676));
  }

  double _d(Object? v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0.0;
  }

  String _dateText(TestResult? result) {
    if (result == null) return 'Not tested yet';
    final delta = DateTime.now().toUtc().difference(result.createdAt.toUtc());
    if (delta.inDays >= 1) return '${delta.inDays} days ago';
    if (delta.inHours >= 1) return '${delta.inHours}h ago';
    return '${delta.inMinutes}m ago';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Row 1: first 2 tests side by side (tall on left, shorter on right) ─
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 5,
                child: _ZestTestCard(
                  def: _tests[0],
                  summary: _summarize(_tests[0].testName,
                      latestResults[_tests[0].testName]?.details),
                  dateText: _dateText(latestResults[_tests[0].testName]),
                  tall: true,
                  onTap: () => onRun(_tests[0].testName),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 4,
                child: Column(
                  children: [
                    _ZestTestCard(
                      def: _tests[1],
                      summary: _summarize(_tests[1].testName,
                          latestResults[_tests[1].testName]?.details),
                      dateText: _dateText(latestResults[_tests[1].testName]),
                      tall: false,
                      onTap: () => onRun(_tests[1].testName),
                    ),
                    const SizedBox(height: 10),
                    _ZestTestCard(
                      def: _tests[2],
                      summary: _summarize(_tests[2].testName,
                          latestResults[_tests[2].testName]?.details),
                      dateText: _dateText(latestResults[_tests[2].testName]),
                      tall: false,
                      onTap: () => onRun(_tests[2].testName),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // ── Rows 2+: remaining tests in uniform 2-col grid ─────────────────
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.1,
          ),
          itemCount: _tests.length - 3,
          itemBuilder: (context, i) {
            final def = _tests[i + 3];
            final (summary, statusColor) =
                _summarize(def.testName, latestResults[def.testName]?.details);
            return _ZestTestCard(
              def: def,
              summary: (summary, statusColor),
              dateText: _dateText(latestResults[def.testName]),
              tall: false,
              onTap: () => onRun(def.testName),
            );
          },
        ),
      ],
    );
  }
}

/// Single Zest-style test card widget.
/// Icon circle (accent) + big status label + test name + date caption + "Run →"
class _ZestTestCard extends StatefulWidget {
  const _ZestTestCard({
    required this.def,
    required this.summary,
    required this.dateText,
    required this.tall,
    required this.onTap,
  });

  final _TestCardDef def;
  final (String, Color) summary;
  final String dateText;
  final bool tall;
  final VoidCallback onTap;

  @override
  State<_ZestTestCard> createState() => _ZestTestCardState();
}

class _ZestTestCardState extends State<_ZestTestCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final accent = widget.def.accentColor;
    final (statusLabel, statusColor) = widget.summary;
    final isDone = statusLabel != '—';

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        transform: Matrix4.diagonal3Values(
            _pressed ? 0.97 : 1.0, _pressed ? 0.97 : 1.0, 1),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1E),
          borderRadius: BorderRadius.circular(18),
          border: Border(
            left: BorderSide(color: accent, width: 3),
            top: const BorderSide(color: Color(0xFF2A2A2E), width: 0.5),
            right: const BorderSide(color: Color(0xFF2A2A2E), width: 0.5),
            bottom: const BorderSide(color: Color(0xFF2A2A2E), width: 0.5),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: widget.tall ? MainAxisSize.max : MainAxisSize.min,
          children: [
            // Icon row + status dot
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(widget.def.icon, size: 16, color: accent),
                ),
                const Spacer(),
                // Status dot — like Zest's circular check marks
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: isDone
                        ? statusColor.withValues(alpha: 0.15)
                        : Colors.white.withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDone
                          ? statusColor.withValues(alpha: 0.5)
                          : Colors.white24,
                      width: 1,
                    ),
                  ),
                  child: isDone
                      ? Icon(
                          statusLabel == 'Normal'
                              ? Icons.check_rounded
                              : Icons.priority_high_rounded,
                          size: 11,
                          color: statusColor,
                        )
                      : null,
                ),
              ],
            ),
            if (widget.tall) const Spacer(),
            if (!widget.tall) const SizedBox(height: 12),
            // Big status label — like "7h 30m" in Zest
            Text(
              statusLabel,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: widget.tall ? 22 : 18,
                fontWeight: FontWeight.w700,
                color: isDone ? statusColor : Colors.white38,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 2),
            // Test name — like "Sleep" in Zest
            Text(
              widget.def.title,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 2),
            // Caption — like "Good start, don't stop" in Zest
            Text(
              isDone ? widget.dateText : "Tap to run →",
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 10,
                color: isDone ? Colors.white30 : accent.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// (No top-level helpers; keep lints strict.)
