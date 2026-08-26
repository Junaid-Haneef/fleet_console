enum FleetVehicleStatus { offline, moving, idle, stopped }

enum FleetFilter { all, moving, idle, stopped, offline }

enum AlertBadgeSeverity { none, warning, critical }

class FleetVehicleRow {
  const FleetVehicleRow({
    required this.vehicleId,
    required this.regNumber,
    required this.model,
    required this.currentGeofenceName,
    required this.soc,
    required this.rangeKm,
    required this.status,
    required this.alertSeverity,
  });

  final String vehicleId;
  final String regNumber;
  final String model;
  final String currentGeofenceName;
  final double? soc;
  final double? rangeKm;
  final FleetVehicleStatus status;
  final AlertBadgeSeverity alertSeverity;
}

class FleetFilterCounts {
  const FleetFilterCounts({
    required this.all,
    required this.moving,
    required this.idle,
    required this.stopped,
    required this.offline,
  });

  const FleetFilterCounts.zero()
    : all = 0,
      moving = 0,
      idle = 0,
      stopped = 0,
      offline = 0;

  final int all;
  final int moving;
  final int idle;
  final int stopped;
  final int offline;

  int forFilter(FleetFilter filter) {
    switch (filter) {
      case FleetFilter.all:
        return all;
      case FleetFilter.moving:
        return moving;
      case FleetFilter.idle:
        return idle;
      case FleetFilter.stopped:
        return stopped;
      case FleetFilter.offline:
        return offline;
    }
  }
}

class FleetSnapshot {
  const FleetSnapshot({required this.rows, required this.counts});

  final List<FleetVehicleRow> rows;
  final FleetFilterCounts counts;
}
