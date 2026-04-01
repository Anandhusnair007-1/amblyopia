import 'package:flutter/material.dart';

/// Brief transition screen between tests. Shows next test name, icon, description,
/// and a short countdown so the patient can prepare.
class TestTransitionScreen extends StatefulWidget {
  const TestTransitionScreen({
    super.key,
    required this.nextTestName,
    required this.nextTestDescription,
    required this.nextTestIcon,
    required this.onReady,
    this.countdownSeconds = 2,
  });

  final String nextTestName;
  final String nextTestDescription;
  final IconData nextTestIcon;
  final VoidCallback onReady;
  final int countdownSeconds;

  @override
  State<TestTransitionScreen> createState() => _TestTransitionScreenState();
}

class _TestTransitionScreenState extends State<TestTransitionScreen> {
  int _countdown = 0;
  bool _calledReady = false;

  @override
  void initState() {
    super.initState();
    _countdown = widget.countdownSeconds;
    Future<void>.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      _tick();
    });
  }

  void _tick() {
    if (!mounted || _calledReady) return;
    if (_countdown <= 0) {
      _calledReady = true;
      widget.onReady();
      return;
    }
    setState(() => _countdown = _countdown - 1);
    Future<void>.delayed(const Duration(seconds: 1), _tick);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Next',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 16),
              Icon(
                widget.nextTestIcon,
                size: 64,
                color: const Color(0xFF00B4D8),
              ),
              const SizedBox(height: 20),
              Text(
                widget.nextTestName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.nextTestDescription,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  color: Colors.white70,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 48),
              if (_countdown > 0)
                Text(
                  '$_countdown...',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF00B4D8),
                  ),
                )
              else
                const Text(
                  'Starting',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF00B4D8),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
