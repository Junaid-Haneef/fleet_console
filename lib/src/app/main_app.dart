part of '../app.dart';

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
    final telemetryRepository = TelemetryRepository(database);
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
        RepositoryProvider<TelemetryRepository>.value(value: telemetryRepository),
        ListenableProvider<ShellTabController>.value(value: shellTabController),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<FleetHomeCubit>(
            create: (_) => FleetHomeCubit(database, repository: fleetRepository),
          ),
          BlocProvider<AlertsBloc>(
            create: (_) => AlertsBloc(database, repository: alertsRepository),
          ),
          BlocProvider<GeofencesCubit>(
            create: (_) => GeofencesCubit(
              repository: geofencesRepository,
              transitionProcessor: geofenceTransitionProcessor,
              tripsRepository: tripsRepository,
            ),
          ),
          BlocProvider<TelemetryIngestBloc>(
            create: (_) => TelemetryIngestBloc(database),
          ),
        ],
        child: MaterialApp(
          title: 'Fleet Console',
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
            bottomNavigationBarTheme: const BottomNavigationBarThemeData(
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.white,
              selectedItemColor: Colors.blue,
              unselectedItemColor: Colors.black54,
              showUnselectedLabels: true,
              selectedLabelStyle: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          home: _MainShell(
            database: database,
            alertsRepository: alertsRepository,
            geofenceTransitionProcessor: geofenceTransitionProcessor,
            tripsRepository: tripsRepository,
            telemetryRepository: telemetryRepository,
            shellTabController: shellTabController,
          ),
        ),
      ),
    );
  }
}
