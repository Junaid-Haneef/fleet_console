import 'dart:io';

import 'package:dart_duckdb/dart_duckdb.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

typedef DatabasePathResolver = Future<String> Function();
typedef DuckDbOpen = Future<dynamic> Function(String path);
typedef DuckDbConnect = Future<dynamic> Function(dynamic database);

class AppDatabase {
  AppDatabase({
    DatabasePathResolver? databasePathResolver,
    DuckDbOpen? duckDbOpen,
    DuckDbConnect? duckDbConnect,
  }) : _databasePathResolver =
           databasePathResolver ?? _defaultDatabasePathResolver,
      _duckDbOpen = duckDbOpen ?? duckdb.open,
      _duckDbConnect = duckDbConnect ?? ((db) => duckdb.connect(db as Database));

  final DatabasePathResolver _databasePathResolver;
  final DuckDbOpen _duckDbOpen;
  final DuckDbConnect _duckDbConnect;

  dynamic _database;
  dynamic _connection;
  bool _initialized = false;
  String? _databasePath;

  bool get isInitialized => _initialized;

  String? get databasePath => _databasePath;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    final dbPath = await _databasePathResolver();
    final db = await _duckDbOpen(dbPath);
    final conn = await _duckDbConnect(db);

    await _runBootstrap(conn);

    _databasePath = dbPath;
    _database = db;
    _connection = conn;
    _initialized = true;
  }

  Future<void> close() async {
    final conn = _connection;
    final db = _database;

    _connection = null;
    _database = null;
    _initialized = false;

    if (conn != null) {
      await conn.dispose();
    }
    if (db != null) {
      await db.dispose();
    }
  }

  Future<void> execute(String sql) async {
    final conn = _requireConnection();
    await conn.execute(sql);
  }

  Future<List<List<Object?>>> query(String sql) async {
    final conn = _requireConnection();
    final result = await conn.query(sql);
    return List<List<Object?>>.from(
      result.fetchAll().map(
        (row) => List<Object?>.from(row as List<dynamic>),
      ),
    );
  }

  Future<bool> healthCheck() async {
    final rows = await query('SELECT 1 AS ok');
    return rows.isNotEmpty && rows.first.isNotEmpty && rows.first.first == 1;
  }

  dynamic _requireConnection() {
    if (!_initialized || _connection == null) {
      throw StateError('AppDatabase is not initialized.');
    }
    return _connection;
  }

  Future<void> _runBootstrap(dynamic conn) async {
    await conn.execute('''
      CREATE TABLE IF NOT EXISTS app_meta (
        key VARCHAR PRIMARY KEY,
        value VARCHAR NOT NULL,
        updated_at TIMESTAMP NOT NULL DEFAULT now()
      )
    ''');

    await conn.execute('''
      INSERT INTO app_meta (key, value)
      VALUES ('schema_version', 'phase1')
      ON CONFLICT (key) DO UPDATE
      SET value = EXCLUDED.value, updated_at = now()
    ''');
  }

  static Future<String> _defaultDatabasePathResolver() async {
    final supportDir = await getApplicationSupportDirectory();
    final fleetDir = Directory(p.join(supportDir.path, 'fleet_console'));
    if (!fleetDir.existsSync()) {
      fleetDir.createSync(recursive: true);
    }
    return p.join(fleetDir.path, 'fleet_console.duckdb');
  }
}