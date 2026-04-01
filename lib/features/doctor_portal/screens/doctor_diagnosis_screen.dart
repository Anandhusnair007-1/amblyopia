import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../core/services/audit_logger.dart';
import '../../../core/theme/ambyo_theme.dart';
import '../../../core/widgets/ambyoai_snackbar.dart';
import '../../../core/widgets/ambyoai_widgets.dart';
import '../../../core/widgets/enterprise_ui.dart';
import '../../../core/widgets/offline_banner.dart';
import '../../../features/offline/database_tables.dart';
import '../../../features/offline/local_database.dart';
import '../../../features/reports/referral_letter_generator.dart';

class DoctorDiagnosisScreen extends StatefulWidget {
  const DoctorDiagnosisScreen({
    super.key,
    required this.sessionId,
    this.patientName,
  });

  final String sessionId;
  final String? patientName;

  @override
  State<DoctorDiagnosisScreen> createState() => _DoctorDiagnosisScreenState();
}

class _DoctorDiagnosisScreenState extends State<DoctorDiagnosisScreen> {
  Future<Map<String, dynamic>?>? _loader;
  final _diagnosis = TextEditingController();
  final _treatment = TextEditingController();
  final _referredTo = ValueNotifier<String>(
    ReferralLetterGenerator.centers.isNotEmpty
        ? '${ReferralLetterGenerator.centers.first.name} ${ReferralLetterGenerator.centers.first.city}'
        : 'Aravind Coimbatore',
  );
  DateTime? _followUpDate;

  int _label = 1;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loader = _load();
  }

  Future<Map<String, dynamic>?> _load() async {
    final session = await LocalDatabase.instance.getSession(widget.sessionId);
    final prediction = await LocalDatabase.instance.getPredictionForSession(widget.sessionId);
    final diagnosis = await LocalDatabase.instance.getDiagnosisForSession(widget.sessionId);
    if (session == null && prediction == null) return null;
    final report = <String, dynamic>{
      'risk_level': prediction?.riskLevel ?? '',
      'risk_score': prediction?.riskScore,
    };
    if (diagnosis != null) {
      _diagnosis.text = diagnosis.diagnosis;
      _treatment.text = diagnosis.treatment;
      _referredTo.value = diagnosis.referredTo ??
          (ReferralLetterGenerator.centers.isNotEmpty
              ? '${ReferralLetterGenerator.centers.first.name} ${ReferralLetterGenerator.centers.first.city}'
              : 'Aravind Coimbatore');
      _followUpDate = diagnosis.followUpDate != null ? DateTime.tryParse(diagnosis.followUpDate!) : null;
      _label = _riskLabelToInt(diagnosis.riskLabel);
    }
    return report;
  }

  static int _riskLabelToInt(String label) {
    final u = label.toLowerCase();
    if (u == 'normal') return 0;
    if (u == 'mild') return 1;
    if (u == 'moderate') return 2;
    if (u == 'severe') return 3;
    return 1;
  }

  @override
  void dispose() {
    _diagnosis.dispose();
    _treatment.dispose();
    _referredTo.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      initialDate: _followUpDate ?? now.add(const Duration(days: 14)),
    );
    if (selected != null) {
      setState(() => _followUpDate = selected);
    }
  }

  Future<void> _save(Map<String, dynamic>? report) async {
    if (_saving) return;
    final diag = _diagnosis.text.trim();
    if (diag.isEmpty) {
      AmbyoSnackbar.show(context, message: 'Clinical diagnosis is required.', type: SnackbarType.warning);
      return;
    }

    setState(() => _saving = true);

    final prefs = await SharedPreferences.getInstance();
    final doctorId = prefs.getString('doctor_id') ?? '';
    if (doctorId.isEmpty) {
      if (mounted) {
        setState(() => _saving = false);
        AmbyoSnackbar.show(context, message: 'Not logged in as doctor.', type: SnackbarType.error);
      }
      return;
    }

    final diagnosis = DoctorDiagnosis(
      id: const Uuid().v4(),
      sessionId: widget.sessionId,
      doctorId: doctorId,
      diagnosis: diag,
      treatment: _treatment.text.trim(),
      riskLabel: _labelToString(_label),
      followUpDate: _followUpDate?.toIso8601String(),
      referredTo: _referredTo.value,
      createdAt: DateTime.now(),
    );
    await LocalDatabase.instance.saveDiagnosis(diagnosis);
    await AuditLogger.log(AuditAction.doctorDiagnosisAdded, targetId: widget.sessionId, targetType: 'session');

    if (!mounted) return;
    setState(() => _saving = false);
    AmbyoSnackbar.show(context, message: 'Diagnosis saved.', type: SnackbarType.success);
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return OfflineBanner(
      child: EnterpriseScaffold(
        title: 'Add Clinical Diagnosis',
        subtitle: widget.patientName?.isNotEmpty == true ? widget.patientName : 'Training label + notes',
        appBarStyle: EnterpriseAppBarStyle.light,
        surfaceStyle: EnterpriseSurfaceStyle.plain,
        backgroundColor: const Color(0xFFF5F7FA),
        child: FutureBuilder<Map<String, dynamic>?>(
          future: _loader,
          builder: (context, snapshot) {
            final report = snapshot.data;
            final riskLevel = (report?['risk_level'] ?? '').toString();
            final riskScore = _toDouble(report?['risk_score']);
            final pill = _riskPill(riskLevel);

            return ListView(
              children: [
                EnterprisePanel(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Session: ${widget.sessionId}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFF66748B),
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
                          border: Border.all(color: pill.color.withValues(alpha: 0.35)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.auto_awesome_rounded, color: pill.color),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'AI suggested: ${pill.label}${riskScore == null ? "" : " (${riskScore.toStringAsFixed(2)})"}',
                                style: TextStyle(color: pill.color, fontWeight: FontWeight.w900),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                EnterprisePanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const EnterpriseSectionHeader(
                        title: 'Clinical Diagnosis',
                        subtitle: 'Your diagnosis and label trains the model to improve future predictions.',
                      ),
                      const SizedBox(height: 16),
                      const Divider(height: 1),
                      const SizedBox(height: 16),
                      AmbyoTextField(
                        controller: _diagnosis,
                        label: 'Clinical Diagnosis',
                        hint: 'e.g. Mild amblyopia right eye, secondary to esotropia',
                        prefixIcon: Icons.medical_information_rounded,
                        minLines: 2,
                        maxLines: 4,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 16),
                      const Divider(height: 1),
                      const SizedBox(height: 16),
                      AmbyoTextField(
                        controller: _treatment,
                        label: 'Recommended Treatment',
                        hint: 'e.g. Patching therapy 2hrs/day, referral to orthoptist',
                        prefixIcon: Icons.healing_rounded,
                        minLines: 2,
                        maxLines: 4,
                        textInputAction: TextInputAction.done,
                      ),
                      const SizedBox(height: 20),
                      const Divider(height: 1),
                      const SizedBox(height: 16),
                      Text(
                        'Confirm AI Label for Training',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF13213A),
                            ),
                      ),
                      const SizedBox(height: 12),
                      _ColoredLabelRadio(
                        label: _label,
                        onSelected: (v) => setState(() => _label = v),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF4FF),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFCFE0FF)),
                        ),
                        child: const Text(
                          'Your label trains the AI model to improve future predictions.',
                          style: TextStyle(color: Color(0xFF102A64), fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _pickDate,
                              icon: const Icon(Icons.event_rounded),
                              label: Text(
                                _followUpDate == null ? 'Follow-up Date' : _fmtDate(_followUpDate!),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Referred to',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF13213A),
                            ),
                      ),
                      const SizedBox(height: 10),
                      ValueListenableBuilder<String>(
                        valueListenable: _referredTo,
                        builder: (context, value, _) {
                          final options = <String>[
                            ...ReferralLetterGenerator.centers.map((c) => '${c.name} ${c.city}'),
                            'AIIMS',
                            'Other',
                          ];
                          return Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: options
                                .map(
                                  (o) => ChoiceChip(
                                    label: Text(o),
                                    selected: value == o,
                                    onSelected: (_) => _referredTo.value = o,
                                    selectedColor: AmbyoTheme.primaryColor.withValues(alpha: 0.14),
                                    labelStyle: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: value == o ? AmbyoTheme.primaryColor : const Color(0xFF334155),
                                    ),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                                  ),
                                )
                                .toList(growable: false),
                          );
                        },
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _saving ? null : () => _save(report),
                          icon: const Icon(Icons.save_rounded),
                          label: Text(_saving ? 'Saving...' : 'Save Diagnosis'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).maybePop(),
                          child: const Text('Cancel'),
                        ),
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
}

