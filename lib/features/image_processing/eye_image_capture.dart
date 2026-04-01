import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../offline/database_tables.dart';
import '../offline/local_database.dart';
import 'clahe_processor.dart';
import 'green_channel.dart';

class EyeImageCapture {
  EyeImageCapture({
    required CameraController cameraController,
    LocalDatabase? database,
  })  : _cameraController = cameraController,
        _database = database ?? LocalDatabase.instance;

  final CameraController _cameraController;
  final LocalDatabase _database;

  static final GreenChannelExtractor _greenExtractor = GreenChannelExtractor();
  static final ClaheProcessor _claheProcessor = ClaheProcessor();
  static const _uuid = Uuid();
  static const _maxBytesPerPatient = 50 * 1024 * 1024;

  Future<EyeImage> captureProcessedFrame(String sessionId, String imageType) async {
    final rawFile = await _cameraController.takePicture();
    final bytes = await rawFile.readAsBytes();
    return _saveProcessedBytes(
      bytes: bytes,
      sessionId: sessionId,
      imageType: imageType,
      database: _database,
    );
  }

  static Future<EyeImage> captureAndSave({
    required CameraImage image,
    required String sessionId,
    required String imageType,
    LocalDatabase? database,
  }) async {
    final allBytes = BytesBuilder(copy: false);
    for (final plane in image.planes) {
      allBytes.add(plane.bytes);
    }
    return _saveProcessedBytes(
      bytes: allBytes.toBytes(),
      sessionId: sessionId,
      imageType: imageType,
      database: database ?? LocalDatabase.instance,
    );
  }

  static Future<EyeImage> _saveProcessedBytes({
    required Uint8List bytes,
    required String sessionId,
    required String imageType,
    required LocalDatabase database,
  }) async {
    final storageUsage = await database.getStorageUsageBytes();
    if (storageUsage >= _maxBytesPerPatient) {
      throw StateError('Local eye-image storage limit reached for this patient');
    }

    final processed = _processBytes(bytes);
    final file = await _persistProcessedBytes(sessionId, imageType, processed);
    final image = EyeImage(
      id: _uuid.v4(),
      sessionId: sessionId,
      imageType: imageType,
      filePath: file.path,
      fileSize: await file.length(),
      createdAt: DateTime.now().toUtc(),
    );
    await database.saveImageRecord(image);
    return image;
  }

  static Uint8List _processBytes(Uint8List input) {
    final green = _greenExtractor.isolate(input);
    final clahe = _claheProcessor.apply(green);
    final normalized = clahe.map((value) => value.clamp(0, 255)).toList(growable: false);
    final cropped = _centerCrop50x50(normalized);
    return Uint8List.fromList(cropped);
  }

  static Future<File> _persistProcessedBytes(
    String sessionId,
    String imageType,
    Uint8List bytes,
  ) async {
    final directory = await getApplicationDocumentsDirectory();
    final sessionDir = Directory(p.join(directory.path, 'sessions', sessionId));
    if (!sessionDir.existsSync()) {
      sessionDir.createSync(recursive: true);
    }

    final file = File(
      p.join(sessionDir.path, '${imageType}_${DateTime.now().millisecondsSinceEpoch}.jpg'),
    );
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  static List<int> _centerCrop50x50(List<int> values) {
    if (values.length <= 2500) {
      return values;
    }
    final start = (values.length / 2).floor() - 1250;
    final safeStart = start < 0 ? 0 : start;
    final end = safeStart + 2500;
    return values.sublist(safeStart, end > values.length ? values.length : end);
  }
}
