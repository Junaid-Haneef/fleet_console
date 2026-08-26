import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:fleet_console/src/core/database/app_database.dart';

class _FakeDatabase {
  bool disposed = false;

  Future<void> dispose() async {
    disposed = true;
  }
}

class _FakeQueryResult {
  _FakeQueryResult(this.rows);

  final List<List<Object?>> rows;

  List<List<Object?>> fetchAll() => rows;
}

class _FakeConnection {
  bool disposed = false;
  final Map<String, String> appMeta = {};
  final List<String> executedSql = [];
  final List<String> queriedSql = [];

  Future<void> execute(String sql) async {
    executedSql.add(sql);
    if (sql.contains('INSERT INTO app_meta') && sql.contains("'schema_version'")) {
      if (sql.contains("'phase6'")) {
        appMeta['schema_version'] = 'phase6';
      } else {
        appMeta['schema_version'] = 'phase1';
      }
    }
  }

  Future<_FakeQueryResult> query(String sql) async {
    queriedSql.add(sql);

    if (sql.contains('SELECT 1 AS ok')) {
      return _FakeQueryResult([
        [1],
      ]);
    }

    if (sql.contains('SELECT * FROM vehicles LIMIT')) {
      return _FakeQueryResult([
        ['VH-001', 'KA-01-AB-1200', 'E-Truck X1'],
      ]);
    }

    if (sql.contains("SELECT value FROM app_meta WHERE key = 'schema_version'")) {
      final value = appMeta['schema_version'];
      if (value == null) {
        return _FakeQueryResult([]);
      }
      return _FakeQueryResult([
        [value],
      ]);
    }

    if (sql.contains('SELECT * FROM duckdb_indexes() ORDER BY table_name, index_name')) {
      return _FakeQueryResult([
        [
          'main',
          'fleet_console',
          'idx_geofence_transitions_vehicle_event_time',
          'geofence_transitions',
          'CREATE INDEX idx_geofence_transitions_vehicle_event_time ON geofence_transitions(vehicle_id, event_time DESC)',
        ],
        [
          'main',
          'fleet_console',
          'idx_geofence_versions_active_effective',
          'geofence_versions',
          'CREATE INDEX idx_geofence_versions_active_effective ON geofence_versions(is_active, effective_from DESC)',
        ],
        [
          'main',
          'fleet_console',
          'idx_geofence_versions_geofence_effective',
          'geofence_versions',
          'CREATE INDEX idx_geofence_versions_geofence_effective ON geofence_versions(geofence_id, effective_from DESC)',
        ],
        [
          'main',
          'fleet_console',
          'idx_location_readings_latest',
          'location_readings',
          'CREATE INDEX idx_location_readings_latest ON location_readings(vehicle_id, event_time DESC)',
        ],
        [
          'main',
          'fleet_console',
          'idx_signal_readings_latest',
          'signal_readings',
          'CREATE INDEX idx_signal_readings_latest ON signal_readings(vehicle_id, signal_name, event_time DESC)',
        ],
        [
          'main',
          'fleet_console',
          'idx_vehicle_geofence_state_current',
          'vehicle_geofence_state',
          'CREATE INDEX idx_vehicle_geofence_state_current ON vehicle_geofence_state(current_geofence_id, source_event_time DESC)',
        ],
      ]);
    }

    if (sql.contains("SELECT * FROM duckdb_indexes() WHERE table_name = 'signal_readings'")) {
      return _FakeQueryResult([
        [
          'main',
          'fleet_console',
          'idx_signal_readings_latest',
          'signal_readings',
          'CREATE INDEX idx_signal_readings_latest ON signal_readings(vehicle_id, signal_name, event_time DESC)',
        ],
      ]);
    }

    if (sql.contains("SELECT 1 FROM duckdb_indexes() WHERE index_name = 'idx_signal_readings_latest'")) {
      return _FakeQueryResult([
        [1],
      ]);
    }

    if (sql.contains("SELECT 1 FROM duckdb_indexes() WHERE index_name = 'idx_missing'")) {
      return _FakeQueryResult([]);
    }

    return _FakeQueryResult([]);
  }

  Future<void> dispose() async {
    disposed = true;
  }
}

