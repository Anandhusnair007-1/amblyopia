import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../core/services/audit_logger.dart';
import '../../../core/theme/ambyo_theme.dart';
import '../../../core/theme/ambyoai_design_system.dart';
import '../../../core/widgets/ambyoai_snackbar.dart';
import '../../../core/widgets/ambyoai_widgets.dart';
import '../../../core/widgets/enterprise_ui.dart';
import '../../consent/consent_flow.dart';
import '../../offline/database_tables.dart';
import '../../offline/local_database.dart';

class AddPatientScreen extends StatefulWidget {
  const AddPatientScreen({super.key});

  @override
  State<AddPatientScreen> createState() => _AddPatientScreenState();
}

class _AddPatientScreenState extends State<AddPatientScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _age = TextEditingController();
  String _gender = 'Male';
  final _phone = TextEditingController();
  final _nameFocus = FocusNode();
  final _ageFocus = FocusNode();
  final _phoneFocus = FocusNode();

  bool _submitting = false;

  @override
  void dispose() {
    _name.dispose();
    _age.dispose();
    _phone.dispose();
    _nameFocus.dispose();
    _ageFocus.dispose();
    _phoneFocus.dispose();
    super.dispose();
  }

  Future<void> _register({required bool startScreening}) async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;
    final name = _name.text.trim();
    final age = int.tryParse(_age.text.trim()) ?? -1;
    final phone = _phone.text.trim();

    if (phone.isNotEmpty) {
      final existing = await LocalDatabase.instance.getPatientByPhone(phone);
      if (existing != null) {
        if (!mounted) return;
        final theme = Theme.of(context);
        final sessions =
            await LocalDatabase.instance.getSessionsForPatient(existing.id);
        if (!mounted) return;
        final lastScreened =
            sessions.isNotEmpty ? sessions.first.testDate : null;
        final action = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AmbyoColors.darkCard,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Text('Patient Already Registered'),
            titleTextStyle: theme.textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${existing.name}, Age ${existing.age} is already registered with this phone number.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Last screened: ${lastScreened != null ? DateFormat('dd MMM yyyy').format(lastScreened.toLocal()) : 'Never'}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'cancel'),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'register'),
                child: const Text('Register Anyway'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, 'screen'),
                child: const Text('Screen Existing Patient'),
              ),
            ],
          ),
        );
        if (!mounted) return;
        if (action == 'screen') {
          final started = await ensureConsentThenStartScreening(
            context,
            existing,
            screener: 'Health Worker',
          );
          if (mounted && started) Navigator.of(context).pop();
          return;
        }
        if (action == 'cancel') return;
      }
    }

    setState(() => _submitting = true);
    final patient = Patient(
      id: const Uuid().v4(),
      name: name,
      age: age,
      gender: _gender,
      phone: phone,
      createdAt: DateTime.now().toUtc(),
    );
    await LocalDatabase.instance.savePatient(patient);
    await AuditLogger.log(
      AuditAction.patientRegistered,
      targetId: patient.id,
      targetType: 'patient',
      details: <String, dynamic>{'name': name, 'age': age},
    );

    if (!mounted) return;
    if (!startScreening) {
      setState(() => _submitting = false);
      AmbyoSnackbar.show(context,
          message: '$name registered successfully', type: SnackbarType.success);
      Navigator.of(context).pop();
      return;
    }

    setState(() => _submitting = false);
    final started = await ensureConsentThenStartScreening(
      context,
      patient,
      screener: 'Health Worker',
    );
    if (mounted && started) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return EnterpriseScaffold(
      title: 'Register Child',
      subtitle: 'Add to screening queue',
      appBarStyle: EnterpriseAppBarStyle.light,
      surfaceStyle: EnterpriseSurfaceStyle.plain,
      backgroundColor: AmbyoColors.darkBg,
      child: ListView(
        children: [
          const EnterpriseBanner(
            tone: EnterpriseBannerTone.info,
            title: 'Offline-ready registration',
            message:
                'This child record is stored locally and can be screened immediately or later from the queue.',
          ),
          const SizedBox(height: 16),
          EnterprisePanel(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const EnterpriseSectionHeader(
                    title: 'Child Details',
                    subtitle: 'Required fields: name, age, gender.',
                  ),
                  const SizedBox(height: 16),
                  AmbyoTextField(
                    controller: _name,
                    label: 'Child Name',
                    hint: 'Full name',
                    prefixIcon: Icons.child_care_rounded,
                    textInputAction: TextInputAction.next,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Child name is required.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  AmbyoTextField(
                    controller: _age,
                    label: 'Age (years)',
                    hint: '1–18',
                    prefixIcon: Icons.cake_rounded,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    validator: (v) {
                      final n = int.tryParse((v ?? '').trim());
                      if (n == null || n < 1 || n > 18) {
                        return 'Age must be 1 to 18 years.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Gender',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: ['Male', 'Female', 'Other'].map((g) {
                      final selected = _gender == g;
                      return ChoiceChip(
                        label: Text(g),
                        selected: selected,
                        onSelected: (_) => setState(() => _gender = g),
                        backgroundColor: AmbyoColors.darkCard,
                        selectedColor:
                            AmbyoTheme.primaryColor.withValues(alpha: 0.24),
                        side: BorderSide(
                          color: selected
                              ? AmbyoTheme.primaryColor
                              : AmbyoColors.darkBorder,
                        ),
                        labelStyle: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: selected ? Colors.white : Colors.white70,
                        ),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999)),
                      );
                    }).toList(growable: false),
                  ),
                  const SizedBox(height: 12),
                  AmbyoTextField(
                    controller: _phone,
                    label: 'Parent/Guardian Phone (optional)',
                    hint: '10 digits',
                    prefixIcon: Icons.phone_iphone_rounded,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.done,
                    validator: (v) {
                      final s = (v ?? '').trim();
                      if (s.isNotEmpty && s.length < 10) {
                        return 'Enter a valid phone number or leave it blank.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AmbyoTheme.warningColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                          color:
                              AmbyoTheme.warningColor.withValues(alpha: 0.28)),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.location_on_rounded,
                          color: AmbyoTheme.warningColor,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Anganwadi Center: Center #142, Kollam',
                            style: TextStyle(
                              color: AmbyoTheme.warningColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 64,
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _submitting
                          ? null
                          : () => _register(startScreening: true),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: Text(
                          _submitting ? 'Working...' : 'Register & Screen'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(64),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _submitting
                          ? null
                          : () => _register(startScreening: false),
                      child: const Text('Register Only'),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Tip: Register-only adds the child to today’s queue so you can screen them later.',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                  foregroundColor: AmbyoTheme.dangerColor),
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded),
              label: const Text('Cancel'),
            ),
          ),
        ],
      ),
    );
  }
}
