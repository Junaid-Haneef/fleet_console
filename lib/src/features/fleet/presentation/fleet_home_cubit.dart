import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/database/app_database.dart';

part 'fleet_home_state.dart';

class FleetHomeCubit extends Cubit<FleetHomeState> {
  FleetHomeCubit(this._database) : super(const FleetHomeState.initial());

  final AppDatabase _database;

  Future<void> refresh() async {
    emit(state.copyWith(status: FleetHomeStatus.loading));

    final ok = await _database.healthCheck();

    emit(
      state.copyWith(
        status: FleetHomeStatus.ready,
        statusMessage: ok ? 'DuckDB ready' : 'DuckDB health check failed',
      ),
    );
  }
}
