import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../offline/database_tables.dart';
import '../../../offline/local_database.dart';
import '../../../offline/vosk_service.dart';
import '../../age_profile.dart';
import '../../test_flow_controller.dart';
import '../models/ishihara_result.dart';

enum IshiharaState {
  notStarted,
  running,
  completed,
  error,
}

class IshiharaController extends ChangeNotifier {
  IshiharaController({
    LocalDatabase? database,
  }) : _database = database ?? LocalDatabase.instance;

  final LocalDatabase _database;
  final Uuid _uuid = const Uuid();

  IshiharaState _state = IshiharaState.notStarted;
  IshiharaResult? _result;
  String _statusMessage = '';
  int _currentPlate = 0;
  bool _isListening = false;

  final List<PlateAttempt> _attempts = <PlateAttempt>[];

  static const List<String> correctAnswers = <String>[
    '12',
    '8',
    '29',
    '5',
    '3',
    '15',
    '74',
    '6',
  ];

  static const Map<String, int> _multilingualNumbers = <String, int>{
    'zero': 0,
    'one': 1,
    'two': 2,
    'three': 3,
    'four': 4,
    'five': 5,
    'six': 6,
    'seven': 7,
    'eight': 8,
    'nine': 9,
    'ten': 10,
    'eleven': 11,
    'twelve': 12,
    'thirteen': 13,
    'fourteen': 14,
    'fifteen': 15,
    'sixteen': 16,
    'seventeen': 17,
    'eighteen': 18,
    'nineteen': 19,
    'twenty': 20,
    'twenty nine': 29,
    'seventy four': 74,
    'nothing': 0,
    'none': 0,
    'cannot see': 0,
    'dont see': 0,
    'no number': 0,
    'onnu': 1,
    'randu': 2,
    'moonnu': 3,
    'naalu': 4,
    'anchu': 5,
    'aaru': 6,
    'ezhu': 7,
    'ettu': 8,
    'ombathu': 9,
    'pathu': 10,
    'panthrantu': 12,
    'irupathu': 20,
    'irupattionbathu': 29,
    'ezhupatthinnaalu': 74,
    'ek': 1,
    'do': 2,
    'teen': 3,
    'char': 4,
    'paanch': 5,
    'chhe': 6,
    'saat': 7,
    'aath': 8,
    'nau': 9,
    'das': 10,
    'barah': 12,
    'bis': 20,
    'unattis': 29,
    'chauhattar': 74,
    'onru': 1,
    'rendu': 2,
    'moonu': 3,
    'naangu': 4,
    'anju': 5,
    'onbadhu': 9,
    'pannirandu': 12,
    'iruvadhu': 20,
    'iruvadhi onbadhu': 29,
  };

  IshiharaState get state => _state;
  IshiharaResult? get result => _result;
  String get statusMessage => _statusMessage;
  int get currentPlate => _currentPlate;
  bool get isListening => _isListening;
  int get totalPlates => correctAnswers.length;
  List<PlateAttempt> get attempts => List<PlateAttempt>.unmodifiable(_attempts);

  Future<void> startTest() async {
    _state = IshiharaState.running;
    _result = null;
    _currentPlate = 0;
    _attempts.clear();

    if (!VoskService.isReady) {
      await VoskService.initialize('en');
    }

    notifyListeners();

    final plates = isIshiharaSimplifiedForProfile(TestFlowController.currentProfile)
        ? correctAnswers.sublist(0, 4)
        : correctAnswers;

    for (var i = 0; i < plates.length; i++) {
      _currentPlate = i;
      _statusMessage = i == 0
          ? 'Demo plate: Say the number you see (should be 12)'
          : 'Plate ${i + 1} of ${plates.length}: What number do you see? Say the number or say NOTHING';
      notifyListeners();

      await Future<void>.delayed(const Duration(seconds: 3));

      final response = await _listenOnce(timeout: const Duration(seconds: 8));
      final parsed = _parseNumberResponse(response);
      final isCorrect = parsed == plates[i];

      _attempts.add(
        PlateAttempt(
          plateIndex: i,
          correctAnswer: plates[i],
          patientAnswer: parsed,
          isCorrect: isCorrect,
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 450));
    }

    await _completeTest();
  }

  Future<String> _listenOnce({required Duration timeout}) async {
    _isListening = true;
    notifyListeners();
    final response = await VoskService.listenOnce(timeout: timeout);
    if (response == 'MIC_PERMISSION_DENIED') {
      _statusMessage = 'Microphone permission denied';
    }
    _isListening = false;
    notifyListeners();
    return response;
  }

  String _parseNumberResponse(String voice) {
    final v = voice.toLowerCase().trim();

    final digits = RegExp(r'\d+').allMatches(v);
    if (digits.isNotEmpty) {
      return digits.first.group(0) ?? '0';
    }

    for (final entry in _multilingualNumbers.entries) {
      if (v.contains(entry.key)) {
        return '${entry.value}';
      }
    }

    if (v.contains('kuch nahi') || v.contains('illai') || v.contains('theriyavillai') || v.contains('onnum')) {
      return '0';
    }

    return '0';
  }

  Future<void> _completeTest() async {
    final correct = _attempts.skip(1).where((a) => a.isCorrect).length;
    final total = _attempts.length - 1;
    final status = IshiharaResult.classify(correct, total);
    final score = total <= 0 ? 0.0 : (correct / total);

    final note = _buildNote(status, correct, total);
    final isSimplified = total <= 3;
    _result = IshiharaResult(
      attempts: List<PlateAttempt>.unmodifiable(_attempts),
      correctAnswers: correct,
      totalTestPlates: total,
      colorVisionStatus: status,
      isNormal: isSimplified ? (correct >= 2) : (correct >= 6),
      requiresReferral: isSimplified ? (correct < 1) : (correct < 4),
      clinicalNote: note,
      normalityScore: score,
    );

    _state = IshiharaState.completed;
    _statusMessage = 'Color vision test complete ✓';
    await _saveResult(_result!);
    notifyListeners();
  }

  String _buildNote(String status, int correct, int total) {
    final base = '$status. $correct of $total plates identified correctly.';
    if (status == 'Normal') {
      return '$base Normal color vision.';
    }
    return '$base Color vision deficiency detected. Referral for clinical confirmation recommended.';
  }

  Future<void> _saveResult(IshiharaResult result) async {
    final flow = TestFlowController();
    flow.onTestComplete('ishihara_color', result);

    await _database.saveTestResult(
      TestResult(
        id: _uuid.v4(),
        sessionId: TestFlowController.currentSessionId ?? '',
        testName: 'ishihara_color',
        rawScore: result.normalityScore,
        normalizedScore: result.normalityScore,
        details: <String, dynamic>{
          ...result.toJson(),
          'rawJson': jsonEncode(result.toJson()),
        },
        createdAt: DateTime.now(),
      ),
    );
  }
}

