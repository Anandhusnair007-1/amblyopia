import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../providers/screening_provider.dart';

class GazeTestScreen extends StatefulWidget {
  const GazeTestScreen({super.key});

  @override
  State<GazeTestScreen> createState() => _GazeTestScreenState();
}

class _GazeTestScreenState extends State<GazeTestScreen> {
  CameraController? _controller;
  final FlutterTts _tts = FlutterTts();
  bool _isAnalyzing = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
    _tts.speak("Gaze Detection Test. Keep your eyes on the moving target.");
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;
    
    _controller = CameraController(cameras.first, ResolutionPreset.medium);
    await _controller!.initialize();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _submit() async {
    setState(() => _isAnalyzing = true);
    await Future.delayed(const Duration(seconds: 2)); // Mock analysis time
    
    final provider = Provider.of<ScreeningProvider>(context, listen: false);
    await provider.submitGaze({
      'left_gaze_x': 0.5, 'left_gaze_y': 0.51, 'right_gaze_x': 0.51, 'right_gaze_y': 0.51,
      'gaze_asymmetry_score': 0.05, 'frames_analyzed': 150, 'confidence_score': 0.88, 'result': 'symmetric'
    });
    
    if (mounted) {
      setState(() => _isAnalyzing = false);
      provider.nextStep();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gaze Detection')),
      body: Stack(
        children: [
          if (_controller != null && _controller!.value.isInitialized)
            CameraPreview(_controller!)
          else
            const Center(child: Text('Camera initializing...')),
            
          Center(
            child: Container(
              width: 200, height: 200,
              decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 2), shape: BoxShape.circle),
              child: const Center(child: Icon(Icons.add, color: Colors.white, size: 40)),
            ),
          ),
          
          if (_isAnalyzing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text('Analyzing Gaze...', style: TextStyle(color: Colors.white, fontSize: 18)),
                  ],
                ),
              ),
            ),
          
          Positioned(
            bottom: 30, left: 24, right: 24,
            child: ElevatedButton(
              onPressed: _isAnalyzing ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('CAPTURE & ANALYZE'),
            ),
          ),
        ],
      ),
    );
  }
}
