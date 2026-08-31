part of '../app.dart';

class _MainShell extends StatefulWidget {
  const _MainShell({
    required this.database,
    required this.alertsRepository,
    required this.geofenceTransitionProcessor,
    required this.tripsRepository,
    required this.telemetryRepository,
    required this.shellTabController,
  });

  final AppDatabase database;
  final AlertsRepository alertsRepository;
  final GeofenceTransitionProcessor geofenceTransitionProcessor;
  final TripsRepository tripsRepository;
  final TelemetryRepository telemetryRepository;
  final ShellTabController shellTabController;

  @override
  State<_MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<_MainShell> {
  static const int _tabCount = 5;
  final Set<int> _loadedTabs = <int>{0};
  bool _alertsLoaded = false;
  bool _geofencesLoaded = false;

  @override
  void initState() {
    super.initState();
    widget.shellTabController.addListener(_handleTabSelectionChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.read<FleetHomeCubit>().refresh();
    });
  }

  @override
  void didUpdateWidget(covariant _MainShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shellTabController != widget.shellTabController) {
      oldWidget.shellTabController.removeListener(_handleTabSelectionChanged);
      widget.shellTabController.addListener(_handleTabSelectionChanged);
      _ensureTabLoaded(widget.shellTabController.value);
    }
  }

  @override
  void dispose() {
    widget.shellTabController.removeListener(_handleTabSelectionChanged);
    super.dispose();
  }

  void _handleTabSelectionChanged() {
    final tabIndex = widget.shellTabController.value;
    _ensureTabLoaded(tabIndex);
    _maybeLoadTabData(tabIndex);
  }

  void _ensureTabLoaded(int tabIndex) {
    if (_loadedTabs.contains(tabIndex)) {
      return;
    }
    setState(() {
      _loadedTabs.add(tabIndex);
    });
  }

  void _maybeLoadTabData(int tabIndex) {
    if (tabIndex == 1 && !_alertsLoaded) {
      _alertsLoaded = true;
      context.read<AlertsBloc>().refresh();
      return;
    }

    if (tabIndex == 2 && !_geofencesLoaded) {
      _geofencesLoaded = true;
      context.read<GeofencesCubit>().refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<TelemetryIngestBloc, TelemetryIngestState>(
      listenWhen: (previous, current) =>
          previous.status != current.status &&
          current.status == TelemetryIngestStatus.success,
      listener: (context, _) async {
        await _recomputeAndRefreshViews();
      },
      child: Scaffold(
        appBar: _buildAppBar(context),
        body: _buildShellBody(),
        bottomNavigationBar: _buildBottomNavigationBar(),
      ),
    );
  }
}
