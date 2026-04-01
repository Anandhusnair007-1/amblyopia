import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/services/audit_logger.dart';
import '../../../core/theme/ambyoai_design_system.dart';
import '../../../core/widgets/ambyoai_snackbar.dart';
import '../../../core/widgets/ambyoai_widgets.dart';
import '../../../core/router/app_router.dart';
import '../../../features/sync/report_syncer.dart';
import '../../ai_prediction/models/prediction_result.dart';
import '../../reports/models/urgent_finding.dart';
import '../../reports/report_model.dart';
import '../pdf_generator.dart';
import '../../offline/database_tables.dart';
import '../referral_letter_generator.dart';

class UrgentReportScreen extends StatefulWidget {
  const UrgentReportScreen({
    super.key,
    required this.data,
  });

  final UrgentReportData data;

  @override
  State<UrgentReportScreen> createState() => _UrgentReportScreenState();
}

class _UrgentReportScreenState extends State<UrgentReportScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    AuditLogger.log(
      AuditAction.urgentCaseFlagged,
      targetId: widget.data.sessionId,
      targetType: 'session',
      details: <String, dynamic>{
        'findings': widget.data.findings.map((f) => f.findingName).toList(),
      },
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
      lowerBound: 0.9,
      upperBound: 1.08,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _generatePdf() async {
    final report = ReportData(
      sessionId: widget.data.sessionId,
      patientId: widget.data.sessionId,
      patientName: widget.data.patientName,
      patientAge: widget.data.patientAge,
      patientGender: 'unknown',
      reportDate: widget.data.testDate,
      screenedBy: 'AmbyoAI App',
      aiPrediction: PredictionResult(
        riskScore: widget.data.riskScore,
        riskClass: 3,
        riskLevel: widget.data.riskLevel,
        recommendation: widget.data.recommendation,
        modelVersion: 'urgent',
        rawOutput: const <double>[0, 0, 0, 1],
      ),
      reportId: widget.data.sessionId,
      modelVersion: 'urgent',
    );
    final path = await PDFGenerator.generateReport(report);
    if (!mounted) {
      return;
    }
    Navigator.of(context).pushNamed(
      AppRouter.reportPreview,
      arguments: <String, dynamic>{'pdfPath': path, 'reportData': report},
    );
  }

  static Future<AravindCenter?> _showCenterPicker(BuildContext context) {
    return showDialog<AravindCenter>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Refer to Aravind Center',
          style: AmbyoTextStyles.subtitle(),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ReferralLetterGenerator.centers
              .map(
                (c) => ListTile(
                  title: Text(c.city, style: AmbyoTextStyles.body()),
                  subtitle: Text(c.phone, style: AmbyoTextStyles.caption()),
                  trailing: const Icon(Icons.chevron_right, color: AmbyoColors.royalBlue),
                  onTap: () => Navigator.pop(ctx, c),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Future<void> _sendToDoctor() async {
    final results = await Connectivity().checkConnectivity();
    final offline = results.contains(ConnectivityResult.none);
    if (!offline) {
      await runFullSync();
    }
    if (!mounted) {
      return;
    }
    AmbyoSnackbar.show(
      context,
      message: offline ? 'Will send when connected.' : 'Urgent report queued for doctor sync.',
      type: SnackbarType.info,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              Color(0xFFC62828),
              Color(0xFF7F0000),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                ScaleTransition(
                  scale: _pulseController,
                  child: const Icon(Icons.warning_amber_rounded, size: 72, color: Colors.white),
                ),
                const SizedBox(height: 12),
                const Text(
                  'URGENT REFERRAL REQUIRED',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Critical findings detected',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${widget.data.patientName} • ${widget.data.patientAge} years',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.data.testDate.toLocal().toString(),
                          style: const TextStyle(color: Color(0xFF66748B)),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Critical Findings:',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: ListView.separated(
                            itemCount: widget.data.findings.length,
                            separatorBuilder: (_, __) => const Divider(height: 18),
                            itemBuilder: (context, index) {
                              final finding = widget.data.findings[index];
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    margin: const EdgeInsets.only(top: 6),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFC62828),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${finding.findingName}: ${finding.measuredValue}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF13213A),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Normal: ${finding.normalRange}',
                                          style: const TextStyle(color: Color(0xFF66748B)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'AI Risk Assessment:',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFC62828),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Text(
                            '${widget.data.riskLevel} — Immediate attention needed',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          widget.data.recommendation,
                          style: const TextStyle(
                            color: Color(0xFF334155),
                            fontSize: 15,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                AmbyoPrimaryButton(
                  label: 'Generate Referral Letter',
                  icon: Icons.send_outlined,
                  onTap: () async {
                    final center = await _showCenterPicker(context);
                    if (center == null || !mounted) return;
                    final path = await ReferralLetterGenerator.generateReferralLetter(
                      patientName: widget.data.patientName,
                      patientAge: widget.data.patientAge,
                      sessionId: widget.data.sessionId,
                      findings: widget.data.findings,
                      riskLevel: widget.data.riskLevel,
                      screenedBy: widget.data.screenedBy,
                      centerName: 'Anganwadi',
                      referTo: center,
                    );
                    if (!mounted) return;
                    await Share.shareXFiles(
                      [XFile(path)],
                      text: 'Urgent referral letter for ${widget.data.patientName}',
                    );
                    await AuditLogger.log(
                      AuditAction.urgentCaseFlagged,
                      targetId: widget.data.sessionId,
                      targetType: 'session',
                      details: <String, dynamic>{'referred_to': center.city},
                    );
                  },
                ),
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: _generatePdf,
                  child: const Text('Generate PDF Report'),
                ),
                const SizedBox(height: 10),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF00897B)),
                  onPressed: _sendToDoctor,
                  child: const Text('Send to Doctor Now'),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white),
                    minimumSize: const Size.fromHeight(54),
                  ),
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text('Continue Remaining Tests'),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Report saved locally. Will sync to doctor portal when internet available.',
                  style: TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
