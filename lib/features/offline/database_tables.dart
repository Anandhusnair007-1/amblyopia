import 'dart:convert';

class Patient {
  final String id;
  final String name;
  final int age;
  final String gender;
  final String phone;
  final DateTime createdAt;
  final bool synced;

  const Patient({
    required this.id,
    required this.name,
    required this.age,
    required this.gender,
    required this.phone,
    required this.createdAt,
    this.synced = false,
  });

  Patient copyWith({
    String? id,
    String? name,
    int? age,
    String? gender,
    String? phone,
    DateTime? createdAt,
    bool? synced,
  }) {
    return Patient(
      id: id ?? this.id,
      name: name ?? this.name,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      phone: phone ?? this.phone,
      createdAt: createdAt ?? this.createdAt,
      synced: synced ?? this.synced,
    );
  }
}

class TestSession {
  final String id;
  final String patientId;
  final DateTime testDate;
  final String workerId;
  final String deviceId;
  final bool completed;
  final bool synced;
  final String? pdfPath;

  const TestSession({
    required this.id,
    required this.patientId,
    required this.testDate,
    required this.workerId,
    required this.deviceId,
    this.completed = false,
    this.synced = false,
    this.pdfPath,
  });
}

/// Local doctor/worker account (device-only auth).
class DoctorAccount {
  final String id;
  final String username;
  final String passwordHash;
  final String fullName;
  final String specialization;
  final String hospitalName;
  final DateTime createdAt;
  final DateTime? lastLoginAt;

  const DoctorAccount({
    required this.id,
    required this.username,
    required this.passwordHash,
    required this.fullName,
    required this.specialization,
    required this.hospitalName,
    required this.createdAt,
    this.lastLoginAt,
  });

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'username': username,
        'password_hash': passwordHash,
        'full_name': fullName,
        'specialization': specialization,
        'hospital_name': hospitalName,
        'created_at': createdAt.toIso8601String(),
        'last_login_at': lastLoginAt?.toIso8601String(),
      };

  static DoctorAccount fromJson(Map<String, Object?> row) {
    return DoctorAccount(
      id: row['id'] as String,
      username: row['username'] as String,
      passwordHash: row['password_hash'] as String,
      fullName: row['full_name'] as String,
      specialization: row['specialization'] as String,
      hospitalName: row['hospital_name'] as String,
      createdAt: DateTime.parse(row['created_at'] as String),
      lastLoginAt: row['last_login_at'] != null
          ? DateTime.parse(row['last_login_at'] as String)
          : null,
    );
  }
}

/// Doctor diagnosis stored locally per session.
class DoctorDiagnosis {
  final String id;
  final String sessionId;
  final String doctorId;
  final String diagnosis;
  final String treatment;
  final String riskLabel;
  final String? followUpDate;
  final String? referredTo;
  final DateTime createdAt;

