import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/database/app_database.dart';
import '../data/fleet_home_repository.dart';
import '../domain/fleet_home_models.dart';

part 'fleet_home_state.dart';

class FleetHomeCubit extends Cubit<FleetHomeState> {
  FleetHomeCubit(
    AppDatabase database, {
    FleetHomeRepository? repository,
  }) : _repository = repository ?? FleetHomeRepository(database),
       super(const FleetHomeState.initial());

  final FleetHomeRepository _repository;

  Future<void> refresh() async {
    emit(state.copyWith(status: FleetHomeStatus.loading, errorMessage: null));

    try {
      final snapshot = await _repository.fetchSnapshot();
      final visibleRows = _applyFilter(snapshot.rows, state.selectedFilter);

      emit(
        state.copyWith(
          status: FleetHomeStatus.ready,
          allRows: snapshot.rows,
          visibleRows: visibleRows,
          counts: snapshot.counts,
          statusMessage: 'Loaded ${snapshot.rows.length} vehicles',
          errorMessage: null,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: FleetHomeStatus.error,
          statusMessage: 'Failed to load fleet data',
          errorMessage: error.toString(),
        ),
      );
    }
  }

  void selectFilter(FleetFilter filter) {
    final visibleRows = _applyFilter(state.allRows, filter);
    emit(state.copyWith(selectedFilter: filter, visibleRows: visibleRows));
  }

  List<FleetVehicleRow> _applyFilter(
    List<FleetVehicleRow> rows,
    FleetFilter filter,
  ) {
    switch (filter) {
      case FleetFilter.all:
        return rows;
      case FleetFilter.moving:
        return rows
            .where((row) => row.status == FleetVehicleStatus.moving)
            .toList(growable: false);
      case FleetFilter.idle:
        return rows
            .where((row) => row.status == FleetVehicleStatus.idle)
            .toList(growable: false);
      case FleetFilter.stopped:
        return rows
            .where((row) => row.status == FleetVehicleStatus.stopped)
            .toList(growable: false);
      case FleetFilter.offline:
        return rows
            .where((row) => row.status == FleetVehicleStatus.offline)
            .toList(growable: false);
    }
  }
}
