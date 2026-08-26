import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/geofence_transition_processor.dart';
import '../data/geofences_repository.dart';
import '../models/geofence_models.dart';

part 'geofences_state.dart';

class GeofencesCubit extends Cubit<GeofencesState> {
  GeofencesCubit({
    required GeofencesRepository repository,
    required GeofenceTransitionProcessor transitionProcessor,
  })
    : _repository = repository,
      _transitionProcessor = transitionProcessor,
      super(const GeofencesState.initial());

  final GeofencesRepository _repository;
  final GeofenceTransitionProcessor _transitionProcessor;

  Future<void> refresh() async {
    emit(state.copyWith(status: GeofencesStatus.loading, errorMessage: null));

    try {
      final snapshot = await _repository.fetchManagementSnapshot();
      emit(
        state.copyWith(
          status: GeofencesStatus.ready,
          activeGeofences: snapshot.activeGeofences,
          inactiveGeofences: snapshot.inactiveGeofences,
          vehicleCounts: snapshot.vehicleCounts,
          statusMessage: 'Loaded ${snapshot.activeGeofences.length} active geofences',
          errorMessage: null,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: GeofencesStatus.error,
          statusMessage: 'Failed to load geofences',
          errorMessage: error.toString(),
        ),
      );
    }
  }

  Future<void> createGeofence({
    required String name,
    required double centerLat,
    required double centerLon,
    required double radiusM,
  }) async {
    await _repository.createGeofence(
      name: name,
      centerLat: centerLat,
      centerLon: centerLon,
      radiusM: radiusM,
    );
    await _transitionProcessor.recomputeConfirmedTransitions();
    await refresh();
  }

  Future<void> editGeofence({
    required String geofenceId,
    required String name,
    required double centerLat,
    required double centerLon,
    required double radiusM,
  }) async {
    await _repository.editGeofence(
      geofenceId: geofenceId,
      name: name,
      centerLat: centerLat,
      centerLon: centerLon,
      radiusM: radiusM,
    );
    await _transitionProcessor.recomputeConfirmedTransitions();
    await refresh();
  }

  Future<void> deactivateGeofence(String geofenceId) async {
    await _repository.deactivateGeofence(geofenceId: geofenceId);
    await _transitionProcessor.recomputeConfirmedTransitions();
    await refresh();
  }
}