  const DoctorDiagnosis({
    required this.id,
    required this.sessionId,
    required this.doctorId,
    required this.diagnosis,
    required this.treatment,
    required this.riskLabel,
    this.followUpDate,
    this.referredTo,
    required this.createdAt,
  });

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'session_id': sessionId,
        'doctor_id': doctorId,
        'diagnosis': diagnosis,
        'treatment': treatment,
        'risk_label': riskLabel,
        'follow_up_date': followUpDate,
        'referred_to': referredTo,
        'created_at': createdAt.toIso8601String(),
      };

  static DoctorDiagnosis fromJson(Map<String, Object?> row) {
    return DoctorDiagnosis(
      id: row['id'] as String,
      sessionId: row['session_id'] as String,
      doctorId: row['doctor_id'] as String,
      diagnosis: row['diagnosis'] as String,
      treatment: row['treatment'] as String,
      riskLabel: row['risk_label'] as String,
      followUpDate: row['follow_up_date'] as String?,
      referredTo: row['referred_to'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }
}

class TestResult {
  final String id;
  final String sessionId;
  final String testName;
  final double rawScore;
  final double normalizedScore;
  final Map<String, dynamic> details;
  final String? imagePath;
  final DateTime createdAt;

  const TestResult({
    required this.id,
    required this.sessionId,
    required this.testName,
    required this.rawScore,
    required this.normalizedScore,
    required this.details,
    this.imagePath,
    required this.createdAt,
  });
}

class AIPrediction {
  final String id;
  final String sessionId;
  final double riskScore;
  final String riskLevel;
  final String recommendation;
  final String modelVersion;
  final DateTime createdAt;
  final bool doctorReviewed;
  final String? doctorNotes;

  const AIPrediction({
    required this.id,
    required this.sessionId,
    required this.riskScore,
    required this.riskLevel,
    required this.recommendation,
    required this.modelVersion,
    required this.createdAt,
    this.doctorReviewed = false,
    this.doctorNotes,
  });
}

class EyeImage {
  final String id;
  final String sessionId;
  final String imageType;
  final String filePath;
  final int fileSize;
  final bool uploaded;
  final DateTime createdAt;

  const EyeImage({
    required this.id,
    required this.sessionId,
    required this.imageType,
    required this.filePath,
    required this.fileSize,
    this.uploaded = false,
    required this.createdAt,
  });
}

class ModelUpdateRecord {
  final int? id;
  final String version;
  final String downloadUrl;
  final bool downloaded;
  final bool applied;
  final DateTime createdAt;

  const ModelUpdateRecord({
    this.id,
    required this.version,
    required this.downloadUrl,
    this.downloaded = false,
    this.applied = false,
    required this.createdAt,
  });
}

class SavedReportRecord {
  final String sessionId;
  final String filePath;
  final DateTime createdAt;

  const SavedReportRecord({
    required this.sessionId,
    required this.filePath,
    required this.createdAt,
  });
}

/// Informed consent record per patient. Shown once before first screening;
/// if consent is older than 12 months, renewal screen is shown.
class ConsentRecord {
  final String patientId;
  final String patientName;
  final DateTime dateOfBirth;
  final String guardianName;
  final String guardianRelation;
  final DateTime consentDate;
  final String signaturePngPath;
  final String language;
  final String appVersion;

  const ConsentRecord({
    required this.patientId,
    required this.patientName,
    required this.dateOfBirth,
    required this.guardianName,
    required this.guardianRelation,
    required this.consentDate,
    required this.signaturePngPath,
    required this.language,
    required this.appVersion,
  });
}

/// Clinical audit log entry.
class AuditLog {
  const AuditLog({
    required this.id,
    required this.action,
    required this.userRole,
    this.userId,
    this.targetId,
    this.targetType,
    required this.timestamp,
    required this.deviceId,
    this.modelVersion,
    this.details,
  });

  final String id;
  final String action;
  final String userRole;
  final String? userId;
  final String? targetId;
  final String? targetType;
  final DateTime timestamp;
  final String deviceId;
  final String? modelVersion;
  final String? details;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'action': action,
        'user_role': userRole,
        'user_id': userId,
        'target_id': targetId,
        'target_type': targetType,
        'timestamp': timestamp.toIso8601String(),
        'device_id': deviceId,
        'model_version': modelVersion,
        'details': details,
      };

  static AuditLog fromJson(Map<String, Object?> row) {
    return AuditLog(
      id: row['id'] as String,
      action: row['action'] as String,
      userRole: row['user_role'] as String,
      userId: row['user_id'] as String?,
      targetId: row['target_id'] as String?,
      targetType: row['target_type'] as String?,
      timestamp: DateTime.parse(row['timestamp'] as String),
      deviceId: row['device_id'] as String,
      modelVersion: row['model_version'] as String?,
      details: row['details'] as String?,
    );
  }
}

enum AuditAction {
  patientRegistered,
  consentGiven,
  consentRenewed,
  sessionStarted,
  testCompleted,
  sessionCompleted,
  aiPredictionGenerated,
  pdfGenerated,
  dataSynced,
  doctorDiagnosisAdded,
  modelUpdated,
  patientDataDeleted,
  workerLogin,
  doctorLogin,
  patientLogin,
  urgentCaseFlagged,
}

class DatabaseTables {
  static const patients = 'patients';
  static const testSessions = 'test_sessions';
  static const testResults = 'test_results';
  static const aiPredictions = 'ai_predictions';
  static const eyeImages = 'eye_images';
  static const modelUpdates = 'model_updates';
  static const reports = 'reports';
  static const consentRecords = 'consent_records';
  static const auditLogs = 'audit_logs';
  static const doctorAccounts = 'doctor_accounts';
  static const doctorDiagnoses = 'doctor_diagnoses';

