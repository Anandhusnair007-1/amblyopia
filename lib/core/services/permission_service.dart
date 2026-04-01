import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../l10n/app_strings.dart';

class PermissionService {
  /// Request all permissions needed at app startup.
  /// Camera and microphone are required; storage is optional (don't block app if denied).
  static Future<bool> requestAllPermissions() async {
    final camera = await Permission.camera.request();
    final microphone = await Permission.microphone.request();

    if (Platform.isAndroid) {
      final sdkInt = await _getAndroidSdkVersion();
      if (sdkInt >= 33) {
        await Permission.photos.request();
      } else {
        await Permission.storage.request();
      }
    } else {
      await Permission.storage.request();
    }

    return camera.isGranted && microphone.isGranted;
  }

  static Future<int> _getAndroidSdkVersion() async {
    if (!Platform.isAndroid) return 0;
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      return info.version.sdkInt;
    } catch (e) {
      return 0;
    }
  }

  /// Check camera permission; request if denied. Returns false if permanently denied.
  static Future<bool> checkCamera() async {
    final status = await Permission.camera.status;
    if (status.isDenied) {
      final result = await Permission.camera.request();
      return result.isGranted;
    }
    if (status.isPermanentlyDenied) {
      return false;
    }
    return status.isGranted;
  }

  /// Check microphone permission; request if denied. Returns false if permanently denied.
  static Future<bool> checkMicrophone() async {
    final status = await Permission.microphone.status;
    if (status.isDenied) {
      final result = await Permission.microphone.request();
      return result.isGranted;
    }
    if (status.isPermanentlyDenied) {
      return false;
    }
    return status.isGranted;
  }

  /// Combined check for camera and mic (e.g. before starting tests). Shows dialog if permanently denied.
  static Future<bool> checkCameraAndMic(BuildContext context) async {
    final camera = await Permission.camera.status;
    final mic = await Permission.microphone.status;

    if (!camera.isGranted) {
      if (camera.isPermanentlyDenied) {
        if (context.mounted) {
          showPermissionDialog(context, 'Camera');
        }
        return false;
      }
      final result = await Permission.camera.request();
      if (!result.isGranted) {
        if (context.mounted) {
          _showPermissionDialog(context, 'Camera', AppStrings.cameraPermissionDenied);
        }
        return false;
      }
    }
    if (!mic.isGranted) {
      if (mic.isPermanentlyDenied) {
        if (context.mounted) {
          showPermissionDialog(context, 'Microphone');
        }
        return false;
      }
      final result = await Permission.microphone.request();
      if (!result.isGranted) {
        if (context.mounted) {
          _showPermissionDialog(context, 'Microphone', AppStrings.micPermissionDenied);
        }
        return false;
      }
    }
    return true;
  }

  /// Show dialog when permission is permanently denied; [Open Settings] opens app settings.
  static Future<void> showPermissionDialog(BuildContext context, String permissionName) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(
          '$permissionName Required',
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'AmbyoAI needs $permissionName to run eye tests. Please enable it in Settings.',
          style: const TextStyle(fontFamily: 'Poppins'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  static void _showPermissionDialog(
    BuildContext context,
    String type,
    String message,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$type Permission Required'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }
}
