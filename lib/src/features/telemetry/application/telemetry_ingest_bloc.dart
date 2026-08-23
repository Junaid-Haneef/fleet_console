import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/database/app_database.dart';
part 'telemetry_ingest_event.dart';
part 'telemetry_ingest_state.dart';

class TelemetryIngestBloc
    extends Bloc<TelemetryIngestEvent, TelemetryIngestState> {
  TelemetryIngestBloc(this._database) : super(const TelemetryIngestState.initial()) {
    on<TelemetryReplayRequested>(_onReplayRequested);
  }

  final AppDatabase _database;

  Future<void> _onReplayRequested(
    TelemetryReplayRequested event,
    Emitter<TelemetryIngestState> emit,
  ) async {
    emit(
      state.copyWith(
        status: TelemetryIngestStatus.running,
        message: 'Replay running',
      ),
    );

    try {
      final ok = await _database.healthCheck();
      emit(
        state.copyWith(
          status: ok ? TelemetryIngestStatus.success : TelemetryIngestStatus.failure,
          message: ok ? 'Replay scaffold complete' : 'DuckDB health check failed',
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          status: TelemetryIngestStatus.failure,
          message: 'Replay scaffold failed',
        ),
      );
    }
  }
}