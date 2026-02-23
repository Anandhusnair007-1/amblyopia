import 'package:flutter_tts/flutter_tts.dart';
import '../config/strings.dart';

class TtsService {
  static final FlutterTts _tts = FlutterTts();
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    await _tts.setVolume(1.0);
    await _tts.setSpeechRate(0.5);
    await _tts.setPitch(1.0);
    await _setLanguage();
    _initialized = true;
  }

  static Future<void> _setLanguage() async {
    switch (AppStrings.currentLanguage) {
      case AppLanguage.tamil:
        await _tts.setLanguage('ta-IN');
        break;
      case AppLanguage.malayalam:
        await _tts.setLanguage('ml-IN');
        break;
      default:
        await _tts.setLanguage('en-IN');
    }
  }

  static Future<void> speak(String text) async {
    await _tts.stop();
    await _tts.speak(text);
  }

  static Future<void> stop() async {
    await _tts.stop();
  }

  static Future<void> sayLookAtBall() => speak(AppStrings.lookAtBall);
  static Future<void> sayReadLetter() => speak(AppStrings.readLetter);
  static Future<void> sayHowManyCircles() => speak(AppStrings.howManyCircles);
  static Future<void> sayCoverLeft() => speak(AppStrings.coverLeftEye);
  static Future<void> sayCoverRight() => speak(AppStrings.coverRightEye);
  static Future<void> sayTestComplete() => speak(AppStrings.testComplete);
  static Future<void> sayUrgent() => speak(AppStrings.urgentReferral);
}
