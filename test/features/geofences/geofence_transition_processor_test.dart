import 'package:flutter_test/flutter_test.dart';

import 'package:fleet_console/src/core/database/app_database.dart';
import 'package:fleet_console/src/features/geofences/data/geofence_transition_processor.dart';

class _FakeDatabase {
  Future<void> dispose() async {}
}

class _FakeQueryResult {
  _FakeQueryResult(this.rows);

  final List<List<Object?>> rows;

  List<List<Object?>> fetchAll() => rows;
}

class _ScriptedConnection {
  _ScriptedConnection({
    required this.geofenceRows,
    required this.locationRows,
    required this.latestTransitionRows,
  });

  final List<List<Object?>> geofenceRows;
  final List<List<Object?>> locationRows;
  final List<List<Object?>> latestTransitionRows;
  final List<String> executedSql = [];
  final List<String> queriedSql = [];

  Future<void> execute(String sql) async {
    executedSql.add(sql);
  }

  Future<_FakeQueryResult> query(String sql) async {
    queriedSql.add(sql);
    if (sql.contains('FROM geofence_versions')) {
      return _FakeQueryResult(geofenceRows);
    }
    if (sql.contains('FROM location_readings')) {
      return _FakeQueryResult(locationRows);
    }
    if (sql.contains('FROM ranked_transitions')) {
      return _FakeQueryResult(latestTransitionRows);
    }
    return _FakeQueryResult([]);
  }

  Future<void> dispose() async {}
}

