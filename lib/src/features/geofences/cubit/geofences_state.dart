part of 'geofences_cubit.dart';

const Object _noErrorMessageChange = Object();

enum GeofencesStatus { initial, loading, ready, error }

class GeofencesState {
  const GeofencesState({
    required this.status,
    required this.statusMessage,
    required this.activeGeofences,
    required this.inactiveGeofences,
    required this.vehicleCounts,
    required this.errorMessage,
  });

  const GeofencesState.initial()
    : status = GeofencesStatus.initial,
      statusMessage = 'Not loaded',
      activeGeofences = const <GeofenceListItem>[],
      inactiveGeofences = const <GeofenceListItem>[],
      vehicleCounts = const <GeofenceVehicleCount>[],
      errorMessage = null;

  final GeofencesStatus status;
  final String statusMessage;
  final List<GeofenceListItem> activeGeofences;
  final List<GeofenceListItem> inactiveGeofences;
  final List<GeofenceVehicleCount> vehicleCounts;
  final String? errorMessage;

  GeofencesState copyWith({
    GeofencesStatus? status,
    String? statusMessage,
    List<GeofenceListItem>? activeGeofences,
    List<GeofenceListItem>? inactiveGeofences,
    List<GeofenceVehicleCount>? vehicleCounts,
    Object? errorMessage = _noErrorMessageChange,
  }) {
    return GeofencesState(
      status: status ?? this.status,
      statusMessage: statusMessage ?? this.statusMessage,
      activeGeofences: activeGeofences ?? this.activeGeofences,
      inactiveGeofences: inactiveGeofences ?? this.inactiveGeofences,
      vehicleCounts: vehicleCounts ?? this.vehicleCounts,
      errorMessage: identical(errorMessage, _noErrorMessageChange)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}
