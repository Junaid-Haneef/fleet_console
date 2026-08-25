import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/database/app_database.dart';
import '../data/telemetry_repository.dart';
import '../domain/telemetry_replay_options.dart';
part 'telemetry_ingest_event.dart';
part 'telemetry_ingest_state.dart';

class TelemetryIngestBloc
    extends Bloc<TelemetryIngestEvent, TelemetryIngestState> {
  TelemetryIngestBloc(
    this._database, {
    TelemetryRepository? repository,
    Future<void> Function()? onReplayCompleted,
  }) : _repository = repository ?? TelemetryRepository(_database),
       _onReplayCompleted = onReplayCompleted,
       super(const TelemetryIngestState.initial()) {
    on<TelemetryReplayRequested>(_onReplayRequested);
  }

  final AppDatabase _database;
  final TelemetryRepository _repository;
  final Future<void> Function()? _onReplayCompleted;

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
      if (!ok) {
        emit(
          state.copyWith(
            status: TelemetryIngestStatus.failure,
            message: 'DuckDB health check failed',
          ),
        );
        return;
      }

      final summary = await _repository.replaySyntheticTelemetry(event.options);
      if (_onReplayCompleted != null) {
        await _onReplayCompleted();
      }

      emit(
        state.copyWith(
          status: TelemetryIngestStatus.success,
          message:
              'Replay complete: packets=${summary.packetsProcessed}, '
              'duplicates=${summary.packetDuplicatesGenerated}, '
              'missing=${summary.packetsDroppedAsMissing}',
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: TelemetryIngestStatus.failure,
          message: 'Replay failed: $error',
        ),
      );
    }
  }
}