import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/screening_provider.dart';
import '../../models/combined_result_model.dart';
import '../../services/tts_service.dart';
import '../../widgets/grade_badge.dart';
import '../new_patient_screen.dart';
import '../village_screen.dart';

class ResultScreen extends StatefulWidget {
  const ResultScreen({super.key});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _scoreCtrl;
  late Animation<double> _scoreAnim;
  bool _reportShared = false;

  @override
  void initState() {
    super.initState();
    _scoreCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward();
    _scoreAnim = CurvedAnimation(parent: _scoreCtrl, curve: Curves.easeOut);
    WidgetsBinding.instance.addPostFrameCallback((_) => _speakResult());
  }

  Future<void> _speakResult() async {
    final prov = context.read<ScreeningProvider>();
    final result = prov.combinedResult;
    if (result == null) return;

    await Future.delayed(const Duration(milliseconds: 500));
    switch (result.severityGrade) {
      case 0:
      case 1:
        await TtsService.speak('Screening complete. Vision appears normal.');
        break;
      case 2:
        await TtsService.speak('Screening complete. Therapy recommended. Please visit Aravind Eye Hospital.');
        break;
      case 3:
        await TtsService.sayUrgent();
        break;
    }
  }

  Future<void> _shareWhatsApp(
      CombinedResultModel result, String sessionId) async {
    final msg =
        'Screening result from Aravind Eye Hospital:\n\n'
        'Grade: ${result.gradeLabel}\n'
        'Risk Score: ${(result.overallRiskScore * 100).toInt()}%\n'
        '${result.recommendation}\n\n'
        'Ref: $sessionId';
    final encoded = Uri.encodeComponent(msg);
    final url = Uri.parse('https://wa.me/?text=$encoded');
    if (await canLaunchUrl(url)) await launchUrl(url);
  }

  Future<void> _shareReport(
      CombinedResultModel result, String sessionId) async {
    final text =
        'AMBLYOPIA SCREENING REPORT\n'
        'Aravind Eye Hospital, Coimbatore\n'
        '================================\n'
        'Session ID: $sessionId\n'
        'Date: ${DateTime.now().toLocal()}\n\n'
        'RESULTS:\n'
        'Overall Grade: ${result.gradeLabel}\n'
        'Risk Score: ${(result.overallRiskScore * 100).toInt()}%\n'
        'Gaze Score: ${(result.gazeScore * 100).toInt()}%\n'
        'Snellen Score: ${(result.snellenScore * 100).toInt()}%\n'
        'Red-Green Score: ${(result.redgreenScore * 100).toInt()}%\n\n'
        'RECOMMENDATION:\n${result.recommendation}\n\n'
        'Referral Needed: ${result.referralNeeded ? "YES" : "NO"}';

    await Share.share(text, subject: 'Amblyopia Screening Report');
    setState(() => _reportShared = true);
  }

