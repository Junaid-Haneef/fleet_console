class TelemetryPacket {
  const TelemetryPacket({
    required this.packetId,
    required this.vehicleId,
    required this.eventTime,
    required this.receivedTime,
    required this.scalarSignals,
    this.location,
  });

  final String packetId;
  final String vehicleId;
  final DateTime eventTime;
  final DateTime receivedTime;
  final Map<String, double> scalarSignals;
  final TelemetryLocation? location;

  TelemetryPacket copyWith({
    String? packetId,
    String? vehicleId,
    DateTime? eventTime,
    DateTime? receivedTime,
    Map<String, double>? scalarSignals,
    TelemetryLocation? location,
  }) {
    return TelemetryPacket(
      packetId: packetId ?? this.packetId,
      vehicleId: vehicleId ?? this.vehicleId,
      eventTime: eventTime ?? this.eventTime,
      receivedTime: receivedTime ?? this.receivedTime,
      scalarSignals: scalarSignals ?? this.scalarSignals,
      location: location ?? this.location,
    );
  }
}

class TelemetryLocation {
  const TelemetryLocation({
    required this.lat,
    required this.lon,
    required this.accuracyM,
  });

  final double lat;
  final double lon;
  final double accuracyM;
}
