import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../offline/database_tables.dart';
import '../../../offline/local_database.dart';
import '../../../offline/vosk_service.dart';
import '../../test_flow_controller.dart';
import '../models/worth_four_dot_result.dart';

enum WorthFourDotState {
  notStarted,
  ready,
  running,
  completed,
  error,
}

class WorthFourDotController extends ChangeNotifier {
  WorthFourDotController({
    LocalDatabase? database,
  }) : _database = database ?? LocalDatabase.instance;

  final LocalDatabase _database;
  final Uuid _uuid = const Uuid();

  WorthFourDotState _state = WorthFourDotState.notStarted;
  WorthFourDotResult? _result;
  int _currentStage = 0;
  String _statusMessage = 'Get ready for the Worth 4 Dot test';
  bool _isListening = false;
  final List<int> _answers = <int>[];
  Completer<int>? _responseCompleter;

  static const List<_WorthStage> _stages = <_WorthStage>[
    _WorthStage(
      label: 'Both eyes open',
      prompt:
          'Look at the 4 dots with both eyes open. How many dots do you see?',
      helper: 'Say a number from 1 to 5, or tap the count below.',
    ),
    _WorthStage(
      label: 'Cover left eye',
      prompt: 'Cover the left eye. How many dots do you see now?',
      helper: 'Expected response is 2 red dots.',
    ),
    _WorthStage(
      label: 'Cover right eye',
      prompt: 'Cover the right eye. How many dots do you see now?',
      helper: 'Expected response is 3 green dots.',
    ),
  ];

  WorthFourDotState get state => _state;
  WorthFourDotResult? get result => _result;
  int get currentStage => _currentStage;
  String get statusMessage => _statusMessage;
  bool get isListening => _isListening;
  int get totalStages => _stages.length;
  String get stageLabel =>
      _stages[_currentStage.clamp(0, _stages.length - 1)].label;
  String get prompt =>
      _stages[_currentStage.clamp(0, _stages.length - 1)].prompt;
  String get helper =>
      _stages[_currentStage.clamp(0, _stages.length - 1)].helper;

  Future<void> initialize() async {
    if (!VoskService.isReady) {
      await VoskService.initialize('en');
    }
    _state = WorthFourDotState.ready;
    _statusMessage = 'Use voice or tap the number of dots you see.';
    notifyListeners();
  }

  Future<void> startTest() async {
    _state = WorthFourDotState.running;
    _result = null;
    _answers.clear();
    _currentStage = 0;
    notifyListeners();

    for (var i = 0; i < _stages.length; i++) {
      _currentStage = i;
      _statusMessage = _stages[i].prompt;
      notifyListeners();

      await Future<void>.delayed(const Duration(milliseconds: 650));
      final answer = await _awaitResponse();
      _answers.add(answer);
    }

    _result = WorthFourDotResult.fromAnswers(
      bothEyesCount: _answers[0],
      leftEyeCoveredCount: _answers[1],
      rightEyeCoveredCount: _answers[2],
    );
    _state = WorthFourDotState.completed;
    _statusMessage = _result!.fusionStatus;
    await _saveResult(_result!);
    notifyListeners();
  }

  Future<int> _awaitResponse() async {
    _responseCompleter = Completer<int>();
    _listenForVoice();
    return _responseCompleter!.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        _isListening = false;
        _statusMessage = 'No voice heard. Tap the number of dots you see.';
        notifyListeners();
        return 0;
      },
    );
  }

  Future<void> _listenForVoice() async {
    _isListening = true;
    notifyListeners();
    final heard =
        await VoskService.listenOnce(timeout: const Duration(seconds: 8));
    if (_responseCompleter == null || _responseCompleter!.isCompleted) {
      _isListening = false;
      notifyListeners();
      return;
    }
    final parsed = _parseCount(heard);
    _isListening = false;
    if (parsed != null) {
      _responseCompleter!.complete(parsed);
      _statusMessage = 'Recorded: $parsed';
    } else {
      _statusMessage = 'Voice not recognized. Tap 1 to 5 below.';
    }
    notifyListeners();
  }

  void submitManualAnswer(int count) {
    if (_responseCompleter == null || _responseCompleter!.isCompleted) {
      return;
    }
    _isListening = false;
    _responseCompleter!.complete(count);
    _statusMessage = 'Recorded: $count';
    notifyListeners();
  }

  int? _parseCount(String raw) {
    final value = raw.trim().toLowerCase();
    if (value.isEmpty || value == '__mic_denied__') {
      return null;
    }
    if (value.contains('one') || value == '1') return 1;
    if (value.contains('two') || value == '2' || value.contains('too')) {
      return 2;
    }
    if (value.contains('three') || value == '3') return 3;
    if (value.contains('four') || value == '4' || value.contains('for')) {
      return 4;
    }
    if (value.contains('five') || value == '5') return 5;
    return int.tryParse(RegExp(r'\d').stringMatch(value) ?? '');
  }

  Future<void> _saveResult(WorthFourDotResult result) async {
    await _database.saveTestResult(
      TestResult(
        id: _uuid.v4(),
        sessionId: TestFlowController.currentSessionId ?? '',
        testName: 'worth_four_dot',
        rawScore: result.correctAnswers.toDouble(),
        normalizedScore: result.normalityScore,
        details: <String, dynamic>{
          ...result.toJson(),
          'raw_json': jsonEncode(result.toJson()),
        },
        createdAt: DateTime.now(),
      ),
    );
  }
}

class _WorthStage {
  const _WorthStage({
    required this.label,
    required this.prompt,
    required this.helper,
  });

  final String label;
  final String prompt;
  final String helper;
}
