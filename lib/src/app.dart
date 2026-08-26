import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/database/app_database.dart';
import 'features/alerts/data/alerts_repository.dart';
import 'features/alerts/bloc/alerts_bloc.dart';
import 'features/alerts/presentation/alerts_page.dart';
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
    final alertsRepository = AlertsRepository(database);

    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AppDatabase>.value(value: database),
        RepositoryProvider<FleetHomeRepository>.value(value: fleetRepository),
        RepositoryProvider<VehicleDetailRepository>.value(
          value: vehicleDetailRepository,
        ),
        RepositoryProvider<AlertsRepository>.value(value: alertsRepository),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<FleetHomeCubit>(
            create: (_) =>
                FleetHomeCubit(database, repository: fleetRepository)..refresh(),
          ),
          BlocProvider<AlertsBloc>(
            create: (_) => AlertsBloc(database, repository: alertsRepository)..refresh(),
          ),
          BlocProvider<TelemetryIngestBloc>(
            create: (_) => TelemetryIngestBloc(database),
          ),
        ],
        child: MaterialApp(
          title: 'Fleet Console',
          home: _MainShell(database: database, alertsRepository: alertsRepository),
        ),
      ),
    );
  }
}

class _MainShell extends StatefulWidget {
  const _MainShell({
    required this.database,
    required this.alertsRepository,
  });

  final AppDatabase database;
  final AlertsRepository alertsRepository;

  @override
  State<_MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<_MainShell> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    return BlocListener<TelemetryIngestBloc, TelemetryIngestState>(
      listenWhen: (previous, current) =>
          previous.status != current.status &&
          current.status == TelemetryIngestStatus.success,
      listener: (context, _) async {
        final fleetCubit = context.read<FleetHomeCubit>();
        final alertsBloc = context.read<AlertsBloc>();

        await widget.alertsRepository.recomputeActiveAlertsFromLatestReadings();
        await fleetCubit.refresh();
        await alertsBloc.refresh();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Fleet Console - Phase 5'),
          actions: [
            BlocBuilder<TelemetryIngestBloc, TelemetryIngestState>(
              builder: (context, ingestState) {
                final replayRunning =
                    ingestState.status == TelemetryIngestStatus.running;
                return TextButton(
                  onPressed: replayRunning
                      ? null
                      : () {
                          context.read<TelemetryIngestBloc>().add(
                            const TelemetryReplayRequested(),
                          );
                        },
                  child: Text(
                    replayRunning ? 'Replaying...' : 'Replay telemetry',
                    style: TextStyle(
                      color: replayRunning
                          ? Theme.of(context).disabledColor
                          : Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        body: IndexedStack(
          index: _tabIndex,
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  child: Text(
                    'Database path: ${widget.database.databasePath ?? 'pending'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 8),
                const Expanded(child: FleetHomePage()),
              ],
            ),
            const AlertsPage(),
          ],
        ),
        bottomNavigationBar: BlocBuilder<AlertsBloc, AlertsState>(
          builder: (context, state) {
            final activeCount = state.activeCount;

            return BottomNavigationBar(
              currentIndex: _tabIndex,
              onTap: (nextIndex) {
                setState(() {
                  _tabIndex = nextIndex;
                });
              },
              items: [
                const BottomNavigationBarItem(
                  icon: Icon(Icons.directions_car_outlined),
                  activeIcon: Icon(Icons.directions_car),
                  label: 'Fleet',
                ),
                BottomNavigationBarItem(
                  icon: _AlertTabIcon(count: activeCount),
                  activeIcon: _AlertTabIcon(count: activeCount, active: true),
                  label: 'Alert',
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AlertTabIcon extends StatelessWidget {
  const _AlertTabIcon({required this.count, this.active = false});

  final int count;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final icon = active ? Icons.warning_amber : Icons.warning_amber_outlined;
    if (count <= 0) {
      return Icon(icon);
    }

    final badgeText = count > 99 ? '99+' : '$count';

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon),
        Positioned(
          right: -10,
          top: -6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(10),
            ),
            constraints: const BoxConstraints(minWidth: 18),
            child: Text(
              badgeText,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
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
