import 'package:speech_to_text/speech_to_text.dart';
import 'dart:async';
import '../config/strings.dart';

class VoiceService {
  static final SpeechToText _stt = SpeechToText();
  static bool _available = false;

  static Future<bool> init() async {
    _available = await _stt.initialize(
      onError: (e) => debugPrintStt('STT error: $e'),
    );
    return _available;
  }

  static void debugPrintStt(String msg) {
    // ignore: avoid_print
    print(msg);
  }

  static Future<String?> listenForLetter({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (!_available) return null;
    final completer = Completer<String?>();
    bool completed = false;

    await _stt.listen(
      onResult: (result) {
        if (result.finalResult && !completed) {
          completed = true;
          final text = result.recognizedWords.toLowerCase().trim();
          completer.complete(_extractLetter(text));
        }
      },
      listenFor: timeout,
      localeId: _getLocale(),
    );

    return completer.future.timeout(
      timeout + const Duration(seconds: 2),
      onTimeout: () {
        stopListening();
        return null;
      },
    );
  }

  static Future<String?> listenForDirection({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (!_available) return null;
    final completer = Completer<String?>();
    bool completed = false;

    await _stt.listen(
      onResult: (result) {
        if (result.finalResult && !completed) {
          completed = true;
          final text = result.recognizedWords.toLowerCase().trim();
          completer.complete(_extractDirection(text));
        }
      },
      listenFor: timeout,
      localeId: _getLocale(),
    );

    return completer.future.timeout(
      timeout + const Duration(seconds: 2),
      onTimeout: () {
        stopListening();
        return null;
      },
    );
  }

  static Future<String?> listenForNumber({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (!_available) return null;
    final completer = Completer<String?>();
    bool completed = false;

    await _stt.listen(
      onResult: (result) {
        if (result.finalResult && !completed) {
          completed = true;
          final text = result.recognizedWords.toLowerCase().trim();
          completer.complete(_extractNumber(text));
        }
      },
      listenFor: timeout,
      localeId: _getLocale(),
    );

    return completer.future.timeout(
      timeout + const Duration(seconds: 2),
      onTimeout: () {
        stopListening();
        return null;
      },
    );
  }

  static void stopListening() {
    _stt.stop();
  }

  static String? _extractLetter(String text) {
    final Map<String, String> corrections = {
      'see': 'C', 'sea': 'C', 'si': 'C',
      'are': 'R', 'our': 'R', 'ar': 'R',
      'you': 'U', 'yu': 'U',
      'why': 'Y', 'wire': 'Y',
      'tea': 'T', 'tee': 'T', 'ti': 'T',
      'pee': 'P', 'pe': 'P', 'bee': 'B',
      'dee': 'D', 'de': 'D',
      'eff': 'F', 'ef': 'F',
      'jay': 'J', 'jae': 'J',
      'kay': 'K', 'ke': 'K',
      'em': 'M', 'en': 'N',
      'oh': 'O', 'zero': 'O',
      'el': 'L', 'ell': 'L',
      'eks': 'X', 'ex': 'X',
      'zee': 'Z', 'zed': 'Z',
      'double': 'W',
      'eye': 'I', 'i': 'I',
      'eight': '8', 'ate': '8',
      'vee': 'V', 've': 'V',
    };

    final lower = text.toLowerCase().trim();

    if (lower.length == 1 && RegExp(r'[a-z]').hasMatch(lower)) {
      return lower.toUpperCase();
    }

    if (corrections.containsKey(lower)) return corrections[lower];

    final words = lower.split(' ');
    if (words.isNotEmpty && words[0].length == 1) {
      return words[0].toUpperCase();
    }

    return null;
  }

  static String? _extractDirection(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('up') || lower.contains('above')) return 'up';
    if (lower.contains('down') || lower.contains('below')) return 'down';
    if (lower.contains('left')) return 'left';
    if (lower.contains('right')) return 'right';
    return null;
  }

  static String? _extractNumber(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('one') || lower.contains('1')) return '1';
    if (lower.contains('two') || lower.contains('2')) return '2';
    if (lower.contains('three') || lower.contains('3')) return '3';
    return null;
  }

  static String _getLocale() {
    switch (AppStrings.currentLanguage) {
      case AppLanguage.tamil: return 'ta_IN';
      case AppLanguage.malayalam: return 'ml_IN';
      default: return 'en_IN';
    }
  }
}
