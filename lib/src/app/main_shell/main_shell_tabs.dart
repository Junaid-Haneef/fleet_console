part of '../../app.dart';

extension _MainShellTabs on _MainShellState {
  Widget _buildShellBody() {
    return ValueListenableBuilder<int>(
      valueListenable: widget.shellTabController,
      builder: (context, tabIndex, _) {
        _ensureTabLoaded(tabIndex);
        _maybeLoadTabData(tabIndex);

        return IndexedStack(
          index: tabIndex,
          children: List<Widget>.generate(_MainShellState._tabCount, (index) {
            if (!_loadedTabs.contains(index)) {
              return const SizedBox.shrink();
            }
            return _buildTab(index);
          }),
        );
      },
    );
  }

  Widget _buildTab(int index) {
    switch (index) {
      case 0:
        return Column(
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
        );
      case 1:
        return const AlertsPage();
      case 2:
        return const GeofencesPage();
      case 3:
        return ScaleExercisePage(
          onClearData: _resetOperationalData,
          onRunReplay: _runScaleReplay,
          onRunSingleVehicleTripMock: _runSingleVehicleTripMock,
          onLoadCounts: _loadScaleCounts,
        );
      case 4:
        return ManualVehicleLabPage(
          onUpsertVehicle: _upsertManualVehicle,
          onAppendRow: _appendManualRow,
          onRunScenario: _runManualScenario,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
