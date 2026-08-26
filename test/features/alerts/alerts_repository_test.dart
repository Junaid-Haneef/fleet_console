import 'package:flutter_test/flutter_test.dart';

import 'package:fleet_console/src/core/database/app_database.dart';
import 'package:fleet_console/src/features/alerts/data/alerts_repository.dart';
import 'package:fleet_console/src/features/alerts/models/alert_models.dart';

class _FakeDatabase {
  Future<void> dispose() async {}
}

class _FakeQueryResult {
  _FakeQueryResult(this.rows);

  final List<List<Object?>> rows;

  List<List<Object?>> fetchAll() => rows;
}

class _CapturingConnection {
  final List<String> executed = <String>[];

  Future<void> execute(String sql) async {
    executed.add(sql);
  }

  Future<_FakeQueryResult> query(String sql) async {
    if (sql.contains('SELECT COUNT(*)') && sql.contains('FROM active_alerts')) {
      return _FakeQueryResult([
        [1],
      ]);
    }

    if (sql.contains('SELECT COUNT(*)') && sql.contains('FROM dismissal_undo_windows')) {
      return _FakeQueryResult([
        [1],
      ]);
    }

    return _FakeQueryResult([]);
  }

  Future<void> dispose() async {}
}

void main() {
  test('recompute writes transition event SQL blocks', () async {
    final connection = _CapturingConnection();
    final database = AppDatabase(
      databasePathResolver: () async => 'memory://alerts-recompute',
      duckDbOpen: (_) async => _FakeDatabase(),
      duckDbConnect: (_) async => connection,
    );

    await database.initialize();

    final repository = AlertsRepository(
      database,
      utcNow: () => DateTime.utc(2026, 8, 26, 12),
    );

    await repository.recomputeActiveAlertsFromLatestReadings();

    expect(
      connection.executed.any((sql) => sql.contains("'FIRED'")),
      isTrue,
    );
    expect(
      connection.executed.any((sql) => sql.contains("'ESCALATED'")),
      isTrue,
    );
    expect(
      connection.executed.any((sql) => sql.contains("'DEESCALATED'")),
      isTrue,
    );
    expect(
      connection.executed.any((sql) => sql.contains("'RESOLVED'")),
      isTrue,
    );

    await database.close();
  });

  test('dismiss writes event, undo window, and removes active alert', () async {
    final connection = _CapturingConnection();
    final database = AppDatabase(
      databasePathResolver: () async => 'memory://alerts-dismiss',
      duckDbOpen: (_) async => _FakeDatabase(),
      duckDbConnect: (_) async => connection,
    );

    await database.initialize();

    final repository = AlertsRepository(
      database,
      utcNow: () => DateTime.utc(2026, 8, 26, 12),
    );

    final expiresAt = await repository.dismissAlert(
      vehicleId: 'VH-001',
      alertType: AlertType.batterySoc,
      reason: AlertDismissReason.iAmOnIt,
    );

    expect(expiresAt, isNotNull);
    expect(
      connection.executed.any((sql) => sql.contains("'DISMISSED'")),
      isTrue,
    );
    expect(
      connection.executed.any((sql) => sql.contains('INSERT INTO dismissal_undo_windows')),
      isTrue,
    );
    expect(
      connection.executed.any((sql) => sql.contains('DELETE FROM active_alerts')),
      isTrue,
    );

    await database.close();
  });

  test('undo writes undone event and clears undo window', () async {
    final connection = _CapturingConnection();
    final database = AppDatabase(
      databasePathResolver: () async => 'memory://alerts-undo',
      duckDbOpen: (_) async => _FakeDatabase(),
      duckDbConnect: (_) async => connection,
    );

    await database.initialize();

    final repository = AlertsRepository(
      database,
      utcNow: () => DateTime.utc(2026, 8, 26, 12),
    );

    final undone = await repository.undoDismissal(
      vehicleId: 'VH-001',
      alertType: AlertType.batterySoc,
    );

    expect(undone, isTrue);
    expect(
      connection.executed.any((sql) => sql.contains("'UNDONE'")),
      isTrue,
    );
    expect(
      connection.executed.any((sql) => sql.contains('DELETE FROM dismissal_undo_windows')),
      isTrue,
    );

    await database.close();
  });
}
