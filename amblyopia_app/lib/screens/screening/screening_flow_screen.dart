import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/screening_provider.dart';
import 'snellen_test_screen.dart';
import 'gaze_test_screen.dart';
import 'red_green_test_screen.dart';
import 'result_screen.dart';

class ScreeningFlowScreen extends StatelessWidget {
  const ScreeningFlowScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screeningProvider = Provider.of<ScreeningProvider>(context);
    final step = screeningProvider.currentStep;

    switch (step) {
      case 0: return const SnellenTestScreen();
      case 1: return const GazeTestScreen();
      case 2: return const RedGreenTestScreen();
      case 3: return const ResultScreen();
      default: return const SnellenTestScreen();
    }
  }
}
