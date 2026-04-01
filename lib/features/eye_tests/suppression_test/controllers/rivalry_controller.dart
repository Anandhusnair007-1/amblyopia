import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../offline/database_tables.dart';
import '../../../offline/local_database.dart';
import '../../../offline/vosk_service.dart';
import '../../age_profile.dart';
import '../../test_flow_controller.dart';
import '../models/suppression_result.dart';

enum RivalryState {
  notStarted,
  ready,
  running,
  completed,
  inconclusive,
  error,
}

class RivalryController extends ChangeNotifier {
  RivalryState _state = RivalryState.notStarted;
  SuppressionResult? _result;
  String _statusMessage = '';

  static const int testDurationSecs = 30;
  static const int readingIntervalSecs = 5;
  static const int totalReadings = 6;

  int _currentReading = 0;
  int _secondsRemaining = testDurationSecs;

  final List<String> _responses = [];
  int _horizontalCount = 0;
  int _verticalCount = 0;
  int _switchCount = 0;
  String _lastResponse = '';
  bool _isSimplifiedVoiceMode = false;

  Timer? _timer;

  void initForProfile(AgeProfile p) {
    _isSimplifiedVoiceMode = p == AgeProfile.b;
  }

  RivalryState get state => _state;
  SuppressionResult? get result => _result;
  String get statusMessage => _statusMessage;
  int get currentReading => _currentReading;
  int get secondsRemaining => _secondsRemaining;
  double get progress => totalReadings > 0 ? _currentReading / totalReadings : 0.0;

  Future<void> startTest() async {
    _state = RivalryState.running;
    _responses.clear();
    _horizontalCount = 0;
    _verticalCount = 0;
    _switchCount = 0;
    _currentReading = 0;
    _secondsRemaining = testDurationSecs;
    _lastResponse = '';

    _statusMessage = _isSimplifiedVoiceMode
        ? 'What color do you see? Say RED, BLUE, or BOTH'
        : 'Look at the pattern. Say HORIZONTAL, VERTICAL, or SWITCHING';
    notifyListeners();

    await Future<void>.delayed(const Duration(seconds: 2));

    await _runReadingsLoop();
  }

  Future<void> _runReadingsLoop() async {
    for (int i = 0; i < totalReadings; i++) {
      _currentReading = i + 1;
      _statusMessage = _isSimplifiedVoiceMode
          ? 'What color do you see? Say RED or BLUE or BOTH'
          : 'Reading ${i + 1} of $totalReadings: What do you see? Say HORIZONTAL, VERTICAL, BOTH, or SWITCHING';
      notifyListeners();

      final response = await VoskService.listenOnce(
        timeout: const Duration(seconds: 4),
      );

      final parsed = _parseResponseForProfile(response);
      _responses.add(parsed);

      if (parsed == 'horizontal') {
        _horizontalCount++;
      } else if (parsed == 'vertical') {
        _verticalCount++;
      }

      if (_lastResponse.isNotEmpty &&
          _lastResponse != parsed &&
          parsed != 'unknown' &&
          _lastResponse != 'unknown') {
        _switchCount++;
      }
      _lastResponse = parsed;

      await Future<void>.delayed(const Duration(milliseconds: 800));
    }

    await _completeTest();
  }

  String _parseResponseForProfile(String voice) {
    if (_isSimplifiedVoiceMode) return _parseColorResponse(voice);
    return _parseResponse(voice);
  }

  /// Profile B: map RED -> horizontal, BLUE -> vertical, BOTH -> switching.
  String _parseColorResponse(String voice) {
    final v = voice.toLowerCase();
    // #region agent log H-B
    debugPrint('AMBYODEBUG:9f653c:H-B:parseColor|input="$voice"');
    // #endregion
    // English + Malayalam + Hindi + Tamil for RED
    if (v.contains('red') || v.contains('crimson') || v.contains('pink') ||
        v.contains('ചുവ') || v.contains('chuva') || // Malayalam: red
        v.contains('laal') || v.contains('lal') || // Hindi: red
        v.contains('sivappu')) { // Tamil: red
      return 'horizontal';
    }
    // English + Malayalam + Hindi + Tamil for BLUE
    if (v.contains('blue') || v.contains('dark') ||
        v.contains('നീ') || v.contains('neela') || // Malayalam: blue
        v.contains('nila') || v.contains('neelam') || // Hindi: blue
        v.contains('neelamani')) { // Tamil: blue
      return 'vertical';
    }
    // Both / switching
    if (v.contains('both') || v.contains('all') || v.contains('two') ||
        v.contains('rendu') || v.contains('randu') || v.contains('രണ്ടും') || // Malayalam: two
        v.contains('dono') || v.contains('dono') || v.contains('दोनों') || // Hindi: both
        v.contains('irandu') || v.contains('இரண்டும்')) { // Tamil: both
      _switchCount++;
      return 'switching';
    }
    return 'unknown';
  }

