import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/ambyo_theme.dart';
import '../../../core/theme/ambyoai_design_system.dart';
import '../../../core/widgets/enterprise_ui.dart';
import '../../../core/widgets/language_selector_widget.dart';
import '../../../core/widgets/offline_banner.dart';
import '../../consent/consent_flow.dart';
import '../../offline/local_database.dart';

class WorkerHomeScreen extends StatelessWidget {
  const WorkerHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return OfflineBanner(
      child: EnterpriseScaffold(
        title: 'Worker Home',
        subtitle: 'Anganwadi operations',
        appBarStyle: EnterpriseAppBarStyle.light,
        surfaceStyle: EnterpriseSurfaceStyle.plain,
        backgroundColor: AmbyoColors.darkBg,
        actions: [
          const LanguageSelectorWidget(),
          IconButton(
            tooltip: 'About',
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () => Navigator.of(context).pushNamed('/about'),
          ),
        ],
        child: const _WorkerBody(),
      ),
    );
  }
}

class _WorkerBody extends StatefulWidget {
  const _WorkerBody();

  @override
  State<_WorkerBody> createState() => _WorkerBodyState();
}

class _WorkerBodyState extends State<_WorkerBody> {
  Future<_WorkerData>? _loader;

  @override
  void initState() {
    super.initState();
    _loader = _load();
  }

  Future<_WorkerData> _load() async {
    final db = LocalDatabase.instance;
    final today = await db.countTodaySessions();
    final week = await db.countSessionsSince(
        DateTime.now().toUtc().subtract(const Duration(days: 7)));
    final totalChildren = await db.countDistinctPatients();
    final urgentToday = await db.countUrgentPredictionsToday();
    final queue = await db.getUnscreenedPatientsToday();
    final recent = await db.recentSessionsToday(limit: 5);
    return _WorkerData(
      todayScreened: today,
      weekScreened: week,
      totalChildren: totalChildren,
      urgentToday: urgentToday,
      queueCount: queue.length,
      recentSessionsToday: recent,
    );
  }

