enum VehicleReadingVerdict { none, normal, alert, stale }

enum VehicleSignalKey {
  soc,
  rangeKm,
  speed,
  batteryTemp,
  odometer,
  lastPing,
}

class VehicleIdentity {
  const VehicleIdentity({
    required this.vehicleId,
    required this.regNumber,
    required this.model,
  });

  final String vehicleId;
  final String regNumber;
  final String model;
}

class VehicleReadingRow {
  const VehicleReadingRow({
    required this.signal,
    required this.label,
    required this.value,
    required this.eventTime,
    required this.ageSeconds,
    required this.verdict,
  });

  final VehicleSignalKey signal;
  final String label;
  final double? value;
  final DateTime? eventTime;
  final int? ageSeconds;
  final VehicleReadingVerdict verdict;

  bool get hasReported => eventTime != null;
}

class SocHistoryPoint {
  const SocHistoryPoint({
    required this.eventTime,
    required this.soc,
  });

  final DateTime eventTime;
  final double soc;
}

class VehicleDetailSnapshot {
  const VehicleDetailSnapshot({
    required this.identity,
    required this.currentGeofenceName,
    required this.readings,
    required this.socHistory,
  });

  final VehicleIdentity identity;
  final String currentGeofenceName;
  final List<VehicleReadingRow> readings;
  final List<SocHistoryPoint> socHistory;
}
