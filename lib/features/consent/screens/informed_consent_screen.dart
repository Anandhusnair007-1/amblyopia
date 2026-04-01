import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/providers/language_provider.dart';
import '../../../core/services/audit_logger.dart';
import '../../offline/database_tables.dart';
import '../../../core/theme/ambyo_theme.dart';
import '../../../core/widgets/ambyoai_widgets.dart';
import '../../../core/widgets/enterprise_ui.dart';
import '../../offline/local_database.dart';
import '../consent_strings.dart';

/// Shown once before first screening per patient, or when consent is older than 12 months (renewal).
/// Saves consent to SQLite and optional [onConsentDone] is called so the caller can proceed to screening.
class InformedConsentScreen extends StatefulWidget {
  const InformedConsentScreen({
    super.key,
    required this.patient,
    this.isRenewal = false,
    this.previousConsentDate,
    this.onConsentDone,
  });

  final Patient patient;
  final bool isRenewal;
  final DateTime? previousConsentDate;
  final VoidCallback? onConsentDone;

  @override
  State<InformedConsentScreen> createState() => _InformedConsentScreenState();
}

class _InformedConsentScreenState extends State<InformedConsentScreen> {
  final _formKey = GlobalKey<FormState>();

  final _patientName = TextEditingController();
  final _dateOfBirth = TextEditingController();
  final _guardianName = TextEditingController();
  final _guardianRelation = TextEditingController();

  DateTime? _pickedDob;
  bool _checkCamera = false;
  bool _checkStored = false;
  bool _checkResearch = false;
  bool _checkShareDoctor = false;
  bool _saving = false;

  static const int _guardianAgeThreshold = 18;

  @override
  void initState() {
    super.initState();
    _patientName.text = widget.patient.name;
    _dateOfBirth.addListener(_validateConsentButton);
    _guardianName.addListener(_validateConsentButton);
    _guardianRelation.addListener(_validateConsentButton);
  }

  @override
  void dispose() {
    _patientName.dispose();
    _dateOfBirth.dispose();
    _guardianName.dispose();
    _guardianRelation.dispose();
    super.dispose();
  }

  void _validateConsentButton() => setState(() {});

  ConsentStrings get _s {
    final code = context.watch<LanguageProvider>().code;
    return ConsentStrings.forLanguage(code);
  }