  Future<void> _quickStartScreening() async {
    final queue = await LocalDatabase.instance.getUnscreenedPatientsToday();
    if (queue.isEmpty) return;
    final patient = queue.first;
    if (!mounted) return;
    final started = await ensureConsentThenStartScreening(
      context,
      patient,
      screener: 'Health Worker',
    );
    if (mounted && started) setState(() => _loader = _load());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_WorkerData>(
      future: _loader,
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (snapshot.connectionState != ConnectionState.done || data == null) {
          return const _WorkerLoading();
        }

        return ListView(
          children: [
            EnterprisePanel(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AmbyoTheme.secondaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.health_and_safety_rounded,
                        color: AmbyoTheme.secondaryColor),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Anitha P. — Health Worker',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color: AmbyoColors.textPrimary,
                                  ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Anganwadi Center #142, Kollam',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Text(
                              '${data.todayScreened} screened today',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (data.urgentToday > 0)
              EnterpriseBanner(
                tone: EnterpriseBannerTone.danger,
                title: '${data.urgentToday} urgent cases today',
                message:
                    'Ensure these children are referred and reports are shared with a clinician.',
              )
            else
              const EnterpriseBanner(
                tone: EnterpriseBannerTone.info,
                title: 'All clear (today)',
                message:
                    'No urgent AI predictions recorded today. Continue screening queue.',
              ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: EnterpriseMetricCard(
                    title: "Today's screenings",
                    value: '${data.todayScreened}',
                    icon: Icons.check_circle_outline_rounded,
                    tint: AmbyoTheme.primaryColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: EnterpriseMetricCard(
                    title: 'This week',
                    value: '${data.weekScreened}',
                    icon: Icons.calendar_month_rounded,
                    tint: AmbyoTheme.secondaryColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: EnterpriseMetricCard(
                    title: 'Total children',
                    value: '${data.totalChildren}',
                    icon: Icons.groups_rounded,
                    tint: AmbyoTheme.accentColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 72,
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.of(context)
                    .pushNamed(AppRouter.addPatient)
                    .then((_) {
                  if (mounted) setState(() => _loader = _load());
                }),
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 24),
                label: const Text('Register New Child'),
                style: FilledButton.styleFrom(
                  backgroundColor: AmbyoTheme.primaryColor,
                  minimumSize: const Size.fromHeight(72),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 72,
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.of(context)
                    .pushNamed(AppRouter.screeningQueue)
                    .then((_) {
                  if (mounted) setState(() => _loader = _load());
                }),
                icon: const Icon(Icons.list_alt_rounded, size: 24),
                label: Text(data.queueCount > 0
                    ? 'Screening Queue  [${data.queueCount} waiting]'
                    : 'Screening Queue'),
                style: FilledButton.styleFrom(
                  backgroundColor: AmbyoTheme.secondaryColor,
                  minimumSize: const Size.fromHeight(72),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _ActionCard(
              icon: Icons.play_circle_outline_rounded,
              title: 'Start Next Screening',
              subtitle: data.queueCount > 0
                  ? 'Begin with the next queued child'
                  : 'No one waiting right now',
              onTap: data.queueCount > 0 ? _quickStartScreening : null,
            ),
            const SizedBox(height: 12),
            _ActionCard(
              icon: Icons.assessment_outlined,
              title: "Today's Summary",
              subtitle:
                  '${data.todayScreened} screened · ${data.urgentToday} urgent',
              onTap: () => setState(() => _loader = _load()),
            ),
            const SizedBox(height: 12),
            _ActionCard(
              icon: Icons.straighten_rounded,
              title: 'Distance calibration',
              subtitle:
                  'One-time: hold A4 at arm\'s length for accurate distance measurement.',
              onTap: () => Navigator.of(context)
                  .pushNamed(AppRouter.distanceCalibration),
            ),
            const SizedBox(height: 16),
            Text(
              'Recent Screenings (Today)',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
            ),
            const SizedBox(height: 10),
            if (data.recentSessionsToday.isEmpty)
              const EnterpriseBanner(
                tone: EnterpriseBannerTone.info,
                title: 'No screenings yet today',
                message:
                    'Register a child or open the queue to start a screening.',
              )
            else
              ...data.recentSessionsToday.map((row) {
                final name = (row['patient_name'] as String?) ?? 'Child';
                final age = (row['patient_age'] as int?) ?? 0;
                final testDate =
                    DateTime.tryParse((row['test_date'] as String?) ?? '')
                        ?.toLocal();
                final riskLevel = (row['risk_level'] ?? '').toString();
                final pill = _riskPill(riskLevel);
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
                            color: pill.color.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child:
                              Icon(Icons.child_care_rounded, color: pill.color),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$name, $age',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w900,
                                      color: AmbyoColors.textPrimary,
                                    ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                testDate == null ? '-' : _fmtTime(testDate),
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
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: pill.color.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                                color: pill.color.withValues(alpha: 0.35)),
                          ),
                          child: Text(
                            pill.label,
                            style: TextStyle(
                                color: pill.color, fontWeight: FontWeight.w900),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
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
              ],
            ),
          ],
        );
      },
    );
  }
}

class _WorkerLoading extends StatelessWidget {
  const _WorkerLoading();

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
        block(92),
        const SizedBox(height: 12),
        block(72),
        const SizedBox(height: 12),
        block(92),
        const SizedBox(height: 12),
        block(92),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: EnterprisePanel(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AmbyoTheme.primaryColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, color: AmbyoTheme.primaryColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: AmbyoColors.textPrimary,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: AmbyoColors.textSecondary),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AmbyoColors.textDisabled),
          ],
        ),
      ),
    );
  }
}

({String label, Color color}) _riskPill(String riskLevel) {
  final upper = riskLevel.toUpperCase();
  if (upper.contains('URGENT'))
    return (label: 'URGENT', color: AmbyoTheme.dangerColor);
  if (upper.contains('HIGH') || upper.contains('SEVERE'))
    return (label: 'HIGH', color: AmbyoColors.mildAmber);
  if (upper.contains('MILD') || upper.contains('MEDIUM'))
    return (label: 'MILD', color: AmbyoColors.mildAmber);
  if (upper.contains('NORMAL') || upper.contains('LOW'))
    return (label: 'NORMAL', color: AmbyoColors.tealMedical);
  return (label: 'PENDING', color: AmbyoColors.textSecondary);
}

String _fmtTime(DateTime dt) {
  final hh = dt.hour.toString().padLeft(2, '0');
  final mm = dt.minute.toString().padLeft(2, '0');
  return '${dt.day.toString().padLeft(2, '0')} ${_month(dt.month)} ${dt.year}  $hh:$mm';
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

class _WorkerData {
  const _WorkerData({
    required this.todayScreened,
    required this.weekScreened,
    required this.totalChildren,
    required this.urgentToday,
    required this.queueCount,
    required this.recentSessionsToday,
  });

  final int todayScreened;
  final int weekScreened;
  final int totalChildren;
  final int urgentToday;
  final int queueCount;
  final List<Map<String, Object?>> recentSessionsToday;
}
