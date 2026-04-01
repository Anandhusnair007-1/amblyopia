import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import '../../core/constants/app_constants.dart';
import 'models/prediction_result.dart';

class TFLiteRunner {
  Interpreter? _interpreter;
  String _modelVersion = '0.0.0';
  bool _isModelLoaded = false;

  static String? _currentVersion;
  static String get currentVersion => _currentVersion ?? '0.0.0';

  static const assetVersionPath = 'assets/models/model_version.json';
  static const prefsVersionKey = 'ambyoai_model_version';

  String get modelVersion => _modelVersion;
  bool get isModelLoaded => _isModelLoaded && _interpreter != null;
  String get modelPath => AppConstants.tfliteModelPath;

  Future<void> loadModel() async {
    _disposeInterpreter();

    const paths = [
      'assets/models/ambyo_model.tflite',
      'ambyo_model.tflite',
    ];

    for (final path in paths) {
      try {
        final options = InterpreterOptions()..threads = 2;
        _interpreter = await Interpreter.fromAsset(path, options: options);

        final inputTensors = _interpreter!.getInputTensors();
        final outputTensors = _interpreter!.getOutputTensors();
        if (inputTensors.isEmpty || outputTensors.isEmpty) {
          _disposeInterpreter();
          continue;
        }
        final inputShape = inputTensors.first.shape;
        final outputShape = outputTensors.first.shape;
        if (inputShape.length >= 2 &&
            outputShape.length >= 2 &&
            inputShape[1] == 10 &&
            outputShape[1] == 4) {
          _isModelLoaded = true;
          _modelVersion = await _loadModelVersion();
          _currentVersion = _modelVersion;
          debugPrint('TFLite loaded from: $path');
          return;
        }
        _disposeInterpreter();
      } catch (e) {
        debugPrint('TFLite load attempt failed ($path): $e');
      }
    }

    await _tryLoadFromDocs();
    if (_isModelLoaded) return;

    _isModelLoaded = false;
    debugPrint('TFLite load failed — using clinical fallback rules');
  }

