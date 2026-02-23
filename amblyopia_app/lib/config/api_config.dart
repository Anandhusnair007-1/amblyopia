class ApiConfig {
  static const String baseUrl = 'http://10.0.2.2:8000';
  static const Duration timeout = Duration(seconds: 30);

  static const String nurseLogin = '/api/auth/nurse-login';
  static const String refreshToken = '/api/auth/refresh-token';
  static const String createPatient = '/api/patient/create';
  static const String patientHistory = '/api/patient/history';
  static const String startSession = '/api/screening/start';
  static const String completeScreening = '/api/screening/complete';
  static const String screeningReport = '/api/screening/report';
  static const String snellenResult = '/api/snellen/result';
  static const String gazeResult = '/api/gaze/result';
  static const String redgreenResult = '/api/redgreen/result';
  static const String syncBatch = '/api/sync/batch';
  static const String checkModelUpdate = '/api/sync/check-model-update';
  static const String villageHeatmap = '/api/dashboard/village-heatmap';
  static const String nurseProfile = '/api/nurse/profile';
}
