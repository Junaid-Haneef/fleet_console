import 'package:flutter_test/flutter_test.dart';

import 'package:fleet_console/src/core/database/app_database.dart';
import 'package:fleet_console/src/features/alerts/bloc/alerts_bloc.dart';
import 'package:fleet_console/src/features/alerts/data/alerts_repository.dart';
import 'package:fleet_console/src/features/alerts/models/alert_models.dart';

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
          databasePathResolver: () async => 'memory://alerts-bloc-test',
          duckDbOpen: (_) async => _FakeDatabase(),
          duckDbConnect: (_) async => _FakeConnection(),
        ),
      );

  final List<ActiveAlertRow> _alerts;
  DateTime? dismissExpiry;

  @override
  Future<List<ActiveAlertRow>> fetchActiveAlerts() async => List<ActiveAlertRow>.from(_alerts);

  @override
  Future<int> fetchActiveAlertCount() async => _alerts.length;

  @override
  Future<DateTime?> dismissAlert({
    required String vehicleId,
    required AlertType alertType,
    required AlertDismissReason reason,
  }) async {
    _alerts.removeWhere((a) => a.vehicleId == vehicleId && a.type == alertType);
    dismissExpiry = DateTime.now().toUtc().add(const Duration(seconds: 5));
    return dismissExpiry;
  }

  @override
  Future<bool> undoDismissal({
    required String vehicleId,
    required AlertType alertType,
  }) async {
    _alerts.add(
      ActiveAlertRow(
        vehicleId: vehicleId,
        regNumber: 'KA-01-AB-1001',
        model: 'Model A',
        type: alertType,
        severity: AlertSeverity.warning,
        sourceEventTime: DateTime.utc(2026, 8, 26, 10),
      ),
    );
    return true;
  }
}

void main() {
  test('refresh loads active alerts into ready state', () async {
    final initialAlerts = <ActiveAlertRow>[
      ActiveAlertRow(
        vehicleId: 'VH-001',
        regNumber: 'KA-01-AB-1001',
        model: 'Model A',
        type: AlertType.batterySoc,
        severity: AlertSeverity.warning,
        sourceEventTime: DateTime.utc(2026, 8, 26, 9),
      ),
    ];

    final repository = _StubAlertsRepository(initialAlerts);
    final database = AppDatabase(
      databasePathResolver: () async => 'memory://alerts-bloc-test',
      duckDbOpen: (_) async => _FakeDatabase(),
      duckDbConnect: (_) async => _FakeConnection(),
    );

    final bloc = AlertsBloc(database, repository: repository);
    await bloc.refresh();

    expect(bloc.state.status, AlertsStatus.ready);
    expect(bloc.state.activeCount, 1);
    expect(bloc.state.alerts, hasLength(1));

    await bloc.close();
  });

  test('dismiss then undo updates active count', () async {
    final initialAlerts = <ActiveAlertRow>[
      ActiveAlertRow(
        vehicleId: 'VH-001',
        regNumber: 'KA-01-AB-1001',
        model: 'Model A',
        type: AlertType.batterySoc,
        severity: AlertSeverity.warning,
        sourceEventTime: DateTime.utc(2026, 8, 26, 9),
      ),
    ];

    final repository = _StubAlertsRepository(initialAlerts);
    final database = AppDatabase(
      databasePathResolver: () async => 'memory://alerts-bloc-test-2',
      duckDbOpen: (_) async => _FakeDatabase(),
      duckDbConnect: (_) async => _FakeConnection(),
    );

    final bloc = AlertsBloc(database, repository: repository);
    await bloc.refresh();

    final alert = bloc.state.alerts.first;
    final dismissUntil = await bloc.dismissAlert(alert, AlertDismissReason.iAmOnIt);
    expect(dismissUntil, isNotNull);
    expect(bloc.state.activeCount, 0);

    final undone = await bloc.undoDismissedAlert(alert);
    expect(undone, isTrue);
    expect(bloc.state.activeCount, 1);

    await bloc.close();
  });
}
