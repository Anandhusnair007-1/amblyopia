import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../offline/database_tables.dart';
import '../../../offline/local_database.dart';
import '../../gaze_detection/models/gaze_result.dart';
import '../../test_flow_controller.dart';
import '../models/prism_result.dart';

class PrismCalculator extends ChangeNotifier {
  PrismCalculator({
    required this.sessionId,
    LocalDatabase? database,
  }) : _database = database ?? LocalDatabase.instance;

  final String sessionId;
  final LocalDatabase _database;
  final Uuid _uuid = const Uuid();

  PrismDiopterResult? _result;
  PrismCalculatorState _state = PrismCalculatorState.notStarted;

  PrismDiopterResult? get result => _result;
  PrismCalculatorState get state => _state;

  Future<PrismDiopterResult> calculateFromGaze(GazeTestResult gazeResult) async {
    _state = PrismCalculatorState.running;
    notifyListeners();

    final prismPerDir = <String, double>{};
    for (final dir in gazeResult.directions) {
      final thetaRad = dir.deviationAngleDegrees * math.pi / 180;
      prismPerDir[dir.direction] = 100 * math.tan(thetaRad);
    }

    const horizontalDirs = <String>[
      'left',
      'right',
      'upLeft',
      'upRight',
      'downLeft',
      'downRight',
    ];
    const verticalDirs = <String>[
      'up',
      'down',
      'upLeft',
      'upRight',
      'downLeft',
      'downRight',
    ];

    var maxH = 0.0;
    var maxV = 0.0;
    for (final direction in horizontalDirs) {
      final value = prismPerDir[direction] ?? 0;
      if (value > maxH) {
        maxH = value;
      }
    }
    for (final direction in verticalDirs) {
      final value = prismPerDir[direction] ?? 0;
      if (value > maxV) {
        maxV = value;
      }
    }

    final centerDirection = gazeResult.directions.firstWhere(
      (d) => d.direction == 'center',
      orElse: () => gazeResult.directions.first,
    );
    final centerPrism = prismPerDir['center'] ?? gazeResult.prismDiopterValue;

    _result = PrismDiopterResult(
      prismPerDirection: prismPerDir,
      maxHorizontalPrism: maxH,
      maxVerticalPrism: maxV,
      totalDeviation: centerPrism,
      distancePrism: centerPrism,
      nearPrism: centerPrism * 1.1,
      baseDirection: _getBaseDirection(centerDirection.leftEyeGaze, centerDirection.rightEyeGaze),
      deviationType: _getDeviationType(centerDirection.leftEyeGaze, centerDirection.rightEyeGaze),
      severity: _classifySeverity(centerPrism),
      requiresCorrection: centerPrism > 10,
    );

    _state = PrismCalculatorState.completed;
    await _saveResult(_result!);
    notifyListeners();
    return _result!;
  }

  Future<PrismDiopterResult> saveManual({
    required double totalDeviation,
    String deviationType = 'Manual Entry',
    String baseDirection = 'Unknown',
  }) async {
    _state = PrismCalculatorState.running;
    notifyListeners();

    _result = PrismDiopterResult(
      prismPerDirection: const <String, double>{},
      maxHorizontalPrism: totalDeviation,
      maxVerticalPrism: 0,
      totalDeviation: totalDeviation,
      distancePrism: totalDeviation,
      nearPrism: totalDeviation,
      baseDirection: baseDirection,
      deviationType: deviationType,
      severity: _classifySeverity(totalDeviation),
      requiresCorrection: totalDeviation > 10,
    );

    _state = PrismCalculatorState.completed;
    await _saveResult(_result!);
    notifyListeners();
    return _result!;
  }

  String _getBaseDirection(Offset left, Offset right) {
    final avgX = (left.dx + right.dx) / 2;
    final avgY = (left.dy + right.dy) / 2;

    if (avgX.abs() > avgY.abs()) {
      return avgX > 0 ? 'Base-Out' : 'Base-In';
    }
    return avgY > 0 ? 'Base-Down' : 'Base-Up';
  }

  String _getDeviationType(Offset left, Offset right) {
    final avgX = (left.dx + right.dx) / 2;
    final avgY = (left.dy + right.dy) / 2;

    if (avgX.abs() < 0.05 && avgY.abs() < 0.05) {
      return 'Normal (Orthophoria)';
    }

    if (avgX.abs() > avgY.abs()) {
      return avgX > 0 ? 'ET (Esotropia)' : 'XT (Exotropia)';
    }
    return avgY < 0 ? 'HT (Hypertropia)' : 'HoT (Hypotropia)';
  }

  String _classifySeverity(double prism) {
    if (prism < 10) {
      return 'Normal';
    }
    if (prism < 20) {
      return 'Mild';
    }
    if (prism < 40) {
      return 'Moderate';
    }
    return 'Severe';
  }

  Future<void> _saveResult(PrismDiopterResult result) async {
    await _database.saveTestResult(
      TestResult(
        id: _uuid.v4(),
        sessionId: sessionId.isNotEmpty ? sessionId : (TestFlowController.currentSessionId ?? ''),
        testName: 'prism_diopter',
        rawScore: result.totalDeviation,
        normalizedScore: (1 - result.totalDeviation / 50).clamp(0.0, 1.0),
        details: <String, dynamic>{
          ...result.toJson(),
          'rawJson': jsonEncode(result.toJson()),
        },
        createdAt: DateTime.now(),
      ),
    );
  }
}

enum PrismCalculatorState {
  notStarted,
  running,
  completed,
  error,
}
