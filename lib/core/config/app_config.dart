import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  AppConfig._();

  static String get backendBaseUrl {
    final configured =
        dotenv.env['AMBYOAI_API_BASE_URL'] ?? dotenv.env['BASE_URL'] ?? '';
    return configured.trim().replaceAll(RegExp(r'/$'), '');
  }

  static bool get hasSecureBackend {
    final uri = Uri.tryParse(backendBaseUrl);
    return uri != null && uri.hasScheme && uri.scheme == 'https';
  }

  static bool get enableRemoteSync => hasSecureBackend;

  static Map<String, Object?> diagnostics() {
    return <String, Object?>{
      'backendBaseUrl': backendBaseUrl,
      'hasSecureBackend': hasSecureBackend,
      'platform': defaultTargetPlatform.name,
    };
  }
}
