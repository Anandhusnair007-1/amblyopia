import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:vosk_flutter/vosk_flutter.dart';

class VoskService {
  static VoskFlutterPlugin? _vosk;
  static Model? _model;
  static Recognizer? _recognizer;
  static SpeechService? _speechService;
  static bool _isVoskInitialized = false;

  static final stt.SpeechToText _speechToText = stt.SpeechToText();
  static bool _isSttInitialized = false;

  static String _currentLanguage = 'en';

  static String get currentLanguage => _currentLanguage;

  static Future<void> initialize([String language = 'en']) async {
    _currentLanguage = language;

    // On Android, skip Vosk: JNA native lib can cause UnsatisfiedLinkError and crash the app.
    // Use device SpeechToText instead so the app stays stable.
    if (Platform.isAndroid) {
      await _initSpeechToText(language);
      return;
    }

    if (language == 'en' || language == 'hi') {
      await _initVosk(language);
    } else if (language == 'ml' || language == 'ta') {
      await _initSpeechToText(language);
    } else {
      await _initVosk('en');
    }
  }

  static Future<void> _initVosk(String language) async {
    try {
      _vosk = VoskFlutterPlugin.instance();
      final modelPath = await _getOrCopyModel(language);
      _model = await _vosk!.createModel(modelPath);
      _recognizer = await _vosk!.createRecognizer(
        model: _model!,
        sampleRate: 16000,
      );
      _speechService = await _vosk!.initSpeechService(_recognizer!);
      _isVoskInitialized = true;
      debugPrint('Vosk initialized: $language');
    } catch (e) {
      debugPrint('Vosk init failed: $e');
      _isVoskInitialized = false;
      await _initSpeechToText(language);
    }
  }

  /// Prefer loading from documents directory (copied there on first run) to avoid asset size limits.
  static Future<String> _getOrCopyModel(String language) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final modelDir = Directory('${docsDir.path}/vosk-$language');

    if (await modelDir.exists()) {
      final list = modelDir.listSync();
      if (list.isNotEmpty) {
        debugPrint('Vosk model found in docs: ${modelDir.path}');
        return modelDir.path;
      }
    }

    debugPrint('Copying Vosk model to docs...');
    await modelDir.create(recursive: true);
    final assetPath = _getVoskModelPath(language);

    try {
      final loadedPath = await ModelLoader().loadFromAssets(assetPath);
      await _copyDirectory(Directory(loadedPath), modelDir);
      return modelDir.path;
    } catch (e) {
      debugPrint('ModelLoader failed: $e');
      return assetPath;
    }
  }

  static Future<void> _copyDirectory(Directory source, Directory destination) async {
    await for (final entity in source.list(recursive: true)) {
      final relative = p.relative(entity.path, from: source.path);
      final destPath = p.join(destination.path, relative);
      if (entity is File) {
        await File(destPath).parent.create(recursive: true);
        await entity.copy(destPath);
      } else if (entity is Directory) {
        await Directory(destPath).create(recursive: true);
      }
    }
  }

  static Future<void> _initSpeechToText(String language) async {
    try {
      _isSttInitialized = await _speechToText.initialize(
        onError: (error) => debugPrint('STT error: $error'),
        debugLogging: false,
      );
      debugPrint(
        'SpeechToText initialized: $language ($_isSttInitialized)',
      );
    } catch (e) {
      debugPrint('STT init failed: $e');
      _isSttInitialized = false;
    }
  }

  static String _getVoskModelPath(String lang) {
    switch (lang) {
      case 'hi':
        return 'assets/vosk/vosk-hi/';
      default:
        return 'assets/vosk/vosk-en/';
    }
  }

  static String _getSttLocale(String lang) {
    switch (lang) {
      case 'ml':
        return 'ml_IN';
      case 'ta':
        return 'ta_IN';
      case 'hi':
        return 'hi_IN';
      default:
        return 'en_IN';
    }
  }

  static const String _kMicDenied = '__MIC_DENIED__';

  static Future<String> listenOnce({
    Duration timeout = const Duration(seconds: 12),
  }) async {
    // #region agent log H-A
    final micStatus = await Permission.microphone.status;
    debugPrint('AMBYODEBUG:9f653c:H-A:listenOnce|micGranted=${micStatus.isGranted}|voskReady=$_isVoskInitialized|sttReady=$_isSttInitialized|lang=$_currentLanguage');
    // #endregion

    if (!micStatus.isGranted) {
      final result = await Permission.microphone.request();
      // #region agent log H-A
      debugPrint('AMBYODEBUG:9f653c:H-A:micRequested|granted=${result.isGranted}');
      // #endregion
      if (!result.isGranted) {
        return _kMicDenied;
      }
    }

    if (_isVoskInitialized &&
        (_currentLanguage == 'en' || _currentLanguage == 'hi')) {
      return await _listenVosk(timeout: timeout);
    }

    if (_isSttInitialized) {
      return await _listenStt(timeout: timeout);
    }

    debugPrint('No speech engine available');
    return '';
  }

  static Future<String> _listenVosk({
    required Duration timeout,
  }) async {
    if (_speechService == null) return '';

    final completer = Completer<String>();
    StreamSubscription<String>? sub;

    await _speechService!.start();
    sub = _speechService!.onResult().listen((event) {
      sub?.cancel();
      _speechService?.stop();
      if (!completer.isCompleted) {
        completer.complete(event);
      }
    });

    Future<void>.delayed(timeout, () {
      sub?.cancel();
      _speechService?.stop();
      if (!completer.isCompleted) {
        completer.complete('');
      }
    });

    return completer.future;
  }

  static Future<String> _listenStt({
    required Duration timeout,
  }) async {
    if (!_isSttInitialized) return '';

    final completer = Completer<String>();
    String finalResult = '';

    await _speechToText.listen(
      onResult: (result) {
        finalResult = result.recognizedWords;
        if (result.finalResult && !completer.isCompleted) {
          completer.complete(finalResult);
        }
      },
      localeId: _getSttLocale(_currentLanguage),
      listenFor: const Duration(seconds: 12),
      pauseFor: const Duration(seconds: 4),
      listenOptions: stt.SpeechListenOptions(
        partialResults: false,
        cancelOnError: false,
      ),
    );

    Future<void>.delayed(timeout, () {
      _speechToText.stop();
      if (!completer.isCompleted) {
        completer.complete(finalResult);
      }
    });

    return completer.future;
  }

  static Future<void> dispose() async {
    _speechService?.stop();
    await _speechService?.dispose();
    await _recognizer?.dispose();
    _model?.dispose();
    await _speechToText.cancel();
    _isVoskInitialized = false;
    _isSttInitialized = false;
  }

  static bool get isReady => _isVoskInitialized || _isSttInitialized;

  static bool isMicDenied(String response) => response == _kMicDenied;

  static String get activeEngine {
    if (_isVoskInitialized) return 'Vosk (offline)';
    if (_isSttInitialized) return 'Device STT (offline)';
    return 'None';
  }
}
