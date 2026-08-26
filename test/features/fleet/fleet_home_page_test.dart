import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fleet_console/src/core/database/app_database.dart';
import 'package:fleet_console/src/features/fleet/data/fleet_home_repository.dart';
import 'package:fleet_console/src/features/fleet/models/fleet_home_models.dart';
import 'package:fleet_console/src/features/fleet/cubit/fleet_home_cubit.dart';
import 'package:fleet_console/src/features/fleet/presentation/fleet_home_page.dart';

class _FakeDatabase {
  Future<void> dispose() async {}
}

class _FakeConnection {
  Future<void> execute(String sql) async {}

  Future<dynamic> query(String sql) async => throw UnimplementedError();

  Future<void> dispose() async {}
}

class _StubFleetHomeRepository extends FleetHomeRepository {
  _StubFleetHomeRepository(this._snapshot)
    : super(
        AppDatabase(
          databasePathResolver: () async => 'memory://unused',
          duckDbOpen: (_) async => _FakeDatabase(),
          duckDbConnect: (_) async => _FakeConnection(),
        ),
      );

  final FleetSnapshot _snapshot;

  @override
  Future<FleetSnapshot> fetchSnapshot() async => _snapshot;
}

void main() {
  testWidgets('renders fleet rows and filter chips with counts', (tester) async {
    final database = AppDatabase(
      databasePathResolver: () async => 'memory://fleet-page-test',
      duckDbOpen: (_) async => _FakeDatabase(),
      duckDbConnect: (_) async => _FakeConnection(),
    );

    final snapshot = FleetSnapshot(
      rows: const [
        FleetVehicleRow(
          vehicleId: 'VH-001',
          regNumber: 'KA-01-AB-1001',
          model: 'Model A',
          currentGeofenceName: 'Depot North',
          soc: 49,
          rangeKm: 110,
          status: FleetVehicleStatus.moving,
          alertSeverity: AlertBadgeSeverity.none,
        ),
        FleetVehicleRow(
          vehicleId: 'VH-002',
          regNumber: 'KA-01-AB-1002',
          model: 'Model B',
          currentGeofenceName: 'No geofence',
          soc: 9,
          rangeKm: 20,
          status: FleetVehicleStatus.offline,
          alertSeverity: AlertBadgeSeverity.critical,
        ),
      ],
      counts: const FleetFilterCounts(
        all: 2,
        moving: 1,
        idle: 0,
        stopped: 0,
        offline: 1,
      ),
    );

    final cubit = FleetHomeCubit(
      database,
      repository: _StubFleetHomeRepository(snapshot),
    );
    await cubit.refresh();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider.value(value: cubit, child: const FleetHomePage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('All (2)'), findsOneWidget);
    expect(find.text('Moving (1)'), findsOneWidget);
    expect(find.text('Offline (1)'), findsOneWidget);

    expect(find.text('KA-01-AB-1001'), findsOneWidget);
    expect(find.text('KA-01-AB-1002'), findsOneWidget);
    expect(find.text('Geofence: Depot North'), findsOneWidget);
    expect(find.text('Geofence: No geofence'), findsOneWidget);
    expect(find.text('MOVING'), findsOneWidget);
    expect(find.text('OFFLINE'), findsOneWidget);
    expect(find.text('Critical'), findsOneWidget);

    final offlineChip = find.widgetWithText(ChoiceChip, 'Offline (1)');
    await tester.ensureVisible(offlineChip);
    await tester.tap(offlineChip);
    await tester.pumpAndSettle();

    expect(find.text('KA-01-AB-1002'), findsOneWidget);
    expect(find.text('KA-01-AB-1001'), findsNothing);

    await cubit.close();
  });

  testWidgets('renders empty state when selected filter has no matches', (tester) async {
    final database = AppDatabase(
      databasePathResolver: () async => 'memory://fleet-page-empty-test',
      duckDbOpen: (_) async => _FakeDatabase(),
      duckDbConnect: (_) async => _FakeConnection(),
    );

    final snapshot = FleetSnapshot(
      rows: const [
        FleetVehicleRow(
          vehicleId: 'VH-001',
          regNumber: 'KA-01-AB-1001',
          model: 'Model A',
          currentGeofenceName: 'No geofence',
          soc: 60,
          rangeKm: 150,
          status: FleetVehicleStatus.stopped,
          alertSeverity: AlertBadgeSeverity.none,
        ),
      ],
      counts: const FleetFilterCounts(
        all: 1,
        moving: 0,
        idle: 0,
        stopped: 1,
        offline: 0,
      ),
    );

    final cubit = FleetHomeCubit(
      database,
      repository: _StubFleetHomeRepository(snapshot),
    );
    await cubit.refresh();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider.value(value: cubit, child: const FleetHomePage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final movingChip = find.widgetWithText(ChoiceChip, 'Moving (0)');
    await tester.ensureVisible(movingChip);
    await tester.tap(movingChip);
    await tester.pumpAndSettle();

    expect(find.text('No vehicles match this filter.'), findsOneWidget);

    await cubit.close();
  });
}
