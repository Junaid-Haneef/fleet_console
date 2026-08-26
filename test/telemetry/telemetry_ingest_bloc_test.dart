import 'package:flutter_test/flutter_test.dart';

import 'package:fleet_console/src/core/database/app_database.dart';
import 'package:fleet_console/src/features/telemetry/bloc/telemetry_ingest_bloc.dart';
import 'package:fleet_console/src/features/telemetry/data/telemetry_repository.dart';
import 'package:fleet_console/src/features/telemetry/models/telemetry_replay_options.dart';

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
    if (sql.contains('SELECT 1 AS ok')) {
      return _FakeQueryResult([
        [1],
      ]);
    }
    return _FakeQueryResult([]);
  }

  Future<void> dispose() async {}
}

class _StubTelemetryRepository extends TelemetryRepository {
  _StubTelemetryRepository(super.database);

  @override
  Future<TelemetryReplaySummary> replaySyntheticTelemetry(
    TelemetryReplayOptions options,
  ) async {
    return const TelemetryReplaySummary(
      packetsProcessed: 12,
      packetDuplicatesGenerated: 4,
      packetsDroppedAsMissing: 2,
    );
  }
}

void main() {
  test('replay request transitions running to success with summary message', () async {
    final fakeDb = _FakeDatabase();
    final fakeConn = _FakeConnection();
    final database = AppDatabase(
      databasePathResolver: () async => 'memory://phase2-bloc-test',
      duckDbOpen: (_) async => fakeDb,
      duckDbConnect: (_) async => fakeConn,
    );
    await database.initialize();

    final bloc = TelemetryIngestBloc(
      database,
      repository: _StubTelemetryRepository(database),
    );

    final states = <TelemetryIngestState>[];
    final sub = bloc.stream.listen(states.add);

    bloc.add(const TelemetryReplayRequested());
    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(states.length, greaterThanOrEqualTo(2));
    expect(states.first.status, TelemetryIngestStatus.running);
    expect(states.last.status, TelemetryIngestStatus.success);
    expect(states.last.message, contains('packets=12'));

    await sub.cancel();
    await bloc.close();
    await database.close();
  });
}
