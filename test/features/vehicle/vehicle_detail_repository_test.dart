import 'package:flutter_test/flutter_test.dart';

import 'package:fleet_console/src/core/database/app_database.dart';
import 'package:fleet_console/src/features/vehicle/data/vehicle_detail_repository.dart';
import 'package:fleet_console/src/features/vehicle/domain/vehicle_detail_models.dart';

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

    if (sql.contains('SELECT event_time, value')) {
      return _FakeQueryResult([
        [DateTime.utc(2026, 8, 25, 11, 0, 0), 55.0],
        [DateTime.utc(2026, 8, 25, 11, 30, 0), 42.0],
      ]);
    }

    return _FakeQueryResult([
      [
        'VH-001',
        'KA-01-AB-1001',
        'Model A',
        9.0,
        DateTime.utc(2026, 8, 25, 11, 49, 0),
        660,
        'ALERT',
        42.0,
        DateTime.utc(2026, 8, 25, 11, 48, 0),
        720,
        'ALERT',
        0.0,
        DateTime.utc(2026, 8, 25, 11, 56, 0),
        240,
        'STALE',
        38.0,
        DateTime.utc(2026, 8, 25, 11, 58, 0),
        120,
        'NORMAL',
        null,
        null,
        null,
        'NONE',
        null,
        DateTime.utc(2026, 8, 25, 11, 30, 0),
        1800,
        'STALE',
      ],
    ]);
  }

  Future<void> dispose() async {}
}

void main() {
  test('fetchSnapshot maps readings, ages, stale vs never reported, and SOC history', () async {
    final conn = _CapturingConnection();
    final db = AppDatabase(
      databasePathResolver: () async => 'memory://vehicle-detail-repo-test',
      duckDbOpen: (_) async => _FakeDatabase(),
      duckDbConnect: (_) async => conn,
    );
    await db.initialize();

    final repository = VehicleDetailRepository(
      db,
      utcNow: () => DateTime.utc(2026, 8, 25, 12, 0, 0),
    );

    final snapshot = await repository.fetchSnapshot('VH-001');

    expect(snapshot.identity.vehicleId, 'VH-001');
    expect(snapshot.identity.regNumber, 'KA-01-AB-1001');
    expect(snapshot.readings, hasLength(6));

    final soc = snapshot.readings[0];
    expect(soc.signal, VehicleSignalKey.soc);
    expect(soc.ageSeconds, 660);
    expect(soc.verdict, VehicleReadingVerdict.alert);

    final range = snapshot.readings[1];
    expect(range.signal, VehicleSignalKey.rangeKm);
    expect(range.verdict, VehicleReadingVerdict.alert);

    final speed = snapshot.readings[2];
    expect(speed.signal, VehicleSignalKey.speed);
    expect(speed.verdict, VehicleReadingVerdict.stale);

    final batteryTemp = snapshot.readings[3];
    expect(batteryTemp.signal, VehicleSignalKey.batteryTemp);
    expect(batteryTemp.verdict, VehicleReadingVerdict.normal);

    final odometer = snapshot.readings[4];
    expect(odometer.signal, VehicleSignalKey.odometer);
    expect(odometer.hasReported, isFalse);
    expect(odometer.verdict, VehicleReadingVerdict.none);

    final lastPing = snapshot.readings[5];
    expect(lastPing.signal, VehicleSignalKey.lastPing);
    expect(lastPing.verdict, VehicleReadingVerdict.stale);

    expect(snapshot.socHistory, hasLength(2));
    expect(snapshot.socHistory.first.soc, 55.0);
    expect(snapshot.socHistory.last.soc, 42.0);

    await db.close();
  });

  test('fetchSnapshot SQL uses event-time latest extraction and SOC history query', () async {
    final conn = _CapturingConnection();
    final db = AppDatabase(
      databasePathResolver: () async => 'memory://vehicle-detail-repo-sql-test',
      duckDbOpen: (_) async => _FakeDatabase(),
      duckDbConnect: (_) async => conn,
    );
    await db.initialize();

    final repository = VehicleDetailRepository(
      db,
      utcNow: () => DateTime.utc(2026, 8, 25, 12, 0, 0),
    );

    await repository.fetchSnapshot('VH-001');

    expect(conn.queries, hasLength(2));

    final detailsSql = conn.queries.first;
    expect(detailsSql, contains('ROW_NUMBER() OVER'));
    expect(detailsSql, contains('ORDER BY event_time DESC'));
    expect(detailsSql, contains('date_diff(\'second\''));
    expect(detailsSql, contains("TIMESTAMP '2026-08-25T12:00:00.000Z'"));

    final historySql = conn.queries.last;
    expect(historySql, contains("signal_name = 'soc'"));
    expect(historySql, contains('ORDER BY event_time ASC'));

    await db.close();
  });
}
