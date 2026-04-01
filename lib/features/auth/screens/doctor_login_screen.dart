import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/router/app_router.dart';
import '../../../core/services/audit_logger.dart';
import '../../../core/theme/ambyo_theme.dart';
import '../../../core/theme/ambyoai_design_system.dart';
import '../../../core/widgets/ambyoai_widgets.dart';
import '../../../core/widgets/enterprise_ui.dart';
import '../../offline/database_tables.dart';
import '../../offline/local_database.dart';
import '../providers/auth_provider.dart';

class DoctorLoginScreen extends ConsumerStatefulWidget {
  const DoctorLoginScreen({super.key});

  @override
  ConsumerState<DoctorLoginScreen> createState() => _DoctorLoginScreenState();
}

class _DoctorLoginScreenState extends ConsumerState<DoctorLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });

    final doctor = await LocalDatabase.instance.verifyDoctorLogin(
      _username.text.trim(),
      _password.text,
    );

    if (doctor == null) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = 'Invalid username or password';
        });
      }
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('doctor_id', doctor.id);
    await prefs.setString('doctor_name', doctor.fullName);
    await prefs.setString('doctor_username', doctor.username);

    await RoleStorage.saveRole(UserRole.doctor);
    ref.read(roleProvider.notifier).state = UserRole.doctor;

    AuditLogger.setUser('doctor', doctor.id);
    AuditLogger.log(AuditAction.doctorLogin, targetId: doctor.id);

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
          builder: (_) => AppRouter.homeForRole(UserRole.doctor)),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return EnterpriseScaffold(
      title: 'Doctor Login',
      subtitle: 'Local access — no network required',
      appBarStyle: EnterpriseAppBarStyle.light,
      surfaceStyle: EnterpriseSurfaceStyle.plain,
      backgroundColor: AmbyoColors.backgroundColor,
      child: ListView(
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Form(
              key: _formKey,
              child: EnterprisePanel(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const EnterpriseSectionHeader(
                      title: 'Sign in as Clinician',
                      subtitle: 'Credentials are stored on this device only.',
                    ),
                    const SizedBox(height: 16),
                    AmbyoTextField(
                      controller: _username,
                      label: 'Username',
                      prefixIcon: Icons.person_rounded,
                      textInputAction: TextInputAction.next,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Username is required.'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    AmbyoTextField(
                      controller: _password,
                      label: 'Password',
                      prefixIcon: Icons.lock_rounded,
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Password is required.'
                          : null,
                    ),
                    if (kDebugMode) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'Dev: doctor / Aravind#2026!',
                        style: TextStyle(
                          color: Color(0x667D879B),
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!,
                          style: const TextStyle(
                              color: AmbyoTheme.dangerColor, fontSize: 13)),
                    ],
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _submitting ? null : _login,
                        icon: const Icon(Icons.login_rounded),
                        label: Text(_submitting ? 'Logging in...' : 'Login'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.arrow_back_rounded,
                            color: AmbyoTheme.primaryColor),
                        label: const Text('Back'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