  Future<void> _tryLoadFromDocs() async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final modelFile = File('${docsDir.path}/ambyo_model.tflite');
      if (await modelFile.exists()) {
        _interpreter = Interpreter.fromFile(
          modelFile,
          options: InterpreterOptions()..threads = 2,
        );
        final inputTensors = _interpreter!.getInputTensors();
        final outputTensors = _interpreter!.getOutputTensors();
        if (inputTensors.isNotEmpty &&
            outputTensors.isNotEmpty &&
            inputTensors.first.shape.length >= 2 &&
            outputTensors.first.shape.length >= 2 &&
            inputTensors.first.shape[1] == 10 &&
            outputTensors.first.shape[1] == 4) {
          _isModelLoaded = true;
          _modelVersion = await _loadModelVersion();
          _currentVersion = _modelVersion;
          debugPrint('TFLite loaded from docs (OTA version)');
        } else {
          _interpreter?.close();
          _interpreter = null;
        }
      }
    } catch (e) {
      debugPrint('Docs model load failed: $e');
    }
  }

  Future<String> _loadModelVersion() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await _resolveVersion(prefs);
    } catch (_) {
      return '0.0.0';
    }
  }

  Future<PredictionResult> runInference(List<double> inputs) async {
    if (inputs.length != 10) {
      throw ArgumentError('Expected 10 input values, got ${inputs.length}');
    }

    if (!isModelLoaded) {
      await loadModel();
    }

    final interpreter = _interpreter;
    if (interpreter == null) {
      return fallbackRules(inputs);
    }

    try {
      final input = <List<double>>[inputs];
      final output = List.generate(1, (_) => List<double>.filled(4, 0.0));
      interpreter.run(input, output);
      final probabilities = output.first;
      final riskClass = _argmax(probabilities);
      final riskScore =
          probabilities.reduce((a, b) => a > b ? a : b).clamp(0.0, 1.0).toDouble();
      final mapped = _mapRisk(riskScore);

      return PredictionResult(
        riskScore: riskScore,
        riskClass: riskClass,
        riskLevel: mapped.$1,
        recommendation: mapped.$2,
        modelVersion: _modelVersion,
        rawOutput: probabilities,
      );
    } catch (_) {
      return fallbackRules(inputs);
    }
  }

  Future<void> reloadModel() async {
    await loadModel();
  }

  Future<bool> validateModelFile(File file) async {
    try {
      final interpreter = Interpreter.fromFile(file);
      final input = <List<double>>[
        <double>[0.5, 0.3, 2.0, 0.1, 0.8, 0.9, 1.0, 0.9, 8.0, 1.5],
      ];
      final output = List.generate(1, (_) => List<double>.filled(4, 0.0));
      interpreter.run(input, output);
      interpreter.close();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<File> getModelStorageFile({String fileName = 'ambyo_model.tflite'}) async {
    final directory = await getApplicationSupportDirectory();
    final modelsDir = Directory(p.join(directory.path, 'models'));
    if (!modelsDir.existsSync()) {
      modelsDir.createSync(recursive: true);
    }
    return File(p.join(modelsDir.path, fileName));
  }

  /// Clinical fallback rules when TFLite model is not available.
  /// Input indices: 0=visual acuity, 1=gaze deviation, 2=prism diopter, 3=suppression,
  /// 4=depth, 5=stereo, 6=color, 7=red reflex, 8=age (normalized), 9=hirschberg.
  PredictionResult fallbackRules(List<double> inputs) {
    final acuity = inputs[0];
    final gaze = inputs[1];
    final prism = inputs[2];
    final suppression = inputs[3];
    final redReflex = inputs[7];

    if (redReflex < 0.1 || prism > 0.8 || gaze > 0.8) {
      const score = 0.92;
      final mapped = _mapRisk(score);
      return PredictionResult(
        riskScore: score,
        riskClass: 3,
        riskLevel: mapped.$1,
        recommendation: mapped.$2,
        modelVersion: _modelVersion,
        usedFallback: true,
        warning: 'Clinical rule: Critical finding',
        rawOutput: const [0, 0, 0, 1],
      );
    }
    if (prism > 0.5 || suppression > 0.7 || acuity < 0.3) {
      const score = 0.72;
      final mapped = _mapRisk(score);
      return PredictionResult(
        riskScore: score,
        riskClass: 2,
        riskLevel: mapped.$1,
        recommendation: mapped.$2,
        modelVersion: _modelVersion,
        usedFallback: true,
        warning: 'Clinical rule: High risk factors',
        rawOutput: const [0, 0, 1, 0],
      );
    }
    if (prism > 0.2 || suppression > 0.3 || acuity < 0.6) {
      const score = 0.42;
      final mapped = _mapRisk(score);
      return PredictionResult(
        riskScore: score,
        riskClass: 1,
        riskLevel: mapped.$1,
        recommendation: mapped.$2,
        modelVersion: _modelVersion,
        usedFallback: true,
        warning: 'Clinical rule: Mild risk factors',
        rawOutput: const [0, 1, 0, 0],
      );
    }
    const score = 0.15;
    final mapped = _mapRisk(score);
    return PredictionResult(
      riskScore: score,
      riskClass: 0,
      riskLevel: mapped.$1,
      recommendation: mapped.$2,
      modelVersion: _modelVersion,
      usedFallback: true,
      warning: 'Clinical rule: No significant risk',
      rawOutput: const [1, 0, 0, 0],
    );
  }

  (String, String) _mapRisk(double score) {
    if (score < 0.3) {
      return (
        'LOW RISK',
        'No significant findings. Routine check-up recommended.',
      );
    }
    if (score < 0.6) {
      return (
        'MEDIUM RISK',
        'Some indicators detected. Optometrist visit recommended within 3 months.',
      );
    }
    if (score < 0.8) {
      return (
        'HIGH RISK',
        'Significant findings detected. Ophthalmologist visit recommended within 2 weeks.',
      );
    }
    return (
      'URGENT',
      'Critical findings. Immediate referral to Aravind Eye Hospital required.',
    );
  }

  int _argmax(List<double> values) {
    var maxIndex = 0;
    var maxValue = values.first;
    for (var i = 1; i < values.length; i++) {
      if (values[i] > maxValue) {
        maxValue = values[i];
        maxIndex = i;
      }
    }
    return maxIndex;
  }

  Future<String> _resolveVersion(SharedPreferences prefs) async {
    final stored = prefs.getString(prefsVersionKey);
    if (stored != null && stored.isNotEmpty) {
      return stored;
    }

    try {
      final raw = await rootBundle.loadString(assetVersionPath);
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final assetVersion = decoded['version']?.toString() ?? '0.0.0';
      await prefs.setString(prefsVersionKey, assetVersion);
      return assetVersion;
    } catch (_) {
      return '0.0.0';
    }
  }

  void _disposeInterpreter() {
    _interpreter?.close();
    _interpreter = null;
    _isModelLoaded = false;
  }
}
