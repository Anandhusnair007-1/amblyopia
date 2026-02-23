import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';

class DatabaseService {
  static Database? _db;

  static Future<Database> get db async {
    _db ??= await _init();
    return _db!;
  }

  static Future<Database> _init() async {
    final dbPath = await getDatabasesPath();
    return openDatabase(
      join(dbPath, 'amblyopia.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE auth_cache (
            id INTEGER PRIMARY KEY,
            token TEXT,
            nurse_id TEXT,
            nurse_name TEXT,
            saved_at TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE local_sessions (
            id TEXT PRIMARY KEY,
            patient_id TEXT,
            village_id TEXT,
            age_group TEXT,
            started_at TEXT,
            completed_at TEXT,
            synced INTEGER DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE local_results (
            id TEXT PRIMARY KEY,
            session_id TEXT,
            type TEXT,
            data TEXT,
            created_at TEXT,
            synced INTEGER DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE sync_queue (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            api_path TEXT,
            payload TEXT,
            created_at TEXT,
            retry_count INTEGER DEFAULT 0,
            synced INTEGER DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE cached_villages (
            id TEXT PRIMARY KEY,
            name TEXT,
            district TEXT,
            status TEXT,
            last_screened TEXT,
            cached_at TEXT
          )
        ''');
      },
    );
  }

  // ── Auth ─────────────────────────────────────────────────────────
  static Future<void> saveToken(String token, String nurseId, String nurseName) async {
    final d = await db;
    await d.delete('auth_cache');
    await d.insert('auth_cache', {
      'token': token,
      'nurse_id': nurseId,
      'nurse_name': nurseName,
      'saved_at': DateTime.now().toIso8601String(),
    });
  }

  static Future<Map<String, dynamic>?> getToken() async {
    final d = await db;
    final rows = await d.query('auth_cache', limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  static Future<void> clearToken() async {
    final d = await db;
    await d.delete('auth_cache');
  }

  // ── Sessions ──────────────────────────────────────────────────────
  static Future<void> saveSession(Map<String, dynamic> session) async {
    final d = await db;
    await d.insert('local_sessions', session,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<List<Map<String, dynamic>>> getUnsyncedSessions() async {
    final d = await db;
    return d.query('local_sessions', where: 'synced = ?', whereArgs: [0]);
  }

  static Future<List<Map<String, dynamic>>> getRecentSessions({int limit = 5}) async {
    final d = await db;
    return d.query('local_sessions', orderBy: 'started_at DESC', limit: limit);
  }

  // ── Results ───────────────────────────────────────────────────────
  static Future<void> saveResult(
      String sessionId, String type, Map<String, dynamic> data) async {
    final d = await db;
    await d.insert(
      'local_results',
      {
        'id': '${sessionId}_$type',
        'session_id': sessionId,
        'type': type,
        'data': jsonEncode(data),
        'created_at': DateTime.now().toIso8601String(),
        'synced': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ── Sync Queue ────────────────────────────────────────────────────
  static Future<void> saveToSyncQueue({
    required String path,
    required Map<String, dynamic> payload,
  }) async {
    final d = await db;
    await d.insert('sync_queue', {
      'api_path': path,
      'payload': jsonEncode(payload),
      'created_at': DateTime.now().toIso8601String(),
      'retry_count': 0,
      'synced': 0,
    });
  }

  static Future<List<Map<String, dynamic>>> getPendingSync() async {
    final d = await db;
    return d.query('sync_queue',
        where: 'synced = ?', whereArgs: [0], orderBy: 'created_at ASC');
  }

  static Future<int> getPendingCount() async {
    final d = await db;
    final result = await d.rawQuery(
        'SELECT COUNT(*) as count FROM sync_queue WHERE synced = 0');
    return (result.first['count'] as int?) ?? 0;
  }

  static Future<void> markSynced(int id) async {
    final d = await db;
    await d.update('sync_queue', {'synced': 1}, where: 'id = ?', whereArgs: [id]);
  }

  // ── Villages ──────────────────────────────────────────────────────
  static Future<void> cacheVillages(List<Map<String, dynamic>> villages) async {
    final d = await db;
    final batch = d.batch();
    for (final v in villages) {
      batch.insert(
        'cached_villages',
        {...v, 'cached_at': DateTime.now().toIso8601String()},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit();
  }

  static Future<List<Map<String, dynamic>>> getCachedVillages() async {
    final d = await db;
    return d.query('cached_villages');
  }
}
