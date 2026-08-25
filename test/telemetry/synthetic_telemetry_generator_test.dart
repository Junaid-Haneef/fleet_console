import 'package:flutter_test/flutter_test.dart';

import 'package:fleet_console/src/features/telemetry/data/synthetic_telemetry_generator.dart';
import 'package:fleet_console/src/features/telemetry/domain/telemetry_replay_options.dart';

void main() {
  group('SyntheticTelemetryGenerator', () {
    test('is deterministic for same seed and options', () {
      const generator = SyntheticTelemetryGenerator();
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
      const generator = SyntheticTelemetryGenerator();
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
  });
}
