import '../../../core/database/app_database.dart';
import '../domain/telemetry_replay_options.dart';
import 'synthetic_telemetry_generator.dart';

class TelemetryRepository {
  TelemetryRepository(this._database, {SyntheticTelemetryGenerator? generator})
    : _generator = generator ?? SyntheticTelemetryGenerator();

  final AppDatabase _database;
  final SyntheticTelemetryGenerator _generator;

  Future<TelemetryReplaySummary> replaySyntheticTelemetry(
    TelemetryReplayOptions options,
  ) async {
    final batch = _generator.generate(options);

    for (final vehicle in batch.seedVehicles) {
      await _database.execute('''
        INSERT INTO vehicles (vehicle_id, reg_number, model)
        VALUES (${_q(vehicle.vehicleId)}, ${_q(vehicle.regNumber)}, ${_q(vehicle.model)})
        ON CONFLICT (vehicle_id) DO NOTHING
      ''');
    }

    for (final packet in batch.packetsByArrival) {
      for (final entry in packet.scalarSignals.entries) {
        await _database.execute('''
          INSERT INTO signal_readings (
            vehicle_id,
            event_time,
            signal_name,
            value,
            packet_id,
            received_time
          )
          VALUES (
            ${_q(packet.vehicleId)},
            ${_q(_ts(packet.eventTime))},
            ${_q(entry.key)},
            ${entry.value},
            ${_q(packet.packetId)},
            ${_q(_ts(packet.receivedTime))}
          )
          ON CONFLICT (vehicle_id, event_time, signal_name) DO NOTHING
        ''');
      }

      final location = packet.location;
      if (location != null) {
        await _database.execute('''
          INSERT INTO location_readings (
            vehicle_id,
            event_time,
            lat,
            lon,
            accuracy_m,
            packet_id,
            received_time
          )
          VALUES (
            ${_q(packet.vehicleId)},
            ${_q(_ts(packet.eventTime))},
            ${location.lat},
            ${location.lon},
            ${location.accuracyM},
            ${_q(packet.packetId)},
            ${_q(_ts(packet.receivedTime))}
          )
          ON CONFLICT (vehicle_id, event_time) DO NOTHING
        ''');
      }
    }

    return TelemetryReplaySummary(
      packetsProcessed: batch.packetsByArrival.length,
      packetDuplicatesGenerated: batch.duplicatePacketCount,
      packetsDroppedAsMissing: batch.droppedPacketCount,
    );
  }

  String _q(String input) => "'${input.replaceAll("'", "''")}'";

  String _ts(DateTime value) => value.toUtc().toIso8601String();
}
