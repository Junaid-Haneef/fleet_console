import 'dart:math';

import '../domain/telemetry_packet.dart';
import '../domain/telemetry_replay_options.dart';

class SyntheticTelemetryGenerator {
  const SyntheticTelemetryGenerator();

  GeneratedTelemetryBatch generate(TelemetryReplayOptions options) {
    final random = Random(options.seed);
    final baseStart = DateTime.utc(2026, 8, 23, 9, 0);

    final basePackets = <TelemetryPacket>[];
    for (var vehicleIndex = 0; vehicleIndex < options.vehicleCount; vehicleIndex++) {
      final vehicleId = _vehicleIdForIndex(vehicleIndex);

      for (var step = 0; step < options.packetsPerVehicle; step++) {
        final eventTime = baseStart.add(Duration(minutes: step));
        final receivedTime = eventTime.add(Duration(seconds: 2 + random.nextInt(4)));

        final speed = (random.nextDouble() * 55).clamp(0, 55);
        final ignition = speed > 0.4 ? 1.0 : 0.0;
        final soc = (88 - (step * 0.4) - random.nextDouble()).clamp(5, 100);
        final range = (soc * 2.6).clamp(10, 380);
        final batteryTemp = (30 + random.nextDouble() * 12).clamp(22, 52);
        final odometer = 12000 + vehicleIndex * 130 + step * 0.8;
        final lat = 12.95 + vehicleIndex * 0.004 + random.nextDouble() * 0.001;
        final lon = 77.56 + vehicleIndex * 0.004 + random.nextDouble() * 0.001;
        final accuracy = (6 + random.nextDouble() * 20).clamp(3, 45);

        basePackets.add(
          TelemetryPacket(
            packetId: 'pkt_${vehicleId}_$step',
            vehicleId: vehicleId,
            eventTime: eventTime,
            receivedTime: receivedTime,
            scalarSignals: {
              'soc': soc.toDouble(),
              'range': range.toDouble(),
              'speed': speed.toDouble(),
              'battery_temp': batteryTemp.toDouble(),
              'odometer': odometer.toDouble(),
              'ignition': ignition,
            },
            location: TelemetryLocation(
              lat: lat.toDouble(),
              lon: lon.toDouble(),
              accuracyM: accuracy.toDouble(),
            ),
          ),
        );
      }
    }

    final arrivals = <TelemetryPacket>[];
    var duplicates = 0;
    var dropped = 0;

    for (final packet in basePackets) {
      if (random.nextDouble() < options.missingRate) {
        dropped += 1;
        continue;
      }

      var adjustedReceived = packet.receivedTime;
      if (random.nextDouble() < options.lateRate) {
        adjustedReceived = adjustedReceived.add(
          Duration(minutes: 2 + random.nextInt(4)),
        );
      }

      final primary = packet.copyWith(receivedTime: adjustedReceived);
      arrivals.add(primary);

      if (random.nextDouble() < options.duplicateRate) {
        duplicates += 1;
        arrivals.add(
          packet.copyWith(
            packetId: '${packet.packetId}_dup_$duplicates',
            receivedTime: adjustedReceived.add(Duration(seconds: 8 + random.nextInt(12))),
          ),
        );
      }
    }

    arrivals.sort((a, b) => a.receivedTime.compareTo(b.receivedTime));

    final seedVehicles = <SeedVehicle>[];
    for (var vehicleIndex = 0; vehicleIndex < options.vehicleCount; vehicleIndex++) {
      seedVehicles.add(
        SeedVehicle(
          vehicleId: _vehicleIdForIndex(vehicleIndex),
          regNumber: _regNumberForIndex(vehicleIndex),
          model: vehicleIndex.isEven ? 'E-Truck X1' : 'E-Truck X2',
        ),
      );
    }

    return GeneratedTelemetryBatch(
      seedVehicles: seedVehicles,
      packetsByArrival: arrivals,
      droppedPacketCount: dropped,
      duplicatePacketCount: duplicates,
    );
  }

  String _vehicleIdForIndex(int index) => 'VH-${(index + 1).toString().padLeft(3, '0')}';

  String _regNumberForIndex(int index) {
    final suffix = (1200 + index).toString();
    return 'KA-01-AB-$suffix';
  }
}

class SeedVehicle {
  const SeedVehicle({
    required this.vehicleId,
    required this.regNumber,
    required this.model,
  });

  final String vehicleId;
  final String regNumber;
  final String model;
}

class GeneratedTelemetryBatch {
  const GeneratedTelemetryBatch({
    required this.seedVehicles,
    required this.packetsByArrival,
    required this.droppedPacketCount,
    required this.duplicatePacketCount,
  });

  final List<SeedVehicle> seedVehicles;
  final List<TelemetryPacket> packetsByArrival;
  final int droppedPacketCount;
  final int duplicatePacketCount;
}