void main() {
  group('GeofenceTransitionProcessor', () {
    test('ignores jitter that never reaches confirmation', () async {
      final conn = _ScriptedConnection(
        geofenceRows: [
          [
            'gf_depot_north',
            'gfv_depot_north_v1',
            12.971600,
            77.594600,
            180.0,
            true,
            '2026-01-01T00:00:00.000Z',
            null,
            '2026-01-01T00:00:00.000Z',
          ],
        ],
        locationRows: [
          ['VH-001', '2026-08-26T10:00:00.000Z', 12.971600, 77.594600, 10.0],
          ['VH-001', '2026-08-26T10:00:20.000Z', 12.974500, 77.600000, 10.0],
          ['VH-001', '2026-08-26T10:00:40.000Z', 12.971650, 77.594650, 10.0],
        ],
        latestTransitionRows: const [],
      );
      final db = AppDatabase(
        databasePathResolver: () async => 'memory://transition-test',
        duckDbOpen: (_) async => _FakeDatabase(),
        duckDbConnect: (_) async => conn,
      );
      await db.initialize();
      conn.executedSql.clear();

      final processor = GeofenceTransitionProcessor(db);
      await processor.recomputeConfirmedTransitions();

      expect(
        conn.executedSql.where((sql) => sql.contains('INSERT INTO geofence_transitions')),
        isEmpty,
      );
      expect(conn.executedSql, contains('DELETE FROM vehicle_geofence_state'));

      await db.close();
    });

    test('confirms entry after three consecutive accurate readings', () async {
      final conn = _ScriptedConnection(
        geofenceRows: [
          [
            'gf_depot_north',
            'gfv_depot_north_v1',
            12.971600,
            77.594600,
            180.0,
            true,
            '2026-01-01T00:00:00.000Z',
            null,
            '2026-01-01T00:00:00.000Z',
          ],
        ],
        locationRows: [
          ['VH-001', '2026-08-26T10:00:00.000Z', 12.971600, 77.594600, 10.0],
          ['VH-001', '2026-08-26T10:00:20.000Z', 12.971610, 77.594610, 10.0],
          ['VH-001', '2026-08-26T10:00:40.000Z', 12.971620, 77.594620, 10.0],
        ],
        latestTransitionRows: [
          ['VH-001', 'ENTER', 'gf_depot_north', 'gfv_depot_north_v1', '2026-08-26T10:00:40.000Z'],
        ],
      );
      final db = AppDatabase(
        databasePathResolver: () async => 'memory://transition-test',
        duckDbOpen: (_) async => _FakeDatabase(),
        duckDbConnect: (_) async => conn,
      );
      await db.initialize();
      conn.executedSql.clear();

      final processor = GeofenceTransitionProcessor(db);
      await processor.recomputeConfirmedTransitions();

      final transitionInserts = conn.executedSql
          .where((sql) => sql.contains('INSERT INTO geofence_transitions'))
          .toList(growable: false);
      expect(transitionInserts, hasLength(1));
      expect(transitionInserts.single, contains('ENTER'));
      expect(transitionInserts.single, contains("'gf_depot_north'"));
      expect(
        conn.executedSql.lastWhere((sql) => sql.contains('INSERT INTO vehicle_geofence_state')),
        contains("'gf_depot_north'"),
      );

      await db.close();
    });

    test('uses smallest radius on overlap and ignores low-accuracy samples', () async {
      final conn = _ScriptedConnection(
        geofenceRows: [
          [
            'gf_large_depot',
            'gfv_large_depot_v1',
            12.971600,
            77.594600,
            300.0,
            true,
            '2026-01-01T00:00:00.000Z',
            null,
            '2026-01-01T00:00:00.000Z',
          ],
          [
            'gf_loading_bay',
            'gfv_loading_bay_v1',
            12.971600,
            77.594600,
            80.0,
            true,
            '2026-01-01T00:05:00.000Z',
            null,
            '2026-01-01T00:05:00.000Z',
          ],
        ],
        locationRows: [
          ['VH-002', '2026-08-26T10:00:00.000Z', 12.971600, 77.594600, 75.0],
          ['VH-002', '2026-08-26T10:00:30.000Z', 12.971601, 77.594601, 10.0],
          ['VH-002', '2026-08-26T10:01:00.000Z', 12.971602, 77.594602, 10.0],
          ['VH-002', '2026-08-26T10:01:30.000Z', 12.971603, 77.594603, 10.0],
        ],
        latestTransitionRows: [
          ['VH-002', 'ENTER', 'gf_loading_bay', 'gfv_loading_bay_v1', '2026-08-26T10:01:30.000Z'],
        ],
      );
      final db = AppDatabase(
        databasePathResolver: () async => 'memory://transition-test',
        duckDbOpen: (_) async => _FakeDatabase(),
        duckDbConnect: (_) async => conn,
      );
      await db.initialize();
      conn.executedSql.clear();

      final processor = GeofenceTransitionProcessor(db);
      await processor.recomputeConfirmedTransitions();

      final transitionInsert = conn.executedSql.singleWhere(
        (sql) => sql.contains('INSERT INTO geofence_transitions'),
      );
      expect(transitionInsert, contains("'gf_loading_bay'"));
      expect(transitionInsert, isNot(contains("'gf_large_depot'")));

      await db.close();
    });

    test('does not confirm a transition from a missing-interval gap alone', () async {
      final conn = _ScriptedConnection(
        geofenceRows: [
          [
            'gf_depot_north',
            'gfv_depot_north_v1',
            12.971600,
            77.594600,
            180.0,
            true,
            '2026-01-01T00:00:00.000Z',
            null,
            '2026-01-01T00:00:00.000Z',
          ],
        ],
        locationRows: [
          ['VH-003', '2026-08-26T10:00:00.000Z', 12.971600, 77.594600, 10.0],
          ['VH-003', '2026-08-26T10:03:00.000Z', 12.971610, 77.594610, 10.0],
        ],
        latestTransitionRows: const [],
      );
      final db = AppDatabase(
        databasePathResolver: () async => 'memory://transition-test',
        duckDbOpen: (_) async => _FakeDatabase(),
        duckDbConnect: (_) async => conn,
      );
      await db.initialize();
      conn.executedSql.clear();

      final processor = GeofenceTransitionProcessor(db);
      await processor.recomputeConfirmedTransitions();

      expect(
        conn.executedSql.where((sql) => sql.contains('INSERT INTO geofence_transitions')),
        isEmpty,
      );

      await db.close();
    });
  });
}