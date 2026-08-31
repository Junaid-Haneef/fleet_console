import 'dart:io';

import 'package:dart_duckdb/dart_duckdb.dart';

import 'database_path.dart';
import 'database_schema.dart';
import 'database_seed.dart';
import 'database_types.dart';

export 'database_types.dart';

/// Owns the DuckDB lifecycle (open, bootstrap, close) and exposes the query
/// API the repositories use. Schema DDL lives in database_schema.dart /
/// schema/, seed data in database_seed.dart.
class AppDatabase {
  AppDatabase({
    DatabasePathResolver? databasePathResolver,
    DuckDbOpen? duckDbOpen,
    DuckDbConnect? duckDbConnect,
  }) : _databasePathResolver =
           databasePathResolver ?? resolveDefaultDatabasePath,
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
    final db = await _openDatabaseWithRecovery(dbPath);
    final conn = await _duckDbConnect(db);

    final schemaCurrent = await _isSchemaVersionCurrent(conn);
    if (!schemaCurrent) {
      await applyDatabaseSchema(conn);
      await seedDefaultGeofences(conn);
      await stampSchemaVersion(conn);
    }

    _databasePath = dbPath;
    _database = db;
    _connection = conn;
    _initialized = true;
  }

  Future<bool> _isSchemaVersionCurrent(dynamic conn) async {
    try {
      final result = await conn.query('''
        SELECT value
        FROM app_meta
        WHERE key = 'schema_version'
        LIMIT 1
      ''');
      final rows = result.fetchAll();
      if (rows.isEmpty || rows.first.isEmpty) {
        return false;
      }

      final value = rows.first.first;
      return value?.toString() == schemaVersion;
    } catch (_) {
      // If metadata tables do not exist yet, run full bootstrap.
      return false;
    }
  }

  Future<dynamic> _openDatabaseWithRecovery(String dbPath) async {
    try {
      return await _duckDbOpen(dbPath);
    } on DuckDBException catch (error) {
      if (!_isWalAutoloadHomeDirectoryFailure(error.toString())) {
        rethrow;
      }

      await _deleteWalIfPresent(dbPath);
      return _duckDbOpen(dbPath);
    }
  }

  bool _isWalAutoloadHomeDirectoryFailure(String message) {
    final normalized = message.toLowerCase();
    return normalized.contains('extension autoloading error') &&
        normalized.contains('home directory');
  }

  Future<void> _deleteWalIfPresent(String dbPath) async {
    final walFile = File('$dbPath.wal');
    if (await walFile.exists()) {
      await walFile.delete();
    }
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
      await conn.execute('DELETE FROM trips');
      await conn.execute('DELETE FROM geofence_transitions');
      await conn.execute('DELETE FROM vehicle_geofence_state');
      await conn.execute('DELETE FROM geofence_versions');
      await conn.execute('DELETE FROM geofences');
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

  /// Resets operational data for replay/benchmark runs and reseeds baseline
  /// geofences so transition and trip features remain usable immediately.
  Future<void> resetOperationalData() async {
    final conn = _requireConnection();
    await clearAllTablesData();
    await seedDefaultGeofences(conn);
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
}
