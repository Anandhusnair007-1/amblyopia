import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/ambyo_theme.dart';
import '../../../core/theme/ambyoai_design_system.dart';
import '../../../core/widgets/ambyoai_list_item.dart';
import '../../../core/widgets/ambyoai_widgets.dart';
import '../../../core/widgets/enterprise_ui.dart';
import '../../../core/widgets/offline_banner.dart';
import '../../auth/screens/patient_login_screen.dart';
import '../../eye_tests/test_flow_controller.dart';
import '../../offline/database_tables.dart';
import '../../offline/local_database.dart';
import '../widgets/patient_bottom_nav.dart';

class TestHistoryScreen extends StatefulWidget {
  const TestHistoryScreen({super.key});

  @override
  State<TestHistoryScreen> createState() => _TestHistoryScreenState();
}

class _TestHistoryScreenState extends State<TestHistoryScreen> {
  Future<_HistoryData>? _loader;
  _HistoryFilter _filter = _HistoryFilter.all;

  @override
  void initState() {
    super.initState();
    _loader = _load();
  }

  Future<_HistoryData> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final patientId = prefs.getString('patient_id');
    if (patientId == null || patientId.isEmpty) {
      return const _HistoryData.notLoggedIn();
    }

    final results =
        await LocalDatabase.instance.getAllResultsForPatient(patientId);
    return _HistoryData(patientId: patientId, results: results);
  }

  Future<void> _runAgain(String patientId, String testName) async {
    final sessionId = await LocalDatabase.instance.createSession(patientId);
    final patient = await LocalDatabase.instance.getPatient(patientId);
    if (patient == null) return;

    TestFlowController.initializeSessionContext(
      sessionId: sessionId,
      patientId: patientId,
      patientName: patient.name,
      patientAge: patient.age,
      gender: patient.gender,
      screener: 'AmbyoAI App',
    );
    if (!mounted) return;
    await TestFlowController.runSingleTest(context, testName, sessionId);
    setState(() => _loader = _load());
  }

  @override
  Widget build(BuildContext context) {
    return OfflineBanner(
      child: EnterpriseScaffold(
        title: 'Test History',
        subtitle: 'All recorded results',
        appBarStyle: EnterpriseAppBarStyle.light,
        surfaceStyle: EnterpriseSurfaceStyle.plain,
        backgroundColor: AmbyoColors.backgroundColor,
        actions: const [],
        bottomNavigationBar: const PatientBottomNav(
          currentRoute: AppRouter.patientTestHistory,
          light: true,
        ),
        child: FutureBuilder<_HistoryData>(
          future: _loader,
          builder: (context, snapshot) {
            final data = snapshot.data;
            if (snapshot.connectionState != ConnectionState.done ||
                data == null) {
              return const _HistoryLoading();
            }

            if (!data.isLoggedIn) {
              return EnterpriseEmptyState(
                icon: Icons.login,
                title: 'Sign in required',
                message:
                    'Log in with your phone number to view your test history.',
                buttonLabel: 'Go to Login',
                onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute<void>(
                      builder: (_) => const PatientLoginScreen()),
                  (_) => false,
                ),
              );
            }

            final filtered = _applyFilter(data.results, _filter);
            if (filtered.isEmpty) {
              return EnterpriseEmptyState(
                icon: Icons.science_outlined,
                title: 'No Tests Yet',
                message: 'Start a screening to see your test history here.',
                buttonLabel: 'Start Screening',
                onPressed: () => Navigator.of(context)
                    .pushReplacementNamed(AppRouter.patientHome),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _HistoryFilter.values.map((f) {
                    final selected = _filter == f;
                    return ChoiceChip(
                      label: Text(f.label),
                      selected: selected,
                      onSelected: (_) => setState(() => _filter = f),
                      selectedColor:
                          AmbyoTheme.primaryColor.withValues(alpha: 0.14),
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
                const SizedBox(height: 14),
                Expanded(
                  child: ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final r = filtered[index];
                      final def = _TestDefs.forName(r.testName);
                      final summary = _summary(def.testName, r.details);
                      final status =
                          _status(def.testName, r.details, r.normalizedScore);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: AmbyoListItem(
                          leading:
                              ambyoIconBox(icon: def.icon, color: status.color),
                          title: def.title,
                          subtitle: _formatDateTime(r.createdAt.toLocal()),
                          caption: 'Result: $summary · ${status.label}',
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AmbyoRiskBadge(level: status.label),
                              const SizedBox(width: 4),
                              const Icon(Icons.chevron_right_rounded,
                                  color: AmbyoColors.textSecondary,
                                  size: AmbyoSpacing.iconMd),
                            ],
                          ),
                          borderLeftColor: status.color,
                          onTap: () => _showDetails(r,
                              onRunAgain: () =>
                                  _runAgain(data.patientId!, r.testName)),
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

  List<TestResult> _applyFilter(List<TestResult> all, _HistoryFilter filter) {
    final allowed = filter.testNames;
    if (allowed == null) return all;
    return all
        .where((r) => allowed.contains(r.testName))
        .toList(growable: false);
  }

  Future<void> _showDetails(
    TestResult result, {
    required VoidCallback onRunAgain,
  }) async {
    final def = _TestDefs.forName(result.testName);
    final summary = _summary(def.testName, result.details);
    final status =
        _status(def.testName, result.details, result.normalizedScore);
    final note = (result.details['clinicalNote'] ??
            result.details['clinical_note'] ??
            '')
        .toString()
        .trim();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 8,
            bottom: 20 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: status.color.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(def.icon, color: status.color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          def.title,
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFF13213A),
                                  ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDateTime(result.createdAt.toLocal()),
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: const Color(0xFF66748B),
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF4FF),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFCFE0FF)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Result: $summary',
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text('Status: ${status.label}',
                        style: TextStyle(
                            color: status.color, fontWeight: FontWeight.w900)),
                    if (note.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(note,
                          style: const TextStyle(color: Color(0xFF334155))),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Raw Data',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF13213A),
                    ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  const JsonEncoder.withIndent('  ').convert(result.details),
                  style: const TextStyle(
                    fontFamily: 'Courier New',
                    fontSize: 12.5,
                    height: 1.35,
                    color: Color(0xFF334155),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    onRunAgain();
                  },
                  icon: const Icon(Icons.replay_rounded),
                  label: const Text('Run This Test Again'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HistoryLoading extends StatelessWidget {
  const _HistoryLoading();

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
        block(48),
        const SizedBox(height: 12),
        block(92),
        const SizedBox(height: 12),
        block(92),
        const SizedBox(height: 12),
        block(92),
      ],
    );
  }
}

class _HistoryData {
  const _HistoryData({
    required this.patientId,
    required this.results,
  });

  const _HistoryData.notLoggedIn()
      : patientId = null,
        results = const <TestResult>[];

  final String? patientId;
  final List<TestResult> results;

  bool get isLoggedIn => patientId != null && patientId!.isNotEmpty;
}

enum _HistoryFilter {
  all,
  gaze,
  vision,
  stereo,
  color,
  reflex;

  String get label {
    switch (this) {
      case _HistoryFilter.all:
        return 'All Tests';
      case _HistoryFilter.gaze:
        return 'Gaze';
      case _HistoryFilter.vision:
        return 'Vision';
      case _HistoryFilter.stereo:
        return 'Stereo';
      case _HistoryFilter.color:
        return 'Color';
      case _HistoryFilter.reflex:
        return 'Reflex';
    }
  }

  Set<String>? get testNames {
    switch (this) {
      case _HistoryFilter.all:
        return null;
      case _HistoryFilter.gaze:
        return const {'gaze_detection', 'hirschberg', 'prism_diopter'};
      case _HistoryFilter.vision:
        return const {'snellen_chart', 'suppression_test', 'worth_four_dot'};
      case _HistoryFilter.stereo:
        return const {'depth_perception', 'titmus_stereo', 'lang_stereo'};
      case _HistoryFilter.color:
        return const {'ishihara_color'};
      case _HistoryFilter.reflex:
        return const {'red_reflex'};
    }
  }
}

class _TestDefs {
  const _TestDefs(this.testName, this.title, this.icon);

  final String testName;
  final String title;
  final IconData icon;

  static _TestDefs forName(String testName) {
    switch (testName) {
      case 'gaze_detection':
        return const _TestDefs(
            'gaze_detection', 'Gaze Detection', Icons.remove_red_eye_rounded);
      case 'hirschberg':
        return const _TestDefs(
            'hirschberg', 'Hirschberg', Icons.flash_on_rounded);
      case 'prism_diopter':
        return const _TestDefs(
            'prism_diopter', 'Prism Diopter', Icons.straighten_rounded);
      case 'red_reflex':
        return const _TestDefs(
            'red_reflex', 'Red Reflex', Icons.circle_rounded);
      case 'suppression_test':
        return const _TestDefs('suppression_test', 'Suppression Test',
            Icons.psychology_alt_rounded);
      case 'depth_perception':
        return const _TestDefs(
            'depth_perception', 'Depth Perception', Icons.square_foot_rounded);
      case 'titmus_stereo':
        return const _TestDefs(
            'titmus_stereo', 'Titmus Stereo', Icons.bug_report_rounded);
      case 'lang_stereo':
        return const _TestDefs(
            'lang_stereo', 'Lang Stereo', Icons.bubble_chart_rounded);
      case 'ishihara_color':
        return const _TestDefs(
            'ishihara_color', 'Color Vision', Icons.palette_rounded);
      case 'snellen_chart':
        return const _TestDefs(
            'snellen_chart', 'Visual Acuity', Icons.text_fields_rounded);
      case 'worth_four_dot':
        return const _TestDefs(
            'worth_four_dot', 'Worth 4 Dot', Icons.visibility_rounded);
      default:
        return _TestDefs(
            testName, testName.replaceAll('_', ' '), Icons.science_outlined);
    }
  }
}

({String label, Color color}) _status(
    String testName, Map<String, dynamic> details, double normalized) {
  switch (testName) {
    case 'red_reflex':
      final urgent = details['requiresUrgentReferral'] ??
          details['requires_urgent_referral'];
      final normal = details['isNormal'] ?? details['is_normal'];
      if (urgent == true)
        return (label: 'Urgent', color: AmbyoTheme.dangerColor);
      if (normal == true)
        return (label: 'Normal', color: const Color(0xFF2E7D32));
      return (label: 'Abnormal', color: const Color(0xFFF9A825));
    case 'snellen_chart':
      final needs = details['requiresReferral'] ?? details['requires_referral'];
      if (needs == true)
        return (label: 'Needs review', color: const Color(0xFFF9A825));
      return (label: 'Normal', color: const Color(0xFF2E7D32));
    case 'worth_four_dot':
      final referral =
          details['requiresReferral'] ?? details['requires_referral'];
      return referral == true
          ? (label: 'Needs review', color: const Color(0xFFF9A825))
          : (label: 'Normal', color: const Color(0xFF2E7D32));
    default:
      if (normalized >= 0.8)
        return (label: 'Normal', color: const Color(0xFF2E7D32));
      if (normalized >= 0.5)
        return (label: 'Mild', color: const Color(0xFFF9A825));
      return (label: 'High', color: AmbyoTheme.dangerColor);
  }
}

String _summary(String testName, Map<String, dynamic> details) {
  String fmt(Object? v) {
    if (v == null) return '-';
    if (v is num) return v.toStringAsFixed(1);
    final d = double.tryParse(v.toString());
    return d == null ? v.toString() : d.toStringAsFixed(1);
  }

  switch (testName) {
    case 'gaze_detection':
      return '${fmt(details['prismDiopterValue'] ?? details['prism_diopter'] ?? 0)}Δ';
    case 'hirschberg':
      return '${fmt(details['leftDisplacementMM'] ?? details['left_displacement_mm'] ?? 0)} mm';
    case 'prism_diopter':
      return '${fmt(details['totalDeviation'] ?? details['total_deviation'] ?? 0)}Δ';
    case 'red_reflex':
      final left =
          details['leftReflexType'] ?? details['left_reflex_type'] ?? '-';
      final right =
          details['rightReflexType'] ?? details['right_reflex_type'] ?? '-';
      return '$left / $right';
    case 'suppression_test':
      return (details['result'] ??
              details['suppressed_eye'] ??
              details['suppressedEye'] ??
              '-')
          .toString();
    case 'depth_perception':
      return (details['stereoGrade'] ?? details['stereo_grade'] ?? '-')
          .toString();
    case 'titmus_stereo':
      return '${fmt(details['stereo_acuity_arc_seconds'] ?? details['stereoAcuityArcSeconds'] ?? 0)} arc-sec';
    case 'lang_stereo':
      final detected =
          details['patterns_detected'] ?? details['patternsDetected'] ?? 0;
      return '$detected/3 patterns';
    case 'ishihara_color':
      return (details['color_vision_status'] ??
              details['colorVisionStatus'] ??
              '-')
          .toString();
    case 'snellen_chart':
      return (details['visual_acuity'] ?? details['visualAcuity'] ?? '-')
          .toString();
    case 'worth_four_dot':
      return (details['fusion_status'] ?? details['fusionStatus'] ?? '-')
          .toString();
    default:
      return 'Recorded';
  }
}

String _formatDateTime(DateTime dt) {
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