  Future<void> _pickDateOfBirth() async {
    final initial =
        _pickedDob ?? DateTime.now().subtract(const Duration(days: 365 * 5));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1990),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      _pickedDob = picked;
      _dateOfBirth.text =
          '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
      setState(() {});
    }
  }

  bool get _allChecks =>
      _checkCamera && _checkStored && _checkResearch && _checkShareDoctor;

  bool get _canConsent {
    if (!_allChecks) return false;
    if (_patientName.text.trim().isEmpty) return false;
    if (_dateOfBirth.text.trim().isEmpty) return false;
    // Only require guardian fields when age is confirmed between 1-17.
    // age=0 means "not set" — don't block consent in that case.
    final age = widget.patient.age;
    final needsGuardian = age > 0 && age < _guardianAgeThreshold;
    if (needsGuardian &&
        (_guardianName.text.trim().isEmpty ||
            _guardianRelation.text.trim().isEmpty)) {
      return false;
    }
    return true;
  }

  Future<void> _submitConsent() async {
    if (!_formKey.currentState!.validate() || !_canConsent || _saving) return;
    setState(() => _saving = true);

    DateTime dob;
    if (_pickedDob != null) {
      dob = _pickedDob!;
    } else {
      final parts = _dateOfBirth.text.trim().split(RegExp(r'[/\-.]'));
      if (parts.length >= 3) {
        final d = int.tryParse(parts[0]) ?? 1;
        final m = int.tryParse(parts[1]) ?? 1;
        final y = int.tryParse(parts[2]) ?? 2000;
        dob = DateTime(y, m, d);
      } else {
        dob = DateTime(2000, 1, 1);
      }
    }

    final code = context.read<LanguageProvider>().code;
    final record = ConsentRecord(
      patientId: widget.patient.id,
      patientName: _patientName.text.trim(),
      dateOfBirth: dob,
      guardianName: _guardianName.text.trim(),
      guardianRelation: _guardianRelation.text.trim(),
      consentDate: DateTime.now().toUtc(),
      signaturePngPath: '',
      language: code,
      appVersion: AppConstants.appVersion,
    );

    await LocalDatabase.instance.saveConsent(record);
    await AuditLogger.log(
      widget.isRenewal ? AuditAction.consentRenewed : AuditAction.consentGiven,
      targetId: widget.patient.id,
      targetType: 'patient',
    );

    if (!mounted) return;
    setState(() => _saving = false);
    widget.onConsentDone?.call();
    Navigator.of(context).pop(true);
  }

  Future<bool> _confirmSkip() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF111827),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFCC02).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.info_outline_rounded,
                    color: Color(0xFFFFCC02), size: 26),
              ),
              const SizedBox(height: 16),
              const Text(
                'Skip Consent?',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Consent is required before eye screening. Are you sure you want to exit?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  color: Colors.white54,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx, false),
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1F2B3E),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Text(
                            'Stay',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx, true),
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFFFF2D55).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: const Color(0xFFFF2D55)
                                  .withValues(alpha: 0.4)),
                        ),
                        child: const Center(
                          child: Text(
                            'Exit',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFFF2D55),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    // Fix: age=0 means "not set" — never force guardian fields
    final needsGuardian =
        widget.patient.age > 0 && widget.patient.age < _guardianAgeThreshold;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldExit = await _confirmSkip();
        if (!context.mounted) return;
        if (shouldExit) {
          Navigator.of(context).pop(false);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0F1C),
        appBar: AppBar(
          title: const Text('Screening Consent'),
          backgroundColor: const Color(0xFF0A0F1C),
          foregroundColor: Colors.white,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              if (widget.isRenewal) ...[
                EnterpriseBanner(
                  tone: EnterpriseBannerTone.warning,
                  title: 'Please renew consent',
                  message: widget.previousConsentDate != null
                      ? '${s.renewalExpiredPrefix}${DateFormat('dd MMM yyyy').format(widget.previousConsentDate!)}${s.renewalExpiredSuffix}'
                      : s.renewalSubtitle,
                ),
                const SizedBox(height: 16),
              ],
              // Simple header — no intro pages
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF111827),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF1E2D45),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.shield_outlined,
                        color: AmbyoTheme.primaryColor, size: 24),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Please confirm the following before starting your screening',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white70,
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              AmbyoTextField(
                controller: _patientName,
                label: s.patientNameLabel,
                hint: 'Full name',
                prefixIcon: Icons.badge_rounded,
                textInputAction: TextInputAction.next,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required.' : null,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _pickDateOfBirth,
                child: AbsorbPointer(
                  child: AmbyoTextField(
                    controller: _dateOfBirth,
                    label: s.dateOfBirthLabel,
                    hint: 'DD/MM/YYYY',
                    prefixIcon: Icons.calendar_today_rounded,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required.' : null,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              AmbyoTextField(
                controller: _guardianName,
                label: s.guardianNameLabel,
                hint: needsGuardian ? 'Guardian full name' : 'Optional',
                prefixIcon: Icons.person_rounded,
                textInputAction: TextInputAction.next,
                validator: needsGuardian
                    ? (v) => (v == null || v.trim().isEmpty)
                        ? 'Required for under 18.'
                        : null
                    : null,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              AmbyoTextField(
                controller: _guardianRelation,
                label: s.guardianRelationLabel,
                hint: 'e.g. Mother, Father',
                prefixIcon: Icons.family_restroom_rounded,
                textInputAction: TextInputAction.done,
                validator: needsGuardian
                    ? (v) => (v == null || v.trim().isEmpty)
                        ? 'Required for under 18.'
                        : null
                    : null,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 20),
              _ConsentCheckbox(
                value: _checkCamera,
                label: s.checkboxCamera,
                onChanged: (v) => setState(() => _checkCamera = v ?? false),
              ),
              _ConsentCheckbox(
                value: _checkStored,
                label: s.checkboxStored,
                onChanged: (v) => setState(() => _checkStored = v ?? false),
              ),
              _ConsentCheckbox(
                value: _checkResearch,
                label: s.checkboxResearch,
                onChanged: (v) => setState(() => _checkResearch = v ?? false),
              ),
              _ConsentCheckbox(
                value: _checkShareDoctor,
                label: s.checkboxShareDoctor,
                onChanged: (v) =>
                    setState(() => _checkShareDoctor = v ?? false),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 56,
                width: double.infinity,
                child: FilledButton(
                  onPressed: (_canConsent && !_saving) ? _submitConsent : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: AmbyoTheme.primaryColor,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFCFD8DC),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    _saving ? 'Saving...' : s.consentButton,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ), // end Scaffold
    ); // end PopScope
  }
}

class _ConsentCheckbox extends StatelessWidget {
  const _ConsentCheckbox({
    required this.value,
    required this.label,
    required this.onChanged,
  });

  final bool value;
  final String label;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: value ? const Color(0x221565C0) : const Color(0xFF111827),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: value ? const Color(0xFF00D4FF) : const Color(0xFF1E2D45),
              width: value ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Switch(
                value: value,
                onChanged: (v) => onChanged(v),
                activeThumbColor: const Color(0xFF00D4FF),
                activeTrackColor: const Color(0x551565C0),
                inactiveThumbColor: Colors.white38,
                inactiveTrackColor: const Color(0xFF1E2D45),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      color: value ? Colors.white : Colors.white70,
                      height: 1.4,
                      fontFamily: 'Poppins',
                      fontWeight: value ? FontWeight.w500 : FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
