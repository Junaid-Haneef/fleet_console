part of 'telemetry_ingest_bloc.dart';

sealed class TelemetryIngestEvent {
	const TelemetryIngestEvent();
}

final class TelemetryReplayRequested extends TelemetryIngestEvent {
	const TelemetryReplayRequested({
		this.options = const TelemetryReplayOptions(),
	});

	final TelemetryReplayOptions options;
}