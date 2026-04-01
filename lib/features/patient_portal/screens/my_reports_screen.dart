// ignore_for_file: unused_element

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/ambyo_theme.dart';
import '../../../core/theme/ambyoai_design_system.dart';
import '../../../core/widgets/ambyoai_list_item.dart';
import '../../../core/widgets/ambyoai_widgets.dart';
import '../../../core/widgets/enterprise_ui.dart';
import '../../../core/widgets/offline_banner.dart';
import '../../auth/screens/patient_login_screen.dart';
import '../../offline/local_database.dart';
import '../widgets/patient_bottom_nav.dart';

class MyReportsScreen extends StatefulWidget {
  const MyReportsScreen({super.key});

  @override
  State<MyReportsScreen> createState() => _MyReportsScreenState();
}

class _MyReportsScreenState extends State<MyReportsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  Future<_ReportsData>? _loader;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _loader = _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<_ReportsData> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final patientId = prefs.getString('patient_id');
    if (patientId == null || patientId.isEmpty) {
      return const _ReportsData.notLoggedIn();
    }

    final db = LocalDatabase.instance;
    final full = await db.allFullReportsForPatient(patientId);
    final mini = await db.allMiniReportsForPatient(patientId);
    return _ReportsData(
        patientId: patientId, fullReports: full, miniReports: mini);
  }

  Future<void> _deleteFullReport(String sessionId, String pdfPath) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Report?'),
        content: const Text(
            'This will remove the PDF from this device. Your test data stays in history.'),
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

    await LocalDatabase.instance.deleteFullReport(sessionId);
    try {
      final f = File(pdfPath);
      if (await f.exists()) {
        await f.delete();
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() => _loader = _load());
  }

  @override
  Widget build(BuildContext context) {
    return OfflineBanner(
      child: EnterpriseScaffold(
        title: 'My Reports',
        subtitle: 'PDF exports',
        appBarStyle: EnterpriseAppBarStyle.light,
        surfaceStyle: EnterpriseSurfaceStyle.plain,
        backgroundColor: AmbyoColors.backgroundColor,
        actions: const [],
        bottomNavigationBar: const PatientBottomNav(
          currentRoute: AppRouter.myReports,
          light: true,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.96),
                    const Color(0xFFF7FBFF),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFD8E8FA)),
                boxShadow: [
                  const BoxShadow(
                    color: Color(0x120C1C38),
                    blurRadius: 26,
                    offset: Offset(0, 14),
                  ),
                  BoxShadow(
                    color: AmbyoColors.cyanAccent.withValues(alpha: 0.08),
                    blurRadius: 24,
                    spreadRadius: -12,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: TabBar(
                controller: _tabs,
                dividerColor: Colors.transparent,
                indicatorSize: TabBarIndicatorSize.tab,
                labelPadding: EdgeInsets.zero,
                labelStyle: const TextStyle(fontWeight: FontWeight.w900),
                labelColor: Colors.white,
                unselectedLabelColor: AmbyoColors.textSecondary,
                indicator: BoxDecoration(
                  gradient: AmbyoGradients.primaryBtn,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: AmbyoShadows.buttonGlow,
                ),
                tabs: const [
                  Tab(
                    child: SizedBox(
                      height: 48,
                      child: Center(child: Text('Full Reports')),
                    ),
                  ),
                  Tab(
                    child: SizedBox(
                      height: 48,
                      child: Center(child: Text('Single Tests')),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder<_ReportsData>(
                future: _loader,
                builder: (context, snapshot) {
                  final data = snapshot.data;
                  if (snapshot.connectionState != ConnectionState.done ||
                      data == null) {
                    return const _ReportsLoading();
                  }

                  if (!data.isLoggedIn) {
                    return EnterpriseEmptyState(
                      icon: Icons.login,
                      title: 'Sign in required',
                      message:
                          'Log in with your phone number to view your reports.',
                      buttonLabel: 'Go to Login',
                      onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute<void>(
                            builder: (_) => const PatientLoginScreen()),
                        (_) => false,
                      ),
                    );
                  }

                  final noReports =
                      data.fullReports.isEmpty && data.miniReports.isEmpty;
                  if (noReports) {
                    return EnterpriseEmptyState(
                      icon: Icons.description_outlined,
                      title: 'No Reports Yet',
                      message:
                          'Complete a full screening to generate your first report.',
                      buttonLabel: 'Start Screening',
                      onPressed: () => Navigator.of(context)
                          .pushReplacementNamed(AppRouter.patientHome),
                    );
                  }

                  return TabBarView(
                    controller: _tabs,
                    children: [
                      _FullReportsTab(
                        rows: data.fullReports,
                        onView: (path) => Navigator.of(context).pushNamed(
                          AppRouter.reportPreview,
                          arguments: <String, dynamic>{
                            'pdfPath': path,
                            'reportData': null
                          },
                        ),
                        onShare: (path) => Share.shareXFiles([XFile(path)]),
                        onDelete: _deleteFullReport,
                      ),
                      _MiniReportsTab(
                        rows: data.miniReports,
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
          ],
        ),
      ),
    );
  }
}

class _ReportsLoading extends StatelessWidget {
  const _ReportsLoading();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AmbyoShimmer(height: 88),
        SizedBox(height: 12),
        AmbyoShimmer(height: 88),
        SizedBox(height: 12),
        AmbyoShimmer(height: 88),
      ],
    );
  }
}

class _FullReportsTab extends StatelessWidget {
  const _FullReportsTab({
    required this.rows,
    required this.onView,
    required this.onShare,
    required this.onDelete,
  });

  final List<Map<String, Object?>> rows;
  final void Function(String pdfPath) onView;
  final void Function(String pdfPath) onShare;
  final void Function(String sessionId, String pdfPath) onDelete;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const _EmptyTab(
        icon: Icons.description_outlined,
        title: 'No reports yet',
        message: 'Complete a full screening to get your first report.',
      );
    }

    return ListView.builder(
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        final sessionId = (row['session_id'] as String?) ?? '';
        final pdfPath = (row['pdf_path'] as String?) ?? '';
        final date =
            DateTime.tryParse((row['test_date'] as String?) ?? '')?.toLocal();
        final level = (row['risk_level'] ?? '').toString();
        final testCount = (row['test_count'] as int?) ?? 0;

        final riskColor =
            AmbyoColors.riskColor(level.isEmpty ? 'PENDING' : level);
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AmbyoListItem(
            leading: ambyoIconBox(
                icon: Icons.picture_as_pdf_rounded, color: riskColor),
            title: 'Full Screening',
            subtitle: date == null ? '-' : _fmtDate(date),
            caption: '$testCount tests completed',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: pdfPath.isEmpty ? null : () => onShare(pdfPath),
                  icon: const Icon(Icons.share_rounded),
                ),
                IconButton(
                  onPressed: (sessionId.isEmpty || pdfPath.isEmpty)
                      ? null
                      : () => onDelete(sessionId, pdfPath),
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
                AmbyoRiskBadge(level: level.isEmpty ? 'PENDING' : level),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded,
                    color: AmbyoColors.textSecondary,
                    size: AmbyoSpacing.iconMd),
              ],
            ),
            borderLeftColor: riskColor,
            onTap: pdfPath.isEmpty ? null : () => onView(pdfPath),
          ),
        );
      },
    );
  }
}

