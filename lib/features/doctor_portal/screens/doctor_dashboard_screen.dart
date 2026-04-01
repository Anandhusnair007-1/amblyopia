import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/ambyo_theme.dart';
import '../../../core/theme/ambyoai_design_system.dart';
import '../../../core/widgets/enterprise_ui.dart';
import '../../../core/widgets/language_selector_widget.dart';
import '../../../core/widgets/offline_banner.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/screens/patient_login_screen.dart';
import '../../offline/local_database.dart';

class DoctorDashboardScreen extends ConsumerStatefulWidget {
  const DoctorDashboardScreen({super.key});

  @override
  ConsumerState<DoctorDashboardScreen> createState() =>
      _DoctorDashboardScreenState();
}

class _DoctorDashboardScreenState extends ConsumerState<DoctorDashboardScreen> {
  Future<_DoctorDashboardData>? _loader;
  int _urgentCount = 0;

  @override
  void initState() {
    super.initState();
    _loader = _load();
  }

  Future<_DoctorDashboardData> _load() async {
    final db = LocalDatabase.instance;
    final totalPatients = await db.countAllPatients();
    final urgentCases = await db.getUrgentUndiagnosedSessions();
    final todayScreened = await db.countTodaySessions();
    final recentSessions = await db.getRecentSessions(limit: 10);
    return _DoctorDashboardData(
      offlineCache: false,
      totalPatients: totalPatients,
      urgentCases: urgentCases,
      todayScreened: todayScreened,
      recentPatients: recentSessions,
    );
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('doctor_id');
    await prefs.remove('doctor_name');
    await prefs.remove('doctor_username');
    ref.read(roleProvider.notifier).state = UserRole.none;
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const PatientLoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return OfflineBanner(
      child: EnterpriseScaffold(
        title: 'Doctor Portal',
        subtitle: 'Clinical oversight',
        appBarStyle: EnterpriseAppBarStyle.light,
        surfaceStyle: EnterpriseSurfaceStyle.plain,
        backgroundColor: AmbyoColors.darkBg,
        actions: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                tooltip: 'Notifications',
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () {},
              ),
              if (_urgentCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AmbyoTheme.dangerColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor:
                      AmbyoTheme.primaryColor.withValues(alpha: 0.2),
                  child: const Icon(Icons.person_outline,
                      size: 20, color: AmbyoTheme.primaryColor),
                ),
                const SizedBox(width: 8),
                Text(
                  'Doctor',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                ),
              ],
            ),
          ),
          const LanguageSelectorWidget(),
          IconButton(
            tooltip: 'About',
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () => Navigator.of(context).pushNamed('/about'),
          ),
        ],
        child: FutureBuilder<_DoctorDashboardData>(
          future: _loader,
          builder: (context, snapshot) {
            final data = snapshot.data;
            if (snapshot.connectionState != ConnectionState.done ||
                data == null) {
              return const _DoctorDashboardLoading();
            }
            if (data.urgentCases.length != _urgentCount) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted)
                  setState(() => _urgentCount = data.urgentCases.length);
              });
            }

            return ListView(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: EnterpriseMetricCard(
                        title: 'Total Patients',
                        value: '${data.totalPatients}',
                        icon: Icons.groups_rounded,
                        tint: AmbyoTheme.primaryColor,
                      )
                          .animate()
                          .fadeIn(duration: const Duration(milliseconds: 200))
                          .slideY(
                              begin: 0.08, end: 0, curve: Curves.easeOutCubic),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: EnterpriseMetricCard(
                        title: 'Urgent Cases',
                        value: '${data.urgentCases.length}',
                        icon: Icons.emergency_outlined,
                        tint: AmbyoTheme.dangerColor,
                      )
                          .animate()
                          .fadeIn(
                              duration: const Duration(milliseconds: 200),
                              delay: const Duration(milliseconds: 50))
                          .slideY(
                              begin: 0.08, end: 0, curve: Curves.easeOutCubic),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: EnterpriseMetricCard(
                        title: 'Today Screened',
                        value: '${data.todayScreened}',
                        icon: Icons.today_rounded,
                        tint: AmbyoTheme.secondaryColor,
                      )
                          .animate()
                          .fadeIn(
                              duration: const Duration(milliseconds: 200),
                              delay: const Duration(milliseconds: 100))
                          .slideY(
                              begin: 0.08, end: 0, curve: Curves.easeOutCubic),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: EnterpriseMetricCard(
                        title: 'Recent (10)',
                        value: '${data.recentPatients.length}',
                        icon: Icons.history_rounded,
                        tint: const Color(0xFF5E35B1),
                      )
                          .animate()
                          .fadeIn(
                              duration: const Duration(milliseconds: 200),
                              delay: const Duration(milliseconds: 140))
                          .slideY(
                              begin: 0.08, end: 0, curve: Curves.easeOutCubic),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (data.urgentCases.isNotEmpty) ...[
                  EnterpriseBanner(
                    tone: EnterpriseBannerTone.danger,
                    title:
                        '${data.urgentCases.length} URGENT CASES NEED ATTENTION',
                    message:
                        'Review these reports and add a clinical diagnosis for training.',
                  ).animate(onPlay: (c) => c.repeat(reverse: true)).scaleXY(
                      begin: 1.0,
                      end: 1.015,
                      duration: const Duration(milliseconds: 1000)),
                  const SizedBox(height: 12),
                  ...data.urgentCases.take(3).map((u) {
                    final sessionId =
                        (u['session_id'] ?? u['hashed_session_id'] ?? '')
                            .toString();
                    final name = (u['patient_name'] ?? 'Child').toString();
                    final age = (u['patient_age'] ?? '').toString();
                    final date = DateTime.tryParse(
                            (u['test_date'] ?? u['created_at'] ?? '')
                                .toString())
                        ?.toLocal();
                    final label = (u['risk_level'] ?? 'URGENT').toString();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: EnterprisePanel(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: AmbyoTheme.dangerColor
                                    .withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: const Icon(Icons.warning_amber_rounded,
                                  color: AmbyoTheme.dangerColor),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$name${age.isEmpty ? "" : ", $age y"}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                        ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${date == null ? "-" : _fmtDateTime(date)}  ·  $label',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: Colors.white70,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            FilledButton(
                              onPressed: sessionId.isEmpty
                                  ? null
                                  : () => Navigator.of(context).pushNamed(
                                        AppRouter.doctorReportViewer,
                                        arguments: sessionId,
                                      ),
                              child: const Text('Review'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Recent Patients',
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: AmbyoColors.textPrimary,
                                ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context)
                          .pushNamed(AppRouter.doctorPatientList),
                      child: const Text('View All'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (data.recentPatients.isEmpty)
                  const EnterpriseBanner(
                    tone: EnterpriseBannerTone.info,
                    title: 'No screenings yet',
                    message:
                        'Complete screenings on this device to see them here.',
                  )
                else
                  ...data.recentPatients.map((p) {
                    final sessionId =
                        (p['session_id'] ?? p['hashed_session_id'] ?? '')
                            .toString();
                    final name = (p['patient_name'] ?? 'Child').toString();
                    final age = (p['patient_age'] ?? '').toString();
                    final date = DateTime.tryParse(
                            (p['test_date'] ?? p['created_at'] ?? '')
                                .toString())
                        ?.toLocal();
                    final riskLevel = (p['risk_level'] ?? '').toString();
                    final pill = _riskPill(riskLevel);
                    final pdfReady = (p['pdf_path'] != null &&
                            (p['pdf_path'] as String).isNotEmpty)
                        ? 'PDF ready'
                        : '';
                    final riskColor = AmbyoColors.riskColor(pill.label);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: EnterprisePanel(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name + (age.isEmpty ? '' : ', $age y'),
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w900,
                                              color: AmbyoColors.textPrimary,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Screened: ${date == null ? '-' : _fmtDate(date)}${pdfReady.isEmpty ? '' : ' · $pdfReady'}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: AmbyoColors.textSecondary,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: riskColor.withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                        color:
                                            riskColor.withValues(alpha: 0.3)),
                                  ),
                                  child: Text(
                                    pill.label,
                                    style: TextStyle(
                                        color: riskColor,
                                        fontWeight: FontWeight.w900),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: sessionId.isEmpty
                                        ? null
                                        : () => Navigator.of(context).pushNamed(
                                              AppRouter.doctorReportViewer,
                                              arguments: sessionId,
                                            ),
                                    icon: const Icon(Icons.visibility_outlined,
                                        size: 18),
                                    label: const Text('View'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: sessionId.isEmpty
                                        ? null
                                        : () => Navigator.of(context).pushNamed(
                                              AppRouter.doctorDiagnosis,
                                              arguments: sessionId,
                                            ),
                                    icon: const Icon(
                                        Icons.medical_services_outlined,
                                        size: 18),
                                    label: const Text('Diagnose'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context)
                      .pushNamed(AppRouter.doctorChangePassword),
                  icon: const Icon(Icons.lock_reset_rounded),
                  label: const Text('Change password'),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => setState(() => _loader = _load()),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Refresh'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                            foregroundColor: AmbyoTheme.dangerColor),
                        onPressed: _logout,
                        icon: const Icon(Icons.logout_rounded),
                        label: const Text('Log Out'),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DoctorDashboardLoading extends StatelessWidget {
  const _DoctorDashboardLoading();

  @override
  Widget build(BuildContext context) {
    Widget block(double h) {
      return Shimmer.fromColors(
        baseColor: const Color(0xFFE6EDF7),
        highlightColor: Colors.white,
        child: Container(
          height: h,
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFFE6EDF7),
            borderRadius: BorderRadius.circular(22),
          ),
        ),
      );
    }

    return ListView(
      children: [
        block(86),
        const SizedBox(height: 12),
        block(170),
        const SizedBox(height: 12),
        block(120),
      ],
    );
  }
}

class _DoctorDashboardData {
  const _DoctorDashboardData({
    required this.offlineCache,
    required this.totalPatients,
    required this.urgentCases,
    required this.todayScreened,
    required this.recentPatients,
  });

  final bool offlineCache;
  final int totalPatients;
  final List<Map<String, dynamic>> urgentCases;
  final int todayScreened;
  final List<Map<String, dynamic>> recentPatients;
}

({String label, Color color}) _riskPill(String riskLevel) {
  final upper = riskLevel.toUpperCase();
  if (upper.contains('URGENT'))
    return (label: 'URGENT', color: AmbyoTheme.dangerColor);
  if (upper.contains('HIGH') ||
      upper.contains('SEVERE') ||
      upper.contains('MODERATE')) {
    return (label: 'HIGH', color: AmbyoColors.mildAmber);
  }
  if (upper.contains('MILD') || upper.contains('MEDIUM'))
    return (label: 'MILD', color: AmbyoColors.mildAmber);
  if (upper.contains('NORMAL') || upper.contains('LOW'))
    return (label: 'NORMAL', color: AmbyoColors.tealMedical);
  return (label: 'PENDING', color: AmbyoColors.textSecondary);
}

String _fmtDate(DateTime dt) {
  return '${dt.day.toString().padLeft(2, '0')} ${_month(dt.month)} ${dt.year}';
}

String _fmtDateTime(DateTime dt) {
  final hh = dt.hour.toString().padLeft(2, '0');
  final mm = dt.minute.toString().padLeft(2, '0');
  return '${_fmtDate(dt)} · $hh:$mm';
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
