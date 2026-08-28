import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:fleet_console/src/app.dart';
import 'package:fleet_console/src/core/database/app_database.dart';
import 'package:fleet_console/src/features/alerts/bloc/alerts_bloc.dart';
import 'package:fleet_console/src/features/alerts/data/alerts_repository.dart';
import 'package:fleet_console/src/features/alerts/models/alert_models.dart';
import 'package:fleet_console/src/features/vehicle/data/vehicle_detail_repository.dart';
import 'package:fleet_console/src/features/vehicle/models/vehicle_detail_models.dart';
import 'package:fleet_console/src/features/vehicle/cubit/vehicle_detail_cubit.dart';
import 'package:fleet_console/src/features/vehicle/presentation/vehicle_detail_page.dart';

class _FakeDatabase {
  Future<void> dispose() async {}
}

class _FakeConnection {
  Future<void> execute(String sql) async {}

  Future<dynamic> query(String sql) async => throw UnimplementedError();

  Future<void> dispose() async {}
}

class _StubAlertsRepository extends AlertsRepository {
  _StubAlertsRepository()
    : super(
        AppDatabase(
          databasePathResolver: () async => 'memory://alerts-nav',
          duckDbOpen: (_) async => _FakeDatabase(),
          duckDbConnect: (_) async => _FakeConnection(),
        ),
      );

  @override
  Future<List<ActiveAlertRow>> fetchActiveAlerts() async => const <ActiveAlertRow>[];

  @override
  Future<int> fetchActiveAlertCount() async => 0;
}

class _StubVehicleDetailRepository extends VehicleDetailRepository {
  _StubVehicleDetailRepository(this._snapshot)
    : super(
        AppDatabase(
          databasePathResolver: () async => 'memory://unused',
          duckDbOpen: (_) async => _FakeDatabase(),
          duckDbConnect: (_) async => _FakeConnection(),
        ),
      );

  final VehicleDetailSnapshot _snapshot;

  @override
  Future<VehicleDetailSnapshot> fetchSnapshot(String vehicleId) async => _snapshot;
}

