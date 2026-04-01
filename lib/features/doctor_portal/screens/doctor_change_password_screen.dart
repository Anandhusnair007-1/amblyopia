import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/ambyo_theme.dart';
import '../../../core/widgets/enterprise_ui.dart';
import '../../../features/offline/local_database.dart';

class DoctorChangePasswordScreen extends StatefulWidget {
  const DoctorChangePasswordScreen({super.key});

  @override
  State<DoctorChangePasswordScreen> createState() => _DoctorChangePasswordScreenState();
}

class _DoctorChangePasswordScreenState extends State<DoctorChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });

    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('doctor_username')?.trim();
    if (username == null || username.isEmpty) {
      if (mounted) {
        setState(() {
          _error = 'Not logged in as doctor';
          _submitting = false;
        });
      }
      return;
    }

    final current = _currentController.text;
    final newPass = _newController.text;
    try {
      final ok = await LocalDatabase.instance.changeDoctorPassword(
        username: username,
        oldPassword: current,
        newPassword: newPass,
      );
      if (!mounted) return;
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password changed successfully')),
        );
        Navigator.of(context).pop();
      } else {
        setState(() {
          _error = 'Current password is wrong';
          _submitting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to change password';
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return EnterpriseScaffold(
      title: 'Change Password',
      subtitle: 'Update your local account password',
      appBarStyle: EnterpriseAppBarStyle.light,
      surfaceStyle: EnterpriseSurfaceStyle.plain,
      backgroundColor: const Color(0xFFF5F7FA),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null) ...[
                EnterpriseBanner(
                  tone: EnterpriseBannerTone.danger,
                  title: _error!,
                  message: '',
                ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _currentController,
                obscureText: _obscureCurrent,
                decoration: InputDecoration(
                  labelText: 'Current password',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureCurrent ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
                  ),
                ),
                validator: (v) => (v == null || v.isEmpty) ? 'Enter current password' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _newController,
                obscureText: _obscureNew,
                decoration: InputDecoration(
                  labelText: 'New password',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureNew ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscureNew = !_obscureNew),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Enter new password';
                  if (v.length < 8) return 'At least 8 characters';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmController,
                obscureText: _obscureConfirm,
                decoration: InputDecoration(
                  labelText: 'Confirm new password',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Confirm new password';
                  if (v != _newController.text) return 'Passwords do not match';
                  return null;
                },
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: AmbyoTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _submitting
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Change password'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
