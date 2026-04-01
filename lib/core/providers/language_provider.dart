import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/offline/vosk_service.dart';

enum AppLanguage {
  english,
  malayalam,
  hindi,
  tamil,
}

class LanguageProvider extends ChangeNotifier {
  AppLanguage _language = AppLanguage.english;

  AppLanguage get current => _language;

  String get code {
    switch (_language) {
      case AppLanguage.english:
        return 'en';
      case AppLanguage.malayalam:
        return 'ml';
      case AppLanguage.hindi:
        return 'hi';
      case AppLanguage.tamil:
        return 'ta';
    }
  }

  String get displayName {
    switch (_language) {
      case AppLanguage.english:
        return 'English';
      case AppLanguage.malayalam:
        return 'Malayalam';
      case AppLanguage.hindi:
        return 'Hindi';
      case AppLanguage.tamil:
        return 'Tamil';
    }
  }

  String get voskModelPath {
    switch (_language) {
      case AppLanguage.english:
        return 'assets/vosk/vosk-en/';
      case AppLanguage.malayalam:
        return 'assets/vosk/vosk-ml/';
      case AppLanguage.hindi:
        return 'assets/vosk/vosk-hi/';
      case AppLanguage.tamil:
        return 'assets/vosk/vosk-ta/';
    }
  }

  Future<void> setLanguage(AppLanguage lang) async {
    _language = lang;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_language', code);
    await prefs.setString('vosk_language', code);
    await VoskService.dispose();
    await VoskService.initialize(code);
    notifyListeners();
  }

  Future<void> loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('app_language') ?? prefs.getString('vosk_language') ?? 'en';
    switch (saved) {
      case 'ml':
        _language = AppLanguage.malayalam;
        break;
      case 'hi':
        _language = AppLanguage.hindi;
        break;
      case 'ta':
        _language = AppLanguage.tamil;
        break;
      default:
        _language = AppLanguage.english;
    }
    notifyListeners();
  }
}

