import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/api_service.dart';
import '../services/tts_service.dart';
import '../services/voice_service.dart';
import 'login_screen.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;
  String _status = 'Initializing...';

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _fadeAnim = Tween(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeIn));
    _scaleAnim = Tween(begin: 0.8, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
    _ctrl.forward();
    _init();
  }

  Future<void> _init() async {
    setState(() => _status = 'Loading services...');
    await TtsService.init();
    await VoiceService.init();

    setState(() => _status = 'Checking login...');
    final auth = await DatabaseService.getToken();

    await Future.delayed(const Duration(milliseconds: 1800));
    if (!mounted) return;

    if (auth != null) {
      ApiService.setToken(auth['token'] as String);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: ScaleTransition(
            scale: _scaleAnim,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF1565C0),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1565C0).withOpacity(0.4),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.remove_red_eye,
                      color: Colors.white, size: 60),
                ),
                const SizedBox(height: 32),
                const Text(
                  'AMBLYOPIA CARE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Aravind Eye Hospital',
                  style: TextStyle(
                    color: Color(0xFF90CAF9),
                    fontSize: 14,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 48),
                const CircularProgressIndicator(
                  color: Color(0xFF00E5FF),
                  strokeWidth: 2,
                ),
                const SizedBox(height: 16),
                Text(
                  _status,
                  style: const TextStyle(
                    color: Color(0xFF546E7A),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }
}
