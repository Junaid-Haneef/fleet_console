part of '../../app.dart';

extension _MainShellNavigation on _MainShellState {
  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      title: const Text('Fleet Console - Phase 8'),
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
    );
  }

  Widget _buildBottomNavigationBar() {
    return BlocBuilder<AlertsBloc, AlertsState>(
      builder: (context, state) {
        final activeCount = state.activeCount;
        return ValueListenableBuilder<int>(
          valueListenable: widget.shellTabController,
          builder: (context, tabIndex, _) {
            return BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.white,
              selectedItemColor: Colors.blue,
              unselectedItemColor: Colors.black54,
              showUnselectedLabels: true,
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
                const BottomNavigationBarItem(
                  icon: Icon(Icons.speed_outlined),
                  activeIcon: Icon(Icons.speed),
                  label: 'Scale',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.science_outlined),
                  activeIcon: Icon(Icons.science),
                  label: 'Manual Lab',
                ),
              ],
            );
          },
        );
      },
    );
  }
}
