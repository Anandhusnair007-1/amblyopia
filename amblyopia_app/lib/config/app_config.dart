class AppConfig {
  static const String appName = 'Amblyopia Care';
  static const String hospital = 'Aravind Eye Hospital';
  static const String version = '1.0.0';
  static const String deviceId = 'device_001';

  // Screening durations (seconds)
  static const int gazeTestDuration = 30;
  static const int redGreenPhaseDuration = 10;

  // Offline settings
  static const int maxRetryCount = 3;
  static const Duration syncInterval = Duration(minutes: 5);
}
