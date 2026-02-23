import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/redgreen_result_model.dart';
import '../../services/tts_service.dart';
import '../../services/voice_service.dart';

class RedGreenScreen extends StatefulWidget {
  final void Function(RedGreenResultModel) onComplete;

  const RedGreenScreen({super.key, required this.onComplete});

  @override
  State<RedGreenScreen> createState() => _RedGreenScreenState();
}

class _RedGreenScreenState extends State<RedGreenScreen> {
  int _phase = 0; // 0=baseline, 1=red, 2=green
  int _secondsLeft = 10;
  Timer? _timer;
  bool _isListening = false;
  bool _testDone = false;

  String? _redAnswer;
  String? _greenAnswer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startPhase0());
  }

  Future<void> _startPhase0() async {
    await TtsService.speak('Red green vision test. Look at the cross.');
    await Future.delayed(const Duration(seconds: 1));
    setState(() { _phase = 0; _secondsLeft = 10; });
    _startCountdown(() async => await _startPhase1());
  }

  Future<void> _startPhase1() async {
    setState(() { _phase = 1; _secondsLeft = 10; _isListening = true; });
    await TtsService.sayHowManyCircles();
    await Future.delayed(const Duration(seconds: 4));
    if (!_testDone && mounted) {
      _redAnswer = await VoiceService.listenForNumber(timeout: const Duration(seconds: 4));
      if (mounted) setState(() => _isListening = false);
    }
    _startCountdown(() async => await _startPhase2());
  }

  Future<void> _startPhase2() async {
    setState(() { _phase = 2; _secondsLeft = 10; _isListening = true; });
    await TtsService.sayHowManyCircles();
    await Future.delayed(const Duration(seconds: 4));
    if (!_testDone && mounted) {
      _greenAnswer = await VoiceService.listenForNumber(timeout: const Duration(seconds: 4));
      if (mounted) setState(() => _isListening = false);
    }
    _startCountdown(() async => await _calculateResults());
  }

  void _startCountdown(Future<void> Function() onDone) {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) {
        t.cancel();
        onDone();
      }
    });
  }

  Future<void> _calculateResults() async {
    if (_testDone) return;
    _testDone = true;

    int binocularScore = 2;
    bool suppressionDetected = false;

    if (_redAnswer == '1' || _greenAnswer == '1') {
      binocularScore = 1;
      suppressionDetected = true;
    } else if (_redAnswer == '3' && _greenAnswer == '3') {
      binocularScore = 3;
    }

    final result = RedGreenResultModel(
      leftPupilDiameter: 4.0,
      rightPupilDiameter: 4.0,
      asymmetryRatio: suppressionDetected ? 0.2 : 0.05,
      suppressionFlag: suppressionDetected,
      dominantEye: _redAnswer == '1' ? 'right' : 'left',
      binocularScore: binocularScore,
      constrictionSpeedLeft: 0.5,
      constrictionSpeedRight: 0.5,
      confidenceScore: (_redAnswer != null || _greenAnswer != null) ? 0.82 : 0.55,
    );

    await TtsService.speak('Test complete.');
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) widget.onComplete(result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                const SizedBox(height: 60),
                // Phase indicator
                _PhaseIndicator(phase: _phase),
                const Spacer(),
                // Phase content
                if (_phase == 0) _buildBaseline(),
                if (_phase == 1) _buildRedStimulus(),
                if (_phase == 2) _buildGreenStimulus(),
                const Spacer(),
                // Timer
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF00E5FF), width: 2),
                        color: Colors.black54,
                      ),
                      child: Center(
                        child: Text('$_secondsLeft',
                            style: const TextStyle(
                                color: Color(0xFF00E5FF),
                                fontSize: 22,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
              ],
            ),
            // Listening indicator
            if (_isListening)
              Positioned(
                bottom: 100,
                right: 24,
                child: _PulsingMic(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBaseline() {
    return Column(
      children: const [
        Text(
          'Look at the cross',
          style: TextStyle(color: Colors.white70, fontSize: 16),
        ),
        SizedBox(height: 40),
        Text(
          '+',
          style: TextStyle(
              color: Colors.white,
              fontSize: 80,
              fontWeight: FontWeight.w100),
        ),
      ],
    );
  }

  Widget _buildRedStimulus() {
    return Column(
      children: [
        Text(
          _isListening ? 'How many circles?' : 'Look carefully...',
          style: const TextStyle(color: Colors.white70, fontSize: 16),
        ),
        const SizedBox(height: 40),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Container(
              width: 120, height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red,
                boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.5), blurRadius: 20)],
              ),
            ),
            Container(
              width: 120, height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey[800],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGreenStimulus() {
    return Column(
      children: [
        Text(
          _isListening ? 'How many circles?' : 'Look carefully...',
          style: const TextStyle(color: Colors.white70, fontSize: 16),
        ),
        const SizedBox(height: 40),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Container(
              width: 120, height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey[800],
              ),
            ),
            Container(
              width: 120, height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.green,
                boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.5), blurRadius: 20)],
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

class _PhaseIndicator extends StatelessWidget {
  final int phase;
  const _PhaseIndicator({required this.phase});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: i <= phase ? const Color(0xFF00E5FF) : Colors.white24,
          ),
        );
      }),
    );
  }
}

class _PulsingMic extends StatefulWidget {
  @override
  State<_PulsingMic> createState() => _PulsingMicState();
}

class _PulsingMicState extends State<_PulsingMic>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))
      ..repeat(reverse: true);
    _anim = Tween(begin: 0.85, end: 1.15).animate(_ctrl);
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _anim,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.red.withOpacity(0.25),
          border: Border.all(color: Colors.red, width: 2),
        ),
        child: const Icon(Icons.mic, color: Colors.red, size: 26),
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }
}
