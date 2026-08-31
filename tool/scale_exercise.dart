import 'dart:io';

import 'package:flutter/widgets.dart';

import 'package:fleet_console/src/core/database/app_database.dart';
import 'package:fleet_console/src/features/alerts/data/alerts_repository.dart';
import 'package:fleet_console/src/features/fleet/data/fleet_home_repository.dart';
import 'package:fleet_console/src/features/geofences/data/geofence_transition_processor.dart';
import 'package:fleet_console/src/features/telemetry/data/telemetry_repository.dart';
import 'package:fleet_console/src/features/telemetry/models/telemetry_replay_options.dart';
import 'package:fleet_console/src/features/trips/data/trips_repository.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  final options = _parseOptions(args);
  final shouldReset = !args.contains('--no-reset');
  final queryRuns = _readIntArg(args, '--query-runs', 50);

  final database = AppDatabase();
  await database.initialize();

  final telemetryRepository = TelemetryRepository(database);
  final transitionProcessor = GeofenceTransitionProcessor(database);
  final tripsRepository = TripsRepository(database);
  final alertsRepository = AlertsRepository(database);
  final fleetRepository = FleetHomeRepository(database);

  try {
    if (shouldReset) {
      stdout.writeln('Resetting operational data...');
      await database.resetOperationalData();
    }

    stdout.writeln('Running replay with options:');
    stdout.writeln(_formatOptions(options));

    final replayWatch = Stopwatch()..start();
    final summary = await telemetryRepository.replaySyntheticTelemetry(options);
    await transitionProcessor.recomputeConfirmedTransitions();
    await tripsRepository.recomputeTripsFromConfirmedTransitions();
    await alertsRepository.recomputeActiveAlertsFromLatestReadings();
    replayWatch.stop();

    final counts = await _readCounts(database);
    final latency = await _measureFleetQueryLatency(
      fleetRepository,
      runs: queryRuns,
    );

    stdout.writeln('');
    stdout.writeln('Scale Exercise Report');
    stdout.writeln('---------------------');
    stdout.writeln('database: ${database.databasePath ?? 'unknown'}');
    stdout.writeln('reset_performed: $shouldReset');
    stdout.writeln('replay_elapsed_ms: ${replayWatch.elapsedMilliseconds}');
    stdout.writeln('packets_processed: ${summary.packetsProcessed}');
    stdout.writeln('generated_duplicates: ${summary.packetDuplicatesGenerated}');
    stdout.writeln('dropped_missing_packets: ${summary.packetsDroppedAsMissing}');
    stdout.writeln('vehicle_rows: ${counts.vehicleRows}');
    stdout.writeln('signal_rows: ${counts.signalRows}');
    stdout.writeln('location_rows: ${counts.locationRows}');
    stdout.writeln('fleet_query_p50_us: ${latency.p50Microseconds}');
    stdout.writeln('fleet_query_p95_us: ${latency.p95Microseconds}');
    stdout.writeln('fleet_query_runs: ${latency.sampleCount}');

    if (counts.signalRows < 2000000) {
      stdout.writeln('warning: stored signal rows are below 2,000,000 target.');
    }
  } finally {
    await database.close();
  }
}

TelemetryReplayOptions _parseOptions(List<String> args) {
  return TelemetryReplayOptions(
    seed: _readIntArg(args, '--seed', 42),
    vehicleCount: _readIntArg(args, '--vehicle-count', 500),
    packetsPerVehicle: _readIntArg(args, '--packets-per-vehicle', 667),
    duplicateRate: _readDoubleArg(args, '--duplicate-rate', 0.20),
    lateRate: _readDoubleArg(args, '--late-rate', 0.25),
    missingRate: _readDoubleArg(args, '--missing-rate', 0.00),
  );
}

int _readIntArg(List<String> args, String name, int fallback) {
  final index = args.indexOf(name);
  if (index < 0 || index + 1 >= args.length) {
    return fallback;
  }

  final parsed = int.tryParse(args[index + 1]);
  return parsed ?? fallback;
}

double _readDoubleArg(List<String> args, String name, double fallback) {
  final index = args.indexOf(name);
  if (index < 0 || index + 1 >= args.length) {
    return fallback;
  }

  final parsed = double.tryParse(args[index + 1]);
  return parsed ?? fallback;
}

String _formatOptions(TelemetryReplayOptions options) {
  return '  seed=${options.seed}\n'
      '  vehicle_count=${options.vehicleCount}\n'
      '  packets_per_vehicle=${options.packetsPerVehicle}\n'
      '  duplicate_rate=${options.duplicateRate}\n'
      '  late_rate=${options.lateRate}\n'
      '  missing_rate=${options.missingRate}';
}

Future<_StorageCounts> _readCounts(AppDatabase database) async {
  final vehicleRows = await database.query('SELECT COUNT(*) FROM vehicles');
  final signalRows = await database.query('SELECT COUNT(*) FROM signal_readings');
  final locationRows = await database.query('SELECT COUNT(*) FROM location_readings');

  int parse(List<List<Object?>> rows) {
    if (rows.isEmpty || rows.first.isEmpty) {
      return 0;
    }
    final first = rows.first.first;
    return first is num ? first.toInt() : 0;
  }

  return _StorageCounts(
    vehicleRows: parse(vehicleRows),
    signalRows: parse(signalRows),
    locationRows: parse(locationRows),
  );
}

Future<_QueryLatencyStats> _measureFleetQueryLatency(
  FleetHomeRepository repository, {
  required int runs,
}) async {
  final durations = <int>[];
  for (var i = 0; i < runs; i++) {
    final watch = Stopwatch()..start();
    await repository.fetchSnapshot();
    watch.stop();
    durations.add(watch.elapsedMicroseconds);
  }

  durations.sort();
  final p50Index = (durations.length * 0.50).floor().clamp(0, durations.length - 1);
  final p95Index = (durations.length * 0.95).floor().clamp(0, durations.length - 1);

  return _QueryLatencyStats(
    p50Microseconds: durations[p50Index],
    p95Microseconds: durations[p95Index],
    sampleCount: durations.length,
  );
}

class _StorageCounts {
  const _StorageCounts({
    required this.vehicleRows,
    required this.signalRows,
    required this.locationRows,
  });

  final int vehicleRows;
  final int signalRows;
  final int locationRows;
}

class _QueryLatencyStats {
  const _QueryLatencyStats({
    required this.p50Microseconds,
    required this.p95Microseconds,
    required this.sampleCount,
  });

  final int p50Microseconds;
  final int p95Microseconds;
  final int sampleCount;
}
