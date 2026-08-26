import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/database/app_database.dart';
import '../data/vehicle_detail_repository.dart';
import '../models/vehicle_detail_models.dart';
part 'vehicle_detail_state.dart';

class VehicleDetailCubit extends Cubit<VehicleDetailState> {
  VehicleDetailCubit(
    AppDatabase database, {
    VehicleDetailRepository? repository,
  }) : _repository = repository ?? VehicleDetailRepository(database),
       super(const VehicleDetailState.initial(vehicleId: null));

  final VehicleDetailRepository _repository;

  Future<void> load(String vehicleId) async {
    emit(
      state.copyWith(
        status: VehicleDetailStatus.loading,
        vehicleId: vehicleId,
        statusMessage: 'Loading vehicle detail',
        errorMessage: null,
      ),
    );

    try {
      final snapshot = await _repository.fetchSnapshot(vehicleId);

      emit(
        state.copyWith(
          status: VehicleDetailStatus.ready,
          snapshot: snapshot,
          statusMessage: 'Loaded ${snapshot.identity.regNumber}',
          errorMessage: null,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: VehicleDetailStatus.error,
          statusMessage: 'Failed to load vehicle detail',
          errorMessage: error.toString(),
        ),
      );
    }
  }

  Future<void> refresh() async {
    final vehicleId = state.vehicleId;
    if (vehicleId == null) {
      return;
    }
    await load(vehicleId);
  }
}
