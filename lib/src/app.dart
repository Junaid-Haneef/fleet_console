import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

import 'core/database/app_database.dart';
import 'features/alerts/data/alerts_repository.dart';
import 'features/alerts/bloc/alerts_bloc.dart';
import 'features/alerts/presentation/alerts_page.dart';
import 'features/fleet/data/fleet_home_repository.dart';
import 'features/fleet/cubit/fleet_home_cubit.dart';
import 'features/fleet/presentation/fleet_home_page.dart';
import 'features/geofences/cubit/geofences_cubit.dart';
import 'features/geofences/data/geofence_transition_processor.dart';
import 'features/geofences/data/geofences_repository.dart';
import 'features/geofences/presentation/geofences_page.dart';
import 'features/telemetry/bloc/telemetry_ingest_bloc.dart';
import 'features/trips/data/trips_repository.dart';
import 'features/vehicle/data/vehicle_detail_repository.dart';

class ShellTabController extends ValueNotifier<int> {
  ShellTabController() : super(0);

  void showFleet() => value = 0;
  void showAlerts() => value = 1;
  void showGeofences() => value = 2;
}

class MainApp extends StatelessWidget {
  const MainApp({super.key, required this.database});

  final AppDatabase database;

  @override
  Widget build(BuildContext context) {
    final fleetRepository = FleetHomeRepository(database);
    final vehicleDetailRepository = VehicleDetailRepository(database);
    final alertsRepository = AlertsRepository(database);
    final geofencesRepository = GeofencesRepository(database);
    final geofenceTransitionProcessor = GeofenceTransitionProcessor(database);
    final tripsRepository = TripsRepository(database);
    final shellTabController = ShellTabController();

    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AppDatabase>.value(value: database),
        RepositoryProvider<FleetHomeRepository>.value(value: fleetRepository),
        RepositoryProvider<VehicleDetailRepository>.value(
          value: vehicleDetailRepository,
        ),
        RepositoryProvider<AlertsRepository>.value(value: alertsRepository),
        RepositoryProvider<GeofencesRepository>.value(value: geofencesRepository),
        RepositoryProvider<GeofenceTransitionProcessor>.value(
          value: geofenceTransitionProcessor,
        ),
        RepositoryProvider<TripsRepository>.value(value: tripsRepository),
        ListenableProvider<ShellTabController>.value(value: shellTabController),
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
          BlocProvider<GeofencesCubit>(
            create: (_) => GeofencesCubit(
              repository: geofencesRepository,
              transitionProcessor: geofenceTransitionProcessor,
              tripsRepository: tripsRepository,
            )..refresh(),
          ),
          BlocProvider<TelemetryIngestBloc>(
            create: (_) => TelemetryIngestBloc(database),
          ),
        ],
        child: MaterialApp(
          title: 'Fleet Console',
          home: _MainShell(
            database: database,
            alertsRepository: alertsRepository,
            geofenceTransitionProcessor: geofenceTransitionProcessor,
            tripsRepository: tripsRepository,
            shellTabController: shellTabController,
          ),
        ),
      ),
    );
  }
}

class _MainShell extends StatefulWidget {
  const _MainShell({
    required this.database,
    required this.alertsRepository,
    required this.geofenceTransitionProcessor,
    required this.tripsRepository,
    required this.shellTabController,
  });

  final AppDatabase database;
  final AlertsRepository alertsRepository;
  final GeofenceTransitionProcessor geofenceTransitionProcessor;
  final TripsRepository tripsRepository;
  final ShellTabController shellTabController;

  @override
  State<_MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<_MainShell> {
  @override
  Widget build(BuildContext context) {
    return BlocListener<TelemetryIngestBloc, TelemetryIngestState>(
      listenWhen: (previous, current) =>
          previous.status != current.status &&
          current.status == TelemetryIngestStatus.success,
      listener: (context, _) async {
        final fleetCubit = context.read<FleetHomeCubit>();
        final alertsBloc = context.read<AlertsBloc>();
        final geofencesCubit = context.read<GeofencesCubit>();

        await widget.geofenceTransitionProcessor.recomputeConfirmedTransitions();
        await widget.tripsRepository.recomputeTripsFromConfirmedTransitions();
        await widget.alertsRepository.recomputeActiveAlertsFromLatestReadings();
        await fleetCubit.refresh();
        await alertsBloc.refresh();
        await geofencesCubit.refresh();
      },
      child: Scaffold(
        appBar: AppBar(
           title: const Text('Fleet Console - Phase 7'),
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
        body: ValueListenableBuilder<int>(
          valueListenable: widget.shellTabController,
          builder: (context, tabIndex, _) {
            return IndexedStack(
              index: tabIndex,
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
                const GeofencesPage(),
              ],
            );
          },
        ),
        bottomNavigationBar: BlocBuilder<AlertsBloc, AlertsState>(
          builder: (context, state) {
            final activeCount = state.activeCount;
            return ValueListenableBuilder<int>(
              valueListenable: widget.shellTabController,
              builder: (context, tabIndex, _) {
                return BottomNavigationBar(
                  currentIndex: tabIndex,
                  onTap: (nextIndex) {
                    widget.shellTabController.value = nextIndex;
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
                    const BottomNavigationBarItem(
                      icon: Icon(Icons.location_on_outlined),
                      activeIcon: Icon(Icons.location_on),
                      label: 'Geofences',
                    ),
                  ],
                );
              },
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
