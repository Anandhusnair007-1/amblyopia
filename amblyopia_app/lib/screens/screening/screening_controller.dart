import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/screening_provider.dart';
import '../../services/tts_service.dart';
import 'gaze_screen.dart';
import 'snellen_screen.dart';
import 'redgreen_screen.dart';
import 'result_screen.dart';
import '../../models/gaze_result_model.dart';
import '../../models/snellen_result_model.dart';
import '../../models/redgreen_result_model.dart';

class ScreeningController extends StatefulWidget {
  const ScreeningController({super.key});

  @override
  State<ScreeningController> createState() => _ScreeningControllerState();
}

class _ScreeningControllerState extends State<ScreeningController> {
  int _currentTest = 0;
  bool _transitioning = false;

  Future<void> _onGazeDone(GazeResultModel result) async {
    if (_transitioning) return;
    _transitioning = true;
    final prov = context.read<ScreeningProvider>();
    await prov.saveGazeResult(result);
    await TtsService.speak('Gaze test complete. Next test starting.');
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() { _currentTest = 1; _transitioning = false; });
  }

  Future<void> _onSnellenDone(SnellenResultModel result) async {
    if (_transitioning) return;
    _transitioning = true;
    final prov = context.read<ScreeningProvider>();
    await prov.saveSnellenResult(result);
    await TtsService.speak('Vision test complete. Final test starting.');
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() { _currentTest = 2; _transitioning = false; });
  }

  Future<void> _onRedGreenDone(RedGreenResultModel result) async {
    if (_transitioning) return;
    _transitioning = true;
    final prov = context.read<ScreeningProvider>();
    await prov.saveRedGreenResult(result);
    if (mounted) setState(() { _currentTest = 3; _transitioning = false; });
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ScreeningProvider>();
    final ageGroup = prov.ageGroup;

    return WillPopScope(
      onWillPop: () async {
        if (_currentTest >= 3) return true;
        final confirm = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: const Color(0xFF0D1B2A),
            title: const Text('Cancel Screening?',
                style: TextStyle(color: Colors.white)),
            content: const Text(
                'Are you sure you want to cancel this screening?',
                style: TextStyle(color: Color(0xFF90CAF9))),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Continue'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Cancel Screening',
                    style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
        return confirm ?? false;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // Active test screen
            if (_currentTest == 0)
              GazeScreen(ageGroup: ageGroup, onComplete: _onGazeDone)
            else if (_currentTest == 1)
              SnellenScreen(ageGroup: ageGroup, onComplete: _onSnellenDone)
            else if (_currentTest == 2)
              RedGreenScreen(onComplete: _onRedGreenDone)
            else if (_currentTest == 3)
              if (prov.isLoading)
                const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Color(0xFF00E5FF)),
                      SizedBox(height: 20),
                      Text('Calculating results...',
                          style: TextStyle(color: Colors.white, fontSize: 16)),
                    ],
                  ),
                )
              else
                const ResultScreen(),

            // Progress dots (top)
            if (_currentTest < 3)
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                left: 0,
                right: 0,
                child: _ProgressDots(current: _currentTest),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProgressDots extends StatelessWidget {
  final int current;
  const _ProgressDots({required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        final done = i < current;
        final active = i == current;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: done
                ? Colors.green
                : active
                    ? const Color(0xFF00E5FF)
                    : Colors.white24,
          ),
        );
      }),
    );
  }
}
