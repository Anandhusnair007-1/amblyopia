import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../providers/screening_provider.dart';

class SnellenTestScreen extends StatefulWidget {
  const SnellenTestScreen({super.key});

  @override
  State<SnellenTestScreen> createState() => _SnellenTestScreenState();
}

class _SnellenTestScreenState extends State<SnellenTestScreen> {
  final FlutterTts _tts = FlutterTts();
  String _rightAcuity = '6/6';
  String _leftAcuity = '6/6';

  @override
  void initState() {
    super.initState();
    _speakInstructions();
  }

  void _speakInstructions() async {
    await _tts.speak("Snellen Test. Please read the letters on the chart starting from the top. Cover one eye at a time.");
  }

  void _submit() async {
    final provider = Provider.of<ScreeningProvider>(context, listen: false);
    await provider.submitSnellen({
      'visual_acuity_right': _rightAcuity,
      'visual_acuity_left': _leftAcuity,
      'hesitation_score': 0.1,
      'gaze_compliance_score': 0.95,
      'confidence_score': 0.9,
    });
    provider.nextStep();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Snellen Test')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Text('Select reached visual acuity for each eye.', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 30),
            _buildAcuitySelector('RIGHT EYE', _rightAcuity, (val) => setState(() => _rightAcuity = val!)),
             const SizedBox(height: 30),
            _buildAcuitySelector('LEFT EYE', _leftAcuity, (val) => setState(() => _leftAcuity = val!)),
            const Spacer(),
            ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white,
              ),
              child: const Text('SUBMIT SNELLEN RESULT'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAcuitySelector(String label, String current, ValueChanged<String?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        DropdownButton<String>(
          value: current,
          isExpanded: true,
          items: ['6/6', '6/9', '6/12', '6/18', '6/24', '6/60'].map((val) {
            return DropdownMenuItem(value: val, child: Text(val));
          }).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