void main() {
  group('AppDatabase Phase 5 smoke tests', () {
    late Directory tempDir;
    late String dbPath;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('fleet_console_phase2_');
      dbPath = p.join(tempDir.path, 'phase2_test.duckdb');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('initialize opens DB and health check succeeds', () async {
      final fakeDb = _FakeDatabase();
      final fakeConn = _FakeConnection();

      final injectedDatabase = AppDatabase(
        databasePathResolver: () async => dbPath,
        duckDbOpen: (_) async => fakeDb,
        duckDbConnect: (_) async => fakeConn,
      );

      await injectedDatabase.initialize();

      expect(injectedDatabase.isInitialized, isTrue);
      expect(injectedDatabase.databasePath, dbPath);
      expect(await injectedDatabase.healthCheck(), isTrue);

      await injectedDatabase.close();
      expect(fakeConn.disposed, isTrue);
      expect(fakeDb.disposed, isTrue);
    });

    test('initialize is idempotent', () async {
      final fakeConn = _FakeConnection();
      var openCalls = 0;
      var connectCalls = 0;

      final database = AppDatabase(
        databasePathResolver: () async => dbPath,
        duckDbOpen: (_) async {
          openCalls += 1;
          return _FakeDatabase();
        },
        duckDbConnect: (_) async {
          connectCalls += 1;
          return fakeConn;
        },
      );

      await database.initialize();
      await database.initialize();

      final rows = await database.query(
        "SELECT value FROM app_meta WHERE key = 'schema_version'",
      );

      expect(rows.length, 1);
      expect(rows.first.first, 'phase6');
      expect(openCalls, 1);
      expect(connectCalls, 1);

      await database.close();
    });

    test('bootstrap creates phase6 geofence, telemetry, and alert tables', () async {
      final fakeDb = _FakeDatabase();
      final fakeConn = _FakeConnection();

      final database = AppDatabase(
        databasePathResolver: () async => dbPath,
        duckDbOpen: (_) async => fakeDb,
        duckDbConnect: (_) async => fakeConn,
      );

      await database.initialize();

      expect(
        fakeConn.executedSql.any(
          (sql) => sql.contains('CREATE TABLE IF NOT EXISTS geofences'),
        ),
        isTrue,
      );
      expect(
        fakeConn.executedSql.any(
          (sql) => sql.contains('CREATE TABLE IF NOT EXISTS geofence_versions'),
        ),
        isTrue,
      );
      expect(
        fakeConn.executedSql.any(
          (sql) => sql.contains('CREATE TABLE IF NOT EXISTS geofence_transitions'),
        ),
        isTrue,
      );
      expect(
        fakeConn.executedSql.any(
          (sql) => sql.contains('CREATE TABLE IF NOT EXISTS vehicle_geofence_state'),
        ),
        isTrue,
      );
      expect(
        fakeConn.executedSql.any(
          (sql) => sql.contains('CREATE TABLE IF NOT EXISTS vehicles'),
        ),
        isTrue,
      );
      expect(
        fakeConn.executedSql.any(
          (sql) => sql.contains('CREATE TABLE IF NOT EXISTS signal_readings'),
        ),
        isTrue,
      );
      expect(
        fakeConn.executedSql.any(
          (sql) => sql.contains('CREATE TABLE IF NOT EXISTS location_readings'),
        ),
        isTrue,
      );
      expect(
        fakeConn.executedSql.any(
          (sql) => sql.contains('CREATE TABLE IF NOT EXISTS active_alerts'),
        ),
        isTrue,
      );
      expect(
        fakeConn.executedSql.any(
          (sql) => sql.contains('CREATE TABLE IF NOT EXISTS alert_events'),
        ),
        isTrue,
      );
      expect(
        fakeConn.executedSql.any(
          (sql) => sql.contains('CREATE TABLE IF NOT EXISTS dismissal_undo_windows'),
        ),
        isTrue,
      );

      await database.close();
    });

    test('bootstrap seeds default geofences idempotently', () async {
      final fakeDb = _FakeDatabase();
      final fakeConn = _FakeConnection();

      final database = AppDatabase(
        databasePathResolver: () async => dbPath,
        duckDbOpen: (_) async => fakeDb,
        duckDbConnect: (_) async => fakeConn,
      );

      await database.initialize();

      final geofenceSeedStatements = fakeConn.executedSql
          .where((sql) => sql.contains('INSERT INTO geofences'));
      final versionSeedStatements = fakeConn.executedSql
          .where((sql) => sql.contains('INSERT INTO geofence_versions'));

      expect(geofenceSeedStatements.length, 1);
      expect(versionSeedStatements.length, 1);
      expect(geofenceSeedStatements.single, contains('gf_depot_north'));
      expect(geofenceSeedStatements.single, contains('gf_charging_hub'));
      expect(geofenceSeedStatements.single, contains('gf_service_yard'));
      expect(versionSeedStatements.single, contains('ON CONFLICT (geofence_version_id) DO NOTHING'));

      await database.initialize();

      final repeatedGeofenceSeedStatements = fakeConn.executedSql
          .where((sql) => sql.contains('INSERT INTO geofences'));

      expect(repeatedGeofenceSeedStatements.length, 1);

      await database.close();
    });

    test('fetchTableRows returns rows from requested table', () async {
      final fakeDb = _FakeDatabase();
      final fakeConn = _FakeConnection();

      final database = AppDatabase(
        databasePathResolver: () async => dbPath,
        duckDbOpen: (_) async => fakeDb,
        duckDbConnect: (_) async => fakeConn,
      );

      await database.initialize();
      final rows = await database.fetchTableRows('vehicles', limit: 1);

      expect(rows.length, 1);
      expect(rows.first.first, 'VH-001');
      expect(
        fakeConn.queriedSql.last,
        'SELECT * FROM vehicles LIMIT 1',
      );

      await database.close();
    });

    test('fetchTableRows rejects unsafe table name', () async {
      final fakeDb = _FakeDatabase();
      final fakeConn = _FakeConnection();

      final database = AppDatabase(
        databasePathResolver: () async => dbPath,
        duckDbOpen: (_) async => fakeDb,
        duckDbConnect: (_) async => fakeConn,
      );

      await database.initialize();

      expect(
        () => database.fetchTableRows('vehicles; DROP TABLE vehicles'),
        throwsArgumentError,
      );

      await database.close();
    });

    test('fetchIndexes returns index metadata', () async {
      final fakeDb = _FakeDatabase();
      final fakeConn = _FakeConnection();

      final database = AppDatabase(
        databasePathResolver: () async => dbPath,
        duckDbOpen: (_) async => fakeDb,
        duckDbConnect: (_) async => fakeConn,
      );

      await database.initialize();

      final allIndexes = await database.fetchIndexes();
      expect(allIndexes.length, 6);

      final signalIndexes = await database.fetchIndexes(tableName: 'signal_readings');
      expect(signalIndexes.length, 1);
      expect(signalIndexes.first[2], 'idx_signal_readings_latest');

      await database.close();
    });

    test('indexExists reports whether an index is present', () async {
      final fakeDb = _FakeDatabase();
      final fakeConn = _FakeConnection();

      final database = AppDatabase(
        databasePathResolver: () async => dbPath,
        duckDbOpen: (_) async => fakeDb,
        duckDbConnect: (_) async => fakeConn,
      );

      await database.initialize();

      expect(await database.indexExists('idx_signal_readings_latest'), isTrue);
      expect(await database.indexExists('idx_missing'), isFalse);

      await database.close();
    });

    test('clearAllTablesData clears telemetry and vehicles in transaction', () async {
      final fakeDb = _FakeDatabase();
      final fakeConn = _FakeConnection();

      final database = AppDatabase(
        databasePathResolver: () async => dbPath,
        duckDbOpen: (_) async => fakeDb,
        duckDbConnect: (_) async => fakeConn,
      );

      await database.initialize();
      fakeConn.executedSql.clear();

      await database.clearAllTablesData();

      expect(fakeConn.executedSql.first, 'BEGIN TRANSACTION');
      expect(fakeConn.executedSql, contains('DELETE FROM geofence_transitions'));
      expect(fakeConn.executedSql, contains('DELETE FROM vehicle_geofence_state'));
      expect(fakeConn.executedSql, contains('DELETE FROM geofence_versions'));
      expect(fakeConn.executedSql, contains('DELETE FROM geofences'));
      expect(fakeConn.executedSql, contains('DELETE FROM alert_events'));
      expect(fakeConn.executedSql, contains('DELETE FROM dismissal_undo_windows'));
      expect(fakeConn.executedSql, contains('DELETE FROM active_alerts'));
      expect(fakeConn.executedSql, contains('DELETE FROM signal_readings'));
      expect(fakeConn.executedSql, contains('DELETE FROM location_readings'));
      expect(fakeConn.executedSql, contains('DELETE FROM vehicles'));
      expect(fakeConn.executedSql, isNot(contains('DELETE FROM app_meta')));
      expect(fakeConn.executedSql.last, 'COMMIT');

      await database.close();
    });

    test('clearAllTablesData can include app_meta rows', () async {
      final fakeDb = _FakeDatabase();
      final fakeConn = _FakeConnection();

      final database = AppDatabase(
        databasePathResolver: () async => dbPath,
        duckDbOpen: (_) async => fakeDb,
        duckDbConnect: (_) async => fakeConn,
      );

      await database.initialize();
      fakeConn.executedSql.clear();

      await database.clearAllTablesData(includeAppMeta: true);

      expect(fakeConn.executedSql, contains('DELETE FROM app_meta'));

      await database.close();
    });
  });
}