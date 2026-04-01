import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Wraps a test screen to intercept Android back button when test is in progress.
/// Shows a confirmation dialog; on Exit disables wakelock and pops.
class TestBackGuard extends StatelessWidget {
  const TestBackGuard({
    super.key,
    required this.child,
    required this.testName,
    required this.testInProgress,
  });

  final Widget child;
  final String testName;
  final bool testInProgress;

  /// Icon button for use in TestScreenHeader: when inProgress shows exit dialog, else pops.
  static Widget buildIconButton(
      BuildContext context, String testName, bool inProgress) {
    final navigator = Navigator.of(context);
    return IconButton(
      onPressed: () async {
        if (inProgress) {
          final shouldExit = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              title: Text(
                'Exit $testName?',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                ),
              ),
              content: const Text(
                'This will cancel the current test. Progress will be lost.',
                style: TextStyle(fontFamily: 'Poppins'),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Continue Test'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Exit Test'),
                ),
              ],
            ),
          );
          if (shouldExit == true) {
            await WakelockPlus.disable();
            navigator.pop();
          }
        } else {
          navigator.pop();
        }
      },
      icon: const Icon(Icons.arrow_back_rounded),
      color: inProgress ? null : Colors.grey,
    );
  }

  @override
  Widget build(BuildContext context) {
    final navigator = Navigator.of(context);
    return PopScope(
      canPop: !testInProgress,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop || !testInProgress) return;

        final shouldExit = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: Text(
              'Exit $testName?',
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
              ),
            ),
            content: const Text(
              'This will cancel the current test. Progress will be lost.',
              style: TextStyle(fontFamily: 'Poppins'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Continue Test'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Exit Test'),
              ),
            ],
          ),
        );

        if (shouldExit == true) {
          await WakelockPlus.disable();
          navigator.pop();
        }
      },
      child: child,
    );
  }
}
