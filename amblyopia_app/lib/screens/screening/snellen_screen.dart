import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/snellen_result_model.dart';
import '../../services/tts_service.dart';
import '../../services/voice_service.dart';
import '../../widgets/snellen_chart.dart';

class SnellenScreen extends StatefulWidget {
  final String ageGroup;
  final void Function(SnellenResultModel) onComplete;

  const SnellenScreen({
    super.key,
    required this.ageGroup,
    required this.onComplete,
  });

  @override
  State<SnellenScreen> createState() => _SnellenScreenState();
}

class _SnellenScreenState extends State<SnellenScreen> {
  static const List<String> vaLines = [
    '6/60', '6/36', '6/24', '6/18', '6/12', '6/9', '6/6', '6/5'
  ];

  static const List<String> letterPool = [
    'E', 'F', 'P', 'T', 'O', 'Z', 'L', 'D', 'C', 'H', 'N', 'V', 'K'
  ];

  static const List<String> directions = ['up', 'down', 'left', 'right'];

  late List<List<String>> _lineLetters;
  int _currentLine = 4; // Start at 6/12
  int _currentEye = 0;  // 0=right, 1=left
  int _letterIndex = 0;
  int _correctRight = 0;
  int _wrongRight = 0;
  int _correctLeft = 0;
  int _wrongLeft = 0;
  String _vaRight = '6/60';
  String _vaLeft = '6/60';
  bool _isListening = false;
  bool _testDone = false;
  bool _showFeedback = false;
  bool _feedbackCorrect = false;

  final List<double> _responseTimes = [];
  final List<Map<String, dynamic>> _perLetterResults = [];
  DateTime? _letterShownAt;

  String _currentLetter = 'E';
  String _currentDirection = 'up';
  String _coverInstruction = '';

  late bool _isTumblingE;
  late bool _isSymbols;

