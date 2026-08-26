import 'package:flutter_test/flutter_test.dart';

import 'package:fleet_console/src/core/database/app_database.dart';
import 'package:fleet_console/src/features/telemetry/data/telemetry_repository.dart';
import 'package:fleet_console/src/features/telemetry/models/telemetry_replay_options.dart';

class _FakeDatabase {
  bool disposed = false;

  Future<void> dispose() async {
    disposed = true;
  }
}

class _FakeQueryResult {
  _FakeQueryResult(this.rows);

  final List<List<Object?>> rows;

  List<List<Object?>> fetchAll() => rows;
}

class _SignalRecord {
  _SignalRecord({required this.eventTime, required this.receivedTime});

  final DateTime eventTime;
  final DateTime receivedTime;
}

class _FakeConnection {
  final Map<String, String> appMeta = {};
  final Set<String> vehicles = <String>{};
  final Map<String, _SignalRecord> signalKeys = <String, _SignalRecord>{};
  final Set<String> locationKeys = <String>{};

  Future<void> execute(String sql) async {
    if (sql.contains('INSERT INTO app_meta') && sql.contains("'schema_version'")) {
      appMeta['schema_version'] = sql.contains("'phase2'") ? 'phase2' : 'phase1';
      return;
    }

    final vehicleInsert = RegExp(
      r"INSERT INTO vehicles[\s\S]*?VALUES \('([^']+)'",
      multiLine: true,
    ).firstMatch(sql);
    if (vehicleInsert != null) {
      vehicles.add(vehicleInsert.group(1)!);
      return;
    }

    final signalInsert = RegExp(
      r"INSERT INTO signal_readings[\s\S]*?VALUES \(\s*'([^']+)'\s*,\s*'([^']+)'\s*,\s*'([^']+)'\s*,\s*([0-9eE+\-.]+)\s*,\s*'([^']*)'\s*,\s*'([^']+)'\s*\)",
      multiLine: true,
    ).firstMatch(sql);
    if (signalInsert != null) {
      final vehicleId = signalInsert.group(1)!;
      final eventTime = signalInsert.group(2)!;
      final signalName = signalInsert.group(3)!;
      final receivedTime = DateTime.parse(signalInsert.group(6)!);
      final key = '$vehicleId|$eventTime|$signalName';
      signalKeys.putIfAbsent(
        key,
        () => _SignalRecord(eventTime: DateTime.parse(eventTime), receivedTime: receivedTime),
      );
      return;
    }

    final locationInsert = RegExp(
      r"INSERT INTO location_readings[\s\S]*?VALUES \(\s*'([^']+)'\s*,\s*'([^']+)'",
      multiLine: true,
    ).firstMatch(sql);
    if (locationInsert != null) {
      final vehicleId = locationInsert.group(1)!;
      final eventTime = locationInsert.group(2)!;
      locationKeys.add('$vehicleId|$eventTime');
      return;
    }
  }

  Future<_FakeQueryResult> query(String sql) async {
    if (sql.contains('SELECT COUNT(*) FROM vehicles')) {
      return _FakeQueryResult([
        [vehicles.length],
      ]);
    }
    if (sql.contains('SELECT COUNT(*) FROM signal_readings')) {
      return _FakeQueryResult([
        [signalKeys.length],
      ]);
    }
    if (sql.contains('SELECT COUNT(*) FROM location_readings')) {
      return _FakeQueryResult([
        [locationKeys.length],
      ]);
    }
    if (sql.contains('WHERE received_time > event_time + INTERVAL 1 MINUTE')) {
      final count = signalKeys.values
          .where((row) => row.receivedTime.isAfter(row.eventTime.add(const Duration(minutes: 1))))
          .length;
      return _FakeQueryResult([
        [count],
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

class _Counts {
  const _Counts({
    required this.vehicleRows,
    required this.signalRows,
    required this.locationRows,
  });

  final int vehicleRows;
  final int signalRows;
  final int locationRows;
}

Future<_Counts> _counts(AppDatabase database) async {
  final vehicleRows = await database.query('SELECT COUNT(*) FROM vehicles');
  final signalRows = await database.query('SELECT COUNT(*) FROM signal_readings');
  final locationRows = await database.query('SELECT COUNT(*) FROM location_readings');

  return _Counts(
    vehicleRows: (vehicleRows.first.first as num).toInt(),
    signalRows: (signalRows.first.first as num).toInt(),
    locationRows: (locationRows.first.first as num).toInt(),
  );
}

void main() {
  group('TelemetryRepository replay', () {
    late AppDatabase database;
    late TelemetryRepository repository;

    setUp(() async {
      final fakeDb = _FakeDatabase();
      final fakeConn = _FakeConnection();
      database = AppDatabase(
        databasePathResolver: () async => 'memory://phase2-test',
        duckDbOpen: (_) async => fakeDb,
        duckDbConnect: (_) async => fakeConn,
      );
      await database.initialize();
      repository = TelemetryRepository(database);
    });

    tearDown(() async {
      await database.close();
    });

    test('replaying identical synthetic stream is idempotent', () async {
      const options = TelemetryReplayOptions(
        seed: 33,
        vehicleCount: 4,
        packetsPerVehicle: 8,
        duplicateRate: 0.6,
        lateRate: 0.5,
        missingRate: 0.2,
      );

      await repository.replaySyntheticTelemetry(options);
      final firstCounts = await _counts(database);

      await repository.replaySyntheticTelemetry(options);
      final secondCounts = await _counts(database);

      expect(secondCounts.signalRows, firstCounts.signalRows);
      expect(secondCounts.locationRows, firstCounts.locationRows);
      expect(secondCounts.vehicleRows, firstCounts.vehicleRows);
    });

    test('stores event and received time distinctly for late packets', () async {
      const options = TelemetryReplayOptions(
        seed: 19,
        vehicleCount: 2,
        packetsPerVehicle: 6,
        duplicateRate: 0,
        lateRate: 1,
        missingRate: 0,
      );

      await repository.replaySyntheticTelemetry(options);

      final rows = await database.query('''
        SELECT COUNT(*)
        FROM signal_readings
        WHERE received_time > event_time + INTERVAL 1 MINUTE
      ''');

      expect(rows.first.first, greaterThan(0));
    });
  });
}
