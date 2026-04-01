import 'package:flutter/material.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/ambyo_theme.dart';
import '../../../core/theme/ambyoai_design_system.dart';
import '../../../core/widgets/ambyoai_list_item.dart';
import '../../../core/widgets/ambyoai_widgets.dart';
import '../../../core/widgets/enterprise_ui.dart';
import '../../../core/widgets/offline_banner.dart';
import '../../../features/offline/local_database.dart';

class DoctorPatientDetailScreen extends StatefulWidget {
  const DoctorPatientDetailScreen({
    super.key,
    required this.patientId,
    this.patientName,
  });

  final String patientId;
  final String? patientName;

  @override
  State<DoctorPatientDetailScreen> createState() => _DoctorPatientDetailScreenState();
}

class _DoctorPatientDetailScreenState extends State<DoctorPatientDetailScreen> {
  Future<List<Map<String, dynamic>>>? _loader;

  @override
  void initState() {
    super.initState();
    _loader = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    return LocalDatabase.instance.getSessionsForPatientDoctor(widget.patientId);
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.patientName?.isNotEmpty == true
        ? widget.patientName!
        : 'Patient';
    return OfflineBanner(
      child: EnterpriseScaffold(
        title: title,
        subtitle: 'Screening sessions',
        appBarStyle: EnterpriseAppBarStyle.light,
        surfaceStyle: EnterpriseSurfaceStyle.plain,
        backgroundColor: const Color(0xFFF5F7FA),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _loader,
          builder: (context, snapshot) {
            final sessions = snapshot.data;
            if (snapshot.connectionState != ConnectionState.done || sessions == null) {
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                itemCount: 5,
                itemBuilder: (_, __) => const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: AmbyoShimmer(height: 72),
                ),
              );
            }
            if (sessions.isEmpty) {
              return Center(
                child: EnterprisePanel(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.assignment_outlined, size: 58, color: AmbyoColors.textSecondary),
                      const SizedBox(height: 14),
                      Text(
                        'No sessions yet',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF13213A),
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Screening sessions for this patient will appear here.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AmbyoColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              itemCount: sessions.length,
              itemBuilder: (context, index) {
                final s = sessions[index];
                final sessionId = (s['session_id'] ?? '').toString();
                final dateStr = (s['created_at'] ?? '').toString();
                final date = DateTime.tryParse(dateStr)?.toLocal();
                final riskLevel = (s['risk_level'] ?? '').toString();
                final hasDiagnosis = (s['diagnosis'] ?? '').toString().trim().isNotEmpty;
                final pill = _riskPill(riskLevel);
                final riskColor = AmbyoColors.riskColor(pill.label);
                final initials = date != null ? _month(date.month).substring(0, 1) : '?';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: AmbyoListItem(
                    leading: ambyoAvatar(initials: initials, color: riskColor),
                    title: date != null ? _fmtDate(date) : dateStr,
                    subtitle: 'Risk: ${pill.label}${hasDiagnosis ? ' · Diagnosed' : ''}',
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AmbyoRiskBadge(level: pill.label),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right_rounded, color: AmbyoColors.textSecondary, size: AmbyoSpacing.iconMd),
                      ],
                    ),
                    borderLeftColor: riskColor,
                    onTap: () => Navigator.of(context).pushNamed(AppRouter.doctorReportViewer, arguments: sessionId),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

({String label, Color color}) _riskPill(String riskLevel) {
  final upper = riskLevel.toUpperCase();
  if (upper.contains('URGENT')) return (label: 'URGENT', color: AmbyoTheme.dangerColor);
  if (upper.contains('HIGH') || upper.contains('SEVERE') || upper.contains('MODERATE')) {
    return (label: 'HIGH', color: const Color(0xFFEF6C00));
  }
  if (upper.contains('MILD') || upper.contains('MEDIUM')) return (label: 'MILD', color: const Color(0xFFF9A825));
  if (upper.contains('NORMAL') || upper.contains('LOW')) return (label: 'NORMAL', color: const Color(0xFF2E7D32));
  return (label: 'PENDING', color: const Color(0xFF64748B));
}

String _fmtDate(DateTime dt) {
  return '${dt.day.toString().padLeft(2, '0')} ${_month(dt.month)} ${dt.year}';
}

String _month(int m) {
  const names = <String>['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return names[(m - 1).clamp(0, 11)];
}
