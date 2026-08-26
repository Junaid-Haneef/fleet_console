class GeofenceListItem {
  const GeofenceListItem({
    required this.geofenceId,
    required this.geofenceVersionId,
    required this.name,
    required this.centerLat,
    required this.centerLon,
    required this.radiusM,
    required this.isActive,
    required this.effectiveFrom,
    required this.createdAt,
  });

  final String geofenceId;
  final String geofenceVersionId;
  final String name;
  final double centerLat;
  final double centerLon;
  final double radiusM;
  final bool isActive;
  final DateTime effectiveFrom;
  final DateTime createdAt;
}

class GeofenceVehicleCount {
  const GeofenceVehicleCount({
    required this.geofenceId,
    required this.geofenceName,
    required this.vehicleCount,
    this.isNoGeofence = false,
  });

  final String? geofenceId;
  final String geofenceName;
  final int vehicleCount;
  final bool isNoGeofence;
}

class GeofenceManagementSnapshot {
  const GeofenceManagementSnapshot({
    required this.activeGeofences,
    required this.inactiveGeofences,
    required this.vehicleCounts,
  });

  final List<GeofenceListItem> activeGeofences;
  final List<GeofenceListItem> inactiveGeofences;
  final List<GeofenceVehicleCount> vehicleCounts;
}
