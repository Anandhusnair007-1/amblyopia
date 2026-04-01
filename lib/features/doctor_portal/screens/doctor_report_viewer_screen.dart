import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/ambyo_theme.dart';
import '../../../core/theme/ambyoai_design_system.dart';
import '../../../core/widgets/enterprise_ui.dart';
import '../../../core/widgets/offline_banner.dart';
import '../../../features/offline/local_database.dart';
import '../../../features/ai_prediction/models/prediction_result.dart';
import '../../../features/reports/pdf_generator.dart';
import '../../../features/reports/report_model.dart';

class DoctorReportViewerScreen extends StatefulWidget {
  const DoctorReportViewerScreen({
    super.key,
    required this.sessionId,
  });

  final String sessionId;

  @override
  State<DoctorReportViewerScreen> createState() =>
      _DoctorReportViewerScreenState();
}

class _DoctorReportViewerScreenState extends State<DoctorReportViewerScreen> {
  Future<Map<String, dynamic>?>? _loader;

  @override
  void initState() {
    super.initState();
    _loader = _load();
  }

  Future<Map<String, dynamic>?> _load() async {
    final session = await LocalDatabase.instance.getSession(widget.sessionId);
    if (session == null) return null;
    final patient = await LocalDatabase.instance.getPatient(session.patientId);
    final results =
        await LocalDatabase.instance.getSessionResults(widget.sessionId);
    final prediction =
        await LocalDatabase.instance.getPredictionForSession(widget.sessionId);
    final diagnosis =
        await LocalDatabase.instance.getDiagnosisForSession(widget.sessionId);

    final patientName = patient?.name ?? 'Child';
    final patientAge = patient?.age ?? 0;
    final tests = results
        .map((r) => <String, dynamic>{
              'test_name': r.testName,
              'normalized_score': r.normalizedScore,
              'details': r.details,
            })
        .toList();
    final report = <String, dynamic>{
      'patient_name': patientName,
      'patient_age': patientAge,
      'test_date': session.testDate.toIso8601String(),
      'pdf_path': session.pdfPath,
      'risk_level': prediction?.riskLevel ?? '',
      'risk_score': prediction?.riskScore,
      'results': <String, dynamic>{
        'patient_name': patientName,
        'patient_age': patientAge,
        'risk_level': prediction?.riskLevel ?? '',
        'risk_score': prediction?.riskScore,
        'tests': tests,
      },
      'doctor_notes': diagnosis?.diagnosis ?? '',
    };
    return report;
  }