  String _parseResponse(String voice) {
    final v = voice.toLowerCase();
    // #region agent log H-B
    debugPrint('AMBYODEBUG:9f653c:H-B:parseRivalry|input="$voice"');
    // #endregion

    if (v.contains('horizontal') ||
        v.contains('horizon') ||
        v.contains('sideways') ||
        v.contains('flat') ||
        v.contains('red') ||
        v.contains('lines') ||
        v.contains('nirayana') ||
        v.contains('chuvappu') ||
        v.contains('ചുവ') ||
        v.contains('ചുവപ്പ്') ||
        v.contains('laal') ||
        v.contains('laali') ||
        v.contains('aadiyo') ||
        v.contains('seedha') ||
        v.contains('लाल') ||
        v.contains('sivappu') ||
        v.contains('kodi') ||
        v.contains('சிவப்பு')) {
      return 'horizontal';
    }

    if (v.contains('vertical') ||
        v.contains('straight') ||
        v.contains('blue') ||
        v.contains('updown') ||
        v.contains('neela') ||
        v.contains('neelappu') ||
        v.contains('neer') ||
        v.contains('നീ') ||
        v.contains('നീലം') ||
        v.contains('neeli') ||
        v.contains('नीला') ||
        v.contains('seedhi') ||
        v.contains('neelam') ||
        v.contains('neel') ||
        v.contains('நீலம்')) {
      return 'vertical';
    }

    if (v.contains('switch') ||
        v.contains('both') ||
        v.contains('changing') ||
        v.contains('alternating') ||
        v.contains('mixing') ||
        v.contains('rendu') ||
        v.contains('randum') ||
        v.contains('maarunnund') ||
        v.contains('രണ്ടും') ||
        v.contains('മാറുന്നുണ്ട്') ||
        v.contains('dono') ||
        v.contains('donon') ||
        v.contains('badal') ||
        v.contains('दोनों') ||
        v.contains('irandum') ||
        v.contains('இரண்டும்')) {
      _switchCount++;
      return 'switching';
    }

    if (v.contains('nothing') || v.contains('none') ||
        v.contains("can't see") || v.contains('cannot') ||
        v.contains('onnum') || v.contains('kannu') || // Malayalam
        v.contains('kuch nahi') || v.contains('nahi') || // Hindi
        v.contains('illai') || v.contains('paakka villai')) { // Tamil
      return 'none';
    }

    return 'unknown';
  }

  Future<void> _completeTest() async {
    final resultType =
        SuppressionResult.classifyResult(_switchCount, totalReadings);

    final score = SuppressionResult.calcScore(_switchCount, totalReadings);

    String dominant = 'equal';
    if (_horizontalCount > _verticalCount + 1) {
      dominant = 'horizontal';
    } else if (_verticalCount > _horizontalCount + 1) {
      dominant = 'vertical';
    }

    final suppressedEye = SuppressionResult.inferSuppressedEye(
      dominant,
      _horizontalCount,
      _verticalCount,
    );

    final suppressionScore = 1 - score;

    final isAbnormal = _switchCount < 3;

    final note = _buildNote(resultType, _switchCount, suppressedEye);

    _result = SuppressionResult(
      responses: List<String>.from(_responses),
      switchCount: _switchCount,
      dominantPattern: dominant,
      suppressedEye: suppressedEye,
      suppressionScore: suppressionScore,
      result: resultType,
      isAbnormal: isAbnormal,
      requiresReferral: suppressionScore > 0.5,
      clinicalNote: note,
      normalityScore: score,
    );

    _state = RivalryState.completed;
    _statusMessage = isAbnormal
        ? 'Suppression detected — $suppressedEye eye'
        : 'Normal binocular vision ✓';

    await _saveResult(_result!);
    notifyListeners();
  }

  String _buildNote(String result, int switches, String suppressedEye) {
    switch (result) {
      case 'Normal Binocular Vision':
        return 'Normal binocular rivalry detected. Perception switched $switches times indicating healthy binocular vision.';

      case 'Mild Suppression':
        return 'Mild suppression detected. Limited perceptual switching ($switches times). '
            '${suppressedEye != 'None' ? '$suppressedEye eye may be suppressed. ' : ''}'
            'Follow-up recommended.';

      case 'Moderate Suppression':
        return 'Moderate suppression detected. Very limited rivalry switching. '
            '${suppressedEye != 'None' ? '$suppressedEye eye suppression suspected. ' : ''}'
            'Ophthalmologist referral recommended.';

      case 'Severe Suppression':
        return 'Severe suppression detected. No perceptual alternation observed. '
            '${suppressedEye != 'None' ? '$suppressedEye eye consistently suppressed. ' : ''}'
            'Consistent with amblyopia. Immediate referral to Aravind Eye Hospital.';

      default:
        return 'Test inconclusive. Patient may not have understood instructions. Please repeat.';
    }
  }

  Future<void> _saveResult(SuppressionResult result) async {
    await LocalDatabase.instance.saveTestResult(
      TestResult(
        id: const Uuid().v4(),
        sessionId: TestFlowController.currentSessionId ?? '',
        testName: 'suppression_test',
        rawScore: result.suppressionScore,
        normalizedScore: result.normalityScore,
        details: result.toJson(),
        createdAt: DateTime.now(),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
