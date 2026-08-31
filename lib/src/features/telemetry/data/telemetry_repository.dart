import 'package:fleet_console/src/features/telemetry/models/telemetry_packet.dart';

import '../../../core/database/app_database.dart';
import '../models/telemetry_replay_options.dart';
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

    await _upsertSeedVehicles(batch.seedVehicles);
    await _persistPackets(batch.packetsByArrival);

    return TelemetryReplaySummary(
      packetsProcessed: batch.packetsByArrival.length,
      packetDuplicatesGenerated: batch.duplicatePacketCount,
      packetsDroppedAsMissing: batch.droppedPacketCount,
    );
  }

  Future<void> upsertVehicleIdentity({
    required String vehicleId,
    required String regNumber,
    required String model,
  }) async {
    await _upsertSeedVehicles([
      SeedVehicle(
        vehicleId: vehicleId,
        regNumber: regNumber,
        model: model,
      ),
    ]);
  }

  Future<void> appendManualTelemetryRow({
    required String vehicleId,
    required DateTime eventTime,
    required double soc,
    required double speed,
    required double ignition,
    required double batteryTemp,
    required double odometer,
    double? rangeKm,
    double? lat,
    double? lon,
    double accuracyM = 8.0,
  }) async {
    final eventUtc = eventTime.toUtc();
    final packetId =
        'manual_${vehicleId}_${eventUtc.microsecondsSinceEpoch}_${DateTime.now().toUtc().microsecondsSinceEpoch}';

    await _persistPackets([
      TelemetryPacket(
        packetId: packetId,
        vehicleId: vehicleId,
        eventTime: eventUtc,
        receivedTime: eventUtc.add(const Duration(seconds: 2)),
        scalarSignals: {
          'soc': soc,
          'range': rangeKm ?? soc * 2.6,
          'speed': speed,
          'battery_temp': batteryTemp,
          'odometer': odometer,
          'ignition': ignition,
        },
        location: lat != null && lon != null
            ? TelemetryLocation(
                lat: lat,
                lon: lon,
                accuracyM: accuracyM,
              )
            : null,
      ),
    ]);
  }

  /// Inserts a deterministic single-vehicle path that produces confirmed
  /// transitions resulting in one completed trip and one in-progress trip.
  Future<TelemetryReplaySummary> replaySingleVehicleTripScenario({
    String vehicleId = 'VH-TRIP-001',
    String regNumber = 'KA-01-TR-1001',
    String model = 'E-Truck X1',
  }) async {
    final seedVehicles = [
      SeedVehicle(
        vehicleId: vehicleId,
        regNumber: regNumber,
        model: model,
      ),
    ];

    final now = DateTime.now().toUtc();
    // Keep the final packet within the 10-minute OFFLINE threshold while
    // still leaving enough event-time room for transition confirmation.
    final base = now.subtract(const Duration(minutes: 6));
    final packets = <TelemetryPacket>[
      _scenarioPacket(
        packetId: '${vehicleId}_trip_00',
        vehicleId: vehicleId,
        eventTime: base,
        lat: 12.971600,
        lon: 77.594600,
        speed: 0,
        ignition: 1,
      ),
      _scenarioPacket(
        packetId: '${vehicleId}_trip_01',
        vehicleId: vehicleId,
        eventTime: base.add(const Duration(seconds: 30)),
        lat: 12.971630,
        lon: 77.594630,
        speed: 2,
        ignition: 1,
      ),
      _scenarioPacket(
        packetId: '${vehicleId}_trip_02',
        vehicleId: vehicleId,
        eventTime: base.add(const Duration(minutes: 1)),
        lat: 12.971570,
        lon: 77.594570,
        speed: 3,
        ignition: 1,
      ),
      // 3 outside samples -> confirm EXIT from depot, trip starts.
      _scenarioPacket(
        packetId: '${vehicleId}_trip_03',
        vehicleId: vehicleId,
        eventTime: base.add(const Duration(minutes: 1, seconds: 30)),
        lat: 12.980500,
        lon: 77.610500,
        speed: 26,
        ignition: 1,
      ),
      _scenarioPacket(
        packetId: '${vehicleId}_trip_04',
        vehicleId: vehicleId,
        eventTime: base.add(const Duration(minutes: 2)),
        lat: 12.980540,
        lon: 77.610550,
        speed: 24,
        ignition: 1,
      ),
      _scenarioPacket(
        packetId: '${vehicleId}_trip_05',
        vehicleId: vehicleId,
        eventTime: base.add(const Duration(minutes: 2, seconds: 30)),
        lat: 12.980580,
        lon: 77.610580,
        speed: 20,
        ignition: 1,
      ),
      // 3 service-yard samples -> confirm ENTER, first trip completes.
      _scenarioPacket(
        packetId: '${vehicleId}_trip_06',
        vehicleId: vehicleId,
        eventTime: base.add(const Duration(minutes: 3)),
        lat: 12.968900,
        lon: 77.587900,
        speed: 12,
        ignition: 1,
      ),
      _scenarioPacket(
        packetId: '${vehicleId}_trip_07',
        vehicleId: vehicleId,
        eventTime: base.add(const Duration(minutes: 3, seconds: 30)),
        lat: 12.968940,
        lon: 77.587940,
        speed: 8,
        ignition: 1,
      ),
      _scenarioPacket(
        packetId: '${vehicleId}_trip_08',
        vehicleId: vehicleId,
        eventTime: base.add(const Duration(minutes: 4)),
        lat: 12.968860,
        lon: 77.587860,
        speed: 4,
        ignition: 1,
      ),
      // 3 outside samples again -> confirm EXIT from service yard,
      // second trip starts and remains IN_PROGRESS (no subsequent ENTER).
      _scenarioPacket(
        packetId: '${vehicleId}_trip_09',
        vehicleId: vehicleId,
        eventTime: base.add(const Duration(minutes: 4, seconds: 30)),
        lat: 12.980620,
        lon: 77.610620,
        speed: 18,
        ignition: 1,
      ),
      _scenarioPacket(
        packetId: '${vehicleId}_trip_10',
        vehicleId: vehicleId,
        eventTime: base.add(const Duration(minutes: 5)),
        lat: 12.980660,
        lon: 77.610660,
        speed: 21,
        ignition: 1,
      ),
      _scenarioPacket(
        packetId: '${vehicleId}_trip_11',
        vehicleId: vehicleId,
        eventTime: base.add(const Duration(minutes: 5, seconds: 30)),
        lat: 12.980700,
        lon: 77.610700,
        speed: 16,
        ignition: 1,
      ),
    ];

    await _upsertSeedVehicles(seedVehicles);
    await _persistPackets(packets);

    return TelemetryReplaySummary(
      packetsProcessed: packets.length,
      packetDuplicatesGenerated: 0,
      packetsDroppedAsMissing: 0,
    );
  }

  Future<void> _upsertSeedVehicles(List<SeedVehicle> vehicles) async {
    for (final vehicle in vehicles) {
      await _database.execute('''
        INSERT INTO vehicles (vehicle_id, reg_number, model)
        VALUES (${_q(vehicle.vehicleId)}, ${_q(vehicle.regNumber)}, ${_q(vehicle.model)})
        ON CONFLICT (vehicle_id) DO NOTHING
      ''');
    }
  }

  Future<void> _persistPackets(List<TelemetryPacket> packetsByArrival) async {
    for (final packet in packetsByArrival) {
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
  }

  TelemetryPacket _scenarioPacket({
    required String packetId,
    required String vehicleId,
    required DateTime eventTime,
    required double lat,
    required double lon,
    required double speed,
    required double ignition,
  }) {
    final receivedTime = eventTime.add(const Duration(seconds: 4));
    final soc = speed > 0 ? 34.0 : 36.0;
    return TelemetryPacket(
      packetId: packetId,
      vehicleId: vehicleId,
      eventTime: eventTime,
      receivedTime: receivedTime,
      scalarSignals: {
        'soc': soc,
        'range': soc * 2.6,
        'speed': speed,
        'battery_temp': 33.0,
        'odometer': 12400 + (eventTime.millisecondsSinceEpoch % 10000) / 1000,
        'ignition': ignition,
      },
      location: TelemetryLocation(
        lat: lat,
        lon: lon,
        accuracyM: 8.0,
      ),
    );
  }

  String _q(String input) => "'${input.replaceAll("'", "''")}'";

  String _ts(DateTime value) => value.toUtc().toIso8601String();
}
