import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/ambyoai_design_system.dart';
import '../../../core/widgets/ambyoai_widgets.dart';
import '../../../core/widgets/dark_input_field.dart';
import '../providers/auth_provider.dart';
import 'doctor_login_screen.dart';
import 'otp_verification_screen.dart';

class PatientLoginScreen extends ConsumerStatefulWidget {
  const PatientLoginScreen({super.key});

  @override
  ConsumerState<PatientLoginScreen> createState() => _PatientLoginScreenState();
}

class _PatientLoginScreenState extends ConsumerState<PatientLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _pinController = TextEditingController();
  String _selectedRole = 'patient';
  String? _error;
  String? _pinError;

  @override
  void dispose() {
    _phoneController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _requestOtp() async {
    final phone = _phoneController.text.trim();
    setState(() {
      _error = null;
      _pinError = null;
    });

    if (_selectedRole == 'doctor') {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const DoctorLoginScreen()),
      );
      return;
    }

    if (_selectedRole == 'worker') {
      final enteredPin = _pinController.text.trim();
      if (enteredPin.isEmpty) {
        setState(() => _pinError = 'Enter your worker PIN.');
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      final storedPin = prefs.getString('worker_pin') ?? '5816';
      if (enteredPin != storedPin) {
        setState(() => _pinError = 'Incorrect PIN. Try again.');
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
      return;
    }

    if (!_formKey.currentState!.validate()) return;
    if (phone.length != 10) {
      setState(() => _error = 'Enter a valid 10-digit number.');
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
            SizedBox(width: 10),
            Text(
              'OTP sent! Use 4826',
              style:
                  TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w500),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1565C0),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
    );

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OtpVerificationScreen(
          phoneNumber: phone,
          role: UserRole.patient,
        ),
      ),
    );
  }

  Widget _buildForm() {
    final isPatient = _selectedRole == 'patient';
    final isWorker = _selectedRole == 'worker';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isWorker) ...[
          DarkInputField(
            controller: _pinController,
            label: 'Worker PIN',
            keyboardType: TextInputType.number,
            maxLength: 4,
            obscureText: true,
            textStyle: const TextStyle(
                color: Colors.white,
                fontFamily: 'JetBrainsMono',
                fontSize: 22,
                letterSpacing: 8),
            hintText: '• • • •',
            hintStyle: const TextStyle(
                color: Colors.white24,
                letterSpacing: 8,
                fontSize: 18,
                fontFamily: 'Poppins'),
            errorText: _pinError,
            focusColor: const Color(0xFF00897B),
          ),
          const SizedBox(height: 4),
          const Text('Default PIN: 5816',
              style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  color: Colors.white24,
                  fontStyle: FontStyle.italic)),
          const SizedBox(height: 12),
        ] else if (isPatient) ...[
          Form(
            key: _formKey,
            child: DarkInputField(
              controller: _phoneController,
              label: 'Mobile Number',
              textStyle: const TextStyle(
                color: Colors.white,
                fontFamily: 'Poppins',
                fontSize: 16,
              ),
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              maxLength: 10,
              onFieldSubmitted: (_) => _requestOtp(),
              validator: (v) {
                final s = (v ?? '').trim();
                if (s.length != 10) return 'Enter a valid 10-digit number.';
                return null;
              },
              hintText: 'Enter phone number',
              prefixText: '+91  ',
              focusColor: const Color(0xFF1565C0),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 6),
            Text(_error!,
                style: const TextStyle(
                    color: Color(0xFFFF5252),
                    fontSize: 12,
                    fontFamily: 'Poppins')),
          ],
          const SizedBox(height: 20),
        ] else ...[
          const SizedBox(height: 4),
          Text(
            _selectedRole == 'doctor'
                ? 'Tap below to open the doctor portal with username & password.'
                : '',
            style: const TextStyle(
                color: Colors.white38,
                fontFamily: 'Poppins',
                fontSize: 13,
                height: 1.4),
          ),
          const SizedBox(height: 20),
        ],
        // CTA Button
        GestureDetector(
          onTap: () => _requestOtp(),
          child: Container(
            width: double.infinity,
            height: 52,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1565C0), Color(0xFF00B4D8)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1565C0).withValues(alpha: 0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Center(
              child: Text(
                _selectedRole == 'patient'
                    ? 'Send OTP'
                    : _selectedRole == 'doctor'
                        ? 'Open Doctor Portal'
                        : 'Enter Worker Portal',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        if (_selectedRole == 'patient') ...[
          const SizedBox(height: 12),
          const Center(
            child: Text(
              'Demo mode: use OTP 4826',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11,
                color: Colors.white24,
              ),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF060D1A),
      body: Stack(
        children: [
          Positioned(
            top: -120,
            right: -90,
            child: Container(
              width: 320,
              height: 320,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                    colors: [Color(0x2000D4FF), Colors.transparent]),
              ),
            ),
          ),
          Positioned(
            bottom: -60,
            left: -90,
            child: Container(
              width: 260,
              height: 260,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                    colors: [Color(0x151565C0), Colors.transparent]),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 36),

                  // ── Brand header ──────────────────────────────────────────
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          gradient: AmbyoGradients.primaryBtn,
                          boxShadow: AmbyoShadows.cyanGlow,
                        ),
                        child: const Icon(Icons.remove_red_eye,
                            color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('AmbyoAI',
                              style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white)),
                          Text('Clinical Eye Screening Platform',
                              style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 10,
                                  color: Colors.white.withValues(alpha: 0.35),
                                  letterSpacing: 0.3)),
                        ],
                      ),
                      const Spacer(),
                      // Aravind badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: const Color(0xFF1565C0)
                                  .withValues(alpha: 0.4)),
                        ),
                        child: Text('Aravind',
                            style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF00B4D8)
                                    .withValues(alpha: 0.8))),
                      ),
                    ],
                  ),

                  const SizedBox(height: 44),

                  // ── Headline ──────────────────────────────────────────────
                  const Text('Welcome back',
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.15)),
                  const SizedBox(height: 10),
                  Text('Select your role to continue',
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.45),
                          height: 1.55)),

                  const SizedBox(height: 36),

                  // ── Role selector row ─────────────────────────────────────
                  Row(
                    children: [
                      _RoleCard(
                          icon: Icons.child_care_rounded,
                          label: 'Patient',
                          accent: const Color(0xFF00B4D8),
                          isSelected: _selectedRole == 'patient',
                          onTap: () =>
                              setState(() => _selectedRole = 'patient')),
                      const SizedBox(width: 10),
                      _RoleCard(
                          icon: Icons.local_hospital_outlined,
                          label: 'Doctor',
                          accent: const Color(0xFF7C3AED),
                          isSelected: _selectedRole == 'doctor',
                          onTap: () =>
                              setState(() => _selectedRole = 'doctor')),
                      const SizedBox(width: 10),
                      _RoleCard(
                          icon: Icons.badge_outlined,
                          label: 'Worker',
                          accent: const Color(0xFF00897B),
                          isSelected: _selectedRole == 'worker',
                          onTap: () =>
                              setState(() => _selectedRole = 'worker')),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ── Animated form card ────────────────────────────────────
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                                begin: const Offset(0, 0.05), end: Offset.zero)
                            .animate(animation),
                        child: child,
                      ),
                    ),
                    child: Container(
                      key: ValueKey(_selectedRole),
                      child: GlassCard(
                        padding: const EdgeInsets.all(20),
                        radius: 20,
                        borderColor: const Color(0x441E2D45),
                        child: _buildForm(),
                      ),
                    ),
                  ),

                  const SizedBox(height: 36),

                  // ── Compliance footer ─────────────────────────────────────
                  Center(
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: const Color(0xFF00E676)
                                    .withValues(alpha: 0.6),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text('All data stored on device  ·  100% offline',
                                style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 11,
                                    color:
                                        Colors.white.withValues(alpha: 0.3))),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                            'AmbyoAI v1.0  ·  Amrita School of Computing × Aravind Eye Hospital',
                            style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 10,
                                color: Colors.white.withValues(alpha: 0.2)),
                            textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.label,
    required this.accent,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color accent;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 88,
            decoration: BoxDecoration(
              color: isSelected
                  ? accent.withValues(alpha: 0.12)
                  : const Color(0x22111827),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? accent.withValues(alpha: 0.6)
                    : const Color(0xFF1E2433),
                width: isSelected ? 1.5 : 1.0,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.25),
                        blurRadius: 16,
                        spreadRadius: -2,
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 26,
                  color: isSelected ? accent : Colors.white24,
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : Colors.white30,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
