import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/audit_logger.dart';
import '../../../core/theme/ambyo_theme.dart';
import '../../../core/theme/ambyoai_design_system.dart';
import '../../offline/database_tables.dart';
import '../../offline/local_database.dart';
import '../providers/auth_provider.dart';
import 'otp_verification_screen.dart';

class RoleSelectionScreen extends ConsumerStatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  ConsumerState<RoleSelectionScreen> createState() =>
      _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends ConsumerState<RoleSelectionScreen> {
  UserRole _selectedRole = UserRole.patient;

  final _patientPhone = TextEditingController();
  final _doctorUser = TextEditingController();
  final _doctorPass = TextEditingController();
  final _workerPhone = TextEditingController();
  final _workerPin = TextEditingController();

  bool _showDoctorPass = false;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _patientPhone.dispose();
    _doctorUser.dispose();
    _doctorPass.dispose();
    _workerPhone.dispose();
    _workerPin.dispose();
    super.dispose();
  }

  void _setRole(UserRole role) {
    setState(() {
      _selectedRole = role;
      _error = null;
    });
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });

    if (_selectedRole == UserRole.patient) {
      final phone = _patientPhone.text.trim();
      if (phone.length != 10) {
        setState(() {
          _submitting = false;
          _error = 'Enter a valid 10-digit mobile number.';
        });
        return;
      }
      await RoleStorage.saveRole(UserRole.patient);
      ref.read(roleProvider.notifier).state = UserRole.patient;
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => OtpVerificationScreen(
            phoneNumber: phone,
            role: UserRole.patient,
          ),
        ),
      );
      setState(() => _submitting = false);
      return;
    }

    if (_selectedRole == UserRole.doctor) {
      final doctor = await LocalDatabase.instance.verifyDoctorLogin(
        _doctorUser.text.trim(),
        _doctorPass.text,
      );
      if (doctor == null) {
        setState(() {
          _submitting = false;
          _error = 'Invalid username or password';
        });
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('doctor_id', doctor.id);
      await prefs.setString('doctor_name', doctor.fullName);
      await prefs.setString('doctor_username', doctor.username);
      await RoleStorage.saveRole(UserRole.doctor);
      ref.read(roleProvider.notifier).state = UserRole.doctor;
      AuditLogger.setUser('doctor', doctor.id);
      await AuditLogger.log(AuditAction.doctorLogin, targetId: doctor.id);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
            builder: (_) => AppRouter.homeForRole(UserRole.doctor)),
        (_) => false,
      );
      setState(() => _submitting = false);
      return;
    }

    final phone = _workerPhone.text.trim();
    final pin = _workerPin.text.trim();
    if (phone.length != 10 || pin.length != 4) {
      setState(() {
        _submitting = false;
        _error = 'Enter a valid phone and 4-digit PIN.';
      });
      return;
    }
    await RoleStorage.saveRole(UserRole.worker);
    ref.read(roleProvider.notifier).state = UserRole.worker;
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
          builder: (_) => AppRouter.homeForRole(UserRole.worker)),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AmbyoColors.darkBg,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: -100,
              right: -80,
              child: Container(
                width: 260,
                height: 260,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                      colors: [Color(0x2200D4FF), Colors.transparent]),
                ),
              ),
            ),
            Positioned(
              bottom: -100,
              left: -80,
              child: Container(
                width: 240,
                height: 240,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                      colors: [Color(0x181565C0), Colors.transparent]),
                ),
              ),
            ),
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _LogoLockup(),
                      const SizedBox(height: 28),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: const Text(
                          'ENTERPRISE ACCESS CONTROL',
                          style: TextStyle(
                            fontFamily: 'JetBrainsMono',
                            fontSize: 10,
                            color: Colors.white70,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Smart vision,\nsmarter care.',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 34,
                          height: 1.12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Choose your role and continue with the right offline workflow for this device.',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 15,
                          height: 1.5,
                          color: Colors.white60,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Row(
                          children: [
                            const _AccessSignal(
                              label: 'Offline',
                              value: 'Ready',
                              accent: Color(0xFF7CFFB2),
                            ),
                            const SizedBox(width: 10),
                            const _AccessSignal(
                              label: 'Device',
                              value: 'Secured',
                              accent: Color(0xFF55E6FF),
                            ),
                            const SizedBox(width: 10),
                            _AccessSignal(
                              label: 'Routing',
                              value: _selectedRole.name.toUpperCase(),
                              accent: const Color(0xFFFFC857),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF141C2C),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0xFF22324D)),
                          boxShadow: AmbyoShadows.card,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _RoleCard(
                                    label: 'Patient',
                                    icon: _RoleIcon.person,
                                    selected: _selectedRole == UserRole.patient,
                                    onTap: () => _setRole(UserRole.patient),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _RoleCard(
                                    label: 'Doctor',
                                    icon: _RoleIcon.stethoscope,
                                    selected: _selectedRole == UserRole.doctor,
                                    onTap: () => _setRole(UserRole.doctor),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _RoleCard(
                                    label: 'Worker',
                                    icon: _RoleIcon.clipboard,
                                    selected: _selectedRole == UserRole.worker,
                                    onTap: () => _setRole(UserRole.worker),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            if (_selectedRole == UserRole.patient)
                              _patientForm(),
                            if (_selectedRole == UserRole.doctor) _doctorForm(),
                            if (_selectedRole == UserRole.worker) _workerForm(),
                            if (_error != null) ...[
                              const SizedBox(height: 10),
                              Text(
                                _error!,
                                style: const TextStyle(
                                    color: Color(0xFFFF8A80),
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Center(
                        child: Text(
                          'AmbyoAI v1.0 · Amrita School of Computing · Aravind Eye Hospital',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            color: Color(0xFF7F8CA2),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _patientForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Patient Login',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _patientPhone,
          keyboardType: TextInputType.phone,
          maxLength: 10,
          decoration: const InputDecoration(
            labelText: 'Phone Number',
            prefixText: '+91 ',
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AmbyoTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            onPressed: _submitting ? null : _submit,
            child: Text(_submitting ? 'Sending...' : 'Send OTP'),
          ),
        ),
      ],
    );
  }

  Widget _doctorForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Doctor Login',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _doctorUser,
          decoration: const InputDecoration(
            labelText: 'Username',
            prefixIcon: Icon(Icons.person_outline_rounded),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _doctorPass,
          obscureText: !_showDoctorPass,
          decoration: InputDecoration(
            labelText: 'Password',
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            suffixIcon: IconButton(
              icon: Icon(_showDoctorPass
                  ? Icons.visibility_off_rounded
                  : Icons.visibility_rounded),
              onPressed: () =>
                  setState(() => _showDoctorPass = !_showDoctorPass),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AmbyoTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            onPressed: _submitting ? null : _submit,
            child: Text(_submitting ? 'Logging in...' : 'Login'),
          ),
        ),
      ],
    );
  }

  Widget _workerForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Worker Login',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _workerPhone,
          keyboardType: TextInputType.phone,
          maxLength: 10,
          decoration: const InputDecoration(
            labelText: 'Phone Number',
            prefixText: '+91 ',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _workerPin,
          keyboardType: TextInputType.number,
          maxLength: 4,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'PIN',
            prefixIcon: Icon(Icons.lock_outline_rounded),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AmbyoTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            onPressed: _submitting ? null : _submit,
            child: Text(_submitting ? 'Logging in...' : 'Login'),
          ),
        ),
      ],
    );
  }
}

