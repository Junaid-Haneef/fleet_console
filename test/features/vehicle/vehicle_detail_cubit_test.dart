import 'package:flutter_test/flutter_test.dart';

import 'package:fleet_console/src/core/database/app_database.dart';
import 'package:fleet_console/src/features/vehicle/data/vehicle_detail_repository.dart';
import 'package:fleet_console/src/features/vehicle/models/vehicle_detail_models.dart';
import 'package:fleet_console/src/features/vehicle/cubit/vehicle_detail_cubit.dart';

class _FakeDatabase {
  Future<void> dispose() async {}
}

class _FakeConnection {
  Future<void> execute(String sql) async {}

  Future<dynamic> query(String sql) async => throw UnimplementedError();

  Future<void> dispose() async {}
}

class _StubVehicleDetailRepository extends VehicleDetailRepository {
  _StubVehicleDetailRepository(this._snapshot, {this.shouldThrow = false})
    : super(
        AppDatabase(
          databasePathResolver: () async => 'memory://unused',
          duckDbOpen: (_) async => _FakeDatabase(),
          duckDbConnect: (_) async => _FakeConnection(),
        ),
      );

  final VehicleDetailSnapshot _snapshot;
  final bool shouldThrow;

  @override
  Future<VehicleDetailSnapshot> fetchSnapshot(String vehicleId) async {
    if (shouldThrow) {
      throw StateError('detail query failed');
    }
    return _snapshot;
  }
}

VehicleDetailSnapshot _snapshotFixture() {
  return VehicleDetailSnapshot(
    identity: const VehicleIdentity(
      vehicleId: 'VH-001',
      regNumber: 'KA-01-AB-1001',
      model: 'Model A',
    ),
    currentGeofenceName: 'No geofence',
    readings: const [
      VehicleReadingRow(
        signal: VehicleSignalKey.soc,
        label: 'SOC',
        value: 42,
        eventTime: null,
        ageSeconds: null,
        verdict: VehicleReadingVerdict.none,
      ),
    ],
    socHistory: const [],
    recentTrips: const [],
  );
}

void main() {
  group('VehicleDetailCubit', () {
    late AppDatabase database;

    setUp(() {
      database = AppDatabase(
        databasePathResolver: () async => 'memory://vehicle-detail-cubit-test',
        duckDbOpen: (_) async => _FakeDatabase(),
        duckDbConnect: (_) async => _FakeConnection(),
      );
    });

    test('load emits ready state with snapshot', () async {
      final cubit = VehicleDetailCubit(
        database,
        repository: _StubVehicleDetailRepository(_snapshotFixture()),
      );

      await cubit.load('VH-001');

      expect(cubit.state.status, VehicleDetailStatus.ready);
      expect(cubit.state.vehicleId, 'VH-001');
      expect(cubit.state.snapshot, isNotNull);
      expect(cubit.state.statusMessage, contains('KA-01-AB-1001'));

      await cubit.close();
    });

    test('load emits error state when repository fails', () async {
      final cubit = VehicleDetailCubit(
        database,
        repository: _StubVehicleDetailRepository(
          _snapshotFixture(),
          shouldThrow: true,
        ),
      );

      await cubit.load('VH-001');

      expect(cubit.state.status, VehicleDetailStatus.error);
      expect(cubit.state.errorMessage, contains('detail query failed'));

      await cubit.close();
    });

    test('refresh reloads currently selected vehicle', () async {
      final cubit = VehicleDetailCubit(
        database,
        repository: _StubVehicleDetailRepository(_snapshotFixture()),
      );

      await cubit.load('VH-001');
      expect(cubit.state.status, VehicleDetailStatus.ready);

      await cubit.refresh();

      expect(cubit.state.status, VehicleDetailStatus.ready);
      expect(cubit.state.vehicleId, 'VH-001');

      await cubit.close();
    });
  });
}
