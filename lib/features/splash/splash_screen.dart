import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/ambyoai_design_system.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _eyeController;
  late final AnimationController _textController;
  late final AnimationController _gridController;

  double _bootProgress = 0.08;
  String _bootStatus = 'Initializing secure clinical runtime';
  String _routeLabel = 'Preparing workspace';
  final List<_BootSignal> _signals = <_BootSignal>[
    const _BootSignal(
      label: 'Secure profile vault',
      value: 'PENDING',
      accent: Color(0xFFFFC857),
    ),
    const _BootSignal(
      label: 'Offline screening stack',
      value: 'PENDING',
      accent: Color(0xFFFFC857),
    ),
    const _BootSignal(
      label: 'Clinical route engine',
      value: 'PENDING',
      accent: Color(0xFFFFC857),
    ),
  ];

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
    );

    _eyeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _gridController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    _runSequence();
  }

  Future<void> _runSequence() async {
    await Future<void>.delayed(const Duration(milliseconds: 220));
    await _eyeController.forward();
    await _textController.forward();

    await _markStep(
      index: 0,
      status: 'VALIDATING',
      accent: const Color(0xFF55E6FF),
      progress: 0.28,
      message: 'Restoring secure role and token state',
    );

    final target = await _nextRoute();
    if (!mounted) return;

    await _markStep(
      index: 0,
      status: 'READY',
      accent: const Color(0xFF7CFFB2),
      progress: 0.48,
      message: 'Secure session restored',
    );
    await _markStep(
      index: 1,
      status: 'READY',
      accent: const Color(0xFF7CFFB2),
      progress: 0.72,
      message: 'Offline screening services online',
    );
    await _markStep(
      index: 2,
      status: 'ROUTED',
      accent: const Color(0xFF55E6FF),
      progress: 1.0,
      message: 'Workspace target: ${_labelForRoute(target)}',
    );

    await Future<void>.delayed(const Duration(milliseconds: 420));
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(target);
  }

  Future<void> _markStep({
    required int index,
    required String status,
    required Color accent,
    required double progress,
    required String message,
  }) async {
    setState(() {
      _bootProgress = progress;
      _bootStatus = message;
      _signals[index] = _signals[index].copyWith(value: status, accent: accent);
      _routeLabel = message;
    });
    await Future<void>.delayed(const Duration(milliseconds: 260));
  }

  Future<String> _nextRoute() async {
    final prefs = await SharedPreferences.getInstance();
    final savedRole =
        prefs.getString('user_role') ?? prefs.getString('ambyoai_user_role');
    final savedPhone = prefs.getString('patient_phone');
    final onboardingDone = prefs.getBool('onboarding_complete') ?? false;
    final token = await const FlutterSecureStorage().read(key: 'doctor_jwt');

    if (savedRole == 'patient' && savedPhone != null && savedPhone.isNotEmpty) {
      _routeLabel = 'Patient workspace ready';
      return AppRouter.patientHome;
    }

    if (savedRole == 'doctor') {
      if (token != null && _isJwtValid(token)) {
        _routeLabel = 'Doctor command center ready';
        return '/doctor-dashboard';
      }
      _routeLabel = 'Doctor authentication required';
      return '/doctor-login';
    }

    if (savedRole == 'worker') {
      _routeLabel = 'Field screening console ready';
      return '/worker-home';
    }

    if (!onboardingDone) {
      _routeLabel = 'Launching onboarding';
      return '/onboarding';
    }

    _routeLabel = 'Launching role selection';
    return '/role-select';
  }

  String _labelForRoute(String route) {
    switch (route) {
      case AppRouter.patientHome:
        return 'Patient Workspace';
      case '/doctor-dashboard':
        return 'Doctor Command Center';
      case '/doctor-login':
        return 'Doctor Sign-In';
      case '/worker-home':
        return 'Worker Operations';
      case '/onboarding':
        return 'Onboarding';
      case '/role-select':
        return 'Role Selection';
      default:
        return 'Clinical Workspace';
    }
  }

  bool _isJwtValid(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return false;
      final payload = _decodeBase64(parts[1]);
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final exp = data['exp'];
      if (exp is! num) return false;
      final expiry =
          DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000, isUtc: true);
      return expiry.isAfter(DateTime.now().toUtc());
    } catch (_) {
      return false;
    }
  }

  String _decodeBase64(String input) {
    final normalized = base64Url.normalize(input);
    return utf8.decode(base64Url.decode(normalized));
  }

  @override
  void dispose() {
    _eyeController.dispose();
    _textController.dispose();
    _gridController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AmbyoColors.deepNavy,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _gridController,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _SplashGridPainter(offset: _gridController.value),
                  );
                },
              ),
            ),
            Positioned(
              right: -100,
              top: -80,
              child: Container(
                width: 280,
                height: 280,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [Color(0x3300B4D8), Colors.transparent],
                  ),
                ),
              ),
            ),
            Positioned(
              left: -80,
              bottom: 90,
              child: Container(
                width: 240,
                height: 240,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [Color(0x221565C0), Colors.transparent],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              child: Column(
                children: [
                  FadeTransition(
                    opacity: _textController,
                    child: Row(
                      children: [
                        const _SignalPill(
                          label: 'ENTERPRISE CLINICAL SUITE',
                          accent: Color(0xFF55E6FF),
                        ),
                        const Spacer(),
                        _SignalPill(
                          label:
                              _bootProgress >= 1 ? 'SYSTEM READY' : 'BOOTING',
                          accent: _bootProgress >= 1
                              ? const Color(0xFF7CFFB2)
                              : const Color(0xFFFFC857),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  AnimatedBuilder(
                    animation: _eyeController,
                    builder: (_, __) {
                      final t =
                          Curves.easeOutCubic.transform(_eyeController.value);
                      final scale = 0.88 + (t * 0.2);
                      final glowAlpha = (0.12 + t * 0.18).clamp(0.0, 1.0);
                      return Transform.scale(
                        scale: scale,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 204,
                              height: 204,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF00D4FF)
                                        .withValues(alpha: glowAlpha),
                                    blurRadius: 42,
                                    spreadRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 188,
                              height: 188,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFF00D4FF)
                                      .withValues(alpha: 0.18),
                                  width: 1.4,
                                ),
                              ),
                            ),
                            Opacity(
                              opacity: t,
                              child: Container(
                                width: 148,
                                height: 148,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const RadialGradient(
                                    colors: [
                                      Color(0xFF133A56),
                                      Color(0xFF08192D),
                                    ],
                                    radius: 0.92,
                                  ),
                                  border: Border.all(
                                    color: const Color(0xFF00D4FF)
                                        .withValues(alpha: 0.28),
                                    width: 1.4,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF00D4FF)
                                          .withValues(alpha: 0.16),
                                      blurRadius: 24,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Container(
                                      width: 114,
                                      height: 114,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: const Color(0xFF00D4FF)
                                              .withValues(alpha: 0.12),
                                          width: 1.6,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      width: 84,
                                      height: 84,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: const Color(0xFF00D4FF)
                                              .withValues(alpha: 0.25),
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                    const Icon(
                                      Icons.remove_red_eye_rounded,
                                      size: 52,
                                      color: Color(0xFF00D4FF),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 28),
                  FadeTransition(
                    opacity: _textController,
                    child: Column(
                      children: [
                        const Text(
                          'AmbyoAI',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 34,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Enterprise Vision Screening Platform',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: Colors.white.withValues(alpha: 0.72),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  FadeTransition(
                    opacity: _textController,
                    child: _BootStatusPanel(
                      bootProgress: _bootProgress,
                      bootStatus: _bootStatus,
                      routeLabel: _routeLabel,
                      signals: _signals,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FadeTransition(
                    opacity: _textController,
                    child: Text(
                      'Amrita School of Computing  ×  Aravind Eye Hospital',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 10,
                        color: Colors.white.withValues(alpha: 0.35),
                        letterSpacing: 0.3,
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

class _BootStatusPanel extends StatelessWidget {
  const _BootStatusPanel({
    required this.bootProgress,
    required this.bootStatus,
    required this.routeLabel,
    required this.signals,
  });

  final double bootProgress;
  final String bootStatus;
  final String routeLabel;
  final List<_BootSignal> signals;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xD9101C31),
                Color(0xCC091220),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: const Color(0xFF00D4FF).withValues(alpha: 0.18),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00D4FF).withValues(alpha: 0.10),
                blurRadius: 32,
                spreadRadius: -14,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'System Readiness',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Text(
                    '${(bootProgress * 100).round()}%',
                    style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.76),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                bootStatus,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.74),
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 10,
                  value: bootProgress.clamp(0.0, 1.0),
                  backgroundColor: const Color(0x221C324B),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF00D4FF),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ...signals.map((signal) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _SignalRow(signal: signal),
                  )),
              const SizedBox(height: 2),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0x6610192A),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      decoration: const BoxDecoration(
                        color: Color(0xFF7CFFB2),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        routeLabel,
                        style: TextStyle(
                          fontFamily: 'JetBrainsMono',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.84),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SignalPill extends StatelessWidget {
  const _SignalPill({
    required this.label,
    required this.accent,
  });

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0x8F0A1424),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: accent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.7,
            ),
          ),
        ],
      ),
    );
  }
}

class _SignalRow extends StatelessWidget {
  const _SignalRow({
    required this.signal,
  });

  final _BootSignal signal;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: signal.accent,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: signal.accent.withValues(alpha: 0.42),
                blurRadius: 12,
                spreadRadius: -2,
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            signal.label,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.86),
            ),
          ),
        ),
        Text(
          signal.value,
          style: TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: signal.accent,
          ),
        ),
      ],
    );
  }
}