  @override
  void initState() {
    super.initState();
    _isTumblingE = (widget.ageGroup == 'child' || widget.ageGroup == 'infant');
    _isSymbols = widget.ageGroup == 'infant';

    final rng = math.Random();
    _lineLetters = List.generate(8, (_) {
      return List.generate(5, (_) => letterPool[rng.nextInt(letterPool.length)]);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _startEye());
  }

  Future<void> _startEye() async {
    if (_currentEye == 0) {
      _coverInstruction = 'Cover your RIGHT eye';
      await TtsService.sayCoverRight();
    } else {
      _coverInstruction = 'Cover your LEFT eye';
      await TtsService.sayCoverLeft();
    }
    await Future.delayed(const Duration(seconds: 2));
    _currentLine = 4;
    _letterIndex = 0;
    if (_currentEye == 0) { _correctRight = 0; _wrongRight = 0; }
    else { _correctLeft = 0; _wrongLeft = 0; }
    await _showNextLetter();
  }

  Future<void> _showNextLetter() async {
    if (_testDone || !mounted) return;
    final rng = math.Random();

    String letter;
    String direction = directions[rng.nextInt(4)];

    if (_isSymbols) {
      letter = ['🏠', '🍎', '⭕', '⬜'][rng.nextInt(4)];
    } else if (_isTumblingE) {
      letter = 'E'; // Direction E
    } else {
      letter = _lineLetters[_currentLine][_letterIndex];
    }

    setState(() {
      _currentLetter = letter;
      _currentDirection = direction;
      _isListening = false;
    });

    _letterShownAt = DateTime.now();

    await TtsService.sayReadLetter();
    await Future.delayed(const Duration(milliseconds: 600));
    await _listenForResponse();
  }

  Future<void> _listenForResponse() async {
    if (_testDone || !mounted) return;
    setState(() => _isListening = true);

    String? response;

    if (_isTumblingE) {
      response = await VoiceService.listenForDirection();
    } else {
      response = await VoiceService.listenForLetter();
    }

    setState(() => _isListening = false);

    final elapsed = _letterShownAt != null
        ? DateTime.now().difference(_letterShownAt!).inMilliseconds.toDouble()
        : 3000.0;
    _responseTimes.add(elapsed);

    bool correct = false;
    if (_isTumblingE) {
      correct = response == _currentDirection;
    } else {
      correct = response == _currentLetter;
    }

    _perLetterResults.add({
      'line': vaLines[_currentLine],
      'shown': _isTumblingE ? _currentDirection : _currentLetter,
      'heard': response,
      'correct': correct,
      'response_time_ms': elapsed,
    });

    setState(() {
      _showFeedback = true;
      _feedbackCorrect = correct;
    });

    if (correct) {
      if (_currentEye == 0) _correctRight++;
      else _correctLeft++;
    } else {
      if (_currentEye == 0) _wrongRight++;
      else _wrongLeft++;
    }

    await Future.delayed(const Duration(milliseconds: 500));
    setState(() => _showFeedback = false);

    _letterIndex++;
    final correct5 = _currentEye == 0 ? _correctRight : _correctLeft;
    final wrong5 = _currentEye == 0 ? _wrongRight : _wrongLeft;

    if (_letterIndex >= 5 || wrong5 + correct5 >= 5) {
      // Check if passed this line
      if (correct5 >= 3 && _currentLine < vaLines.length - 1) {
        // Advance line
        if (_currentEye == 0) _vaRight = vaLines[_currentLine];
        else _vaLeft = vaLines[_currentLine];
        _currentLine++;
        _letterIndex = 0;
        if (_currentEye == 0) { _correctRight = 0; _wrongRight = 0; }
        else { _correctLeft = 0; _wrongLeft = 0; }
        await _showNextLetter();
      } else {
        // Failed line — record VA
        if (_currentEye == 0) _vaRight = vaLines[_currentLine];
        else _vaLeft = vaLines[_currentLine];

        if (_currentEye == 0) {
          // Switch to left eye
          _currentEye = 1;
          await _startEye();
        } else {
          // Both eyes done
          await _finishTest();
        }
      }
    } else {
      await _showNextLetter();
    }
  }

  Future<void> _finishTest() async {
    if (_testDone) return;
    _testDone = true;

    final avgResponse =
        _responseTimes.isEmpty ? 0.0 :
        _responseTimes.reduce((a, b) => a + b) / _responseTimes.length;
    final hesitation = avgResponse > 3000 ? 0.8 : avgResponse > 2000 ? 0.5 : 0.2;

    final result = SnellenResultModel(
      visualAcuityRight: _vaRight,
      visualAcuityLeft: _vaLeft,
      visualAcuityBoth:
          SnellenResultModel.vaToNumeric(_vaRight) >=
                  SnellenResultModel.vaToNumeric(_vaLeft)
              ? _vaRight
              : _vaLeft,
      perLetterResults: _perLetterResults,
      responseTimes: _responseTimes,
      hesitationScore: hesitation,
      gazeComplianceScore: 0.85,
      testMode: _isTumblingE ? 'tumbling_e' : 'letter',
      confidenceScore: _responseTimes.length > 5 ? 0.85 : 0.65,
    );

    await TtsService.speak('Vision test complete.');
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
                // Cover instruction card
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                  decoration: BoxDecoration(
                    color: _currentEye == 0
                        ? Colors.blue.withOpacity(0.2)
                        : Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _currentEye == 0
                          ? Colors.blue.withOpacity(0.6)
                          : Colors.green.withOpacity(0.6),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.visibility_off,
                        color: _currentEye == 0 ? Colors.blue : Colors.green,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _coverInstruction.isEmpty
                            ? (_currentEye == 0
                                ? 'Cover RIGHT eye'
                                : 'Cover LEFT eye')
                            : _coverInstruction,
                        style: TextStyle(
                          color: _currentEye == 0 ? Colors.blue : Colors.green,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // Line indicator
                Text(
                  'Line ${_currentLine + 1}/8  ·  ${vaLines[_currentLine]}',
                  style: const TextStyle(color: Color(0xFF546E7A), fontSize: 13),
                ),
                const Spacer(),
                // Big letter in center
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.35,
                  child: SnellenChart(
                    letter: _isTumblingE ? 'E' : _currentLetter,
                    vaLine: vaLines[_currentLine],
                    direction: _isTumblingE ? _currentDirection : null,
                    showFeedback: _showFeedback,
                    feedbackCorrect: _feedbackCorrect,
                  ),
                ),
                const Spacer(),
                // Progress rows
                _buildProgressRows(),
                const SizedBox(height: 20),
              ],
            ),
            // Listening indicator
            if (_isListening)
              Positioned(
                bottom: 80,
                right: 24,
                child: _ListeningIndicator(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressRows() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(
          math.min(_currentLine + 1, vaLines.length),
          (lineIdx) {
            return Row(
              children: [
                SizedBox(
                  width: 40,
                  child: Text(
                    vaLines[lineIdx],
                    style: const TextStyle(
                      color: Color(0xFF546E7A),
                      fontSize: 10,
                    ),
                  ),
                ),
                ...List.generate(5, (letterIdx) {
                  Color c = Colors.white24;
                  if (lineIdx < _currentLine) {
                    // Past line
                    if (letterIdx < _perLetterResults
                        .where((r) => r['line'] == vaLines[lineIdx])
                        .length) {
                      final res = _perLetterResults
                          .where((r) => r['line'] == vaLines[lineIdx])
                          .toList();
                      if (letterIdx < res.length) {
                        c = res[letterIdx]['correct'] as bool
                            ? Colors.green
                            : Colors.red;
                      }
                    }
                  }
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: c,
                    ),
                  );
                }),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ListeningIndicator extends StatefulWidget {
  @override
  State<_ListeningIndicator> createState() => _ListeningIndicatorState();
}

class _ListeningIndicatorState extends State<_ListeningIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _pulse = Tween(begin: 0.8, end: 1.2).animate(_ctrl);
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _pulse,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.red.withOpacity(0.3),
          border: Border.all(color: Colors.red, width: 2),
        ),
        child: const Icon(Icons.mic, color: Colors.red, size: 28),
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }
}
