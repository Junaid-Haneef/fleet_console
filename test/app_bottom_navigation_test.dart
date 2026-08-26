import 'package:flutter_test/flutter_test.dart';

import 'package:fleet_console/src/app.dart';
import 'package:fleet_console/src/core/database/app_database.dart';

class _FakeDatabase {
  Future<void> dispose() async {}
}

class _FakeQueryResult {
  _FakeQueryResult(this.rows);

  final List<List<Object?>> rows;

  List<List<Object?>> fetchAll() => rows;
}

class _FakeConnection {
  Future<void> execute(String sql) async {}

  Future<_FakeQueryResult> query(String sql) async {
    if (sql.contains('COUNT(*) AS all_count')) {
      return _FakeQueryResult([
        [1, 1, 0, 0, 0],
      ]);
    }

    if (sql.contains('FROM fleet_projection') && sql.contains('ORDER BY reg_number ASC')) {
      return _FakeQueryResult([
        ['VH-001', 'KA-01-AB-1001', 'Model A', 'No geofence', 52.0, 140.0, 'MOVING', 'NONE'],
      ]);
    }

    if (sql.contains('FROM ranked_versions') && sql.contains('is_active = TRUE')) {
      return _FakeQueryResult([
        [
          'gf_depot_north',
          'gfv_depot_north_v1',
          'Depot North',
          12.9716,
          77.5946,
          180.0,
          true,
          DateTime.utc(2026, 1, 1),
          DateTime.utc(2026, 1, 1),
        ],
      ]);
    }

    if (sql.contains('WHERE rn = 1 AND is_active = FALSE')) {
      return _FakeQueryResult([]);
    }

    if (sql.contains('FROM active_counts')) {
      return _FakeQueryResult([
        ['gf_depot_north', 'Depot North', 1, false],
        [null, 'No geofence', 0, true],
      ]);
    }

    if (sql.contains('FROM active_alerts a')) {
      return _FakeQueryResult([
        ['VH-001', 'KA-01-AB-1001', 'Model A', 'battery_soc', 'WARNING', DateTime.utc(2026, 8, 25)],
      ]);
    }

    if (sql.contains('SELECT COUNT(*) FROM active_alerts')) {
      return _FakeQueryResult([
        [1],
      ]);
    }

    if (sql.contains('SELECT 1 AS ok')) {
      return _FakeQueryResult([
        [1],
      ]);
    }

    return _FakeQueryResult([]);
  }

  Future<void> dispose() async {}
}

void main() {
  testWidgets('shows Fleet and Alert tabs with alert badge count', (tester) async {
    final database = AppDatabase(
      databasePathResolver: () async => 'memory://app-nav-test',
      duckDbOpen: (_) async => _FakeDatabase(),
      duckDbConnect: (_) async => _FakeConnection(),
    );

    await database.initialize();

    await tester.pumpWidget(MainApp(database: database));
    await tester.pumpAndSettle();

    expect(find.text('Fleet'), findsOneWidget);
    expect(find.text('Alert'), findsOneWidget);
    expect(find.text('Geofences'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);

    await tester.tap(find.text('Alert'));
    await tester.pumpAndSettle();

    expect(find.text('Battery SOC alert'), findsOneWidget);
    expect(find.text('Warning'), findsOneWidget);

    await tester.tap(find.text('Geofences'));
    await tester.pumpAndSettle();

    expect(find.text('Live Vehicle Counts'), findsOneWidget);
    expect(find.text('Depot North'), findsWidgets);
  });
}
