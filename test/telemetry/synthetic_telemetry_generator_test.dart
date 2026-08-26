import 'package:flutter_test/flutter_test.dart';

import 'package:fleet_console/src/features/telemetry/data/synthetic_telemetry_generator.dart';
import 'package:fleet_console/src/features/telemetry/models/telemetry_packet.dart';
import 'package:fleet_console/src/features/telemetry/models/telemetry_replay_options.dart';

void main() {
  group('SyntheticTelemetryGenerator', () {
    test('is deterministic for same seed and options', () {
      final generator = SyntheticTelemetryGenerator(
        utcNow: () => DateTime.utc(2026, 8, 25, 12, 0),
      );
      const options = TelemetryReplayOptions(
        seed: 99,
        vehicleCount: 3,
        packetsPerVehicle: 6,
        duplicateRate: 0.4,
        lateRate: 0.5,
        missingRate: 0.2,
      );

      final first = generator.generate(options);
      final second = generator.generate(options);

      expect(first.seedVehicles.length, second.seedVehicles.length);
      expect(first.packetsByArrival.length, second.packetsByArrival.length);
      expect(first.droppedPacketCount, second.droppedPacketCount);
      expect(first.duplicatePacketCount, second.duplicatePacketCount);

      for (var i = 0; i < first.packetsByArrival.length; i++) {
        final a = first.packetsByArrival[i];
        final b = second.packetsByArrival[i];
        expect(a.packetId, b.packetId);
        expect(a.vehicleId, b.vehicleId);
        expect(a.eventTime, b.eventTime);
        expect(a.receivedTime, b.receivedTime);
        expect(a.scalarSignals, b.scalarSignals);
      }
    });

    test('generates flaky arrivals with duplicates, missing, and late packets', () {
      final generator = SyntheticTelemetryGenerator(
        utcNow: () => DateTime.utc(2026, 8, 25, 12, 0),
      );
      const options = TelemetryReplayOptions(
        seed: 7,
        vehicleCount: 2,
        packetsPerVehicle: 12,
        duplicateRate: 0.7,
        lateRate: 0.8,
        missingRate: 0.3,
      );

      final batch = generator.generate(options);

      expect(batch.duplicatePacketCount, greaterThan(0));
      expect(batch.droppedPacketCount, greaterThan(0));

      var hasLate = false;
      for (final packet in batch.packetsByArrival) {
        if (packet.receivedTime.isAfter(packet.eventTime.add(const Duration(minutes: 2)))) {
          hasLate = true;
          break;
        }
      }
      expect(hasLate, isTrue);

      var outOfOrderByEventTime = false;
      for (var i = 1; i < batch.packetsByArrival.length; i++) {
        if (batch.packetsByArrival[i].eventTime.isBefore(batch.packetsByArrival[i - 1].eventTime)) {
          outOfOrderByEventTime = true;
          break;
        }
      }
      expect(outOfOrderByEventTime, isTrue);
    });

    test('latest packets cover mixed fleet statuses and alerts', () {
      final now = DateTime.utc(2026, 8, 25, 12, 0);
      final generator = SyntheticTelemetryGenerator(utcNow: () => now);
      const options = TelemetryReplayOptions(
        seed: 23,
        vehicleCount: 8,
        packetsPerVehicle: 8,
        duplicateRate: 0,
        lateRate: 0,
        missingRate: 0,
      );

      final batch = generator.generate(options);

      final latestByVehicle = <String, TelemetryPacket>{};
      for (final packet in batch.packetsByArrival) {
        final previous = latestByVehicle[packet.vehicleId];
        if (previous == null || packet.eventTime.isAfter(previous.eventTime)) {
          latestByVehicle[packet.vehicleId] = packet;
        }
      }

      final statuses = <String>{};
      final severities = <String>{};
      final cutoff = now.subtract(const Duration(minutes: 10));

      for (final packet in latestByVehicle.values) {
        final speed = packet.scalarSignals['speed']!;
        final ignition = packet.scalarSignals['ignition']!;
        final soc = packet.scalarSignals['soc']!;
        final batteryTemp = packet.scalarSignals['battery_temp']!;

        if (packet.eventTime.isBefore(cutoff)) {
          statuses.add('OFFLINE');
        } else if (speed > 0) {
          statuses.add('MOVING');
        } else if (speed == 0 && ignition > 0) {
          statuses.add('IDLE');
        } else {
          statuses.add('STOPPED');
        }

        if (soc < 10 || batteryTemp > 45) {
          severities.add('CRITICAL');
        } else if (soc < 20) {
          severities.add('WARNING');
        } else {
          severities.add('NONE');
        }
      }

      expect(statuses, containsAll(<String>['MOVING', 'IDLE', 'STOPPED', 'OFFLINE']));
      expect(severities, containsAll(<String>['WARNING', 'CRITICAL']));
    });
  });
}
