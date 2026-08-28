import 'package:flutter_test/flutter_test.dart';

import 'package:fleet_console/src/core/database/app_database.dart';
import 'package:fleet_console/src/features/trips/data/trips_repository.dart';

class _FakeDatabase {
  Future<void> dispose() async {}
}

class _FakeQueryResult {
  _FakeQueryResult(this.rows);

  final List<List<Object?>> rows;

  List<List<Object?>> fetchAll() => rows;
}

class _ScriptedConnection {
  _ScriptedConnection(this.transitionRows);

  final List<List<Object?>> transitionRows;
  final List<String> executedSql = [];

  Future<void> execute(String sql) async {
    executedSql.add(sql);
  }

  Future<_FakeQueryResult> query(String sql) async {
    if (sql.contains('FROM geofence_transitions')) {
      return _FakeQueryResult(transitionRows);
    }
    return _FakeQueryResult([]);
  }

  Future<void> dispose() async {}
}

void main() {
  group('TripsRepository', () {
    test('creates completed trip from confirmed EXIT then ENTER', () async {
      final conn = _ScriptedConnection([
        [
          'VH-001|EXIT|gf_depot_north|2026-08-26T10:00:00.000Z',
          'VH-001',
          'EXIT',
          'gf_depot_north',
          'gfv_depot_north_v1',
          '2026-08-26T10:00:00.000Z',
        ],
        [
          'VH-001|ENTER|gf_service_yard|2026-08-26T10:10:00.000Z',
          'VH-001',
          'ENTER',
          'gf_service_yard',
          'gfv_service_yard_v1',
          '2026-08-26T10:10:00.000Z',
        ],
      ]);

      final db = AppDatabase(
        databasePathResolver: () async => 'memory://trips-test',
        duckDbOpen: (_) async => _FakeDatabase(),
        duckDbConnect: (_) async => conn,
      );
      await db.initialize();
      conn.executedSql.clear();

      final repository = TripsRepository(db);
      await repository.recomputeTripsFromConfirmedTransitions();

      expect(conn.executedSql.first, 'BEGIN TRANSACTION');
      final upserts = conn.executedSql
          .where((sql) => sql.contains('INSERT INTO trips'))
          .toList(growable: false);
      expect(upserts, hasLength(1));
      expect(upserts.single, contains("'COMPLETED'"));
      expect(upserts.single, contains("'gf_depot_north'"));
      expect(upserts.single, contains("'gf_service_yard'"));

      await db.close();
    });

    test('keeps trip IN_PROGRESS when no later ENTER exists', () async {
      final conn = _ScriptedConnection([
        [
          'VH-002|EXIT|gf_depot_north|2026-08-26T10:00:00.000Z',
          'VH-002',
          'EXIT',
          'gf_depot_north',
          'gfv_depot_north_v1',
          '2026-08-26T10:00:00.000Z',
        ],
      ]);

      final db = AppDatabase(
        databasePathResolver: () async => 'memory://trips-test-progress',
        duckDbOpen: (_) async => _FakeDatabase(),
        duckDbConnect: (_) async => conn,
      );
      await db.initialize();
      conn.executedSql.clear();

      final repository = TripsRepository(db);
      await repository.recomputeTripsFromConfirmedTransitions();

      final upsert = conn.executedSql.singleWhere(
        (sql) => sql.contains('INSERT INTO trips'),
      );
      expect(upsert, contains("'IN_PROGRESS'"));
      expect(upsert, contains('NULL'));

      await db.close();
    });

    test('handles return-to-origin as completed trip', () async {
      final conn = _ScriptedConnection([
        [
          'VH-003|EXIT|gf_depot_north|2026-08-26T10:00:00.000Z',
          'VH-003',
          'EXIT',
          'gf_depot_north',
          'gfv_depot_north_v1',
          '2026-08-26T10:00:00.000Z',
        ],
        [
          'VH-003|ENTER|gf_depot_north|2026-08-26T10:30:00.000Z',
          'VH-003',
          'ENTER',
          'gf_depot_north',
          'gfv_depot_north_v1',
          '2026-08-26T10:30:00.000Z',
        ],
      ]);

      final db = AppDatabase(
        databasePathResolver: () async => 'memory://trips-test-return',
        duckDbOpen: (_) async => _FakeDatabase(),
        duckDbConnect: (_) async => conn,
      );
      await db.initialize();
      conn.executedSql.clear();

      final repository = TripsRepository(db);
      await repository.recomputeTripsFromConfirmedTransitions();

      final upsert = conn.executedSql.singleWhere(
        (sql) => sql.contains('INSERT INTO trips'),
      );
      expect(upsert, contains("'COMPLETED'"));
      expect(upsert, contains("'gf_depot_north'"));

      await db.close();
    });

    test('deletes existing rows when there are no derived trips', () async {
      final conn = _ScriptedConnection(const []);

      final db = AppDatabase(
        databasePathResolver: () async => 'memory://trips-test-empty',
        duckDbOpen: (_) async => _FakeDatabase(),
        duckDbConnect: (_) async => conn,
      );
      await db.initialize();
      conn.executedSql.clear();

      final repository = TripsRepository(db);
      await repository.recomputeTripsFromConfirmedTransitions();

      expect(conn.executedSql, contains('DELETE FROM trips'));
      expect(conn.executedSql.last, 'COMMIT');

      await db.close();
    });
  });
}
