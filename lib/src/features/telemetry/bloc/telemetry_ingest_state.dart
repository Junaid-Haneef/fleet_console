part of 'telemetry_ingest_bloc.dart';

enum TelemetryIngestStatus { idle, running, success, failure }

class TelemetryIngestState {
  const TelemetryIngestState({required this.status, required this.message});

  const TelemetryIngestState.initial()
    : status = TelemetryIngestStatus.idle,
      message = 'Idle';

  final TelemetryIngestStatus status;
  final String message;

  TelemetryIngestState copyWith({TelemetryIngestStatus? status, String? message}) {
    return TelemetryIngestState(
      status: status ?? this.status,
      message: message ?? this.message,
    );
  }
}