/// Four colored radio options: Normal=green, Mild=amber, Moderate=orange, Severe=red.
class _ColoredLabelRadio extends StatelessWidget {
  const _ColoredLabelRadio({
    required this.label,
    required this.onSelected,
  });

  final int label;
  final ValueChanged<int> onSelected;

  static const _options = <_LabelOption>[
    _LabelOption(0, 'Normal', Color(0xFF2E7D32)),
    _LabelOption(1, 'Mild', Color(0xFFF9A825)),
    _LabelOption(2, 'Moderate', Color(0xFFEF6C00)),
    _LabelOption(3, 'Severe', Color(0xFFC62828)),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < _options.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: _buildOption(context, _options[i]),
          ),
        ],
      ],
    );
  }

  Widget _buildOption(BuildContext context, _LabelOption opt) {
    final selected = label == opt.value;
    return Material(
      color: selected ? opt.color.withValues(alpha: 0.14) : const Color(0xFFF1F5F9),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => onSelected(opt.value),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? opt.color : const Color(0xFFE2E8F0),
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: opt.color,
                  border: Border.all(
                    color: selected ? opt.color : const Color(0xFF94A3B8),
                    width: 1.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                opt.label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: selected ? opt.color : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LabelOption {
  const _LabelOption(this.value, this.label, this.color);
  final int value;
  final String label;
  final Color color;
}

double? _toDouble(Object? v) {
  if (v is num) return v.toDouble();
  return double.tryParse(v?.toString() ?? '');
}

({String label, Color color}) _riskPill(String riskLevel) {
  final upper = riskLevel.toUpperCase();
  if (upper.contains('URGENT')) return (label: 'Urgent', color: AmbyoTheme.dangerColor);
  if (upper.contains('HIGH') || upper.contains('SEVERE') || upper.contains('MODERATE')) {
    return (label: 'High', color: const Color(0xFFEF6C00));
  }
  if (upper.contains('MILD') || upper.contains('MEDIUM')) return (label: 'Mild', color: const Color(0xFFF9A825));
  if (upper.contains('NORMAL') || upper.contains('LOW')) return (label: 'Normal', color: const Color(0xFF2E7D32));
  return (label: 'Pending', color: const Color(0xFF64748B));
}

String _labelToString(int label) {
  switch (label) {
    case 0:
      return 'normal';
    case 1:
      return 'mild';
    case 2:
      return 'moderate';
    case 3:
      return 'severe';
    default:
      return 'unknown';
  }
}

String _fmtDate(DateTime dt) {
  return '${dt.day.toString().padLeft(2, '0')} ${_month(dt.month)} ${dt.year}';
}

String _month(int m) {
  const names = <String>['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return names[(m - 1).clamp(0, 11)];
}