  Color _bgColor(int grade) {
    switch (grade) {
      case 0: return const Color(0xFF0D2B0D);
      case 1: return const Color(0xFF2B2200);
      case 2: return const Color(0xFF2B1400);
      case 3: return const Color(0xFF2B0000);
      default: return const Color(0xFF0A1628);
    }
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ScreeningProvider>();
    final result = prov.combinedResult;

    if (result == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A1628),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF00E5FF)),
        ),
      );
    }

    final sessionId = prov.sessionId ?? 'N/A';
    final snellen = prov.snellenResult;

    return Scaffold(
      backgroundColor: _bgColor(result.severityGrade),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () {
            prov.reset();
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const VillageScreen()),
              (route) => route.isFirst,
            );
          },
        ),
        title: const Text('Screening Result',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Overall result card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: result.gradeColor.withOpacity(0.5), width: 1.5),
              ),
              child: Column(
                children: [
                  // Animated score circle
                  AnimatedBuilder(
                    animation: _scoreAnim,
                    builder: (context, _) {
                      final displayScore =
                          (result.overallRiskScore * _scoreAnim.value * 100)
                              .toInt();
                      return Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: result.gradeColor, width: 4),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '$displayScore%',
                                style: TextStyle(
                                  color: result.gradeColor,
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Text('Risk',
                                  style: TextStyle(
                                      color: Colors.white60, fontSize: 12)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  // Grade badge
                  GradeBadge(grade: result.severityGrade, label: result.gradeLabel),
                  const SizedBox(height: 16),
                  // Recommendation
                  Text(
                    result.recommendation,
                    style: TextStyle(
                      color: result.severityGrade == 3
                          ? Colors.red[300]
                          : Colors.white70,
                      fontSize: result.severityGrade == 3 ? 16 : 14,
                      fontWeight: result.severityGrade == 3
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Scores breakdown
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Score Breakdown',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _ScoreBar(
                      label: 'Gaze',
                      score: result.gazeScore,
                      color: Colors.cyan),
                  const SizedBox(height: 10),
                  _ScoreBar(
                      label: 'Snellen',
                      score: result.snellenScore,
                      color: Colors.blue),
                  const SizedBox(height: 10),
                  _ScoreBar(
                      label: 'Red-Green',
                      score: result.redgreenScore,
                      color: Colors.green),
                  if (snellen != null) ...[
                    const SizedBox(height: 16),
                    const Divider(color: Colors.white12),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _VADisplay(eye: 'Right Eye', va: snellen.visualAcuityRight),
                        _VADisplay(eye: 'Left Eye', va: snellen.visualAcuityLeft),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            // AI confidence card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  Icon(
                    result.overallRiskScore < 0.9
                        ? Icons.warning_amber_outlined
                        : Icons.check_circle_outline,
                    color: result.overallRiskScore < 0.9
                        ? Colors.amber
                        : Colors.green,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('AI Confidence',
                            style: TextStyle(
                                color: Colors.white60, fontSize: 12)),
                        Text(
                          result.gazeScore > 0.88
                              ? '✅ High confidence result'
                              : '⚠️ Doctor review recommended',
                          style: TextStyle(
                            color: result.gazeScore > 0.88
                                ? Colors.green
                                : Colors.amber,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Action buttons
            _ActionButton(
              icon: Icons.message,
              label: 'WhatsApp Parent',
              color: const Color(0xFF25D366),
              onTap: () => _shareWhatsApp(result, sessionId),
            ),
            const SizedBox(height: 10),
            _ActionButton(
              icon: Icons.share,
              label: _reportShared ? 'Report Shared ✅' : 'Share Report',
              color: const Color(0xFF1565C0),
              onTap: () => _shareReport(result, sessionId),
            ),
            const SizedBox(height: 10),
            _ActionButton(
              icon: Icons.person_add,
              label: 'Screen New Patient',
              color: const Color(0xFF263238),
              onTap: () {
                prov.reset();
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const VillageScreen()),
                  (route) => route.isFirst,
                );
              },
            ),
            if (result.severityGrade >= 3) ...[
              const SizedBox(height: 10),
              _ActionButton(
                icon: Icons.local_hospital,
                label: 'Book Aravind Appointment',
                color: Colors.red[800]!,
                onTap: () async {
                  final url = Uri.parse('https://aravind.org/appointment');
                  if (await canLaunchUrl(url)) await launchUrl(url);
                },
              ),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scoreCtrl.dispose();
    super.dispose();
  }
}

class _ScoreBar extends StatelessWidget {
  final String label;
  final double score;
  final Color color;

  const _ScoreBar({required this.label, required this.score, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 78,
          child: Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: score.clamp(0.0, 1.0),
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 10,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${(score * 100).toInt()}%',
          style: TextStyle(
              color: color, fontSize: 13, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class _VADisplay extends StatelessWidget {
  final String eye;
  final String va;
  const _VADisplay({required this.eye, required this.va});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(eye, style: const TextStyle(color: Colors.white60, fontSize: 12)),
        const SizedBox(height: 4),
        Text(va,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
