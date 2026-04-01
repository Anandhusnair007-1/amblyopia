import 'package:flutter/material.dart';

import '../theme/ambyoai_design_system.dart';
import 'test_back_guard.dart';

/// Standard test screen header: exit button, title, "Test X of Y", progress bar. Height 72.
class TestScreenHeader extends StatelessWidget implements PreferredSizeWidget {
  const TestScreenHeader({
    super.key,
    required this.testName,
    required this.testIndex,
    required this.totalTests,
    required this.inProgress,
    this.isDark = true,
  });

  final String testName;
  final int testIndex;
  final int totalTests;
  final bool inProgress;
  final bool isDark;

  @override
  Size get preferredSize => const Size.fromHeight(72);

  @override
  Widget build(BuildContext context) {
    final progress = (testIndex / totalTests).clamp(0.0, 1.0);
    final fg = isDark ? Colors.white : AmbyoColors.textPrimary;
    final fgMuted = isDark ? const Color(0xFFE2E8F0) : AmbyoColors.textSecondary;

    return SafeArea(
      bottom: false,
      child: Container(
        height: 72,
        color: isDark ? Colors.black : Colors.white,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
              child: Row(
                children: [
                  TestBackGuard.buildIconButton(context, testName, inProgress),
                  Expanded(
                    child: Center(
                      child: Text(
                        testName,
                        style: AmbyoTextStyles.subtitle(color: fg).copyWith(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      'Test $testIndex of $totalTests',
                      style: AmbyoTextStyles.caption(color: fgMuted).copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            LinearProgressIndicator(
              value: progress,
              minHeight: 3,
              backgroundColor: isDark ? const Color(0x3320293B) : const Color(0xFFE2E8F0),
              valueColor: const AlwaysStoppedAnimation<Color>(AmbyoColors.cyanAccent),
            ),
          ],
        ),
      ),
    );
  }
}