class _LogoLockup extends StatelessWidget {
  const _LogoLockup();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.remove_red_eye_rounded,
              color: Color(0xFF00B4D8), size: 20),
        ),
        const SizedBox(width: 10),
        const Text(
          AppConstants.appName,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

class _AccessSignal extends StatelessWidget {
  const _AccessSignal({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accent.withValues(alpha: 0.16)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 10,
                color: Colors.white54,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _RoleIcon { person, stethoscope, clipboard }

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final _RoleIcon icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor =
        selected ? const Color(0xFF00B4D8) : const Color(0xFF24344E);
    final fillColor =
        selected ? const Color(0xFF0C2A36) : const Color(0xFF1A2233);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: fillColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 1.4),
        ),
        child: Column(
          children: [
            SizedBox(
              width: 34,
              height: 34,
              child: CustomPaint(
                painter: _RoleIconPainter(
                    icon: icon,
                    color: selected
                        ? const Color(0xFF00B4D8)
                        : const Color(0xFF93A4BE)),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : const Color(0xFF93A4BE),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleIconPainter extends CustomPainter {
  const _RoleIconPainter({
    required this.icon,
    required this.color,
  });

  final _RoleIcon icon;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (icon) {
      case _RoleIcon.person:
        canvas.drawCircle(Offset(size.width / 2, size.height * 0.35),
            size.width * 0.18, paint);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(size.width / 2, size.height * 0.72),
              width: size.width * 0.55,
              height: size.height * 0.35,
            ),
            const Radius.circular(8),
          ),
          paint,
        );
        break;
      case _RoleIcon.stethoscope:
        final center = Offset(size.width / 2, size.height * 0.42);
        final path = Path()
          ..moveTo(
              center.dx - size.width * 0.25, center.dy - size.height * 0.05)
          ..quadraticBezierTo(
              center.dx - size.width * 0.1,
              center.dy + size.height * 0.25,
              center.dx,
              center.dy + size.height * 0.25)
          ..quadraticBezierTo(
              center.dx + size.width * 0.1,
              center.dy + size.height * 0.25,
              center.dx + size.width * 0.25,
              center.dy - size.height * 0.05);
        canvas.drawPath(path, paint);
        canvas.drawCircle(
            Offset(
                center.dx - size.width * 0.25, center.dy - size.height * 0.05),
            size.width * 0.06,
            paint);
        canvas.drawCircle(
            Offset(
                center.dx + size.width * 0.25, center.dy - size.height * 0.05),
            size.width * 0.06,
            paint);
        canvas.drawCircle(
            Offset(
                center.dx + size.width * 0.12, center.dy + size.height * 0.3),
            size.width * 0.07,
            paint);
        break;
      case _RoleIcon.clipboard:
        final board = RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(size.width / 2, size.height * 0.58),
            width: size.width * 0.65,
            height: size.height * 0.65,
          ),
          const Radius.circular(6),
        );
        canvas.drawRRect(board, paint);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(size.width / 2, size.height * 0.25),
              width: size.width * 0.3,
              height: size.height * 0.18,
            ),
            const Radius.circular(4),
          ),
          paint,
        );
        final check = Path()
          ..moveTo(size.width * 0.32, size.height * 0.62)
          ..lineTo(size.width * 0.44, size.height * 0.72)
          ..lineTo(size.width * 0.64, size.height * 0.52);
        canvas.drawPath(check, paint);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _RoleIconPainter oldDelegate) {
    return oldDelegate.icon != icon || oldDelegate.color != color;
  }
}
