class ApiConfig {
  static const String baseUrl = "http://localhost:8000/api";
  
  // Auth
  static const String nurseLogin = "$baseUrl/auth/nurse-login";
  static const String refreshToken = "$baseUrl/auth/refresh-token";
  
  // Patient
  static const String createPatient = "$baseUrl/patient/create";
  static const String patientHistory = "$baseUrl/patient/history";
  
  // Screening
  static const String startScreening = "$baseUrl/screening/start";
  static const String completeScreening = "$baseUrl/screening/complete";
  
  // Test Results
  static const String snellenResult = "$baseUrl/snellen/result";
  static const String gazeResult = "$baseUrl/gaze/result";
  static const String redGreenResult = "$baseUrl/redgreen/result";
  
  // Sync & Model
  static const String checkModel = "$baseUrl/sync/check-model-update";
  static const String batchUpload = "$baseUrl/sync/batch-upload";
  
  // Village
  static const String assignedVillages = "$baseUrl/nurse/assigned-villages";
  static const String villageHeatmap = "$baseUrl/village/heatmap-data";
}
