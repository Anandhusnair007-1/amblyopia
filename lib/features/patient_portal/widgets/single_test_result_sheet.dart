import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../eye_tests/depth_perception/models/depth_result.dart';
import '../../eye_tests/gaze_detection/models/gaze_result.dart';
import '../../eye_tests/hirschberg_test/models/hirschberg_result.dart';
import '../../eye_tests/ishihara_color/models/ishihara_result.dart';
import '../../eye_tests/lang_stereo/models/lang_result.dart';
import '../../eye_tests/prism_diopter/models/prism_result.dart';
import '../../eye_tests/red_reflex/models/red_reflex_result.dart';
import '../../eye_tests/snellen_chart/models/snellen_result.dart';
import '../../eye_tests/suppression_test/models/suppression_result.dart';
import '../../eye_tests/titmus_stereo/models/titmus_result.dart';
import '../../eye_tests/worth_four_dot/models/worth_four_dot_result.dart';
import '../../offline/local_database.dart';
import '../../reports/mini_pdf_generator.dart';

// Full-screen enterprise test result page — shown after completing a single test.
// Design: Zest-style dark, large status badge, plain-language interpretation,
//         trend indicator, mini-report CTA.

class SingleTestResultSheet extends StatefulWidget {
  const SingleTestResultSheet({
    super.key,
    required this.testName,
    required this.result,
  });

  final String testName;
  final dynamic result;

  @override
  State<SingleTestResultSheet> createState() => _SingleTestResultSheetState();
}

