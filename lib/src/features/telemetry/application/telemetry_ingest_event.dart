part of 'telemetry_ingest_bloc.dart';

sealed class TelemetryIngestEvent {}

final class TelemetryReplayRequested extends TelemetryIngestEvent {}