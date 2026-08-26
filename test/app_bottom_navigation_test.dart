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
        ['VH-001', 'KA-01-AB-1001', 'Model A', 52.0, 140.0, 'MOVING', 'NONE'],
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
    expect(find.text('1'), findsOneWidget);

    await tester.tap(find.text('Alert'));
    await tester.pumpAndSettle();

    expect(find.text('Battery SOC alert'), findsOneWidget);
    expect(find.text('Warning'), findsOneWidget);
  });
}
