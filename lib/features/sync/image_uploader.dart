import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../core/config/app_config.dart';
import '../../core/network/api_client.dart';
import '../offline/database_tables.dart';
import '../offline/local_database.dart';

class ImageUploader {
  ImageUploader({
    Dio? dio,
    LocalDatabase? database,
  })  : _dio = dio ?? ApiClient.create(),
        _database = database ?? LocalDatabase.instance;

  final Dio _dio;
  final LocalDatabase _database;

  Future<void> uploadImage(EyeImage image) async {
    try {
      final uri = Uri.tryParse(AppConfig.backendBaseUrl);
      if (uri == null ||
          uri.scheme != 'https' ||
          AppConfig.backendBaseUrl.isEmpty) {
        debugPrint('ImageUploader: skipped, no valid secure backend URL');
        return;
      }

      final file = File(image.filePath);
      if (!file.existsSync()) {
        await _database.markImageUploaded(image.id);
        return;
      }

      final formData = FormData.fromMap(<String, Object?>{
        'session_id': image.sessionId,
        'image_type': image.imageType,
        'image': await MultipartFile.fromFile(file.path,
            filename: file.uri.pathSegments.last),
      });

      final dio = _dio.options.baseUrl.isEmpty ? ApiClient.create() : _dio;
      await dio.post('/api/sync/images', data: formData);
      await _database.markImageUploaded(image.id);
      if (file.existsSync()) {
        await file.delete();
      }
    } catch (e, st) {
      debugPrint('ImageUploader.uploadImage error: $e $st');
    }
  }
}