void main() {
  testWidgets(
    'renders reading rows, verdict pills, never-reported no-pill, stale, and SOC history',
    (tester) async {
      final database = AppDatabase(
        databasePathResolver: () async => 'memory://vehicle-detail-page-test',
        duckDbOpen: (_) async => _FakeDatabase(),
        duckDbConnect: (_) async => _FakeConnection(),
      );

      final snapshot = VehicleDetailSnapshot(
        identity: const VehicleIdentity(
          vehicleId: 'VH-001',
          regNumber: 'KA-01-AB-1001',
          model: 'Model A',
        ),
        currentGeofenceName: 'Charging Hub',
        readings: [
          VehicleReadingRow(
            signal: VehicleSignalKey.soc,
            label: 'SOC',
            value: 9,
            eventTime: DateTime.utc(2026, 8, 25, 11, 49),
            ageSeconds: 660,
            verdict: VehicleReadingVerdict.alert,
          ),
          VehicleReadingRow(
            signal: VehicleSignalKey.rangeKm,
            label: 'Range',
            value: 42,
            eventTime: DateTime.utc(2026, 8, 25, 11, 48),
            ageSeconds: 720,
            verdict: VehicleReadingVerdict.alert,
          ),
          VehicleReadingRow(
            signal: VehicleSignalKey.speed,
            label: 'Speed',
            value: 0,
            eventTime: DateTime.utc(2026, 8, 25, 11, 56),
            ageSeconds: 240,
            verdict: VehicleReadingVerdict.stale,
          ),
          VehicleReadingRow(
            signal: VehicleSignalKey.batteryTemp,
            label: 'Battery temp',
            value: 38,
            eventTime: DateTime.utc(2026, 8, 25, 11, 58),
            ageSeconds: 120,
            verdict: VehicleReadingVerdict.normal,
          ),
          const VehicleReadingRow(
            signal: VehicleSignalKey.odometer,
            label: 'Odometer',
            value: null,
            eventTime: null,
            ageSeconds: null,
            verdict: VehicleReadingVerdict.none,
          ),
          VehicleReadingRow(
            signal: VehicleSignalKey.lastPing,
            label: 'Last ping',
            value: null,
            eventTime: DateTime.utc(2026, 8, 25, 11, 30),
            ageSeconds: 1800,
            verdict: VehicleReadingVerdict.stale,
          ),
        ],
        socHistory: [
          SocHistoryPoint(
            eventTime: DateTime.utc(2026, 8, 25, 11, 0),
            soc: 55,
          ),
          SocHistoryPoint(
            eventTime: DateTime.utc(2026, 8, 25, 11, 30),
            soc: 42,
          ),
        ],
        recentTrips: [
          VehicleTripRow(
            tripId: 'VH-001|exit-1',
            status: VehicleTripStatus.completed,
            originGeofenceName: 'Depot North',
            destinationGeofenceName: 'Charging Hub',
            startEventTime: DateTime.utc(2026, 8, 25, 9, 0),
            endEventTime: DateTime.utc(2026, 8, 25, 9, 45),
          ),
          VehicleTripRow(
            tripId: 'VH-001|exit-2',
            status: VehicleTripStatus.inProgress,
            originGeofenceName: 'Charging Hub',
            destinationGeofenceName: null,
            startEventTime: DateTime.utc(2026, 8, 25, 10, 15),
            endEventTime: null,
          ),
        ],
      );

      final cubit = VehicleDetailCubit(
        database,
        repository: _StubVehicleDetailRepository(snapshot),
      );
      final alertsBloc = AlertsBloc(
        database,
        repository: _StubAlertsRepository(),
      );
      final shellTabController = ShellTabController();
      await alertsBloc.refresh();

      await tester.pumpWidget(
        MaterialApp(
          home: ListenableProvider<ShellTabController>.value(
            value: shellTabController,
            child: MultiBlocProvider(
              providers: [
                BlocProvider.value(value: cubit),
                BlocProvider.value(value: alertsBloc),
              ],
              child: const VehicleDetailPage(vehicleId: 'VH-001'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Readings Register'), findsOneWidget);
      expect(find.text('Current geofence: Charging Hub'), findsOneWidget);
      expect(find.byKey(const ValueKey('reading-row-soc')), findsOneWidget);
      expect(find.byKey(const ValueKey('reading-row-range')), findsOneWidget);
      expect(find.byKey(const ValueKey('reading-row-speed')), findsOneWidget);
      expect(find.byKey(const ValueKey('reading-row-battery_temp')), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('reading-row-odometer')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byKey(const ValueKey('reading-row-odometer')), findsOneWidget);

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('reading-row-last_ping')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byKey(const ValueKey('reading-row-last_ping')), findsOneWidget);

      expect(find.text('ALERT'), findsNWidgets(2));
      expect(find.text('STALE'), findsNWidgets(2));
      expect(find.text('NORMAL'), findsOneWidget);

      expect(find.byKey(const ValueKey('reading-value-odometer')), findsOneWidget);
      expect(find.text('—'), findsOneWidget);
      expect(find.byKey(const ValueKey('reading-pill-odometer')), findsNothing);

      await tester.scrollUntilVisible(
        find.text('History & Trips'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('History & Trips'), findsOneWidget);
      expect(find.text('SOC History'), findsOneWidget);
      expect(find.text('55.0%'), findsOneWidget);
      expect(find.text('42.0%'), findsOneWidget);

      await tester.tap(find.text('Recent Trips'));
      await tester.pumpAndSettle();
      expect(find.text('Recent Trips'), findsOneWidget);
      expect(find.text('Depot North -> Charging Hub'), findsOneWidget);
      expect(find.text('Charging Hub -> Pending entry'), findsOneWidget);
      expect(find.text('COMPLETED'), findsOneWidget);
      expect(find.text('IN PROGRESS'), findsOneWidget);

      await tester.tap(find.byTooltip('Open alerts'));
      await tester.pumpAndSettle();
      expect(shellTabController.value, 1);

      await cubit.close();
      await alertsBloc.close();
    },
  );
}
