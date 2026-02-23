import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../providers/screening_provider.dart';

class RedGreenTestScreen extends StatefulWidget {
  const RedGreenTestScreen({super.key});

  @override
  State<RedGreenTestScreen> createState() => _RedGreenTestScreenState();
}

class _RedGreenTestScreenState extends State<RedGreenTestScreen> with SingleTickerProviderStateMixin {
  final FlutterTts _tts = FlutterTts();
  late AnimationController _animController;
  int _binocularScore = 3;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
    _tts.speak("Red Green Test. Look at the flashing lights through the goggles.");
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _submit() async {
    final provider = Provider.of<ScreeningProvider>(context, listen: false);
    await provider.submitRedGreen({
      'left_pupil_diameter': 4.4, 'right_pupil_diameter': 4.5,
      'suppression_flag': false, 'binocular_score': _binocularScore, 'confidence_score': 0.92
    });
    provider.nextStep();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Red-Green Test')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Text('Binocular Suppression Check', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FadeTransition(
                  opacity: _animController,
                  child: Container(width: 60, height: 60, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.red, blurRadius: 20)])),
                ),
                const SizedBox(width: 40),
                FadeTransition(
                  opacity: _animController,
                  child: Container(width: 60, height: 60, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.green, blurRadius: 20)])),
                ),
              ],
            ),
            const SizedBox(height: 60),
            const Text('How many lights do you see?'),
            Slider(
              value: _binocularScore.toDouble(),
              min: 1, max: 4, divisions: 3,
              label: _binocularScore.toString(),
              onChanged: (val) => setState(() => _binocularScore = val.toInt()),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white,
              ),
              child: const Text('SUBMIT BINOCULAR RESULT'),
            ),
          ],
        ),
      ),
    );
  }
}
