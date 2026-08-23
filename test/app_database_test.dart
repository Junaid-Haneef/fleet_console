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

  Future<void> execute(String sql) async {
    if (sql.contains('INSERT INTO app_meta') && sql.contains("'schema_version'")) {
      appMeta['schema_version'] = 'phase1';
    }
  }

  Future<_FakeQueryResult> query(String sql) async {
    if (sql.contains('SELECT 1 AS ok')) {
      return _FakeQueryResult([
        [1],
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

    return _FakeQueryResult([]);
  }

  Future<void> dispose() async {
    disposed = true;
  }
}

void main() {
  group('AppDatabase Phase 1 smoke tests', () {
    late Directory tempDir;
    late String dbPath;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('fleet_console_phase1_');
      dbPath = p.join(tempDir.path, 'phase1_test.duckdb');
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
      expect(rows.first.first, 'phase1');
      expect(openCalls, 1);
      expect(connectCalls, 1);

      await database.close();
    });
  });
}