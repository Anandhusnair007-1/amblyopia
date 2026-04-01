import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../../../core/theme/ambyo_theme.dart';
import '../../../core/widgets/enterprise_ui.dart';
import '../../../core/services/distance_calibration_service.dart';

/// One-time per device: hold A4 paper at arm's length, capture, then tap left and right edges
/// to measure paper width in pixels. Calibrates distance calculation.
class DistanceCalibrationScreen extends StatefulWidget {
  const DistanceCalibrationScreen({super.key});

  @override
  State<DistanceCalibrationScreen> createState() => _DistanceCalibrationScreenState();
}

class _DistanceCalibrationScreenState extends State<DistanceCalibrationScreen> {
  String? _imagePath;
  int? _imageWidth;
  int? _imageHeight;
  Offset? _tap1;
  Offset? _tap2;
  bool _saving = false;
  String? _error;

  Future<void> _capture() async {
    setState(() => _error = null);
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw StateError('No camera');
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      if (!mounted) return;
      final file = await controller.takePicture();
      await controller.dispose();
      if (!mounted) return;
      final bytes = await File(file.path).readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        setState(() => _error = 'Could not read image.');
        return;
      }
      setState(() {
        _imagePath = file.path;
        _imageWidth = decoded.width;
        _imageHeight = decoded.height;
        _tap1 = null;
        _tap2 = null;
      });
    } catch (e) {
      setState(() => _error = 'Camera error: $e');
    }
  }

  void _onImageTap(TapDownDetails d, double scale, double offsetX, double offsetY) {
    final ix = (d.localPosition.dx - offsetX) / scale;
    final iy = (d.localPosition.dy - offsetY) / scale;
    setState(() {
      if (_tap1 == null) {
        _tap1 = Offset(ix, iy);
      } else {
        _tap2 = Offset(ix, iy);
      }
    });
  }

  Future<void> _saveCalibration() async {
    if (_tap1 == null || _tap2 == null || _imageWidth == null) return;
    final widthPx = (_tap2!.dx - _tap1!.dx).abs();
    if (widthPx < 10) return;
    setState(() => _saving = true);
    await DistanceCalibrationService.instance.save(paperWidthPx: widthPx);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Distance calibration saved.')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    if (_imagePath != null && _imageWidth != null && _imageHeight != null) {
      return _buildMeasureStep();
    }
    return _buildCaptureStep();
  }

  Widget _buildCaptureStep() {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Distance calibration'),
        backgroundColor: AmbyoTheme.cardLight,
        foregroundColor: AmbyoTheme.navyColor,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          EnterprisePanel(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.straighten_rounded, size: 48, color: AmbyoTheme.primaryColor),
                const SizedBox(height: 16),
                Text(
                  'Hold A4 paper at arm\'s length',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AmbyoTheme.navyColor,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Take a photo of a standard A4 paper (21 cm wide) held at arm\'s length. '
                  'Then tap the left and right edges of the paper in the photo. '
                  'This calibrates distance for more accurate measurements.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF66748B),
                      ),
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _capture,
            icon: const Icon(Icons.camera_alt_rounded),
            label: const Text('Capture photo'),
            style: FilledButton.styleFrom(
              backgroundColor: AmbyoTheme.primaryColor,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeasureStep() {
    final w = _imageWidth!.toDouble();
    final h = _imageHeight!.toDouble();
    return Scaffold(
      backgroundColor: Colors.black87,
      appBar: AppBar(
        title: const Text('Tap paper edges'),
        backgroundColor: Colors.black54,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              _tap1 == null
                  ? 'Tap the LEFT edge of the paper'
                  : _tap2 == null
                      ? 'Tap the RIGHT edge of the paper'
                      : 'Width: ${((_tap2!.dx - _tap1!.dx).abs()).toStringAsFixed(0)} px. Save or retry.',
              style: const TextStyle(color: Colors.white, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final scale = (constraints.maxWidth / w) < (constraints.maxHeight / h)
                    ? (constraints.maxWidth / w)
                    : (constraints.maxHeight / h);
                final paintedW = w * scale;
                final paintedH = h * scale;
                final offsetX = (constraints.maxWidth - paintedW) / 2;
                final offsetY = (constraints.maxHeight - paintedH) / 2;
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      left: offsetX,
                      top: offsetY,
                      width: paintedW,
                      height: paintedH,
                      child: Image.file(
                        File(_imagePath!),
                        fit: BoxFit.contain,
                      ),
                    ),
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapDown: (d) => _onImageTap(d, scale, offsetX, offsetY),
                      ),
                    ),
                    if (_tap1 != null)
                      Positioned(
                        left: offsetX + _tap1!.dx * scale,
                        top: offsetY + _tap1!.dy * scale,
                        child: const Icon(Icons.circle, color: Colors.greenAccent, size: 24),
                      ),
                    if (_tap2 != null)
                      Positioned(
                        left: offsetX + _tap2!.dx * scale,
                        top: offsetY + _tap2!.dy * scale,
                        child: const Icon(Icons.circle, color: Colors.orangeAccent, size: 24),
                      ),
                  ],
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                TextButton(
                  onPressed: () => setState(() {
                    _imagePath = null;
                    _imageWidth = null;
                    _imageHeight = null;
                    _tap1 = null;
                    _tap2 = null;
                  }),
                  child: const Text('Retake'),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton(
                    onPressed: (_tap1 != null && _tap2 != null && !_saving) ? _saveCalibration : null,
                    style: FilledButton.styleFrom(backgroundColor: AmbyoTheme.primaryColor),
                    child: Text(_saving ? 'Saving...' : 'Save calibration'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
