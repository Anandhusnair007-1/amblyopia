import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';
import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

class SQLCipherSetup {
  static const _keyStorageKey = 'ambyoai_db_encryption_key';

  static DatabaseConnection? _connection;
  static bool _isOpening = false;
  static Completer<DatabaseConnection>? _openCompleter;

  static Future<DatabaseConnection> openEncryptedDatabase() async {
    if (_connection != null) {
      return _connection!;
    }
    if (_isOpening && _openCompleter != null) {
      return _openCompleter!.future;
    }

    _isOpening = true;
    _openCompleter = Completer<DatabaseConnection>();

    try {
      final connection = await _doOpen();
      _connection = connection;
      _openCompleter!.complete(connection);
      return connection;
    } catch (e) {
      _isOpening = false;
      _openCompleter!.completeError(e);
      rethrow;
    }
  }

  static Future<DatabaseConnection> _doOpen() async {
    const storage = FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
    );

    String? key = await storage.read(key: _keyStorageKey);
    if (key == null) {
      final random = Random.secure();
      final bytes = List<int>.generate(32, (_) => random.nextInt(256));
      key = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      await storage.write(key: _keyStorageKey, value: key);
      debugPrint('New DB key generated');
    }

    open.overrideFor(OperatingSystem.android, openCipherOnAndroid);

    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'ambyoai_encrypted.db'));
    debugPrint('Opening DB at: ${file.path}');

    final dbKey = key;

    return DatabaseConnection(
      NativeDatabase.createInBackground(
        file,
        setup: (db) {
          db.execute("PRAGMA key = '$dbKey'");
          db.execute('PRAGMA cipher_page_size = 4096');
          db.execute('PRAGMA kdf_iter = 256000');
          db.execute('PRAGMA cipher_hmac_algorithm = HMAC_SHA512');
          db.execute('PRAGMA foreign_keys = ON;');
        },
        logStatements: false,
      ),
    );
  }

  static sqlite.Database? _sqliteDb;
  static bool _isOpeningSqlite = false;
  static Completer<sqlite.Database>? _openSqliteCompleter;

  static Future<sqlite.Database> openEncryptedSqliteDatabase() async {
    if (_sqliteDb != null) {
      return _sqliteDb!;
    }
    if (_isOpeningSqlite && _openSqliteCompleter != null) {
      return _openSqliteCompleter!.future;
    }

    _isOpeningSqlite = true;
    _openSqliteCompleter = Completer<sqlite.Database>();

    try {
      final key = await _readOrCreateKey();
      open.overrideFor(OperatingSystem.android, openCipherOnAndroid);

      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File(p.join(dbFolder.path, 'ambyoai_encrypted.db'));
      if (!file.existsSync()) {
        file.createSync(recursive: true);
      }

      final db = sqlite.sqlite3.open(file.path);
      db.execute("PRAGMA key = '$key';");
      db.execute('PRAGMA foreign_keys = ON;');
      _sqliteDb = db;
      _openSqliteCompleter!.complete(db);
      return db;
    } catch (e) {
      _isOpeningSqlite = false;
      _openSqliteCompleter!.completeError(e);
      rethrow;
    }
  }

  static Future<String> _readOrCreateKey() async {
    const storage = FlutterSecureStorage();
    final existing = await storage.read(key: _keyStorageKey);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final key = _generateSecureKey();
    await storage.write(key: _keyStorageKey, value: key);
    return key;
  }

  static String _generateSecureKey() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