class _SingleTestResultSheetState extends State<SingleTestResultSheet>
    with TickerProviderStateMixin {
  bool _loading = true;
  String? _patientId;
  String? _patientName;
  String? _patientPhone;
  String? _currentSummary;
  String? _previousSummary;
  String? _trend;
  String? _status;
  String? _testResultId;
  bool _generatingReport = false;

  late final AnimationController _entryController;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _load();
  }

  @override
  void dispose() {
    _entryController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final patientId = prefs.getString('patient_id');
    final phone = prefs.getString('patient_phone') ??
        prefs.getString('ambyoai_user_phone');
    if (patientId == null || phone == null) {
      setState(() => _loading = false);
      _entryController.forward();
      return;
    }
    final patient = await LocalDatabase.instance.getPatient(patientId);
    final recent = await LocalDatabase.instance
        .recentResultsForTest(patientId, widget.testName, limit: 2);

    String? current;
    String? prev;
    String? status;
    if (recent.isNotEmpty) {
      final c = recent.first;
      _testResultId = c.id;
      current = _summaryFor(widget.testName, c.details);
      status = _statusForDetails(widget.testName, c.details, c.normalizedScore);
    }
    if (recent.length >= 2) {
      prev = _summaryFor(widget.testName, recent[1].details);
      _trend = _trendFor(current, prev);
    }

    setState(() {
      _patientId = patientId;
      _patientName = patient?.name ?? 'Patient';
      _patientPhone = phone;
      _currentSummary =
          current ?? _summaryForObject(widget.testName, widget.result);
      _previousSummary = prev;
      _status = _statusForObject(widget.testName, widget.result) ??
          status ??
          'Recorded';
      _loading = false;
    });
    _entryController.forward();
  }

  // ── Interpretation helpers ──────────────────────────────────────────────────

  String _displayTitle() {
    switch (widget.testName) {
      case 'gaze_detection':
        return 'Gaze Detection';
      case 'hirschberg':
        return 'Hirschberg Test';
      case 'prism_diopter':
        return 'Prism Diopter';
      case 'red_reflex':
        return 'Red Reflex Test';
      case 'suppression_test':
        return 'Suppression Test';
      case 'depth_perception':
        return 'Depth Perception';
      case 'titmus_stereo':
        return 'Titmus Stereo Test';
      case 'lang_stereo':
        return 'Lang Stereo Test';
      case 'ishihara_color':
        return 'Color Vision Test';
      case 'snellen_chart':
        return 'Visual Acuity';
      case 'worth_four_dot':
        return 'Worth 4 Dot';
      default:
        return widget.testName.replaceAll('_', ' ').toUpperCase();
    }
  }

  /// Plain-language interpretation shown to the patient/parent.
  String _interpretation() {
    final s = (_status ?? '').toLowerCase();
    final isNormal = s.contains('normal') || s == 'recorded';
    final isUrgent = s.contains('urgent') || s.contains('abnormal');
    switch (widget.testName) {
      case 'gaze_detection':
        if (isUrgent)
          return 'Eye misalignment detected. We recommend seeing an eye doctor soon.';
        if (!isNormal)
          return 'A slight gaze imbalance was noticed. Follow-up may be needed.';
        return 'Eyes are tracking together normally. No misalignment detected.';
      case 'hirschberg':
        if (isUrgent)
          return 'Corneal light reflex appears off-centre. An ophthalmologist review is recommended.';
        if (!isNormal)
          return 'Mild asymmetry in corneal reflex. Keep monitoring.';
        return 'Corneal light reflex is symmetric. Eyes appear well-aligned.';
      case 'prism_diopter':
        if (isUrgent)
          return 'Significant eye deviation measured. Urgent clinical review advised.';
        if (!isNormal)
          return 'Moderate deviation detected. A follow-up with a specialist is suggested.';
        return 'Eye alignment is within normal range.';
      case 'red_reflex':
        if (isUrgent)
          return 'Abnormal red reflex found. This needs prompt evaluation by an ophthalmologist.';
        if (!isNormal)
          return 'Red reflex appears unusual in one eye. Further testing recommended.';
        return 'Red reflex is present and symmetric in both eyes. Normal finding.';
      case 'suppression_test':
        if (isUrgent)
          return 'Significant visual suppression detected. One eye may be suppressing the image.';
        if (!isNormal)
          return 'Some visual rivalry was observed. This may indicate mild amblyopia risk.';
        return 'Both eyes are contributing equally to vision. No suppression detected.';
      case 'depth_perception':
        if (isUrgent)
          return 'Poor depth perception detected. 3D vision may be significantly impaired.';
        if (!isNormal)
          return 'Reduced depth perception noted. Stereo vision may be mildly affected.';
        return 'Good depth perception. Stereo vision appears normal.';
      case 'titmus_stereo':
        if (isUrgent)
          return 'Stereo vision is severely reduced. Referral recommended.';
        if (!isNormal)
          return 'Stereo acuity is below expected range. Monitor closely.';
        return 'Stereo vision is within the normal range for the child\'s age.';
      case 'lang_stereo':
        if (isUrgent)
          return 'Unable to detect stereoscopic patterns. Vision assessment needed.';
        if (!isNormal)
          return 'Reduced pattern detection. May indicate reduced binocular vision.';
        return 'Stereoscopic patterns detected correctly. Binocular vision is functional.';
      case 'ishihara_color':
        if (isUrgent) return 'Significant color vision deficiency detected.';
        if (!isNormal)
          return 'Some difficulty with color discrimination noted. A formal color vision test is advised.';
        return 'Color vision appears normal. All Ishihara plates were identified correctly.';
      case 'snellen_chart':
        if (isUrgent)
          return 'Visual acuity is significantly reduced. Glasses or further testing may be needed urgently.';
        if (!isNormal)
          return 'Vision is slightly reduced. Glasses may help. Recommend an optometrist visit.';
        return 'Visual acuity is within the normal range. Clear vision detected.';
      case 'worth_four_dot':
        if (isUrgent) {
          return 'Worth 4 Dot suggests significant binocular fusion difficulty. Clinical review is recommended.';
        }
        if (!isNormal) {
          return 'Worth 4 Dot suggests possible suppression or inconsistent fusion. Follow-up is recommended.';
        }
        return 'Worth 4 Dot indicates binocular fusion is working normally.';
      default:
        return 'Test completed. Results have been saved for clinical review.';
    }
  }

  _StatusConfig _statusConfig() {
    final s = (_status ?? '').toLowerCase();
    if (s.contains('urgent') || s.contains('abnormal')) {
      return const _StatusConfig(
        label: 'Urgent',
        color: Color(0xFFD50000),
        bg: Color(0x1FD50000),
        icon: Icons.warning_amber_rounded,
      );
    }
    if (s.contains('mild') || s.contains('moderate')) {
      return const _StatusConfig(
        label: 'Mild Risk',
        color: Color(0xFFFFB300),
        bg: Color(0x1FFFB300),
        icon: Icons.info_outline_rounded,
      );
    }
    return const _StatusConfig(
      label: 'Normal',
      color: Color(0xFF00E676),
      bg: Color(0x1F00E676),
      icon: Icons.check_circle_outline_rounded,
    );
  }

  String _summaryForObject(String testName, dynamic result) {
    try {
      if (result is GazeTestResult)
        return '${result.prismDiopterValue.toStringAsFixed(1)} prism diopters';
      if (result is HirschbergResult)
        return '${math.max(result.leftDisplacementMM, result.rightDisplacementMM).toStringAsFixed(1)} mm displacement';
      if (result is PrismDiopterResult)
        return '${result.totalDeviation.toStringAsFixed(1)} Δ total deviation';
      if (result is RedReflexResult)
        return 'Left: ${result.leftReflexType}  ·  Right: ${result.rightReflexType}';
      if (result is SuppressionResult) return 'Pattern: ${result.result}';
      if (result is DepthPerceptionResult)
        return 'Stereo grade: ${result.stereoGrade}';
      if (result is TitmusResult)
        return '${result.stereoAcuityArcSeconds.toStringAsFixed(0)} arc-seconds acuity';
      if (result is LangResult)
        return '${result.patternsDetected}/3 patterns detected';
      if (result is IshiharaResult)
        return 'Color vision: ${result.colorVisionStatus}';
      if (result is SnellenResult)
        return 'Visual acuity: ${result.visualAcuity}';
      if (result is WorthFourDotResult) return 'Fusion: ${result.fusionStatus}';
      if (result is Map<String, dynamic>) return _summaryFor(testName, result);
    } catch (_) {}
    return 'Result saved.';
  }

  String _summaryFor(String testName, Map<String, dynamic> details) {
    switch (testName) {
      case 'gaze_detection':
        final pd = details['prismDiopterValue'] ??
            details['prism_diopter'] ??
            details['prismDiopters'];
        return '${_fmt(pd)} prism diopters';
      case 'hirschberg':
        final mm =
            details['leftDisplacementMM'] ?? details['left_displacement_mm'];
        return '${_fmt(mm)} mm displacement';
      case 'prism_diopter':
        final delta = details['totalDeviation'] ?? details['total_deviation'];
        return '${_fmt(delta)} Δ total deviation';
      case 'red_reflex':
        final l =
            details['leftReflexType'] ?? details['left_reflex_type'] ?? '–';
        final r =
            details['rightReflexType'] ?? details['right_reflex_type'] ?? '–';
        return 'Left: $l  ·  Right: $r';
      case 'suppression_test':
        final res = details['result'] ?? details['suppressedEye'] ?? '–';
        return 'Pattern: $res';
      case 'depth_perception':
        final grade = details['stereoGrade'] ?? details['stereo_grade'] ?? '–';
        return 'Stereo grade: $grade';
      case 'titmus_stereo':
        final arc = details['stereo_acuity_arc_seconds'] ??
            details['stereoAcuityArcSeconds'];
        return '${_fmt(arc)} arc-seconds acuity';
      case 'lang_stereo':
        final detected =
            details['patterns_detected'] ?? details['patternsDetected'];
        return '${detected ?? 0}/3 patterns detected';
      case 'ishihara_color':
        final s = details['color_vision_status'] ??
            details['colorVisionStatus'] ??
            '–';
        return 'Color vision: $s';
      case 'snellen_chart':
        final a = details['visual_acuity'] ?? details['visualAcuity'] ?? '–';
        return 'Visual acuity: $a';
      case 'worth_four_dot':
        final status =
            details['fusion_status'] ?? details['fusionStatus'] ?? '–';
        return 'Fusion: $status';
      default:
        return 'Result saved.';
    }
  }

  String _statusForDetails(
      String testName, Map<String, dynamic> details, double normalized) {
    switch (testName) {
      case 'gaze_detection':
        final urgent = details['requiresUrgentReferral'] == true;
        final prism =
            _toDouble(details['prismDiopterValue'] ?? details['prism_diopter']);
        if (urgent || prism > 20) return 'Urgent';
        if (prism > 10) return 'Mild';
        return 'Normal';
      case 'hirschberg':
      case 'prism_diopter':
        final severity = (details['severity'] ?? 'Normal').toString();
        if (severity == 'Severe') return 'Urgent';
        if (severity == 'Moderate' || severity == 'Mild') return 'Mild';
        return 'Normal';
      case 'red_reflex':
        final urgent = details['requiresUrgentReferral'] ??
            details['requires_urgent_referral'];
        final normal = details['isNormal'] ?? details['is_normal'];
        if (urgent == true) return 'Urgent';
        if (normal == true) return 'Normal';
        return 'Mild';
      case 'suppression_test':
        final abnormal = details['isAbnormal'] ?? details['is_abnormal'];
        return abnormal == true ? 'Mild' : 'Normal';
      case 'depth_perception':
        final referral =
            details['requiresReferral'] ?? details['requires_referral'];
        final grade = (details['stereoGrade'] ?? details['stereo_grade'] ?? '')
            .toString();
        if (referral == true && grade == 'Absent') return 'Urgent';
        if (referral == true) return 'Mild';
        return 'Normal';
      case 'titmus_stereo':
      case 'lang_stereo':
        final referral =
            details['requiresReferral'] ?? details['requires_referral'];
        return referral == true ? 'Mild' : 'Normal';
      case 'ishihara_color':
        final isNormal = details['isNormal'] ?? details['is_normal'];
        return isNormal == true ? 'Normal' : 'Mild';
      case 'snellen_chart':
        final referral =
            details['requiresReferral'] ?? details['requires_referral'];
        return referral == true ? 'Mild' : 'Normal';
      case 'worth_four_dot':
        final referral =
            details['requiresReferral'] ?? details['requires_referral'];
        return referral == true ? 'Mild' : 'Normal';
      default:
        if (normalized >= 0.8) return 'Normal';
        if (normalized >= 0.5) return 'Mild';
        return 'Urgent';
    }
  }

  String? _statusForObject(String testName, dynamic result) {
    switch (result) {
      case GazeTestResult r:
        if (r.requiresUrgentReferral || r.prismDiopterValue > 20)
          return 'Urgent';
        if (r.prismDiopterValue > 10) return 'Mild';
        return 'Normal';
      case HirschbergResult r:
        if (r.severity == 'Severe') return 'Urgent';
        if (r.severity == 'Moderate' || r.severity == 'Mild') return 'Mild';
        return 'Normal';
      case PrismDiopterResult r:
        if (r.severity == 'Severe') return 'Urgent';
        if (r.severity == 'Moderate' || r.severity == 'Mild') return 'Mild';
        return 'Normal';
      case RedReflexResult r:
        if (r.requiresUrgentReferral) return 'Urgent';
        if (!r.isNormal) return 'Mild';
        return 'Normal';
      case SuppressionResult r:
        return r.isAbnormal ? 'Mild' : 'Normal';
      case DepthPerceptionResult r:
        if (r.requiresReferral && r.stereoGrade == 'Absent') return 'Urgent';
        if (r.requiresReferral) return 'Mild';
        return 'Normal';
      case TitmusResult r:
        return r.requiresReferral ? 'Mild' : 'Normal';
      case LangResult r:
        return r.requiresReferral ? 'Mild' : 'Normal';
      case IshiharaResult r:
        return r.isNormal ? 'Normal' : 'Mild';
      case SnellenResult r:
        return r.requiresReferral ? 'Mild' : 'Normal';
      case WorthFourDotResult r:
        return r.requiresReferral ? 'Mild' : 'Normal';
      default:
        return null;
    }
  }

  String? _trendFor(String? current, String? prev) {
    if (current == null || prev == null) return null;
    final c = _extractNumber(current);
    final p = _extractNumber(prev);
    if (c == null || p == null) return null;
    if ((c - p).abs() < 0.01) return 'Stable';
    if (c < p) return 'Improving';
    return 'Worsening';
  }

  double? _extractNumber(String s) {
    final match = RegExp(r'(-?\d+(?:\.\d+)?)').firstMatch(s);
    if (match == null) return null;
    return double.tryParse(match.group(1)!);
  }

  String _fmt(Object? value) {
    if (value == null) return '–';
    if (value is num) return value.toStringAsFixed(1);
    final n = double.tryParse(value.toString());
    return n == null ? value.toString() : n.toStringAsFixed(1);
  }

  double _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  // ── Actions ─────────────────────────────────────────────────────────────────

  Future<void> _generateMiniReport() async {
    final patientId = _patientId;
    final testResultId = _testResultId;
    if (patientId == null || testResultId == null) return;
    setState(() => _generatingReport = true);
    try {
      final filePath = await MiniPDFGenerator.generateSingleTestReport(
        patientName: _patientName ?? 'Patient',
        patientPhone: _patientPhone ?? '',
        testName: widget.testName,
        summary: _currentSummary ?? 'Result recorded.',
        status: _status ?? '',
      );
      await LocalDatabase.instance.saveMiniReportPath(testResultId, filePath);
      if (!mounted) return;
      await Share.shareXFiles([XFile(filePath)]);
    } finally {
      if (mounted) setState(() => _generatingReport = false);
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0E12),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00B4D8)))
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    final cfg = _statusConfig();

    return SafeArea(
      child: Column(
        children: [
          // ── Top bar ──────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).maybePop();
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E24),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF2A2A32)),
                    ),
                    child: const Icon(Icons.arrow_back_rounded,
                        color: Colors.white70, size: 20),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _displayTitle(),
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      if (_patientName != null && _patientName != 'Patient')
                        Text(
                          _patientName!,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            color: Colors.white38,
                          ),
                        ),
                    ],
                  ),
                ),
                // Test complete chip
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00B4D8).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: const Color(0xFF00B4D8).withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_rounded,
                          size: 12, color: Color(0xFF00B4D8)),
                      SizedBox(width: 4),
                      Text(
                        'Complete',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF00B4D8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
              child: Column(
                children: [
                  // ── Hero status card ─────────────────────────────────────────
                  FadeTransition(
                    opacity: _entryController,
                    child: SlideTransition(
                      position: Tween<Offset>(
                              begin: const Offset(0, 0.06), end: Offset.zero)
                          .animate(CurvedAnimation(
                              parent: _entryController, curve: Curves.easeOut)),
                      child: _HeroStatusCard(
                        config: cfg,
                        pulseController: _pulseController,
                        interpretation: _interpretation(),
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ── Measurement card ─────────────────────────────────────────
                  FadeTransition(
                    opacity: _entryController,
                    child: _MeasurementCard(
                      testName: widget.testName,
                      summary: _currentSummary ?? '–',
                      previous: _previousSummary,
                      trend: _trend,
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ── What this means card ─────────────────────────────────────
                  _WhatNextCard(testName: widget.testName, statusConfig: cfg),

                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),

          // ── Bottom action buttons ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                // Generate mini report (Zest-style primary CTA)
                _ZestButton(
                  label:
                      _generatingReport ? 'Generating...' : 'Share Test Report',
                  icon: _generatingReport
                      ? Icons.hourglass_top_rounded
                      : Icons.share_rounded,
                  color: const Color(0xFF00B4D8),
                  onTap: _generatingReport ? null : _generateMiniReport,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _ZestButton(
                        label: 'Run Again',
                        icon: Icons.refresh_rounded,
                        color: const Color(0xFF1E1E24),
                        textColor: Colors.white70,
                        borderColor: const Color(0xFF2A2A32),
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).pop();
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ZestButton(
                        label: 'Back to Home',
                        icon: Icons.home_rounded,
                        color: const Color(0xFF1E1E24),
                        textColor: Colors.white70,
                        borderColor: const Color(0xFF2A2A32),
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).maybePop();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _StatusConfig {
  const _StatusConfig({
    required this.label,
    required this.color,
    required this.bg,
    required this.icon,
  });

  final String label;
  final Color color;
  final Color bg;
  final IconData icon;
}

class _HeroStatusCard extends StatelessWidget {
  const _HeroStatusCard({
    required this.config,
    required this.pulseController,
    required this.interpretation,
  });

  final _StatusConfig config;
  final AnimationController pulseController;
  final String interpretation;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1E),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: config.color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: config.color.withValues(alpha: 0.08),
            blurRadius: 32,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Animated status ring + big label (like Zest's 90% ring)
          Row(
            children: [
              AnimatedBuilder(
                animation: pulseController,
                builder: (_, __) {
                  final scale = 0.92 + pulseController.value * 0.08;
                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: config.bg,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: config.color.withValues(alpha: 0.4),
                            width: 2),
                      ),
                      child: Icon(config.icon, color: config.color, size: 30),
                    ),
                  );
                },
              ),
              const SizedBox(width: 18),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Result',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      color: Colors.white38,
                    ),
                  ),
                  Text(
                    config.label,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: config.color,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(color: Color(0xFF2A2A2E), height: 1),
          const SizedBox(height: 16),
          // Plain-language interpretation — the most important thing for a parent
          Text(
            interpretation,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              color: Colors.white70,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

class _MeasurementCard extends StatelessWidget {
  const _MeasurementCard({
    required this.testName,
    required this.summary,
    required this.previous,
    required this.trend,
  });

  final String testName;
  final String summary;
  final String? previous;
  final String? trend;

  Color _trendColor() {
    if (trend == null) return Colors.white38;
    if (trend!.contains('Improving')) return const Color(0xFF00E676);
    if (trend!.contains('Worsening')) return const Color(0xFFFF1744);
    return const Color(0xFF00B4D8);
  }

  IconData _trendIcon() {
    if (trend == null) return Icons.horizontal_rule_rounded;
    if (trend!.contains('Improving')) return Icons.trending_down_rounded;
    if (trend!.contains('Worsening')) return Icons.trending_up_rounded;
    return Icons.trending_flat_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1E),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF2A2A2E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Clinical Measurement',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white38,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            summary,
            style: const TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          if (previous != null) ...[
            const SizedBox(height: 14),
            const Divider(color: Color(0xFF2A2A2E), height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text(
                  'Previous: ',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    color: Colors.white38,
                  ),
                ),
                Text(
                  previous!,
                  style: const TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 12,
                    color: Colors.white54,
                  ),
                ),
                const Spacer(),
                if (trend != null) ...[
                  Icon(_trendIcon(), size: 16, color: _trendColor()),
                  const SizedBox(width: 4),
                  Text(
                    trend!,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _trendColor(),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _WhatNextCard extends StatelessWidget {
  const _WhatNextCard({required this.testName, required this.statusConfig});

  final String testName;
  final _StatusConfig statusConfig;

  String _whatNext() {
    final isUrgent = statusConfig.label == 'Urgent';
    final isMild = statusConfig.label == 'Mild Risk';
    if (isUrgent) {
      return 'Please visit an Aravind Eye Hospital centre as soon as possible. Show this report to the doctor.';
    }
    if (isMild) {
      return 'Consider scheduling a follow-up with an ophthalmologist. Run a full screening for a complete picture.';
    }
    return 'No immediate action needed. Run a complete 10-test screening to track overall eye health over time.';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1E),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF2A2A2E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline_rounded,
                  size: 16, color: statusConfig.color),
              const SizedBox(width: 8),
              const Text(
                'What to do next',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white38,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _whatNext(),
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              color: Colors.white60,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

/// Zest-style action button — solid fill CTA or ghost secondary.
class _ZestButton extends StatefulWidget {
  const _ZestButton({
    required this.label,
    required this.icon,
    required this.color,
    this.textColor = Colors.white,
    this.borderColor,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final Color textColor;
  final Color? borderColor;
  final VoidCallback? onTap;

  @override
  State<_ZestButton> createState() => _ZestButtonState();
}

class _ZestButtonState extends State<_ZestButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:
          widget.onTap != null ? (_) => setState(() => _pressed = true) : null,
      onTapUp: widget.onTap != null
          ? (_) {
              setState(() => _pressed = false);
              widget.onTap!();
            }
          : null,
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: AnimatedOpacity(
          opacity: widget.onTap == null ? 0.5 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              color: widget.color,
              borderRadius: BorderRadius.circular(14),
              border: widget.borderColor != null
                  ? Border.all(color: widget.borderColor!, width: 1)
                  : null,
              boxShadow: widget.borderColor == null
                  ? [
                      BoxShadow(
                        color: widget.color.withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      )
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.icon, color: widget.textColor, size: 18),
                const SizedBox(width: 8),
                Text(
                  widget.label,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: widget.textColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
