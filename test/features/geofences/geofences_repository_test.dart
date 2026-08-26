import 'package:flutter_test/flutter_test.dart';

import 'package:fleet_console/src/core/database/app_database.dart';
import 'package:fleet_console/src/features/geofences/data/geofences_repository.dart';
import 'package:fleet_console/src/features/geofences/models/geofence_models.dart';

class _FakeDatabase {
  Future<void> dispose() async {}
}

class _FakeQueryResult {
  _FakeQueryResult(this.rows);

  final List<List<Object?>> rows;

  List<List<Object?>> fetchAll() => rows;
}

class _CapturingConnection {
  final List<String> executedSql = [];
  final List<String> queriedSql = [];

  Future<void> execute(String sql) async {
    executedSql.add(sql);
  }

  Future<_FakeQueryResult> query(String sql) async {
    queriedSql.add(sql);

    if (sql.contains('ORDER BY effective_from DESC') &&
        sql.contains('LIMIT 1') &&
        sql.contains("WHERE geofence_id = 'gf_depot_north'")) {
      return _FakeQueryResult([
        ['Depot North', 12.9716, 77.5946, 180.0, '2026-08-26T11:00:00.000Z'],
      ]);
    }

    if (sql.contains('FROM active_counts')) {
      return _FakeQueryResult([
        ['gf_charging_hub', 'Charging Hub', BigInt.from(12), false],
        ['gf_depot_north', 'Depot North', BigInt.from(8), false],
        [null, 'No geofence', BigInt.from(480), true],
      ]);
    }

    if (sql.contains('WHERE rn = 1 AND is_active = TRUE')) {
      return _FakeQueryResult([
        [
          'gf_charging_hub',
          'gfv_charging_hub_v2',
          'Charging Hub',
          12.9732,
          77.5991,
          120.0,
          true,
          '2026-08-25T10:00:00.000Z',
          '2026-01-01T00:01:00.000Z',
        ],
      ]);
    }

    if (sql.contains('WHERE rn = 1 AND is_active = FALSE')) {
      return _FakeQueryResult([
        [
          'gf_service_yard',
          'gfv_service_yard_v3',
          'Service Yard',
          12.9689,
          77.5879,
          150.0,
          false,
          '2026-08-25T11:00:00.000Z',
          '2026-01-01T00:02:00.000Z',
        ],
      ]);
    }

    return _FakeQueryResult([]);
  }

  Future<void> dispose() async {}
}

void main() {
  group('GeofencesRepository', () {
    late _CapturingConnection conn;
    late AppDatabase db;

    setUp(() async {
      conn = _CapturingConnection();
      db = AppDatabase(
        databasePathResolver: () async => 'memory://geofences-repo-test',
        duckDbOpen: (_) async => _FakeDatabase(),
        duckDbConnect: (_) async => conn,
      );
      await db.initialize();
      conn.executedSql.clear();
      conn.queriedSql.clear();
    });

    tearDown(() async {
      await db.close();
    });

    test('fetchManagementSnapshot maps active, inactive, and count queries', () async {
      final repository = GeofencesRepository(db);

      final snapshot = await repository.fetchManagementSnapshot();

      expect(snapshot.activeGeofences, hasLength(1));
      expect(snapshot.inactiveGeofences, hasLength(1));
      expect(snapshot.vehicleCounts, hasLength(3));
      expect(snapshot.activeGeofences.single.name, 'Charging Hub');
      expect(snapshot.inactiveGeofences.single.name, 'Service Yard');
      expect(snapshot.vehicleCounts.last, isA<GeofenceVehicleCount>());
      expect(snapshot.vehicleCounts.last.isNoGeofence, isTrue);
      expect(snapshot.vehicleCounts.last.vehicleCount, 480);

      expect(conn.queriedSql.length, 3);
      expect(conn.queriedSql.first, contains('ROW_NUMBER() OVER'));
      expect(conn.queriedSql[1], contains('WHERE rn = 1 AND is_active = FALSE'));
      expect(conn.queriedSql[2], contains("'No geofence'"));
    });

    test('createGeofence inserts identity and first active version in one transaction', () async {
      final repository = GeofencesRepository(
        db,
        utcNow: () => DateTime.utc(2026, 8, 26, 10, 15, 0),
      );

      await repository.createGeofence(
        name: 'Airport Yard',
        centerLat: 12.95,
        centerLon: 77.61,
        radiusM: 200,
      );

      expect(conn.executedSql.first, 'BEGIN TRANSACTION');
      expect(conn.executedSql[1], contains('INSERT INTO geofences'));
      expect(conn.executedSql[1], contains('gf_airport_yard_'));
      expect(conn.executedSql[2], contains('INSERT INTO geofence_versions'));
      expect(conn.executedSql[2], contains("'Airport Yard'"));
      expect(conn.executedSql.last, 'COMMIT');
    });

    test('editGeofence supersedes open version and inserts a later version', () async {
      final repository = GeofencesRepository(
        db,
        utcNow: () => DateTime.utc(2026, 8, 26, 12, 0, 0),
      );

      await repository.editGeofence(
        geofenceId: 'gf_depot_north',
        name: 'Depot North Expanded',
        centerLat: 12.9717,
        centerLon: 77.5948,
        radiusM: 220,
      );

      expect(conn.executedSql.first, 'BEGIN TRANSACTION');
      expect(conn.executedSql[1], contains('UPDATE geofence_versions'));
      expect(conn.executedSql[1], contains('superseded_at = TIMESTAMP'));
      expect(conn.executedSql[2], contains('INSERT INTO geofence_versions'));
      expect(conn.executedSql[2], contains("'Depot North Expanded'"));
      expect(conn.executedSql.last, 'COMMIT');
    });

    test('editGeofence rejects backdated effective time', () async {
      final repository = GeofencesRepository(
        db,
        utcNow: () => DateTime.utc(2026, 8, 26, 12, 0, 0),
      );

      await expectLater(
        () => repository.editGeofence(
          geofenceId: 'gf_depot_north',
          name: 'Depot North Backdated',
          centerLat: 12.9717,
          centerLon: 77.5948,
          radiusM: 220,
          effectiveFrom: DateTime.utc(2026, 8, 26, 10, 59, 59),
        ),
        throwsA(isA<StateError>()),
      );

      expect(conn.executedSql, isEmpty);
    });

    test('deactivateGeofence preserves latest shape but inserts inactive version', () async {
      final repository = GeofencesRepository(
        db,
        utcNow: () => DateTime.utc(2026, 8, 26, 13, 45, 0),
      );

      await repository.deactivateGeofence(geofenceId: 'gf_depot_north');

      expect(conn.queriedSql.single, contains("WHERE geofence_id = 'gf_depot_north'"));
      expect(conn.executedSql.first, 'BEGIN TRANSACTION');
      expect(conn.executedSql[2], contains('INSERT INTO geofence_versions'));
      expect(conn.executedSql[2], contains('FALSE'));
      expect(conn.executedSql[2], contains("'Depot North'"));
      expect(conn.executedSql.last, 'COMMIT');
    });

    test('deactivateGeofence rejects backdated effective time', () async {
      final repository = GeofencesRepository(
        db,
        utcNow: () => DateTime.utc(2026, 8, 26, 13, 45, 0),
      );

      await expectLater(
        () => repository.deactivateGeofence(
          geofenceId: 'gf_depot_north',
          effectiveFrom: DateTime.utc(2026, 8, 26, 10, 59, 59),
        ),
        throwsA(isA<StateError>()),
      );

      expect(conn.executedSql, isEmpty);
    });
  });
}