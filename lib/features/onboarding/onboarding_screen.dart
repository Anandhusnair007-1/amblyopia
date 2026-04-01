import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/services/permission_service.dart';
import '../../core/theme/ambyoai_design_system.dart';
import 'widgets/onboarding_page.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;
  double _pageOffset = 0;
  String _langCode = 'en';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _setLanguage(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_code', code);
    setState(() => _langCode = code);
  }

  Future<void> _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
    // Seed worker PIN if not set
    final workerPin = prefs.getString('worker_pin');
    if (workerPin == null || workerPin == '7391') {
      await prefs.setString('worker_pin', '5816');
    }
    // Request permissions after user has seen what the app does
    await PermissionService.requestAllPermissions();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/role-select');
  }

  String _langLabel(String code) {
    switch (code) {
      case 'en':
        return 'English';
      case 'ml':
        return 'മലയാളം';
      case 'hi':
        return 'हिंदी';
      case 'ta':
        return 'தமிழ்';
      default:
        return 'English';
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final pages = [
      const _OnboardingData(
        title: '10 Clinical Eye Tests',
        subtitle:
            'Screening-grade amblyopia detection in 8 minutes.\nNo equipment needed.',
        painter: _ChildScanPainter(),
      ),
      const _OnboardingData(
        title: 'Works Without Internet',
        subtitle:
            'All tests run on your device.\nResults sync securely when connected.',
        painter: _OfflinePainter(),
      ),
      const _OnboardingData(
        title: 'Reviewed by Specialists',
        subtitle: 'Results reviewed by\nAravind Eye Hospital ophthalmologists.',
        painter: _DoctorConnectPainter(),
      ),
    ];

    return Scaffold(
      backgroundColor: AmbyoColors.deepNavy,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: -80,
              right: -40,
              child: Container(
                width: 260,
                height: 260,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [Color(0x3300B4D8), Colors.transparent],
                  ),
                ),
              ),
            ),
            Positioned(
              left: -90,
              bottom: 80,
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
            Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    children: [
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
                          'AMBYOAI CLINICAL SETUP',
                          style: TextStyle(
                            fontFamily: 'JetBrainsMono',
                            fontSize: 10,
                            color: Colors.white70,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (_page < pages.length - 1)
                        TextButton(
                          onPressed: _finishOnboarding,
                          child: const Text(
                            'Skip',
                            style: TextStyle(
                              color: Colors.white38,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      if (notification.metrics is PageMetrics) {
                        final metrics = notification.metrics as PageMetrics;
                        setState(() =>
                            _pageOffset = metrics.page ?? _page.toDouble());
                      }
                      return false;
                    },
                    child: PageView.builder(
                      controller: _controller,
                      itemCount: pages.length,
                      onPageChanged: (idx) => setState(() => _page = idx),
                      itemBuilder: (context, index) {
                        final data = pages[index];
                        final offset = (_pageOffset - index).clamp(-1.0, 1.0);
                        return OnboardingPage(
                          title: data.title,
                          subtitle: data.subtitle,
                          painter: data.painter,
                          parallax: offset,
                        );
                      },
                    ),
                  ),
                ),
                Container(
                  margin: EdgeInsets.fromLTRB(
                    18,
                    0,
                    18,
                    math.max(18, media.padding.bottom + 8),
                  ),
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Column(
                    children: [
                      if (_page == 0) ...[
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Language selection',
                            style: TextStyle(
                              fontFamily: 'JetBrainsMono',
                              fontSize: 10,
                              color: Colors.white.withValues(alpha: 0.52),
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: ['en', 'ml', 'hi', 'ta'].map((lang) {
                            final isSelected = _langCode == lang;
                            return GestureDetector(
                              onTap: () => _setLanguage(lang),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFF1565C0)
                                      : Colors.white.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFF00B4D8)
                                        : Colors.white.withValues(alpha: 0.12),
                                  ),
                                ),
                                child: Text(
                                  _langLabel(lang),
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.white60,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 14),
                      ],
                      Row(
                        children: [
                          Expanded(
                            child: _Dots(count: pages.length, index: _page),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '${_page + 1}/${pages.length}',
                            style: TextStyle(
                              fontFamily: 'JetBrainsMono',
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.54),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF00B4D8),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          onPressed: _page < pages.length - 1
                              ? () => _controller.nextPage(
                                    duration: const Duration(milliseconds: 260),
                                    curve: Curves.easeOut,
                                  )
                              : _finishOnboarding,
                          child: Text(
                            _page < pages.length - 1
                                ? 'Continue Setup'
                                : 'Enter Clinical Workspace',
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final selected = i == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: selected ? 18 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFF00B4D8)
                : Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }
}

class _OnboardingData {
  const _OnboardingData({
    required this.title,
    required this.subtitle,
    required this.painter,
  });

  final String title;
  final String subtitle;
  final CustomPainter painter;
}

class _ChildScanPainter extends CustomPainter {
  const _ChildScanPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final headPaint = Paint()..color = const Color(0xFF1565C0);
    final facePaint = Paint()..color = const Color(0xFFFFE0B2);
    final hairPaint = Paint()..color = const Color(0xFF0A1628);

    final head = Offset(center.dx - 40, center.dy - 8);
    canvas.drawCircle(head, 40, headPaint);
    canvas.drawCircle(head, 34, facePaint);

    final hairPath = Path()
      ..addArc(Rect.fromCircle(center: head, radius: 34), math.pi, math.pi);
    canvas.drawPath(hairPath, hairPaint);

    final eye = Offset(head.dx + 10, head.dy - 6);
    final irisPaint = Paint()..color = const Color(0xFF00B4D8);
    final pupilPaint = Paint()..color = const Color(0xFF0A1628);
    canvas.drawCircle(eye, 7, irisPaint);
    canvas.drawCircle(eye, 3, pupilPaint);

    final scanPaint = Paint()
      ..color = const Color(0xFF00B4D8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(eye, 18, scanPaint);

    final phoneRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
          center: Offset(center.dx + 70, center.dy - 6),
          width: 60,
          height: 110),
      const Radius.circular(12),
    );
    final phonePaint = Paint()..color = const Color(0xFF0A1628);
    canvas.drawRRect(phoneRect, phonePaint);
    canvas.drawCircle(phoneRect.center.translate(0, -30), 6,
        Paint()..color = const Color(0xFF00B4D8));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: phoneRect.center.translate(0, 16), width: 42, height: 54),
        const Radius.circular(6),
      ),
      Paint()..color = const Color(0xFF1C2A3F),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _OfflinePainter extends CustomPainter {
  const _OfflinePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final body = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width * 0.35,
      height: size.height * 0.6,
    );
    final bodyPaint = Paint()..color = const Color(0xFF0A1628);
    canvas.drawRRect(
        RRect.fromRectAndRadius(body, const Radius.circular(20)), bodyPaint);

    final shieldPath = Path()
      ..moveTo(body.center.dx, body.center.dy - 40)
      ..lineTo(body.center.dx + 28, body.center.dy - 20)
      ..lineTo(body.center.dx + 20, body.center.dy + 28)
      ..quadraticBezierTo(body.center.dx, body.center.dy + 44,
          body.center.dx - 20, body.center.dy + 28)
      ..lineTo(body.center.dx - 28, body.center.dy - 20)
      ..close();
    canvas.drawPath(shieldPath, Paint()..color = const Color(0xFF1565C0));

    final lockPaint = Paint()..color = Colors.white;
    final lockRect = Rect.fromCenter(
        center: body.center.translate(0, 4), width: 28, height: 24);
    canvas.drawRRect(
        RRect.fromRectAndRadius(lockRect, const Radius.circular(6)), lockPaint);
    canvas.drawArc(
      Rect.fromCenter(
          center: body.center.translate(0, -6), width: 22, height: 16),
      math.pi,
      math.pi,
      false,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );

    final cloudCenter = Offset(body.center.dx + 80, body.center.dy - 10);
    final cloudPaint = Paint()..color = const Color(0xFFCBD5E1);
    canvas.drawCircle(cloudCenter, 14, cloudPaint);
    canvas.drawCircle(cloudCenter.translate(-16, 6), 12, cloudPaint);
    canvas.drawCircle(cloudCenter.translate(16, 6), 12, cloudPaint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: cloudCenter.translate(0, 14), width: 46, height: 18),
        const Radius.circular(9),
      ),
      cloudPaint,
    );
    final slashPaint = Paint()
      ..color = const Color(0xFFF57C00)
      ..strokeWidth = 3;
    canvas.drawLine(cloudCenter.translate(-24, -16),
        cloudCenter.translate(24, 28), slashPaint);

    final barPaint = Paint()..color = const Color(0xFF00B4D8);
    for (int i = 0; i < 4; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
              body.left - 40 + i * 10, body.bottom - 10 - i * 8, 6, 8 + i * 8),
          const Radius.circular(3),
        ),
        barPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DoctorConnectPainter extends CustomPainter {
  const _DoctorConnectPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final leftPhone = RRect.fromRectAndRadius(
      Rect.fromCenter(
          center: Offset(size.width * 0.3, size.height * 0.5),
          width: 70,
          height: 120),
      const Radius.circular(16),
    );
    final rightScreen = RRect.fromRectAndRadius(
      Rect.fromCenter(
          center: Offset(size.width * 0.7, size.height * 0.45),
          width: 90,
          height: 110),
      const Radius.circular(16),
    );
    canvas.drawRRect(leftPhone, Paint()..color = const Color(0xFF0A1628));
    canvas.drawRRect(rightScreen, Paint()..color = const Color(0xFF1565C0));

    final linePaint = Paint()
      ..color = const Color(0xFF00B4D8)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(leftPhone.right + 6, leftPhone.center.dy - 10)
      ..quadraticBezierTo(size.width * 0.5, size.height * 0.35,
          rightScreen.left - 6, rightScreen.center.dy - 12);
    canvas.drawPath(path, linePaint);

    for (int i = 0; i < 3; i++) {
      final t = (i + 1) / 4;
      final x =
          leftPhone.right + 6 + (rightScreen.left - leftPhone.right - 12) * t;
      final y = leftPhone.center.dy - 10 + math.sin(t * math.pi) * -20;
      final lockRect =
          Rect.fromCenter(center: Offset(x, y), width: 14, height: 12);
      canvas.drawRRect(
          RRect.fromRectAndRadius(lockRect, const Radius.circular(3)),
          Paint()..color = const Color(0xFF0A1628));
    }

    canvas.drawCircle(rightScreen.center.translate(0, -16), 12,
        Paint()..color = const Color(0xFFFFE0B2));
    canvas.drawLine(
      rightScreen.center.translate(0, -2),
      rightScreen.center.translate(0, 30),
      Paint()
        ..color = Colors.white
        ..strokeWidth = 6,
    );
    canvas.drawLine(
      rightScreen.center.translate(-16, 8),
      rightScreen.center.translate(16, 8),
      Paint()
        ..color = Colors.white
        ..strokeWidth = 6,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
