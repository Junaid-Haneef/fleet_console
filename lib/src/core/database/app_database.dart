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

  Future<List<List<Object?>>> fetchTableRows(
    String tableName, {
    int limit = 100,
  }) async {
    final safeTableName = _sanitizeIdentifier(tableName);
    if (limit < 1) {
      throw ArgumentError.value(limit, 'limit', 'Must be at least 1.');
    }

    return query('SELECT * FROM $safeTableName LIMIT $limit');
  }

  Future<List<List<Object?>>> fetchIndexes({
    String? tableName,
  }) async {
    if (tableName == null) {
      return query('SELECT * FROM duckdb_indexes() ORDER BY table_name, index_name');
    }

    final safeTableName = _sanitizeIdentifier(tableName);
    return query(
      "SELECT * FROM duckdb_indexes() WHERE table_name = '$safeTableName' ORDER BY index_name",
    );
  }

  Future<bool> indexExists(String indexName) async {
    final safeIndexName = _sanitizeIdentifier(indexName);
    final rows = await query(
      "SELECT 1 FROM duckdb_indexes() WHERE index_name = '$safeIndexName' LIMIT 1",
    );
    return rows.isNotEmpty;
  }

  Future<bool> healthCheck() async {
    final rows = await query('SELECT 1 AS ok');
    return rows.isNotEmpty && rows.first.isNotEmpty && rows.first.first == 1;
  }

  Future<void> clearAllTablesData({bool includeAppMeta = false}) async {
    final conn = _requireConnection();

    await conn.execute('BEGIN TRANSACTION');
    try {
      await conn.execute('DELETE FROM alert_events');
      await conn.execute('DELETE FROM dismissal_undo_windows');
      await conn.execute('DELETE FROM active_alerts');
      await conn.execute('DELETE FROM signal_readings');
      await conn.execute('DELETE FROM location_readings');
      await conn.execute('DELETE FROM vehicles');

      if (includeAppMeta) {
        await conn.execute('DELETE FROM app_meta');
      }

      await conn.execute('COMMIT');
    } catch (_) {
      await conn.execute('ROLLBACK');
      rethrow;
    }
  }

  dynamic _requireConnection() {
    if (!_initialized || _connection == null) {
      throw StateError('AppDatabase is not initialized.');
    }
    return _connection;
  }

  String _sanitizeIdentifier(String identifier) {
    final normalized = identifier.trim();
    final isValid = RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(normalized);
    if (!isValid) {
      throw ArgumentError.value(
        identifier,
        'tableName',
        'Only letters, numbers, and underscore are allowed.',
      );
    }
    return normalized;
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
      CREATE TABLE IF NOT EXISTS vehicles (
        vehicle_id VARCHAR PRIMARY KEY,
        reg_number VARCHAR NOT NULL,
        model VARCHAR NOT NULL,
        created_at TIMESTAMP NOT NULL DEFAULT now()
      )
    ''');

    await conn.execute('''
      CREATE TABLE IF NOT EXISTS signal_readings (
        vehicle_id VARCHAR NOT NULL,
        event_time TIMESTAMP NOT NULL,
        signal_name VARCHAR NOT NULL,
        value DOUBLE NOT NULL,
        packet_id VARCHAR,
        received_time TIMESTAMP NOT NULL,
        PRIMARY KEY (vehicle_id, event_time, signal_name)
      )
    ''');

    await conn.execute('''
      CREATE INDEX IF NOT EXISTS idx_signal_readings_latest
      ON signal_readings (vehicle_id, signal_name, event_time DESC)
    ''');

    await conn.execute('''
      CREATE TABLE IF NOT EXISTS location_readings (
        vehicle_id VARCHAR NOT NULL,
        event_time TIMESTAMP NOT NULL,
        lat DOUBLE NOT NULL,
        lon DOUBLE NOT NULL,
        accuracy_m DOUBLE NOT NULL,
        packet_id VARCHAR,
        received_time TIMESTAMP NOT NULL,
        PRIMARY KEY (vehicle_id, event_time)
      )
    ''');

    await conn.execute('''
      CREATE INDEX IF NOT EXISTS idx_location_readings_latest
      ON location_readings (vehicle_id, event_time DESC)
    ''');

    await conn.execute('''
      CREATE TABLE IF NOT EXISTS active_alerts (
        vehicle_id VARCHAR NOT NULL,
        alert_type VARCHAR NOT NULL,
        severity VARCHAR NOT NULL,
        source_event_time TIMESTAMP NOT NULL,
        active_since TIMESTAMP NOT NULL,
        updated_at TIMESTAMP NOT NULL,
        PRIMARY KEY (vehicle_id, alert_type)
      )
    ''');

    await conn.execute('''
      CREATE INDEX IF NOT EXISTS idx_active_alerts_severity_updated
      ON active_alerts (severity, updated_at DESC)
    ''');

    await conn.execute('''
      CREATE TABLE IF NOT EXISTS alert_events (
        event_id VARCHAR PRIMARY KEY,
        vehicle_id VARCHAR NOT NULL,
        alert_type VARCHAR NOT NULL,
        transition VARCHAR NOT NULL,
        severity_before VARCHAR,
        severity_after VARCHAR,
        source_event_time TIMESTAMP,
        event_time TIMESTAMP NOT NULL,
        reason VARCHAR
      )
    ''');

    await conn.execute('''
      CREATE INDEX IF NOT EXISTS idx_alert_events_lookup
      ON alert_events (vehicle_id, alert_type, event_time DESC)
    ''');

    await conn.execute('''
      CREATE TABLE IF NOT EXISTS dismissal_undo_windows (
        vehicle_id VARCHAR NOT NULL,
        alert_type VARCHAR NOT NULL,
        reason VARCHAR NOT NULL,
        dismissed_severity VARCHAR NOT NULL,
        dismissed_source_event_time TIMESTAMP NOT NULL,
        dismissed_at TIMESTAMP NOT NULL,
        expires_at TIMESTAMP NOT NULL,
        PRIMARY KEY (vehicle_id, alert_type)
      )
    ''');

    await conn.execute('''
      ALTER TABLE dismissal_undo_windows
      ADD COLUMN IF NOT EXISTS dismissed_severity VARCHAR
    ''');

    await conn.execute('''
      ALTER TABLE dismissal_undo_windows
      ADD COLUMN IF NOT EXISTS dismissed_source_event_time TIMESTAMP
    ''');

    await conn.execute('''
      CREATE INDEX IF NOT EXISTS idx_dismissal_undo_windows_expires
      ON dismissal_undo_windows (expires_at)
    ''');

    await conn.execute('''
      INSERT INTO app_meta (key, value)
      VALUES ('schema_version', 'phase5')
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