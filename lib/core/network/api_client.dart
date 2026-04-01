import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/app_config.dart';

class ApiClient {
  ApiClient._();

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static Dio create() {
    final dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.backendBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        sendTimeout: const Duration(seconds: 20),
        headers: const <String, String>{
          'Accept': 'application/json',
        },
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.read(key: 'doctor_jwt');
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );

    return dio;
  }

  static T unwrap<T>(
    dynamic payload, {
    T Function(dynamic raw)? mapper,
  }) {
    final raw = payload is Map<String, dynamic> && payload.containsKey('data')
        ? payload['data']
        : payload;
    if (mapper != null) {
      return mapper(raw);
    }
    return raw as T;
  }
}