  @override
  Widget build(BuildContext context) {
    return OfflineBanner(
      child: EnterpriseScaffold(
        title: 'Patient Report',
        subtitle:
            'Session ${widget.sessionId.substring(0, widget.sessionId.length.clamp(0, 10))}',
        appBarStyle: EnterpriseAppBarStyle.light,
        surfaceStyle: EnterpriseSurfaceStyle.plain,
        backgroundColor: AmbyoColors.darkBg,
        child: FutureBuilder<Map<String, dynamic>?>(
          future: _loader,
          builder: (context, snapshot) {
            final report = snapshot.data;
            if (snapshot.connectionState != ConnectionState.done) {
              return const _ReportLoading();
            }
            if (report == null) {
              return Center(
                child: EnterprisePanel(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          size: 58, color: AmbyoTheme.dangerColor),
                      const SizedBox(height: 14),
                      Text(
                        'Report not available',
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Session not found locally.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(color: Colors.white70),
                      ),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: () => setState(() => _loader = _load()),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final testDate =
                DateTime.tryParse((report['test_date'] ?? '').toString())
                    ?.toLocal();
            final results = _parseResults(report['results']);
            final patientName = (results['patient_name'] ?? 'Child').toString();
            final patientAge = results['patient_age']?.toString() ?? '';
            final riskLevel =
                (report['risk_level'] ?? results['risk_level'] ?? '')
                    .toString();
            final riskScore =
                _toDouble(report['risk_score'] ?? results['risk_score']);
            final pill = _riskPill(riskLevel);

            final tests = _extractTests(results);

            return ListView(
              children: [
                EnterprisePanel(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$patientName${patientAge.isEmpty ? "" : " · $patientAge y"}',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        testDate == null ? '-' : _fmtDateTime(testDate),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.white70,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: pill.color.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                              color: pill.color.withValues(alpha: 0.35)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.shield_rounded, color: pill.color),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '${pill.label} RISK${riskScore == null ? "" : " — AI Score: ${riskScore.toStringAsFixed(2)}"}',
                                style: TextStyle(
                                    color: pill.color,
                                    fontWeight: FontWeight.w900),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildPdfSection(context, report),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () => Navigator.of(context).pushNamed(
                                AppRouter.doctorDiagnosis,
                                arguments: <String, dynamic>{
                                  'sessionId': widget.sessionId,
                                  'patientName':
                                      (report['patient_name'] ?? '').toString(),
                                },
                              ),
                              icon: const Icon(Icons.edit_note_rounded),
                              label: Text((report['doctor_notes'] ?? '')
                                      .toString()
                                      .trim()
                                      .isEmpty
                                  ? 'Add Diagnosis'
                                  : 'Edit Diagnosis'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Test Results Summary',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                ),
                const SizedBox(height: 10),
                ...tests.map((t) {
                  final status = _testStatus(t);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: EnterprisePanel(
                      padding: EdgeInsets.zero,
                      child: ExpansionTile(
                        collapsedIconColor: Colors.white70,
                        iconColor: Colors.white,
                        collapsedTextColor: Colors.white,
                        textColor: Colors.white,
                        leading: Container(
                          width: 44,
                          height: 44,
                          margin: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: status.color.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Icon(t.icon, color: status.color),
                        ),
                        title: Text(
                          t.title,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                        ),
                        trailing: Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Text(
                            status.label,
                            style: TextStyle(
                                color: status.color,
                                fontWeight: FontWeight.w900),
                          ),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t.summary,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                                if (t.detailsText.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    t.detailsText,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(color: Colors.white70),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 6),
                if ((report['doctor_notes'] ?? '').toString().trim().isNotEmpty)
                  EnterprisePanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const EnterpriseSectionHeader(
                          title: 'Doctor Notes',
                          subtitle: 'Saved diagnosis and treatment guidance.',
                        ),
                        const SizedBox(height: 12),
                        Text(
                          (report['doctor_notes'] ?? '').toString(),
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(color: Colors.white),
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

  Widget _buildPdfSection(BuildContext context, Map<String, dynamic> report) {
    final pdfPath = report['pdf_path'] as String?;
    final hasPdf =
        pdfPath != null && pdfPath.isNotEmpty && File(pdfPath).existsSync();
    if (hasPdf) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).pushNamed(
                    AppRouter.reportPreview,
                    arguments: <String, dynamic>{'pdfPath': pdfPath},
                  ),
                  icon: const Icon(Icons.picture_as_pdf_rounded),
                  label: const Text('View Full PDF'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await Share.shareXFiles([XFile(pdfPath)],
                        text: 'AmbyoAI screening report');
                  },
                  icon: const Icon(Icons.share_rounded),
                  label: const Text('Share Report'),
                ),
              ),
            ],
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'PDF not available',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: Colors.white70),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: () => _generatePdf(report),
          icon: const Icon(Icons.picture_as_pdf_rounded),
          label: const Text('Generate PDF'),
        ),
      ],
    );
  }

  Future<void> _generatePdf(Map<String, dynamic> report) async {
    final sessionId = widget.sessionId;
    final session = await LocalDatabase.instance.getSession(sessionId);
    final patient =
        await LocalDatabase.instance.getPatient(session?.patientId ?? '');
    final prediction =
        await LocalDatabase.instance.getPredictionForSession(sessionId);
    if (session == null || patient == null || prediction == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Cannot generate PDF: missing session, patient, or prediction.')),
        );
      }
      return;
    }
    final predictionResult = PredictionResult(
      riskScore: prediction.riskScore,
      riskClass: _riskClassFromLevel(prediction.riskLevel),
      riskLevel: prediction.riskLevel,
      recommendation: prediction.recommendation,
      modelVersion: prediction.modelVersion,
    );
    final reportData = ReportData(
      sessionId: sessionId,
      patientId: patient.id,
      patientName: patient.name,
      patientAge: patient.age,
      patientGender: patient.gender,
      reportDate: session.testDate,
      screenedBy: 'AmbyoAI',
      aiPrediction: predictionResult,
      reportId: const Uuid().v4(),
      modelVersion: prediction.modelVersion,
    );
    try {
      await PDFGenerator.generateReport(reportData);
      if (mounted) {
        setState(() => _loader = _load());
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('PDF generated.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('PDF generation failed: $e')));
      }
    }
  }

  static int _riskClassFromLevel(String level) {
    final u = level.toUpperCase();
    if (u.contains('URGENT')) {
      return 3;
    }
    if (u.contains('HIGH') || u.contains('SEVERE') || u.contains('MODERATE')) {
      return 2;
    }
    if (u.contains('MILD') || u.contains('MEDIUM')) {
      return 1;
    }
    return 0;
  }
}

class _ReportLoading extends StatelessWidget {
  const _ReportLoading();

  @override
  Widget build(BuildContext context) {
    Widget block(double h) {
      return Shimmer.fromColors(
        baseColor: AmbyoColors.darkCard,
        highlightColor: AmbyoColors.darkElevated,
        child: Container(
          height: h,
          width: double.infinity,
          decoration: BoxDecoration(
            color: AmbyoColors.darkCard,
            borderRadius: BorderRadius.circular(22),
          ),
        ),
      );
    }

    return ListView(
      children: [
        block(160),
        const SizedBox(height: 12),
        block(120),
        const SizedBox(height: 12),
        block(120),
      ],
    );
  }
}

Map<String, dynamic> _parseResults(Object? raw) {
  if (raw is Map) return Map<String, dynamic>.from(raw);
  if (raw is String) {
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return <String, dynamic>{};
    }
  }
  return <String, dynamic>{};
}

double? _toDouble(Object? v) {
  if (v is num) return v.toDouble();
  return double.tryParse(v?.toString() ?? '');
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

String _fmtDateTime(DateTime dt) {
  final hh = dt.hour.toString().padLeft(2, '0');
  final mm = dt.minute.toString().padLeft(2, '0');
  return '${dt.day.toString().padLeft(2, '0')} ${_month(dt.month)} ${dt.year} · $hh:$mm';
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

class _DoctorTestCard {
  const _DoctorTestCard({
    required this.keyName,
    required this.title,
    required this.icon,
    required this.summary,
    required this.detailsText,
    required this.score,
  });

  final String keyName;
  final String title;
  final IconData icon;
  final String summary;
  final String detailsText;
  final double? score;
}

List<_DoctorTestCard> _extractTests(Map<String, dynamic> results) {
  final tests = <_DoctorTestCard>[];

  // Prefer detailed list if the sync payload includes it.
  final list = results['tests'];
  if (list is List) {
    for (final item in list) {
      if (item is! Map) continue;
      final m = Map<String, dynamic>.from(item);
      final name = (m['test_name'] ?? '').toString();
      final normalized = _toDouble(m['normalized_score']);
      final details = m['details'];
      final detailsMap = details is Map
          ? Map<String, dynamic>.from(details)
          : <String, dynamic>{};
      final def = _defFor(name);
      tests.add(
        _DoctorTestCard(
          keyName: name,
          title: def.title,
          icon: def.icon,
          summary: _summaryFor(name, detailsMap, normalized),
          detailsText: _detailsLine(name, detailsMap),
          score: normalized,
        ),
      );
    }
    return tests;
  }

  // Fallback: show the features available.
  for (final def in _featureDefs) {
    final score = _toDouble(results[def.keyName]);
    tests.add(
      _DoctorTestCard(
        keyName: def.keyName,
        title: def.title,
        icon: def.icon,
        summary: score == null
            ? 'No data'
            : 'Normalized score: ${score.toStringAsFixed(2)}',
        detailsText: def.hint,
        score: score,
      ),
    );
  }
  return tests;
}

({String title, IconData icon}) _defFor(String testName) {
  switch (testName) {
    case 'gaze_detection':
      return (title: 'Gaze Detection', icon: Icons.remove_red_eye_rounded);
    case 'hirschberg':
      return (title: 'Hirschberg', icon: Icons.flash_on_rounded);
    case 'prism_diopter':
      return (title: 'Prism Diopter', icon: Icons.straighten_rounded);
    case 'red_reflex':
      return (title: 'Red Reflex', icon: Icons.circle_rounded);
    case 'suppression_test':
      return (title: 'Suppression', icon: Icons.psychology_alt_rounded);
    case 'depth_perception':
      return (title: 'Depth Perception', icon: Icons.square_foot_rounded);
    case 'titmus_stereo':
      return (title: 'Titmus Stereo', icon: Icons.bug_report_rounded);
    case 'lang_stereo':
      return (title: 'Lang Stereo', icon: Icons.bubble_chart_rounded);
    case 'ishihara_color':
      return (title: 'Color Vision', icon: Icons.palette_rounded);
    case 'snellen_chart':
      return (title: 'Visual Acuity', icon: Icons.text_fields_rounded);
    default:
      return (
        title: testName.replaceAll('_', ' '),
        icon: Icons.science_outlined
      );
  }
}

String _summaryFor(
    String testName, Map<String, dynamic> details, double? normalized) {
  String fmt(Object? v) {
    if (v == null) return '-';
    if (v is num) return v.toStringAsFixed(1);
    final d = double.tryParse(v.toString());
    return d == null ? v.toString() : d.toStringAsFixed(1);
  }

  switch (testName) {
    case 'gaze_detection':
      return 'Prism diopters: ${fmt(details['prismDiopterValue'] ?? details['prism_diopter'] ?? '-')}Δ';
    case 'hirschberg':
      return 'Displacement: ${fmt(details['leftDisplacementMM'] ?? details['left_displacement_mm'] ?? '-')} mm';
    case 'prism_diopter':
      return 'Deviation: ${fmt(details['totalDeviation'] ?? details['total_deviation'] ?? '-')}Δ';
    case 'red_reflex':
      return 'Left/Right: ${(details['leftReflexType'] ?? details['left_reflex_type'] ?? '-')} / ${(details['rightReflexType'] ?? details['right_reflex_type'] ?? '-')}';
    case 'snellen_chart':
      return 'Acuity: ${(details['visual_acuity'] ?? details['visualAcuity'] ?? '-')}';
    case 'ishihara_color':
      return 'Status: ${(details['color_vision_status'] ?? details['colorVisionStatus'] ?? '-')}';
    default:
      return normalized == null
          ? 'Recorded'
          : 'Normalized score: ${normalized.toStringAsFixed(2)}';
  }
}

String _detailsLine(String testName, Map<String, dynamic> details) {
  final note = (details['clinicalNote'] ?? details['clinical_note'] ?? '')
      .toString()
      .trim();
  return note;
}

({String label, Color color}) _testStatus(_DoctorTestCard t) {
  final score = t.score;
  if (score == null) return (label: '—', color: AmbyoColors.unscreened);
  if (score >= 0.8) return (label: 'Normal', color: AmbyoTheme.successColor);
  if (score >= 0.5) return (label: 'Mild', color: AmbyoTheme.warningColor);
  return (label: 'High', color: AmbyoTheme.dangerColor);
}

class _FeatureDef {
  const _FeatureDef(this.keyName, this.title, this.icon, this.hint);
  final String keyName;
  final String title;
  final IconData icon;
  final String hint;
}

const _featureDefs = <_FeatureDef>[
  _FeatureDef('visual_acuity', 'Visual Acuity', Icons.text_fields_rounded,
      'Snellen normalized score.'),
  _FeatureDef('gaze_deviation', 'Gaze Deviation', Icons.remove_red_eye_rounded,
      'Gaze deviation normalized score.'),
  _FeatureDef('prism_diopter', 'Prism Diopter', Icons.straighten_rounded,
      'Prism deviation score.'),
  _FeatureDef('suppression_level', 'Suppression', Icons.psychology_alt_rounded,
      'Suppression score.'),
  _FeatureDef('depth_score', 'Depth', Icons.square_foot_rounded,
      'Depth perception score.'),
  _FeatureDef(
      'stereo_score', 'Stereo', Icons.bug_report_rounded, 'Stereo score.'),
  _FeatureDef(
      'color_score', 'Color Vision', Icons.palette_rounded, 'Color score.'),
  _FeatureDef(
      'red_reflex', 'Red Reflex', Icons.circle_rounded, 'Red reflex score.'),
  _FeatureDef('hirschberg', 'Hirschberg', Icons.flash_on_rounded,
      'Hirschberg normalized score.'),
];
