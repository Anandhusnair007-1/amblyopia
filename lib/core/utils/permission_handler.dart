import 'package:permission_handler/permission_handler.dart';

class PermissionHelper {
  static Future<bool> requestCamera() async => (await Permission.camera.request()).isGranted;

  static Future<bool> requestMicrophone() async => (await Permission.microphone.request()).isGranted;

  static Future<bool> requestStorage() async => (await Permission.storage.request()).isGranted;
}
