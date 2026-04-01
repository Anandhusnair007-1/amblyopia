import 'package:flutter/material.dart';

class AllTestsCompleteScreen extends StatefulWidget {
  const AllTestsCompleteScreen({
    super.key,
    this.onContinue,
  });

  final VoidCallback? onContinue;

  @override
  State<AllTestsCompleteScreen> createState() => _AllTestsCompleteScreenState();
}

class _AllTestsCompleteScreenState extends State<AllTestsCompleteScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07121A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: FadeTransition(
              opacity: CurvedAnimation(parent: _controller, curve: Curves.easeOut),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ScaleTransition(
                    scale: Tween<double>(begin: 0.88, end: 1).animate(
                      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
                    ),
                    child: Container(
                      width: 86,
                      height: 86,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0x1A00BCD4),
                        border: Border.all(color: const Color(0xFF00BCD4), width: 1.2),
                      ),
                      child: const Icon(Icons.check_rounded, size: 48, color: Color(0xFF00BCD4)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'All Tests Complete',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Clinical analysis is ready. Generate and review the report.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: Colors.white70,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: widget.onContinue ?? () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.description_outlined),
                      label: const Text('Generate Report'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
