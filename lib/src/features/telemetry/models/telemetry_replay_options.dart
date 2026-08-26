class TelemetryReplayOptions {
  const TelemetryReplayOptions({
    this.seed = 42,
    this.vehicleCount = 8,
    this.packetsPerVehicle = 16,
    this.duplicateRate = 0.2,
    this.lateRate = 0.25,
    this.missingRate = 0.1,
  });

  final int seed;
  final int vehicleCount;
  final int packetsPerVehicle;
  final double duplicateRate;
  final double lateRate;
  final double missingRate;
}

class TelemetryReplaySummary {
  const TelemetryReplaySummary({
    required this.packetsProcessed,
    required this.packetDuplicatesGenerated,
    required this.packetsDroppedAsMissing,
  });

  final int packetsProcessed;
  final int packetDuplicatesGenerated;
  final int packetsDroppedAsMissing;
}
