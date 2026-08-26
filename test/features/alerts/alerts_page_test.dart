import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fleet_console/src/core/database/app_database.dart';
import 'package:fleet_console/src/features/alerts/data/alerts_repository.dart';
import 'package:fleet_console/src/features/alerts/models/alert_models.dart';
import 'package:fleet_console/src/features/alerts/bloc/alerts_bloc.dart';
import 'package:fleet_console/src/features/alerts/presentation/alerts_page.dart';

class _FakeDatabase {
  Future<void> dispose() async {}
}

class _FakeConnection {
  Future<void> execute(String sql) async {}

  Future<dynamic> query(String sql) async => throw UnimplementedError();

  Future<void> dispose() async {}
}

class _StubAlertsRepository extends AlertsRepository {
  _StubAlertsRepository(this._alerts)
    : super(
        AppDatabase(
          databasePathResolver: () async => 'memory://alerts-page-test',
          duckDbOpen: (_) async => _FakeDatabase(),
          duckDbConnect: (_) async => _FakeConnection(),
        ),
      );

  final List<ActiveAlertRow> _alerts;

  int _activeCount = 0;

  @override
  Future<List<ActiveAlertRow>> fetchActiveAlerts() async => List<ActiveAlertRow>.from(_alerts);

  @override
  Future<int> fetchActiveAlertCount() async => _activeCount;

  @override
  Future<DateTime?> dismissAlert({
    required String vehicleId,
    required AlertType alertType,
    required AlertDismissReason reason,
  }) async {
    _alerts.removeWhere((alert) => alert.vehicleId == vehicleId && alert.type == alertType);
    _activeCount = _alerts.length;
    return DateTime.now().toUtc().add(const Duration(seconds: 5));
  }

  @override
  Future<bool> undoDismissal({
    required String vehicleId,
    required AlertType alertType,
  }) async {
    return true;
  }
}

void main() {
  testWidgets('dismiss reason sheet keeps exact option order and shows undo snackbar', (
    tester,
  ) async {
    final alerts = <ActiveAlertRow>[
      ActiveAlertRow(
        vehicleId: 'VH-001',
        regNumber: 'KA-01-AB-1001',
        model: 'Model A',
        type: AlertType.batterySoc,
        severity: AlertSeverity.warning,
        sourceEventTime: DateTime.utc(2026, 8, 25, 10),
      ),
    ];

    final repository = _StubAlertsRepository(alerts);
    final database = AppDatabase(
      databasePathResolver: () async => 'memory://alerts-page-test',
      duckDbOpen: (_) async => _FakeDatabase(),
      duckDbConnect: (_) async => _FakeConnection(),
    );

    final bloc = AlertsBloc(database, repository: repository);
    await bloc.refresh();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider.value(
            value: bloc,
            child: const AlertsPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dismiss'));
    await tester.pumpAndSettle();

    final iAmOnIt = find.text('I am on it');
    final wrongAlert = find.text('Wrong alert');
    final somethingElse = find.text('Something else…');

    expect(iAmOnIt, findsOneWidget);
    expect(wrongAlert, findsOneWidget);
    expect(somethingElse, findsOneWidget);

    final iTop = tester.getTopLeft(iAmOnIt).dy;
    final wTop = tester.getTopLeft(wrongAlert).dy;
    final sTop = tester.getTopLeft(somethingElse).dy;
    expect(iTop < wTop, isTrue);
    expect(wTop < sTop, isTrue);

    await tester.tap(iAmOnIt);
    await tester.pumpAndSettle();

    expect(find.text('UNDO'), findsOneWidget);
    expect(find.textContaining('alert dismissed'), findsOneWidget);

    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(find.text('UNDO'), findsNothing);

    await bloc.close();
  });
}
