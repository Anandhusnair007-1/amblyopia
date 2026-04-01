import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:uuid/uuid.dart';

import 'database_tables.dart';
import 'sqlcipher_setup.dart';

class LocalDatabase {
  LocalDatabase._();

  static final LocalDatabase instance = LocalDatabase._();
  static Database? _db;
  static bool _initialized = false;
  static const _storage = FlutterSecureStorage();
  static const _uuid = Uuid();

  static Future<void> initialize() async {
    await instance._initializeInternal();
  }

  static Future<LocalDatabase> openDatabase() async {
    await initialize();
    return instance;
  }

  static bool get isReady => _initialized && _db != null;

  Future<void> _initializeInternal() async {
    if (_initialized && _db != null) {
      return;
    }

    _db = await SQLCipherSetup.openEncryptedSqliteDatabase();
    for (final statement in DatabaseTables.createStatements) {
      _db!.execute(statement);
    }
    _ensureSchemaUpgrades(_db!);
    _initialized = true;
  }

  void _ensureSchemaUpgrades(Database db) {
    _ensureColumn(db,
        table: 'test_sessions', column: 'pdf_path', definition: 'TEXT');
    _ensureColumn(db,
        table: 'test_results', column: 'mini_pdf_path', definition: 'TEXT');
  }

  void _ensureColumn(
    Database db, {
    required String table,
    required String column,
    required String definition,
  }) {
    final rows = db.select('PRAGMA table_info($table)');
    final hasColumn = rows.any((r) => (r['name'] as String?) == column);
    if (hasColumn) {
      return;
    }
    db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
  }

  Future<String> savePatient(Patient patient) async {
    final db = _requireDb();
    db.execute(
      '''
      INSERT OR REPLACE INTO patients
      (id, name, age, gender, phone, created_at, synced)
      VALUES (?, ?, ?, ?, ?, ?, ?)
      ''',
      <Object?>[
        patient.id,
        patient.name,
        patient.age,
        patient.gender,
        patient.phone,
        patient.createdAt.toIso8601String(),
        patient.synced ? 1 : 0,
      ],
    );
    return patient.id;
  }

  Future<List<Patient>> getAllPatients() async {
    final rows = _requireDb().select(
      '''
      SELECT id, name, age, gender, phone, created_at, synced
      FROM patients ORDER BY created_at DESC
      ''',
    );
    return rows
        .map(
          (row) => Patient(
            id: row['id'] as String,
            name: row['name'] as String,
            age: row['age'] as int,
            gender: row['gender'] as String,
            phone: row['phone'] as String,
            createdAt: DateTime.parse(row['created_at'] as String),
            synced: (row['synced'] as int) == 1,
          ),
        )
        .toList();
  }

  Future<Patient?> getPatient(String id) async {
    final rows = _requireDb().select(
      'SELECT * FROM patients WHERE id = ? LIMIT 1',
      <Object?>[id],
    );
    if (rows.isEmpty) {
      return null;
    }
    final row = rows.first;
    return Patient(
      id: row['id'] as String,
      name: row['name'] as String,
      age: row['age'] as int,
      gender: row['gender'] as String,
      phone: row['phone'] as String,
      createdAt: DateTime.parse(row['created_at'] as String),
      synced: (row['synced'] as int) == 1,
    );
  }

