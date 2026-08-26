import 'dart:math';

import '../models/telemetry_packet.dart';
import '../models/telemetry_replay_options.dart';

typedef UtcNow = DateTime Function();

class SyntheticTelemetryGenerator {
  SyntheticTelemetryGenerator({UtcNow? utcNow})
    : _utcNow = utcNow ?? (() => DateTime.now().toUtc());

  final UtcNow _utcNow;

  GeneratedTelemetryBatch generate(TelemetryReplayOptions options) {
    final random = Random(options.seed);
    final rawNowUtc = _utcNow();
    final nowUtc = DateTime.utc(
      rawNowUtc.year,
      rawNowUtc.month,
      rawNowUtc.day,
      rawNowUtc.hour,
      rawNowUtc.minute,
    );

    final basePackets = <TelemetryPacket>[];
    for (var vehicleIndex = 0; vehicleIndex < options.vehicleCount; vehicleIndex++) {
      final vehicleId = _vehicleIdForIndex(vehicleIndex);
      final profile = _profileForVehicle(vehicleIndex);

      final latestEventTime = nowUtc.subtract(Duration(minutes: profile.latestPacketAgeMinutes));
      final seriesStart = latestEventTime.subtract(
        Duration(minutes: options.packetsPerVehicle - 1),
      );

      for (var step = 0; step < options.packetsPerVehicle; step++) {
        final eventTime = seriesStart.add(Duration(minutes: step));
        final receivedTime = eventTime.add(Duration(seconds: 2 + random.nextInt(4)));
        final isLatestStep = step == options.packetsPerVehicle - 1;

        final speed = isLatestStep
            ? profile.latestSpeed
            : (random.nextDouble() * 55).clamp(0, 55).toDouble();
        final ignition = isLatestStep
            ? profile.latestIgnition
            : (speed > 0.4 ? 1.0 : 0.0);
        final soc = isLatestStep
            ? profile.latestSoc
            : (88 - (step * 0.4) - random.nextDouble()).clamp(5, 100).toDouble();
        final range = (soc * 2.6).clamp(10, 380);
        final batteryTemp = isLatestStep
            ? profile.latestBatteryTemp
            : (30 + random.nextDouble() * 12).clamp(22, 52).toDouble();
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
              'soc': soc,
              'range': range.toDouble(),
              'speed': speed,
              'battery_temp': batteryTemp,
              'odometer': odometer,
              'ignition': ignition,
            },
            location: TelemetryLocation(
              lat: lat,
              lon: lon,
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

  _VehicleProfile _profileForVehicle(int vehicleIndex) {
    final statusType = vehicleIndex % 4;
    final alertType = vehicleIndex % 3;

    final latestPacketAgeMinutes = switch (statusType) {
      0 => 2,
      1 => 3,
      2 => 4,
      _ => 20,
    };

    final latestSpeed = switch (statusType) {
      0 => 26.0,
      1 => 0.0,
      2 => 0.0,
      _ => 12.0,
    };

    final latestIgnition = switch (statusType) {
      0 => 1.0,
      1 => 1.0,
      2 => 0.0,
      _ => 1.0,
    };

    final (latestSoc, latestBatteryTemp) = switch (alertType) {
      0 => (66.0, 34.0),
      1 => (16.0, 34.0),
      _ => (8.0, 47.0),
    };

    return _VehicleProfile(
      latestPacketAgeMinutes: latestPacketAgeMinutes,
      latestSpeed: latestSpeed,
      latestIgnition: latestIgnition,
      latestSoc: latestSoc,
      latestBatteryTemp: latestBatteryTemp,
    );
  }
}

class _VehicleProfile {
  const _VehicleProfile({
    required this.latestPacketAgeMinutes,
    required this.latestSpeed,
    required this.latestIgnition,
    required this.latestSoc,
    required this.latestBatteryTemp,
  });

  final int latestPacketAgeMinutes;
  final double latestSpeed;
  final double latestIgnition;
  final double latestSoc;
  final double latestBatteryTemp;
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
