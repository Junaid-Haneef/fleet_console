import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/database/app_database.dart';
part 'vehicle_detail_state.dart';

class VehicleDetailCubit extends Cubit<VehicleDetailState> {
  VehicleDetailCubit(this._database)
    : super(const VehicleDetailState.initial(vehicleId: null));

  final AppDatabase _database;

  Future<void> load(String vehicleId) async {
    emit(
      state.copyWith(
        status: VehicleDetailStatus.loading,
        vehicleId: vehicleId,
        statusMessage: 'Loading',
      ),
    );

    final ok = await _database.healthCheck();

    emit(
      state.copyWith(
        status: VehicleDetailStatus.ready,
        statusMessage: ok ? 'DuckDB ready' : 'DuckDB health check failed',
      ),
    );
  }
}