class _SplashGridPainter extends CustomPainter {
  const _SplashGridPainter({
    required this.offset,
  });

  final double offset;

  @override
  void paint(Canvas canvas, Size size) {
    final minorPaint = Paint()
      ..color = const Color(0x0F8FEAFF)
      ..strokeWidth = 0.6;
    final majorPaint = Paint()
      ..color = const Color(0x18FFFFFF)
      ..strokeWidth = 0.8;

    const minorGap = 22.0;
    const majorGap = 88.0;
    final drift = offset * minorGap;

    for (double x = -minorGap; x <= size.width + minorGap; x += minorGap) {
      final dx = x + drift;
      final isMajor = ((dx / majorGap) - (dx / majorGap).round()).abs() < 0.05;
      canvas.drawLine(
        Offset(dx, 0),
        Offset(dx, size.height),
        isMajor ? majorPaint : minorPaint,
      );
    }

    for (double y = 0; y <= size.height; y += minorGap) {
      final isMajor = ((y / majorGap) - (y / majorGap).round()).abs() < 0.05;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        isMajor ? majorPaint : minorPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SplashGridPainter oldDelegate) =>
      oldDelegate.offset != offset;
}

class _BootSignal {
  const _BootSignal({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  _BootSignal copyWith({
    String? label,
    String? value,
    Color? accent,
  }) {
    return _BootSignal(
      label: label ?? this.label,
      value: value ?? this.value,
      accent: accent ?? this.accent,
    );
  }
}
