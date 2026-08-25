import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/database/app_database.dart';
import 'features/fleet/data/fleet_home_repository.dart';
import 'features/fleet/presentation/fleet_home_cubit.dart';
import 'features/fleet/presentation/fleet_home_page.dart';
import 'features/telemetry/application/telemetry_ingest_bloc.dart';
import 'features/vehicle/data/vehicle_detail_repository.dart';

class MainApp extends StatelessWidget {
  const MainApp({super.key, required this.database});

  final AppDatabase database;

  @override
  Widget build(BuildContext context) {
    final fleetRepository = FleetHomeRepository(database);
    final vehicleDetailRepository = VehicleDetailRepository(database);

    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AppDatabase>.value(value: database),
        RepositoryProvider<FleetHomeRepository>.value(value: fleetRepository),
        RepositoryProvider<VehicleDetailRepository>.value(
          value: vehicleDetailRepository,
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<FleetHomeCubit>(
            create: (_) =>
                FleetHomeCubit(database, repository: fleetRepository)..refresh(),
          ),
          BlocProvider<TelemetryIngestBloc>(
            create: (_) => TelemetryIngestBloc(database),
          ),
        ],
        child: MaterialApp(
          title: 'Fleet Console',
          home: Scaffold(
            appBar: AppBar(title: const Text('Fleet Console - Phase 3')),
            body: BlocListener<TelemetryIngestBloc, TelemetryIngestState>(
              listenWhen: (previous, current) =>
                  previous.status != current.status &&
                  current.status == TelemetryIngestStatus.success,
              listener: (context, _) {
                context.read<FleetHomeCubit>().refresh();
              },
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Database path: ${database.databasePath ?? 'pending'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        BlocBuilder<TelemetryIngestBloc, TelemetryIngestState>(
                          builder: (context, ingestState) {
                            final replayRunning =
                                ingestState.status == TelemetryIngestStatus.running;
                            return OutlinedButton(
                              onPressed: replayRunning
                                  ? null
                                  : () async{
                                      context.read<TelemetryIngestBloc>().add(
                                        const TelemetryReplayRequested(),
                                      );
                                    },
                              child: Text(
                                replayRunning ? 'Replaying...' : 'Replay telemetry',
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const Expanded(child: FleetHomePage()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class BootstrapErrorApp extends StatelessWidget {
  const BootstrapErrorApp({
    super.key,
    required this.error,
    required this.stackTrace,
  });

  final Object error;
  final StackTrace stackTrace;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Fleet Console - Startup Error')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Text(
              'DuckDB initialization failed.\n\n'
              'Error: $error\n\n'
              'Stack: $stackTrace',
            ),
          ),
        ),
      ),
    );
  }
}
