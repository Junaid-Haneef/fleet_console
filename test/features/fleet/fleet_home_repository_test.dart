import 'package:flutter_test/flutter_test.dart';

import 'package:fleet_console/src/core/database/app_database.dart';
import 'package:fleet_console/src/features/fleet/data/fleet_home_repository.dart';
import 'package:fleet_console/src/features/fleet/models/fleet_home_models.dart';

class _FakeDatabase {
  Future<void> dispose() async {}
}

class _FakeQueryResult {
  _FakeQueryResult(this.rows);

  final List<List<Object?>> rows;

  List<List<Object?>> fetchAll() => rows;
}

class _CapturingConnection {
  final List<String> queries = [];

  Future<void> execute(String sql) async {}

  Future<_FakeQueryResult> query(String sql) async {
    queries.add(sql);

    return _FakeQueryResult([
      [
        'VH-001',
        'KA-01-AB-1001',
        'Model A',
        'Depot North',
        52.0,
        130.0,
        'MOVING',
        'NONE',
        BigInt.from(4),
        BigInt.from(1),
        BigInt.from(1),
        BigInt.from(1),
        BigInt.from(1),
      ],
      [
        'VH-002',
        'KA-01-AB-1002',
        'Model B',
        'No geofence',
        8.0,
        25.0,
        'OFFLINE',
        'CRITICAL',
        BigInt.from(4),
        BigInt.from(1),
        BigInt.from(1),
        BigInt.from(1),
        BigInt.from(1),
      ],
      [
        'VH-003',
        'KA-01-AB-1003',
        'Model C',
        'Charging Hub',
        14.0,
        40.0,
        'IDLE',
        'WARNING',
        BigInt.from(4),
        BigInt.from(1),
        BigInt.from(1),
        BigInt.from(1),
        BigInt.from(1),
      ],
      [
        'VH-004',
        'KA-01-AB-1004',
        'Model D',
        'Service Yard',
        null,
        null,
        'STOPPED',
        'NONE',
        BigInt.from(4),
        BigInt.from(1),
        BigInt.from(1),
        BigInt.from(1),
        BigInt.from(1),
      ],
    ]);
  }

  Future<void> dispose() async {}
}

void main() {
  test('fetchSnapshot maps rows and counts and uses event-time latest SQL', () async {
    final conn = _CapturingConnection();
    final db = AppDatabase(
      databasePathResolver: () async => 'memory://fleet-repo-test',
      duckDbOpen: (_) async => _FakeDatabase(),
      duckDbConnect: (_) async => conn,
    );
    await db.initialize();

    final repository = FleetHomeRepository(
      db,
      utcNow: () => DateTime.utc(2026, 8, 25, 12, 0, 0),
    );

    final snapshot = await repository.fetchSnapshot();

    expect(snapshot.rows, hasLength(4));
    expect(snapshot.counts.all, 4);
    expect(snapshot.counts.moving, 1);
    expect(snapshot.counts.idle, 1);
    expect(snapshot.counts.stopped, 1);
    expect(snapshot.counts.offline, 1);

    expect(snapshot.rows.first.status, FleetVehicleStatus.moving);
    expect(snapshot.rows.first.currentGeofenceName, 'Depot North');
    expect(snapshot.rows[1].status, FleetVehicleStatus.offline);
    expect(snapshot.rows[1].currentGeofenceName, 'No geofence');
    expect(snapshot.rows[1].alertSeverity, AlertBadgeSeverity.critical);
    expect(snapshot.rows[2].alertSeverity, AlertBadgeSeverity.warning);

    expect(conn.queries.length, 2);
    final rowsSql = conn.queries.last;
    expect(rowsSql, contains('COUNT(*) OVER () AS all_count'));
    expect(rowsSql, contains('arg_max(value, event_time)'));
    expect(rowsSql, contains('FILTER (WHERE signal_name = '));
    expect(rowsSql, contains('GREATEST('));
    expect(rowsSql, contains('current_geofence_name'));
    expect(rowsSql, contains("TIMESTAMP '2026-08-25T11:50:00.000Z'"));

    await db.close();
  });
}
