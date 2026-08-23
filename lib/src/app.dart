import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/database/app_database.dart';
import 'features/fleet/presentation/fleet_home_cubit.dart';
import 'features/telemetry/application/telemetry_ingest_bloc.dart';
import 'features/vehicle/presentation/vehicle_detail_cubit.dart';

class MainApp extends StatelessWidget {
  const MainApp({super.key, required this.database});

  final AppDatabase database;

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [RepositoryProvider<AppDatabase>.value(value: database)],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<FleetHomeCubit>(
            create: (_) => FleetHomeCubit(database)..refresh(),
          ),
          BlocProvider<VehicleDetailCubit>(
            create: (_) => VehicleDetailCubit(database),
          ),
          BlocProvider<TelemetryIngestBloc>(
            create: (_) => TelemetryIngestBloc(database),
          ),
        ],
        child: MaterialApp(
          title: 'Fleet Console',
          home: Scaffold(
            appBar: AppBar(title: const Text('Fleet Console - Phase 1')),
            body: BlocBuilder<FleetHomeCubit, FleetHomeState>(
              builder: (context, state) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Database path: ${database.databasePath ?? 'pending'}'),
                      const SizedBox(height: 8),
                      Text('FleetHome status: ${state.status.name}'),
                      const SizedBox(height: 8),
                      Text('Message: ${state.statusMessage}'),
                    ],
                  ),
                );
              },
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