  /// Returns the current consent for this patient, or null if none.
  Future<ConsentRecord?> getConsent(String patientId) async {
    final rows = _requireDb().select(
      'SELECT * FROM consent_records WHERE patient_id = ? LIMIT 1',
      <Object?>[patientId],
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    return ConsentRecord(
      patientId: row['patient_id'] as String,
      patientName: row['patient_name'] as String,
      dateOfBirth: DateTime.parse(row['date_of_birth'] as String),
      guardianName: row['guardian_name'] as String,
      guardianRelation: row['guardian_relation'] as String,
      consentDate: DateTime.parse(row['consent_date'] as String),
      signaturePngPath: row['signature_png_path'] as String,
      language: row['language'] as String,
      appVersion: row['app_version'] as String,
    );
  }

  /// True if patient has consent but it is older than 12 months (renewal needed).
  static const consentValidityMonths = 12;

  Future<bool> consentNeedsRenewal(String patientId) async {
    final consent = await getConsent(patientId);
    if (consent == null) return false;
    final cutoff = DateTime.now().toUtc().subtract(const Duration(days: 365));
    return consent.consentDate.isBefore(cutoff);
  }

  /// Returns true if patient has valid consent (exists and not older than 12 months).
  Future<bool> hasValidConsent(String patientId) async {
    final consent = await getConsent(patientId);
    if (consent == null) return false;
    final cutoff = DateTime.now().toUtc().subtract(const Duration(days: 365));
    return !consent.consentDate.isBefore(cutoff);
  }

  Future<void> saveConsent(ConsentRecord record) async {
    final db = _requireDb();
    db.execute(
      '''
      INSERT OR REPLACE INTO consent_records
      (patient_id, patient_name, date_of_birth, guardian_name, guardian_relation,
       consent_date, signature_png_path, language, app_version)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      <Object?>[
        record.patientId,
        record.patientName,
        record.dateOfBirth.toIso8601String(),
        record.guardianName,
        record.guardianRelation,
        record.consentDate.toIso8601String(),
        record.signaturePngPath,
        record.language,
        record.appVersion,
      ],
    );
  }

  Future<void> saveAuditLog(AuditLog log) async {
    final j = log.toJson();
    _requireDb().execute(
      '''
      INSERT OR REPLACE INTO audit_logs
      (id, action, user_role, user_id, target_id, target_type, timestamp, device_id, model_version, details)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      <Object?>[
        j['id'],
        j['action'],
        j['user_role'],
        j['user_id'],
        j['target_id'],
        j['target_type'],
        j['timestamp'],
        j['device_id'],
        j['model_version'],
        j['details'],
      ],
    );
  }

  Future<List<AuditLog>> getAuditLogs(
      {int limit = 100, String? targetId}) async {
    final db = _requireDb();
    final results = targetId != null
        ? db.select(
            'SELECT * FROM audit_logs WHERE target_id = ? ORDER BY timestamp DESC LIMIT ?',
            <Object?>[targetId, limit],
          )
        : db.select(
            'SELECT * FROM audit_logs ORDER BY timestamp DESC LIMIT ?',
            <Object?>[limit],
          );
    return results
        .map(
          (r) => AuditLog(
            id: r['id'] as String,
            action: r['action'] as String,
            userRole: r['user_role'] as String,
            userId: r['user_id'] as String?,
            targetId: r['target_id'] as String?,
            targetType: r['target_type'] as String?,
            timestamp: DateTime.parse(r['timestamp'] as String),
            deviceId: r['device_id'] as String,
            modelVersion: r['model_version'] as String?,
            details: r['details'] as String?,
          ),
        )
        .toList();
  }

  Future<String> createSession(String patientId) async {
    final db = _requireDb();
    final sessionId = _uuid.v4();
    db.execute(
      '''
      INSERT INTO test_sessions
      (id, patient_id, test_date, worker_id, device_id, completed, synced, pdf_path)
      VALUES (?, ?, ?, ?, ?, 0, 0, NULL)
      ''',
      <Object?>[
        sessionId,
        patientId,
        DateTime.now().toUtc().toIso8601String(),
        await _deviceScopedValue('worker_id'),
        await _deviceScopedValue('device_id'),
      ],
    );
    await _trimSessionHistory();
    return sessionId;
  }

  Future<void> completeSession(String sessionId) async {
    _requireDb().execute(
      'UPDATE test_sessions SET completed = 1 WHERE id = ?',
      <Object?>[sessionId],
    );
  }

  Future<void> saveTestResult(TestResult result) async {
    _requireDb().execute(
      '''
      INSERT OR REPLACE INTO test_results
      (id, session_id, test_name, raw_score, normalized_score, details, image_path, mini_pdf_path, created_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      <Object?>[
        result.id,
        result.sessionId,
        result.testName,
        result.rawScore,
        result.normalizedScore,
        jsonEncode(result.details),
        result.imagePath,
        null,
        result.createdAt.toIso8601String(),
      ],
    );
  }

  Future<void> saveMiniReportPath(String testResultId, String filePath) async {
    _requireDb().execute(
      'UPDATE test_results SET mini_pdf_path = ? WHERE id = ?',
      <Object?>[filePath, testResultId],
    );
  }

  Future<String?> getMiniReportPath(String testResultId) async {
    final rows = _requireDb().select(
      'SELECT mini_pdf_path FROM test_results WHERE id = ? LIMIT 1',
      <Object?>[testResultId],
    );
    if (rows.isEmpty) return null;
    return rows.first['mini_pdf_path'] as String?;
  }

  Future<List<TestResult>> getSessionResults(String sessionId) async {
    final rows = _requireDb().select(
      'SELECT * FROM test_results WHERE session_id = ? ORDER BY created_at ASC',
      <Object?>[sessionId],
    );
    return rows
        .map(
          (row) => TestResult(
            id: row['id'] as String,
            sessionId: row['session_id'] as String,
            testName: row['test_name'] as String,
            rawScore: (row['raw_score'] as num).toDouble(),
            normalizedScore: (row['normalized_score'] as num).toDouble(),
            details:
                jsonDecode(row['details'] as String) as Map<String, dynamic>,
            imagePath: row['image_path'] as String?,
            createdAt: DateTime.parse(row['created_at'] as String),
          ),
        )
        .toList();
  }

  Future<void> savePrediction(AIPrediction prediction) async {
    _requireDb().execute(
      '''
      INSERT OR REPLACE INTO ai_predictions
      (id, session_id, risk_score, risk_level, recommendation, model_version, created_at, doctor_reviewed, doctor_notes)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      <Object?>[
        prediction.id,
        prediction.sessionId,
        prediction.riskScore,
        prediction.riskLevel,
        prediction.recommendation,
        prediction.modelVersion,
        prediction.createdAt.toIso8601String(),
        prediction.doctorReviewed ? 1 : 0,
        prediction.doctorNotes,
      ],
    );
  }

  Future<AIPrediction?> getPredictionForSession(String sessionId) async {
    final rows = _requireDb().select(
      'SELECT * FROM ai_predictions WHERE session_id = ? ORDER BY created_at DESC LIMIT 1',
      <Object?>[sessionId],
    );
    if (rows.isEmpty) {
      return null;
    }
    final row = rows.first;
    return AIPrediction(
      id: row['id'] as String,
      sessionId: row['session_id'] as String,
      riskScore: (row['risk_score'] as num).toDouble(),
      riskLevel: row['risk_level'] as String,
      recommendation: row['recommendation'] as String,
      modelVersion: row['model_version'] as String,
      createdAt: DateTime.parse(row['created_at'] as String),
      doctorReviewed: (row['doctor_reviewed'] as int) == 1,
      doctorNotes: row['doctor_notes'] as String?,
    );
  }

  Future<void> saveImageRecord(EyeImage image) async {
    _requireDb().execute(
      '''
      INSERT OR REPLACE INTO eye_images
      (id, session_id, image_type, file_path, file_size, uploaded, created_at)
      VALUES (?, ?, ?, ?, ?, ?, ?)
      ''',
      <Object?>[
        image.id,
        image.sessionId,
        image.imageType,
        image.filePath,
        image.fileSize,
        image.uploaded ? 1 : 0,
        image.createdAt.toIso8601String(),
      ],
    );
  }

  Future<List<EyeImage>> getPendingUploads() async {
    final rows = _requireDb().select(
      'SELECT * FROM eye_images WHERE uploaded = 0 ORDER BY created_at ASC',
    );
    return rows
        .map(
          (row) => EyeImage(
            id: row['id'] as String,
            sessionId: row['session_id'] as String,
            imageType: row['image_type'] as String,
            filePath: row['file_path'] as String,
            fileSize: row['file_size'] as int,
            uploaded: (row['uploaded'] as int) == 1,
            createdAt: DateTime.parse(row['created_at'] as String),
          ),
        )
        .toList();
  }

  Future<List<EyeImage>> getSessionImages(String sessionId) async {
    final rows = _requireDb().select(
      'SELECT * FROM eye_images WHERE session_id = ? ORDER BY created_at ASC',
      <Object?>[sessionId],
    );
    return rows
        .map(
          (row) => EyeImage(
            id: row['id'] as String,
            sessionId: row['session_id'] as String,
            imageType: row['image_type'] as String,
            filePath: row['file_path'] as String,
            fileSize: row['file_size'] as int,
            uploaded: (row['uploaded'] as int) == 1,
            createdAt: DateTime.parse(row['created_at'] as String),
          ),
        )
        .toList();
  }

  Future<void> markImageUploaded(String imageId) async {
    _requireDb().execute(
      'UPDATE eye_images SET uploaded = 1 WHERE id = ?',
      <Object?>[imageId],
    );
  }

  Future<List<TestSession>> getUnsyncedSessions() async {
    final rows = _requireDb().select(
      'SELECT * FROM test_sessions WHERE synced = 0 AND completed = 1 ORDER BY test_date ASC',
    );
    return rows
        .map(
          (row) => TestSession(
            id: row['id'] as String,
            patientId: row['patient_id'] as String,
            testDate: DateTime.parse(row['test_date'] as String),
            workerId: row['worker_id'] as String,
            deviceId: row['device_id'] as String,
            completed: (row['completed'] as int) == 1,
            synced: (row['synced'] as int) == 1,
            pdfPath: row['pdf_path'] as String?,
          ),
        )
        .toList();
  }

  Future<void> markSessionSynced(String sessionId) async {
    final db = _requireDb();
    db.execute('UPDATE test_sessions SET synced = 1 WHERE id = ?',
        <Object?>[sessionId]);
    db.execute(
      '''
      UPDATE patients SET synced = 1 WHERE id = (
        SELECT patient_id FROM test_sessions WHERE id = ? LIMIT 1
      )
      ''',
      <Object?>[sessionId],
    );
  }

  Future<void> logModelUpdate(ModelUpdateRecord record) async {
    _requireDb().execute(
      '''
      INSERT INTO model_updates
      (version, download_url, downloaded, applied, created_at)
      VALUES (?, ?, ?, ?, ?)
      ''',
      <Object?>[
        record.version,
        record.downloadUrl,
        record.downloaded ? 1 : 0,
        record.applied ? 1 : 0,
        record.createdAt.toIso8601String(),
      ],
    );
  }

  Future<void> markModelUpdateApplied(String version) async {
    _requireDb().execute(
      'UPDATE model_updates SET applied = 1, downloaded = 1 WHERE version = ?',
      <Object?>[version],
    );
  }

  Future<TestSession?> getSession(String sessionId) async {
    final rows = _requireDb().select(
      'SELECT * FROM test_sessions WHERE id = ? LIMIT 1',
      <Object?>[sessionId],
    );
    if (rows.isEmpty) {
      return null;
    }
    final row = rows.first;
    return TestSession(
      id: row['id'] as String,
      patientId: row['patient_id'] as String,
      testDate: DateTime.parse(row['test_date'] as String),
      workerId: row['worker_id'] as String,
      deviceId: row['device_id'] as String,
      completed: (row['completed'] as int) == 1,
      synced: (row['synced'] as int) == 1,
      pdfPath: row['pdf_path'] as String?,
    );
  }

  Future<void> saveReportPath(String sessionId, String filePath) async {
    final db = _requireDb();
    db.execute(
      '''
      INSERT OR REPLACE INTO reports (session_id, file_path, created_at)
      VALUES (?, ?, ?)
      ''',
      <Object?>[
        sessionId,
        filePath,
        DateTime.now().toIso8601String(),
      ],
    );
    db.execute(
      'UPDATE test_sessions SET pdf_path = ? WHERE id = ?',
      <Object?>[filePath, sessionId],
    );
  }

  static String _sha256(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> seedDefaultDoctor() async {
    final existing = await getDoctorByUsername('doctor');
    final secureDefault = _sha256('Aravind#2026!');
    final oldDefault = _sha256('AmbyoDoc#9274!');
    if (existing != null) {
      if (existing.passwordHash == oldDefault) {
        final db = _requireDb();
        db.execute(
          'UPDATE doctor_accounts SET password_hash = ? WHERE username = ?',
          <Object?>[secureDefault, 'doctor'],
        );
      }
      return;
    }
    await insertDoctor(DoctorAccount(
      id: _uuid.v4(),
      username: 'doctor',
      passwordHash: secureDefault,
      fullName: 'Dr. Aravind',
      specialization: 'Paediatric Ophthalmologist',
      hospitalName: 'Aravind Eye Hospital',
      createdAt: DateTime.now(),
    ));
  }

  Future<void> seedDefaultWorker() async {
    final existing = await getDoctorByUsername('worker');
    final secureDefault = _sha256('Worker#5816!');
    final oldDefault = _sha256('worker123');
    if (existing != null) {
      if (existing.passwordHash == oldDefault) {
        final db = _requireDb();
        db.execute(
          'UPDATE doctor_accounts SET password_hash = ? WHERE username = ?',
          <Object?>[secureDefault, 'worker'],
        );
      }
      return;
    }
    await insertDoctor(DoctorAccount(
      id: _uuid.v4(),
      username: 'worker',
      passwordHash: secureDefault,
      fullName: 'Health Worker',
      specialization: 'Health Worker',
      hospitalName: 'Anganwadi Center',
      createdAt: DateTime.now(),
    ));
  }

  Future<DoctorAccount?> getDoctorByUsername(String username) async {
    final rows = _requireDb().select(
      'SELECT * FROM doctor_accounts WHERE username = ? LIMIT 1',
      <Object?>[username],
    );
    if (rows.isEmpty) return null;
    return DoctorAccount.fromJson(Map<String, Object?>.from(rows.first));
  }

  Future<DoctorAccount?> verifyDoctorLogin(
      String username, String password) async {
    final doctor = await getDoctorByUsername(username);
    if (doctor == null) return null;
    final hash = _sha256(password);
    if (doctor.passwordHash != hash) return null;
    final db = _requireDb();
    db.execute(
      'UPDATE doctor_accounts SET last_login_at = ? WHERE id = ?',
      <Object?>[DateTime.now().toIso8601String(), doctor.id],
    );
    return getDoctorByUsername(username);
  }

  Future<void> insertDoctor(DoctorAccount doctor) async {
    final db = _requireDb();
    db.execute(
      '''
      INSERT OR REPLACE INTO doctor_accounts
      (id, username, password_hash, full_name, specialization, hospital_name, created_at, last_login_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      <Object?>[
        doctor.id,
        doctor.username,
        doctor.passwordHash,
        doctor.fullName,
        doctor.specialization,
        doctor.hospitalName,
        doctor.createdAt.toIso8601String(),
        doctor.lastLoginAt?.toIso8601String(),
      ],
    );
  }

  Future<bool> changeDoctorPassword({
    required String username,
    required String oldPassword,
    required String newPassword,
  }) async {
    final doctor = await verifyDoctorLogin(username, oldPassword);
    if (doctor == null) return false;
    final db = _requireDb();
    db.execute(
      'UPDATE doctor_accounts SET password_hash = ? WHERE username = ?',
      <Object?>[_sha256(newPassword), username],
    );
    return true;
  }

  Future<void> saveDiagnosis(DoctorDiagnosis diagnosis) async {
    final db = _requireDb();
    db.execute(
      '''
      INSERT OR REPLACE INTO doctor_diagnoses
      (id, session_id, doctor_id, diagnosis, treatment, risk_label, follow_up_date, referred_to, created_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      <Object?>[
        diagnosis.id,
        diagnosis.sessionId,
        diagnosis.doctorId,
        diagnosis.diagnosis,
        diagnosis.treatment,
        diagnosis.riskLabel,
        diagnosis.followUpDate,
        diagnosis.referredTo,
        diagnosis.createdAt.toIso8601String(),
      ],
    );
  }

  Future<DoctorDiagnosis?> getDiagnosisForSession(String sessionId) async {
    final rows = _requireDb().select(
      'SELECT * FROM doctor_diagnoses WHERE session_id = ? LIMIT 1',
      <Object?>[sessionId],
    );
    if (rows.isEmpty) return null;
    return DoctorDiagnosis.fromJson(Map<String, Object?>.from(rows.first));
  }

  Future<List<DoctorDiagnosis>> getAllDiagnoses() async {
    final rows = _requireDb().select(
      'SELECT * FROM doctor_diagnoses ORDER BY created_at DESC',
    );
    return rows
        .map((row) => DoctorDiagnosis.fromJson(Map<String, Object?>.from(row)))
        .toList();
  }

  Future<SavedReportRecord?> getReportPath(String sessionId) async {
    final rows = _requireDb().select(
      'SELECT * FROM reports WHERE session_id = ? LIMIT 1',
      <Object?>[sessionId],
    );
    if (rows.isEmpty) {
      return null;
    }
    final row = rows.first;
    return SavedReportRecord(
      sessionId: row['session_id'] as String,
      filePath: row['file_path'] as String,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  Future<Patient?> getPatientByPhone(String phone) async {
    final rows = _requireDb().select(
      'SELECT * FROM patients WHERE phone = ? LIMIT 1',
      <Object?>[phone],
    );
    if (rows.isEmpty) {
      return null;
    }
    final row = rows.first;
    return Patient(
      id: row['id'] as String,
      name: row['name'] as String,
      age: row['age'] as int,
      gender: row['gender'] as String,
      phone: row['phone'] as String,
      createdAt: DateTime.parse(row['created_at'] as String),
      synced: (row['synced'] as int) == 1,
    );
  }

  Future<void> updatePatient(Patient patient) async {
    _requireDb().execute(
      '''
      UPDATE patients
      SET name = ?, age = ?, gender = ?, synced = ?
      WHERE id = ?
      ''',
      <Object?>[
        patient.name,
        patient.age,
        patient.gender,
        patient.synced ? 1 : 0,
        patient.id,
      ],
    );
  }

  Future<List<TestSession>> getSessionsForPatient(String patientId) async {
    final rows = _requireDb().select(
      'SELECT * FROM test_sessions WHERE patient_id = ? ORDER BY test_date DESC',
      <Object?>[patientId],
    );
    return rows
        .map(
          (row) => TestSession(
            id: row['id'] as String,
            patientId: row['patient_id'] as String,
            testDate: DateTime.parse(row['test_date'] as String),
            workerId: row['worker_id'] as String,
            deviceId: row['device_id'] as String,
            completed: (row['completed'] as int) == 1,
            synced: (row['synced'] as int) == 1,
            pdfPath: row['pdf_path'] as String?,
          ),
        )
        .toList();
  }

  Future<List<TestResult>> getResultsByTestName(
      String patientId, String testName) async {
    final rows = _requireDb().select(
      '''
      SELECT tr.*
      FROM test_results tr
      JOIN test_sessions ts ON tr.session_id = ts.id
      WHERE ts.patient_id = ? AND tr.test_name = ?
      ORDER BY tr.created_at DESC
      ''',
      <Object?>[patientId, testName],
    );
    return rows
        .map(
          (row) => TestResult(
            id: row['id'] as String,
            sessionId: row['session_id'] as String,
            testName: row['test_name'] as String,
            rawScore: (row['raw_score'] as num).toDouble(),
            normalizedScore: (row['normalized_score'] as num).toDouble(),
            details:
                jsonDecode(row['details'] as String) as Map<String, dynamic>,
            imagePath: row['image_path'] as String?,
            createdAt: DateTime.parse(row['created_at'] as String),
          ),
        )
        .toList();
  }

  Future<List<TestResult>> getAllResultsForPatient(String patientId) async {
    final rows = _requireDb().select(
      '''
      SELECT tr.*
      FROM test_results tr
      JOIN test_sessions ts ON tr.session_id = ts.id
      WHERE ts.patient_id = ?
      ORDER BY tr.created_at DESC
      ''',
      <Object?>[patientId],
    );
    return rows
        .map(
          (row) => TestResult(
            id: row['id'] as String,
            sessionId: row['session_id'] as String,
            testName: row['test_name'] as String,
            rawScore: (row['raw_score'] as num).toDouble(),
            normalizedScore: (row['normalized_score'] as num).toDouble(),
            details:
                jsonDecode(row['details'] as String) as Map<String, dynamic>,
            imagePath: row['image_path'] as String?,
            createdAt: DateTime.parse(row['created_at'] as String),
          ),
        )
        .toList();
  }

  Future<int> countTodaySessions() async {
    final today = DateTime.now().toUtc();
    final dayStart = DateTime.utc(today.year, today.month, today.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final rows = _requireDb().select(
      '''
      SELECT COUNT(*) AS count
      FROM test_sessions
      WHERE test_date >= ? AND test_date < ?
      ''',
      <Object?>[dayStart.toIso8601String(), dayEnd.toIso8601String()],
    );
    if (rows.isEmpty) return 0;
    return (rows.first['count'] as int?) ?? 0;
  }

  Future<int> countSessionsSince(DateTime fromUtc) async {
    final rows = _requireDb().select(
      'SELECT COUNT(*) AS count FROM test_sessions WHERE test_date >= ?',
      <Object?>[fromUtc.toIso8601String()],
    );
    if (rows.isEmpty) return 0;
    return (rows.first['count'] as int?) ?? 0;
  }

  Future<int> countDistinctPatients() async {
    final rows =
        _requireDb().select('SELECT COUNT(DISTINCT id) AS count FROM patients');
    if (rows.isEmpty) return 0;
    return (rows.first['count'] as int?) ?? 0;
  }

  Future<int> countAllPatients() async {
    final rows = _requireDb().select('SELECT COUNT(*) AS count FROM patients');
    if (rows.isEmpty) return 0;
    return (rows.first['count'] as int?) ?? 0;
  }

  /// Sessions with URGENT/HIGH risk that have no doctor diagnosis yet.
  Future<List<Map<String, dynamic>>> getUrgentUndiagnosedSessions() async {
    final rows = _requireDb().select(
      '''
      SELECT
        ts.id AS session_id,
        p.name AS patient_name,
        p.age AS patient_age,
        ap.risk_level AS risk_level,
        ap.risk_score AS risk_score,
        ts.test_date AS created_at,
        ts.test_date AS test_date
      FROM test_sessions ts
      JOIN patients p ON ts.patient_id = p.id
      JOIN ai_predictions ap ON ap.session_id = ts.id
      LEFT JOIN doctor_diagnoses dd ON dd.session_id = ts.id
      WHERE ap.risk_level IN ('URGENT', 'HIGH')
        AND dd.id IS NULL
      ORDER BY ts.test_date DESC
      LIMIT 20
      ''',
    );
    return rows.map((r) => <String, dynamic>{...r}).toList();
  }

  /// Recent sessions with patient and AI prediction joined.
  Future<List<Map<String, dynamic>>> getRecentSessions({int limit = 10}) async {
    final rows = _requireDb().select(
      '''
      SELECT
        ts.id AS session_id,
        p.id AS patient_id,
        p.name AS patient_name,
        p.age AS patient_age,
        p.phone AS patient_phone,
        ap.risk_level AS risk_level,
        ap.risk_score AS risk_score,
        ts.test_date AS test_date,
        ts.test_date AS created_at,
        ts.pdf_path AS pdf_path,
        dd.diagnosis AS diagnosis
      FROM test_sessions ts
      JOIN patients p ON ts.patient_id = p.id
      LEFT JOIN ai_predictions ap ON ap.session_id = ts.id
      LEFT JOIN doctor_diagnoses dd ON dd.session_id = ts.id
      ORDER BY ts.test_date DESC
      LIMIT ?
      ''',
      <Object?>[limit],
    );
    return rows.map((r) => <String, dynamic>{...r}).toList();
  }

  /// All patients with latest session risk and session count (for doctor patient list).
  Future<List<Map<String, dynamic>>> getAllPatientsWithRisk() async {
    final rows = _requireDb().select(
      '''
      SELECT
        p.id AS id,
        p.name AS name,
        p.age AS age,
        p.phone AS phone,
        p.gender AS gender,
        MAX(ts.test_date) AS last_session_date,
        (SELECT id FROM test_sessions WHERE patient_id = p.id ORDER BY test_date DESC LIMIT 1) AS latest_session_id,
        (SELECT ap.risk_level FROM ai_predictions ap
         JOIN test_sessions ts2 ON ap.session_id = ts2.id
         WHERE ts2.patient_id = p.id
         ORDER BY ts2.test_date DESC LIMIT 1) AS latest_risk,
        COUNT(DISTINCT ts.id) AS session_count,
        (SELECT COUNT(*) FROM test_sessions tsx
         JOIN ai_predictions apx ON apx.session_id = tsx.id
         LEFT JOIN doctor_diagnoses ddx ON ddx.session_id = tsx.id
         WHERE tsx.patient_id = p.id AND apx.risk_level IN ('URGENT','HIGH') AND ddx.id IS NULL) AS pending_diagnoses
      FROM patients p
      LEFT JOIN test_sessions ts ON ts.patient_id = p.id
      GROUP BY p.id
      ORDER BY last_session_date DESC NULLS LAST
      ''',
    );
    return rows.map((r) => <String, dynamic>{...r}).toList();
  }

  /// All sessions for one patient (doctor view) with risk and diagnosis.
  Future<List<Map<String, dynamic>>> getSessionsForPatientDoctor(
      String patientId) async {
    final rows = _requireDb().select(
      '''
      SELECT
        ts.id AS session_id,
        ts.test_date AS created_at,
        ts.pdf_path AS pdf_path,
        ap.risk_level AS risk_level,
        ap.risk_score AS risk_score,
        dd.diagnosis AS diagnosis,
        dd.risk_label AS risk_label
      FROM test_sessions ts
      LEFT JOIN ai_predictions ap ON ap.session_id = ts.id
      LEFT JOIN doctor_diagnoses dd ON dd.session_id = ts.id
      WHERE ts.patient_id = ?
      ORDER BY ts.test_date DESC
      ''',
      <Object?>[patientId],
    );
    return rows.map((r) => <String, dynamic>{...r}).toList();
  }

  Future<int> countUrgentPredictionsToday() async {
    final today = DateTime.now().toUtc();
    final dayStart = DateTime.utc(today.year, today.month, today.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final rows = _requireDb().select(
      '''
      SELECT COUNT(*) AS count
      FROM ai_predictions ap
      JOIN test_sessions ts ON ap.session_id = ts.id
      WHERE ap.risk_level = 'URGENT' AND ts.test_date >= ? AND ts.test_date < ?
      ''',
      <Object?>[dayStart.toIso8601String(), dayEnd.toIso8601String()],
    );
    if (rows.isEmpty) return 0;
    return (rows.first['count'] as int?) ?? 0;
  }

  Future<int> countUnsyncedSessions() async {
    final rows = _requireDb()
        .select('SELECT COUNT(*) AS count FROM test_sessions WHERE synced = 0');
    if (rows.isEmpty) return 0;
    return (rows.first['count'] as int?) ?? 0;
  }

  Future<List<Map<String, Object?>>> recentSessionsToday(
      {int limit = 5}) async {
    final today = DateTime.now().toUtc();
    final dayStart = DateTime.utc(today.year, today.month, today.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final rows = _requireDb().select(
      '''
      SELECT ts.id AS session_id, ts.test_date, ts.completed, ts.synced,
             p.name AS patient_name, p.age AS patient_age, p.gender AS patient_gender,
             ap.risk_score, ap.risk_level
      FROM test_sessions ts
      JOIN patients p ON p.id = ts.patient_id
      LEFT JOIN ai_predictions ap ON ap.session_id = ts.id
      WHERE ts.test_date >= ? AND ts.test_date < ?
      ORDER BY ts.test_date DESC
      LIMIT ?
      ''',
      <Object?>[dayStart.toIso8601String(), dayEnd.toIso8601String(), limit],
    );
    return rows.map((r) => <String, Object?>{...r}).toList();
  }

  Future<List<Patient>> getUnscreenedPatientsToday() async {
    final today = DateTime.now().toUtc();
    final dayStart = DateTime.utc(today.year, today.month, today.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final rows = _requireDb().select(
      '''
      SELECT p.*
      FROM patients p
      WHERE p.id NOT IN (
        SELECT patient_id
        FROM test_sessions
        WHERE test_date >= ? AND test_date < ?
      )
      ORDER BY p.name ASC
      ''',
      <Object?>[dayStart.toIso8601String(), dayEnd.toIso8601String()],
    );
    return rows
        .map(
          (row) => Patient(
            id: row['id'] as String,
            name: row['name'] as String,
            age: row['age'] as int,
            gender: row['gender'] as String,
            phone: row['phone'] as String,
            createdAt: DateTime.parse(row['created_at'] as String),
            synced: (row['synced'] as int) == 1,
          ),
        )
        .toList();
  }

  Future<void> deletePatientData(String patientId) async {
    final db = _requireDb();
    db.execute(
      '''
      DELETE FROM eye_images
      WHERE session_id IN (
        SELECT id FROM test_sessions WHERE patient_id = ?
      )
      ''',
      <Object?>[patientId],
    );
    db.execute(
      '''
      DELETE FROM test_results
      WHERE session_id IN (
        SELECT id FROM test_sessions WHERE patient_id = ?
      )
      ''',
      <Object?>[patientId],
    );
    db.execute(
      '''
      DELETE FROM ai_predictions
      WHERE session_id IN (
        SELECT id FROM test_sessions WHERE patient_id = ?
      )
      ''',
      <Object?>[patientId],
    );
    db.execute(
      'DELETE FROM reports WHERE session_id IN (SELECT id FROM test_sessions WHERE patient_id = ?)',
      <Object?>[patientId],
    );
    db.execute(
      'DELETE FROM test_sessions WHERE patient_id = ?',
      <Object?>[patientId],
    );
    db.execute(
      'DELETE FROM patients WHERE id = ?',
      <Object?>[patientId],
    );
  }

  Future<int> countSessionsForPatient(String patientId) async {
    final rows = _requireDb().select(
      'SELECT COUNT(*) AS count FROM test_sessions WHERE patient_id = ?',
      <Object?>[patientId],
    );
    if (rows.isEmpty) return 0;
    return (rows.first['count'] as int?) ?? 0;
  }

  Future<DateTime?> latestSessionDateForPatient(String patientId) async {
    final rows = _requireDb().select(
      'SELECT test_date FROM test_sessions WHERE patient_id = ? ORDER BY test_date DESC LIMIT 1',
      <Object?>[patientId],
    );
    if (rows.isEmpty) return null;
    return DateTime.tryParse(rows.first['test_date'] as String);
  }

  Future<int> countReportsForPatient(String patientId) async {
    final rows = _requireDb().select(
      '''
      SELECT COUNT(*) AS count
      FROM test_sessions
      WHERE patient_id = ? AND pdf_path IS NOT NULL
      ''',
      <Object?>[patientId],
    );
    if (rows.isEmpty) return 0;
    return (rows.first['count'] as int?) ?? 0;
  }

  Future<TestResult?> latestResultForTest(
      String patientId, String testName) async {
    final rows = _requireDb().select(
      '''
      SELECT tr.*
      FROM test_results tr
      JOIN test_sessions ts ON tr.session_id = ts.id
      WHERE ts.patient_id = ? AND tr.test_name = ?
      ORDER BY tr.created_at DESC
      LIMIT 1
      ''',
      <Object?>[patientId, testName],
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    return TestResult(
      id: row['id'] as String,
      sessionId: row['session_id'] as String,
      testName: row['test_name'] as String,
      rawScore: (row['raw_score'] as num).toDouble(),
      normalizedScore: (row['normalized_score'] as num).toDouble(),
      details: jsonDecode(row['details'] as String) as Map<String, dynamic>,
      imagePath: row['image_path'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  Future<List<TestResult>> recentResultsForTest(
    String patientId,
    String testName, {
    int limit = 2,
  }) async {
    final rows = _requireDb().select(
      '''
      SELECT tr.*
      FROM test_results tr
      JOIN test_sessions ts ON tr.session_id = ts.id
      WHERE ts.patient_id = ? AND tr.test_name = ?
      ORDER BY tr.created_at DESC
      LIMIT ?
      ''',
      <Object?>[patientId, testName, limit],
    );
    return rows
        .map(
          (row) => TestResult(
            id: row['id'] as String,
            sessionId: row['session_id'] as String,
            testName: row['test_name'] as String,
            rawScore: (row['raw_score'] as num).toDouble(),
            normalizedScore: (row['normalized_score'] as num).toDouble(),
            details:
                jsonDecode(row['details'] as String) as Map<String, dynamic>,
            imagePath: row['image_path'] as String?,
            createdAt: DateTime.parse(row['created_at'] as String),
          ),
        )
        .toList();
  }

  Future<AIPrediction?> latestPredictionForPatient(String patientId) async {
    final rows = _requireDb().select(
      '''
      SELECT ap.*
      FROM ai_predictions ap
      JOIN test_sessions ts ON ap.session_id = ts.id
      WHERE ts.patient_id = ?
      ORDER BY ap.created_at DESC
      LIMIT 1
      ''',
      <Object?>[patientId],
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    return AIPrediction(
      id: row['id'] as String,
      sessionId: row['session_id'] as String,
      riskScore: (row['risk_score'] as num).toDouble(),
      riskLevel: row['risk_level'] as String,
      recommendation: row['recommendation'] as String,
      modelVersion: row['model_version'] as String,
      createdAt: DateTime.parse(row['created_at'] as String),
      doctorReviewed: (row['doctor_reviewed'] as int) == 1,
      doctorNotes: row['doctor_notes'] as String?,
    );
  }

  Future<List<Map<String, Object?>>> recentReportsForPatient(String patientId,
      {int limit = 3}) async {
    final rows = _requireDb().select(
      '''
      SELECT ts.id AS session_id, ts.test_date, ts.pdf_path,
             ap.risk_score, ap.risk_level, ap.model_version
      FROM test_sessions ts
      LEFT JOIN ai_predictions ap ON ap.session_id = ts.id
      WHERE ts.patient_id = ? AND ts.pdf_path IS NOT NULL
      ORDER BY ts.test_date DESC
      LIMIT ?
      ''',
      <Object?>[patientId, limit],
    );
    return rows.map((r) => <String, Object?>{...r}).toList();
  }

  Future<List<Map<String, Object?>>> allFullReportsForPatient(
      String patientId) async {
    final rows = _requireDb().select(
      '''
      SELECT ts.id AS session_id, ts.test_date, ts.pdf_path,
             ap.risk_score, ap.risk_level, ap.model_version,
             (SELECT COUNT(*) FROM test_results tr WHERE tr.session_id = ts.id) AS test_count
      FROM test_sessions ts
      LEFT JOIN ai_predictions ap ON ap.session_id = ts.id
      WHERE ts.patient_id = ? AND ts.pdf_path IS NOT NULL
      ORDER BY ts.test_date DESC
      ''',
      <Object?>[patientId],
    );
    return rows.map((r) => <String, Object?>{...r}).toList();
  }

  Future<List<Map<String, Object?>>> allMiniReportsForPatient(
      String patientId) async {
    final rows = _requireDb().select(
      '''
      SELECT tr.id AS test_result_id, tr.test_name, tr.created_at, tr.details, tr.mini_pdf_path
      FROM test_results tr
      JOIN test_sessions ts ON tr.session_id = ts.id
      WHERE ts.patient_id = ? AND tr.mini_pdf_path IS NOT NULL
      ORDER BY tr.created_at DESC
      ''',
      <Object?>[patientId],
    );
    return rows.map((r) => <String, Object?>{...r}).toList();
  }

  Future<List<AIPrediction>> recentPredictionsForPatient(String patientId,
      {int limit = 2}) async {
    final rows = _requireDb().select(
      '''
      SELECT ap.*
      FROM ai_predictions ap
      JOIN test_sessions ts ON ap.session_id = ts.id
      WHERE ts.patient_id = ?
      ORDER BY ap.created_at DESC
      LIMIT ?
      ''',
      <Object?>[patientId, limit],
    );
    return rows
        .map(
          (row) => AIPrediction(
            id: row['id'] as String,
            sessionId: row['session_id'] as String,
            riskScore: (row['risk_score'] as num).toDouble(),
            riskLevel: row['risk_level'] as String,
            recommendation: row['recommendation'] as String,
            modelVersion: row['model_version'] as String,
            createdAt: DateTime.parse(row['created_at'] as String),
            doctorReviewed: (row['doctor_reviewed'] as int) == 1,
            doctorNotes: row['doctor_notes'] as String?,
          ),
        )
        .toList();
  }

  Future<List<String>> pdfPathsForPatient(String patientId) async {
    final paths = <String>[];
    final fullRows = _requireDb().select(
      'SELECT pdf_path FROM test_sessions WHERE patient_id = ? AND pdf_path IS NOT NULL',
      <Object?>[patientId],
    );
    for (final row in fullRows) {
      final p = row['pdf_path'] as String?;
      if (p != null && p.isNotEmpty) paths.add(p);
    }
    final miniRows = _requireDb().select(
      '''
      SELECT tr.mini_pdf_path AS mini_pdf_path
      FROM test_results tr
      JOIN test_sessions ts ON tr.session_id = ts.id
      WHERE ts.patient_id = ? AND tr.mini_pdf_path IS NOT NULL
      ''',
      <Object?>[patientId],
    );
    for (final row in miniRows) {
      final p = row['mini_pdf_path'] as String?;
      if (p != null && p.isNotEmpty) paths.add(p);
    }
    return paths;
  }

  Future<void> deleteFullReport(String sessionId) async {
    final db = _requireDb();
    db.execute(
        'DELETE FROM reports WHERE session_id = ?', <Object?>[sessionId]);
    db.execute('UPDATE test_sessions SET pdf_path = NULL WHERE id = ?',
        <Object?>[sessionId]);
  }

  Future<void> deleteMiniReport(String testResultId) async {
    _requireDb().execute(
        'UPDATE test_results SET mini_pdf_path = NULL WHERE id = ?',
        <Object?>[testResultId]);
  }

  Future<int> getStorageUsageBytes() async {
    final row = _requireDb()
        .select('SELECT COALESCE(SUM(file_size), 0) AS total FROM eye_images')
        .first;
    return row['total'] as int;
  }

  Future<void> pruneUploadedImages() async {
    final rows =
        _requireDb().select('SELECT * FROM eye_images WHERE uploaded = 1');
    for (final row in rows) {
      final file = File(row['file_path'] as String);
      if (file.existsSync()) {
        file.deleteSync();
      }
    }
  }

  Database _requireDb() {
    final db = _db;
    if (!_initialized || db == null) {
      throw StateError('LocalDatabase not initialized');
    }
    return db;
  }

  Future<String> _deviceScopedValue(String name) async {
    final storageKey = 'ambyoai_$name';
    final existing = await _storage.read(key: storageKey);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }
    final value = _uuid.v4();
    await _storage.write(key: storageKey, value: value);
    return value;
  }

  Future<void> _trimSessionHistory() async {
    final db = _requireDb();
    final oldRows = db.select(
      'SELECT id FROM test_sessions ORDER BY test_date DESC LIMIT -1 OFFSET 100',
    );
    for (final row in oldRows) {
      db.execute(
          'DELETE FROM test_sessions WHERE id = ?', <Object?>[row['id']]);
    }
  }
}
