import 'package:flutter_test/flutter_test.dart';

import 'package:fleet_console/src/core/database/app_database.dart';
import 'package:fleet_console/src/features/fleet/data/fleet_home_repository.dart';
import 'package:fleet_console/src/features/fleet/models/fleet_home_models.dart';
import 'package:fleet_console/src/features/fleet/cubit/fleet_home_cubit.dart';

class _FakeDatabase {
  Future<void> dispose() async {}
}

class _FakeConnection {
  Future<void> execute(String sql) async {}

  Future<dynamic> query(String sql) async => throw UnimplementedError();

  Future<void> dispose() async {}
}

class _StubFleetHomeRepository extends FleetHomeRepository {
  _StubFleetHomeRepository(this._snapshot, {this.shouldThrow = false})
    : super(
        AppDatabase(
          databasePathResolver: () async => 'memory://unused',
          duckDbOpen: (_) async => _FakeDatabase(),
          duckDbConnect: (_) async => _FakeConnection(),
        ),
      );

  final FleetSnapshot _snapshot;
  final bool shouldThrow;

  @override
  Future<FleetSnapshot> fetchSnapshot() async {
    if (shouldThrow) {
      throw StateError('query failed');
    }
    return _snapshot;
  }
}

void main() {
  group('FleetHomeCubit', () {
    late AppDatabase database;

    setUp(() {
      database = AppDatabase(
        databasePathResolver: () async => 'memory://fleet-cubit-test',
        duckDbOpen: (_) async => _FakeDatabase(),
        duckDbConnect: (_) async => _FakeConnection(),
      );
    });

    test('refresh loads rows and counts', () async {
      final snapshot = FleetSnapshot(
        rows: const [
          FleetVehicleRow(
            vehicleId: 'VH-001',
            regNumber: 'KA-01-AB-1001',
            model: 'Model A',
            currentGeofenceName: 'Depot North',
            soc: 48,
            rangeKm: 120,
            status: FleetVehicleStatus.moving,
            alertSeverity: AlertBadgeSeverity.none,
          ),
        ],
        counts: const FleetFilterCounts(
          all: 1,
          moving: 1,
          idle: 0,
          stopped: 0,
          offline: 0,
        ),
      );

      final cubit = FleetHomeCubit(
        database,
        repository: _StubFleetHomeRepository(snapshot),
      );

      await cubit.refresh();

      expect(cubit.state.status, FleetHomeStatus.ready);
      expect(cubit.state.visibleRows, hasLength(1));
      expect(cubit.state.counts.moving, 1);
      expect(cubit.state.statusMessage, contains('Loaded 1 vehicles'));

      cubit.selectFilter(FleetFilter.offline);
      expect(cubit.state.visibleRows, isEmpty);

      await cubit.close();
    });

    test('refresh emits error state when query fails', () async {
      final cubit = FleetHomeCubit(
        database,
        repository: _StubFleetHomeRepository(
          const FleetSnapshot(rows: [], counts: FleetFilterCounts.zero()),
          shouldThrow: true,
        ),
      );

      await cubit.refresh();

      expect(cubit.state.status, FleetHomeStatus.error);
      expect(cubit.state.errorMessage, contains('query failed'));

      await cubit.close();
    });
  });
}