  static const createStatements = <String>[
    '''
    CREATE TABLE IF NOT EXISTS patients (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      age INTEGER NOT NULL,
      gender TEXT NOT NULL,
      phone TEXT NOT NULL,
      created_at TEXT NOT NULL,
      synced INTEGER NOT NULL DEFAULT 0
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS test_sessions (
      id TEXT PRIMARY KEY,
      patient_id TEXT NOT NULL,
      test_date TEXT NOT NULL,
      worker_id TEXT NOT NULL,
      device_id TEXT NOT NULL,
      completed INTEGER NOT NULL DEFAULT 0,
      synced INTEGER NOT NULL DEFAULT 0,
      pdf_path TEXT,
      FOREIGN KEY(patient_id) REFERENCES patients(id) ON DELETE CASCADE
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS test_results (
      id TEXT PRIMARY KEY,
      session_id TEXT NOT NULL,
      test_name TEXT NOT NULL,
      raw_score REAL NOT NULL,
      normalized_score REAL NOT NULL,
      details TEXT NOT NULL,
      image_path TEXT,
      mini_pdf_path TEXT,
      created_at TEXT NOT NULL,
      FOREIGN KEY(session_id) REFERENCES test_sessions(id) ON DELETE CASCADE
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS ai_predictions (
      id TEXT PRIMARY KEY,
      session_id TEXT NOT NULL,
      risk_score REAL NOT NULL,
      risk_level TEXT NOT NULL,
      recommendation TEXT NOT NULL,
      model_version TEXT NOT NULL,
      created_at TEXT NOT NULL,
      doctor_reviewed INTEGER NOT NULL DEFAULT 0,
      doctor_notes TEXT,
      FOREIGN KEY(session_id) REFERENCES test_sessions(id) ON DELETE CASCADE
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS eye_images (
      id TEXT PRIMARY KEY,
      session_id TEXT NOT NULL,
      image_type TEXT NOT NULL,
      file_path TEXT NOT NULL,
      file_size INTEGER NOT NULL,
      uploaded INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL,
      FOREIGN KEY(session_id) REFERENCES test_sessions(id) ON DELETE CASCADE
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS model_updates (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      version TEXT NOT NULL,
      download_url TEXT NOT NULL,
      downloaded INTEGER NOT NULL DEFAULT 0,
      applied INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS reports (
      session_id TEXT PRIMARY KEY,
      file_path TEXT NOT NULL,
      created_at TEXT NOT NULL,
      FOREIGN KEY(session_id) REFERENCES test_sessions(id) ON DELETE CASCADE
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS consent_records (
      patient_id TEXT PRIMARY KEY,
      patient_name TEXT NOT NULL,
      date_of_birth TEXT NOT NULL,
      guardian_name TEXT NOT NULL,
      guardian_relation TEXT NOT NULL,
      consent_date TEXT NOT NULL,
      signature_png_path TEXT NOT NULL,
      language TEXT NOT NULL,
      app_version TEXT NOT NULL,
      FOREIGN KEY(patient_id) REFERENCES patients(id) ON DELETE CASCADE
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS audit_logs (
      id TEXT PRIMARY KEY,
      action TEXT NOT NULL,
      user_role TEXT NOT NULL,
      user_id TEXT,
      target_id TEXT,
      target_type TEXT,
      timestamp TEXT NOT NULL,
      device_id TEXT NOT NULL,
      model_version TEXT,
      details TEXT
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS doctor_accounts (
      id TEXT PRIMARY KEY,
      username TEXT NOT NULL UNIQUE,
      password_hash TEXT NOT NULL,
      full_name TEXT NOT NULL,
      specialization TEXT NOT NULL,
      hospital_name TEXT NOT NULL,
      created_at TEXT NOT NULL,
      last_login_at TEXT
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS doctor_diagnoses (
      id TEXT PRIMARY KEY,
      session_id TEXT NOT NULL,
      doctor_id TEXT NOT NULL,
      diagnosis TEXT NOT NULL,
      treatment TEXT NOT NULL,
      risk_label TEXT NOT NULL,
      follow_up_date TEXT,
      referred_to TEXT,
      created_at TEXT NOT NULL,
      FOREIGN KEY(session_id) REFERENCES test_sessions(id) ON DELETE CASCADE
    )
    ''',
  ];

  static Map<String, Object?> testResultToMap(
    TestResult result, {
    String? encryptedPath,
  }) {
    return <String, Object?>{
      'id': result.id,
      'session_id': result.sessionId,
      'test_name': result.testName,
      'raw_score': result.rawScore,
      'normalized_score': result.normalizedScore,
      'details': jsonEncode(result.details),
      'image_path': encryptedPath ?? result.imagePath,
      'created_at': result.createdAt.toIso8601String(),
    };
  }
}