class _MiniReportsTab extends StatelessWidget {
  const _MiniReportsTab({
    required this.rows,
    required this.onView,
    required this.onShare,
  });

  final List<Map<String, Object?>> rows;
  final void Function(String pdfPath) onView;
  final void Function(String pdfPath) onShare;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const _EmptyTab(
        icon: Icons.assignment_turned_in_outlined,
        title: 'No mini reports yet',
        message: 'Run an individual test and generate a one-page PDF summary.',
      );
    }

    return ListView.builder(
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        final testName = (row['test_name'] as String?) ?? '';
        final pdfPath = (row['mini_pdf_path'] as String?) ?? '';
        final created =
            DateTime.tryParse((row['created_at'] as String?) ?? '')?.toLocal();
        final detailsRaw = (row['details'] as String?) ?? '{}';
        final details = _safeJson(detailsRaw);

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AmbyoListItem(
            leading: ambyoIconBox(
                icon: Icons.picture_as_pdf_rounded,
                color: AmbyoColors.royalBlue),
            title: _prettyTestName(testName),
            subtitle: created == null ? '-' : _fmtDate(created),
            caption: 'Result: ${_miniSummary(testName, details)}',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: pdfPath.isEmpty ? null : () => onShare(pdfPath),
                  icon: const Icon(Icons.share_rounded),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: AmbyoColors.textSecondary,
                    size: AmbyoSpacing.iconMd),
              ],
            ),
            onTap: pdfPath.isEmpty ? null : () => onView(pdfPath),
          ),
        );
      },
    );
  }
}

class _RiskPill extends StatelessWidget {
  const _RiskPill({
    required this.level,
    required this.score,
  });

  final String level;
  final double? score;

