part of '../../app.dart';

extension _MainShellActions on _MainShellState {
  Future<void> _recomputeAndRefreshViews() async {
    final fleetCubit = context.read<FleetHomeCubit>();
    final alertsBloc = context.read<AlertsBloc>();
    final geofencesCubit = context.read<GeofencesCubit>();

    await widget.geofenceTransitionProcessor.recomputeConfirmedTransitions();
    await widget.tripsRepository.recomputeTripsFromConfirmedTransitions();
    await widget.alertsRepository.recomputeActiveAlertsFromLatestReadings();
    await fleetCubit.refresh();
    await alertsBloc.refresh();
    await geofencesCubit.refresh();
  }

  Future<ScaleTelemetryCounts> _loadScaleCounts() async {
    final vehicleRows = await widget.database.query(
      'SELECT COUNT(*) FROM vehicles',
    );
    final signalRows = await widget.database.query(
      'SELECT COUNT(*) FROM signal_readings',
    );
    final locationRows = await widget.database.query(
      'SELECT COUNT(*) FROM location_readings',
    );
    final transitionRows = await widget.database.query(
      'SELECT COUNT(*) FROM geofence_transitions',
    );
    final tripRows = await widget.database.query(
      'SELECT COUNT(*) FROM trips',
    );
    final inProgressTrips = await widget.database.query(
      "SELECT COUNT(*) FROM trips WHERE status = 'IN_PROGRESS'",
    );
    final completedTrips = await widget.database.query(
      "SELECT COUNT(*) FROM trips WHERE status = 'COMPLETED'",
    );

    int parseCount(List<List<Object?>> rows) {
      if (rows.isEmpty || rows.first.isEmpty) {
        return 0;
      }
      final value = rows.first.first;
      return value is num ? value.toInt() : 0;
    }

    return ScaleTelemetryCounts(
      vehicleRows: parseCount(vehicleRows),
      signalRows: parseCount(signalRows),
      locationRows: parseCount(locationRows),
      transitionRows: parseCount(transitionRows),
      tripRows: parseCount(tripRows),
      inProgressTrips: parseCount(inProgressTrips),
      completedTrips: parseCount(completedTrips),
    );
  }

  Future<ScaleTelemetryCounts> _resetOperationalData() async {
    await widget.database.resetOperationalData();
    await _recomputeAndRefreshViews();
    return _loadScaleCounts();
  }

  Future<ScaleReplayResult> _runScaleReplay(TelemetryReplayOptions options) async {
    final healthy = await widget.database.healthCheck();
    if (!healthy) {
      throw StateError('DuckDB health check failed');
    }

    final watch = Stopwatch()..start();
    final summary = await widget.telemetryRepository.replaySyntheticTelemetry(options);
    await _recomputeAndRefreshViews();
    watch.stop();

    final counts = await _loadScaleCounts();
    return ScaleReplayResult(
      summary: summary,
      counts: counts,
      elapsed: watch.elapsed,
    );
  }

  Future<String> _runSingleVehicleTripMock() async {
    final healthy = await widget.database.healthCheck();
    if (!healthy) {
      throw StateError('DuckDB health check failed');
    }

    await widget.telemetryRepository.replaySingleVehicleTripScenario();
    await _recomputeAndRefreshViews();
    final counts = await _loadScaleCounts();

    return 'Trip mock complete: transitions=${counts.transitionRows}, '
        'trips=${counts.tripRows}, in_progress=${counts.inProgressTrips}, '
        'completed=${counts.completedTrips}';
  }

  Future<String> _upsertManualVehicle({
    required String vehicleId,
    required String regNumber,
    required String model,
  }) async {
    await widget.telemetryRepository.upsertVehicleIdentity(
      vehicleId: vehicleId,
      regNumber: regNumber,
      model: model,
    );
    await _recomputeAndRefreshViews();
    return 'Vehicle upserted: $vehicleId ($regNumber)';
  }

  Future<String> _appendManualRow(ManualTelemetryRowInput input) async {
    await widget.telemetryRepository.upsertVehicleIdentity(
      vehicleId: input.vehicleId,
      regNumber: input.regNumber,
      model: input.model,
    );

    final eventTime = input.eventTimeUtc;

    await widget.telemetryRepository.appendManualTelemetryRow(
      vehicleId: input.vehicleId,
      eventTime: eventTime,
      soc: input.soc,
      speed: input.speed,
      ignition: input.ignition,
      batteryTemp: input.batteryTemp,
      odometer: input.odometer,
      lat: input.includeLocation ? input.lat : null,
      lon: input.includeLocation ? input.lon : null,
      accuracyM: input.accuracyM,
    );

    await _recomputeAndRefreshViews();
    return 'Row appended at ${eventTime.toIso8601String()} for ${input.vehicleId}';
  }

  Future<String> _runManualScenario({
    required ManualScenario scenario,
    required String vehicleId,
    required String regNumber,
    required String model,
  }) async {
    await widget.telemetryRepository.upsertVehicleIdentity(
      vehicleId: vehicleId,
      regNumber: regNumber,
      model: model,
    );

    Future<void> addRow({
      required int minutesAgo,
      required double soc,
      required double speed,
      required double ignition,
      required double batteryTemp,
      required double odometer,
      double? lat,
      double? lon,
      double accuracyM = 8,
    }) {
      final eventTime = DateTime.now().toUtc().subtract(
        Duration(minutes: minutesAgo),
      );
      return widget.telemetryRepository.appendManualTelemetryRow(
        vehicleId: vehicleId,
        eventTime: eventTime,
        soc: soc,
        speed: speed,
        ignition: ignition,
        batteryTemp: batteryTemp,
        odometer: odometer,
        lat: lat,
        lon: lon,
        accuracyM: accuracyM,
      );
    }

    switch (scenario) {
      case ManualScenario.idle:
        await addRow(
          minutesAgo: 0,
          soc: 62,
          speed: 0,
          ignition: 1,
          batteryTemp: 34,
          odometer: 12010,
          lat: 12.971600,
          lon: 77.594600,
        );
      case ManualScenario.moving:
        await addRow(
          minutesAgo: 0,
          soc: 60,
          speed: 28,
          ignition: 1,
          batteryTemp: 35,
          odometer: 12020,
          lat: 12.972200,
          lon: 77.595500,
        );
      case ManualScenario.stopped:
        await addRow(
          minutesAgo: 0,
          soc: 58,
          speed: 0,
          ignition: 0,
          batteryTemp: 33,
          odometer: 12030,
          lat: 12.971800,
          lon: 77.594900,
        );
      case ManualScenario.offline:
        await addRow(
          minutesAgo: 11,
          soc: 57,
          speed: 0,
          ignition: 1,
          batteryTemp: 33,
          odometer: 12040,
          lat: 12.971700,
          lon: 77.594700,
        );
      case ManualScenario.warning:
        await addRow(
          minutesAgo: 0,
          soc: 16,
          speed: 0,
          ignition: 1,
          batteryTemp: 34,
          odometer: 12050,
          lat: 12.971700,
          lon: 77.594700,
        );
      case ManualScenario.critical:
        await addRow(
          minutesAgo: 0,
          soc: 8,
          speed: 0,
          ignition: 1,
          batteryTemp: 44,
          odometer: 12060,
          lat: 12.971700,
          lon: 77.594700,
        );
      case ManualScenario.tripCompleted:
        await widget.telemetryRepository.replaySingleVehicleTripScenario(
          vehicleId: vehicleId,
          regNumber: regNumber,
          model: model,
        );
    }

    await _recomputeAndRefreshViews();
    return 'Scenario applied: ${scenario.name} for $vehicleId';
  }
}
