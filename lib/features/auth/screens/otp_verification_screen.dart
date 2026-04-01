import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/router/app_router.dart';
import '../../../core/widgets/ambyoai_snackbar.dart';
import '../providers/auth_provider.dart';
import '../providers/patient_provider.dart';

class OtpVerificationScreen extends ConsumerStatefulWidget {
  const OtpVerificationScreen({
    super.key,
    required this.phoneNumber,
    required this.role,
  });

  final String phoneNumber;
  final UserRole role;

  @override
  ConsumerState<OtpVerificationScreen> createState() =>
      _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen>
    with TickerProviderStateMixin {
  final _controllers = List.generate(4, (_) => TextEditingController());
  final _focusNodes = List.generate(4, (_) => FocusNode());
  late final AnimationController _shakeController;
  late final AnimationController _successController;

  Timer? _timer;
  int _secondsRemaining = 28;
  int _attempts = 0;
  bool _lockedOut = false;
  bool _errorFlash = false;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _successController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    for (final node in _focusNodes) {
      node.addListener(() {
        if (mounted) setState(() {});
      });
    }
    _startTimer();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    _timer?.cancel();
    _shakeController.dispose();
    _successController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _secondsRemaining = 28;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsRemaining <= 0) {
        timer.cancel();
        setState(() {});
      } else {
        setState(() => _secondsRemaining--);
      }
    });
  }

  String _collectOtp() => _controllers.map((c) => c.text).join();

  Future<void> _verifyOtp() async {
    if (_lockedOut) return;
    final otp = _collectOtp();
    if (otp.length < 4) {
      _triggerError();
      return;
    }

    if (otp != '4826') {
      _attempts += 1;
      if (_attempts >= 3) {
        setState(() => _lockedOut = true);
      }
      _triggerError();
      _clearInputs();
      return;
    }

    await _successController.forward(from: 0);
    await _successController.reverse();
    await _completeLogin();
  }

  Future<void> _completeLogin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('patient_phone', widget.phoneNumber);

    await RoleStorage.savePhone(widget.phoneNumber);
    await RoleStorage.saveRole(UserRole.patient);

    final patientState = ref.read(patientProvider);
    await patientState.loadPatient(widget.phoneNumber);
    if (patientState.current == null) {
      await patientState.createPatient(widget.phoneNumber);
    }
    final patientId = patientState.current?.id;
    if (patientId != null) {
      await prefs.setString('patient_id', patientId);
    }

    if (!mounted) return;
    ref.read(roleProvider.notifier).state = UserRole.patient;
    ref.read(phoneProvider.notifier).state = widget.phoneNumber;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
          builder: (_) => AppRouter.homeForRole(UserRole.patient)),
      (_) => false,
    );
  }

  void _triggerError() {
    _shakeController.forward(from: 0);
    setState(() => _errorFlash = true);
    Future<void>.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() => _errorFlash = false);
    });
  }

  void _clearInputs() {
    for (final c in _controllers) {
      c.clear();
    }
    _focusNodes.first.requestFocus();
  }

  void _onChanged(int index, String value) {
    if (value.isEmpty) {
      if (index > 0) _focusNodes[index - 1].requestFocus();
      return;
    }
    if (value.length > 1) {
      final chars = value.split('');
      _controllers[index].text = chars.first;
    }
    if (index < _focusNodes.length - 1) {
      _focusNodes[index + 1].requestFocus();
    } else {
      _focusNodes[index].unfocus();
      _verifyOtp();
    }
  }

  Future<void> _resendOtp() async {
    _startTimer();
    if (!mounted) return;
    AmbyoSnackbar.show(context,
        message: 'OTP resent! (use 4826)', type: SnackbarType.info);
  }

  Widget _buildLockedOutView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFFF2D55).withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                    color: const Color(0xFFFF2D55).withValues(alpha: 0.3)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF2D55).withValues(alpha: 0.2),
                    blurRadius: 20,
                    spreadRadius: -4,
                  ),
                ],
              ),
              child: const Icon(Icons.lock_outline_rounded,
                  color: Color(0xFFFF2D55), size: 36),
            ),
            const SizedBox(height: 24),
            const Text(
              'Too many attempts',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'You entered the wrong OTP 3 times. Please go back and try a different phone number.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                color: Colors.white38,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 40),
            GestureDetector(
              onTap: () {
                setState(() {
                  _lockedOut = false;
                  _attempts = 0;
                  for (final c in _controllers) {
                    c.clear();
                  }
                });
                Navigator.of(context).maybePop();
              },
              child: Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFF1565C0), Color(0xFF00D4FF)]),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1565C0).withValues(alpha: 0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    'Try Different Number',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () {
                setState(() {
                  _lockedOut = false;
                  _attempts = 0;
                  for (final c in _controllers) {
                    c.clear();
                  }
                });
                _focusNodes.first.requestFocus();
              },
              child: const Text(
                'Try again with same number',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  color: Colors.white30,
                  decoration: TextDecoration.underline,
                  decorationColor: Colors.white24,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_lockedOut) {
      return Scaffold(
        backgroundColor: const Color(0xFF060D1A),
        body: SafeArea(child: _buildLockedOutView()),
      );
    }

    final shake = Tween<double>(begin: 0, end: 1).animate(_shakeController);
    return Scaffold(
      backgroundColor: const Color(0xFF060D1A),
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
              bottom: -60,
              left: -80,
              child: Container(
                width: 220,
                height: 220,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                      colors: [Color(0x151565C0), Colors.transparent]),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_rounded,
                        color: Colors.white),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Verify Phone',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '+91 ${widget.phoneNumber}',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF00B4D8),
                    ),
                  ),
                  const SizedBox(height: 48),
                  AnimatedBuilder(
                    animation: shake,
                    builder: (context, child) {
                      final dx = math.sin(shake.value * math.pi * 6) * 6;
                      return Transform.translate(
                          offset: Offset(dx, 0), child: child);
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(
                        4,
                        (i) => _OtpBox(
                          controller: _controllers[i],
                          focusNode: _focusNodes[i],
                          isError: _errorFlash,
                          isSuccess: _successController.isAnimating,
                          onChanged: (value) => _onChanged(i, value),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Text(
                        _secondsRemaining > 0
                            ? 'Resend OTP in ${_secondsRemaining}s'
                            : 'Didn\'t receive OTP?',
                        style: TextStyle(
                          fontSize: 13,
                          fontFamily: 'Poppins',
                          color: _secondsRemaining > 0
                              ? Colors.white38
                              : Colors.white54,
                        ),
                      ),
                      if (_secondsRemaining == 0) ...[
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: _resendOtp,
                          child: const Text(
                            'Resend',
                            style: TextStyle(
                              fontSize: 13,
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF00B4D8),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 32),
                  // Verify button
                  GestureDetector(
                    onTap: _verifyOtp,
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
                            color: const Color(0xFF1565C0).withOpacity(0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          'Verify',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  const Center(
                    child: Text(
                      'Demo: 4826',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: Colors.white24,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OtpBox extends StatelessWidget {
  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.isError,
    required this.isSuccess,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isError;
  final bool isSuccess;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final focused = focusNode.hasFocus;
    final bool filled = controller.text.isNotEmpty;
    final Color borderColor = isSuccess
        ? const Color(0xFF00E676)
        : isError
            ? const Color(0xFFFF5252)
            : focused
                ? const Color(0xFF00D4FF)
                : filled
                    ? const Color(0xFF1565C0)
                    : const Color(0xFF1E2D45);

    final double borderWidth = (focused || isError || isSuccess) ? 2.0 : 1.0;
    final List<BoxShadow>? glow = focused
        ? [
            BoxShadow(
              color: const Color(0xFF00D4FF).withOpacity(0.3),
              blurRadius: 16,
              spreadRadius: -2,
            ),
            BoxShadow(
              color: const Color(0xFF00D4FF).withOpacity(0.1),
              blurRadius: 30,
              spreadRadius: 0,
            ),
          ]
        : null;

    return AnimatedScale(
      duration: const Duration(milliseconds: 180),
      scale: isSuccess ? 1.04 : 1.0,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 68,
        height: 78,
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: borderWidth),
          boxShadow: glow,
        ),
        child: Stack(
          children: [
            // Invisible TextField captures input
            Positioned.fill(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 1,
                style: const TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
                decoration: const InputDecoration(
                  counterText: '',
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