  @override
  Widget build(BuildContext context) {
    final upper = level.toUpperCase();
    final (text, color) = () {
      if (upper.contains('URGENT')) {
        return ('URGENT', AmbyoTheme.dangerColor);
      }
      if (upper.contains('HIGH') || upper.contains('SEVERE')) {
        return ('HIGH', const Color(0xFFEF6C00));
      }
      if (upper.contains('MILD') || upper.contains('MEDIUM')) {
        return ('MILD', const Color(0xFFF9A825));
      }
      if (upper.contains('NORMAL') || upper.contains('LOW')) {
        return ('NORMAL', const Color(0xFF2E7D32));
      }
      return ('RISK', const Color(0xFF1565C0));
    }();

    final label = score == null ? text : '$text ${score!.toStringAsFixed(2)}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: color, fontWeight: FontWeight.w900, letterSpacing: 0.4),
      ),
    );
  }
}

class _EmptyTab extends StatelessWidget {
  const _EmptyTab({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: EnterprisePanel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 58, color: AmbyoTheme.primaryColor),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF13213A),
                    ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(color: const Color(0xFF66748B)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DarkReportsEmptyState extends StatelessWidget {
  const _DarkReportsEmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.onButton,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final VoidCallback onButton;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: const BoxDecoration(
              color: Color(0xFF1E1E1E), shape: BoxShape.circle),
          child: Icon(icon, size: 32, color: Colors.white24),
        ),
        const SizedBox(height: 20),
        Text(title,
            style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white)),
        const SizedBox(height: 8),
        Text(subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontFamily: 'Poppins', fontSize: 14, color: Colors.white38)),
        const SizedBox(height: 24),
        GestureDetector(
          onTap: onButton,
          child: Container(
            height: 52,
            margin: const EdgeInsets.symmetric(horizontal: 48),
            decoration: BoxDecoration(
              gradient: AmbyoGradients.primaryBtn,
              borderRadius: BorderRadius.circular(14),
              boxShadow: AmbyoShadows.buttonGlow,
            ),
            child: Center(
              child: Text(buttonLabel,
                  style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white)),
            ),
          ),
        ),
      ],
    );
  }
}

class _ReportsData {
  const _ReportsData({
    required this.patientId,
    required this.fullReports,
    required this.miniReports,
  });

  const _ReportsData.notLoggedIn()
      : patientId = null,
        fullReports = const <Map<String, Object?>>[],
        miniReports = const <Map<String, Object?>>[];

  final String? patientId;
  final List<Map<String, Object?>> fullReports;
  final List<Map<String, Object?>> miniReports;

  bool get isLoggedIn => patientId != null && patientId!.isNotEmpty;
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

String _prettyTestName(String t) {
  switch (t) {
    case 'gaze_detection':
      return 'Gaze Detection';
    case 'hirschberg':
      return 'Hirschberg';
    case 'prism_diopter':
      return 'Prism Diopter';
    case 'red_reflex':
      return 'Red Reflex';
    case 'suppression_test':
      return 'Suppression Test';
    case 'depth_perception':
      return 'Depth Perception';
    case 'titmus_stereo':
      return 'Titmus Stereo';
    case 'lang_stereo':
      return 'Lang Stereo';
    case 'ishihara_color':
      return 'Color Vision';
    case 'snellen_chart':
      return 'Visual Acuity';
    default:
      return t.replaceAll('_', ' ');
  }
}

Map<String, dynamic> _safeJson(String raw) {
  try {
    return (raw.isEmpty
        ? <String, dynamic>{}
        : (jsonDecode(raw) as Map<String, dynamic>));
  } catch (_) {
    return <String, dynamic>{};
  }
}

String _miniSummary(String testName, Map<String, dynamic> details) {
  String fmt(Object? v) {
    if (v == null) return '-';
    if (v is num) return v.toStringAsFixed(1);
    final d = double.tryParse(v.toString());
    return d == null ? v.toString() : d.toStringAsFixed(1);
  }

  switch (testName) {
    case 'snellen_chart':
      return (details['visual_acuity'] ?? details['visualAcuity'] ?? '-')
          .toString();
    case 'ishihara_color':
      return '${details['correct_answers'] ?? details['correctAnswers'] ?? '-'} / ${details['total_plates'] ?? details['totalTestPlates'] ?? '-'} correct';
    case 'titmus_stereo':
      return '${fmt(details['stereo_acuity_arc_seconds'] ?? details['stereoAcuityArcSeconds'] ?? '-')}" stereo';
    case 'lang_stereo':
      return '${details['patterns_detected'] ?? details['patternsDetected'] ?? '-'} / 3 patterns';
    case 'gaze_detection':
      return '${fmt(details['prismDiopterValue'] ?? details['prism_diopter'] ?? '-')}Δ';
    case 'prism_diopter':
      return '${fmt(details['totalDeviation'] ?? details['total_deviation'] ?? '-')}Δ';
    case 'red_reflex':
      final left =
          details['leftReflexType'] ?? details['left_reflex_type'] ?? '-';
      final right =
          details['rightReflexType'] ?? details['right_reflex_type'] ?? '-';
      return '$left / $right';
    default:
      return 'Saved';
  }
}
