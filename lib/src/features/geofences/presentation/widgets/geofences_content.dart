import 'package:flutter/material.dart';

import '../../cubit/geofences_cubit.dart';
import '../../models/geofence_models.dart';
import 'geofences_widgets.dart';

class GeofencesContent extends StatelessWidget {
  const GeofencesContent({
    required this.state,
    required this.onRefresh,
    required this.onCreatePressed,
    required this.onEditPressed,
    required this.onDeactivatePressed,
    super.key,
  });

  final GeofencesState state;
  final RefreshCallback onRefresh;
  final VoidCallback onCreatePressed;
  final ValueChanged<GeofenceListItem> onEditPressed;
  final ValueChanged<GeofenceListItem> onDeactivatePressed;

  @override
  Widget build(BuildContext context) {
    if (state.status == GeofencesStatus.loading &&
        state.activeGeofences.isEmpty &&
        state.inactiveGeofences.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          ManagementHeaderCard(
            activeCount: state.activeGeofences.length,
            inactiveCount: state.inactiveGeofences.length,
            onCreatePressed: onCreatePressed,
          ),
          const SizedBox(height: 16),
          SectionHeader(
            title: 'Live Vehicle Counts',
            icon: Icons.directions_car_filled_outlined,
            trailingCount: state.vehicleCounts.length,
          ),
          const SizedBox(height: 8),
          if (state.vehicleCounts.isEmpty)
            const EmptySectionLabel(message: 'No geofence counts yet.')
          else
            ...state.vehicleCounts.map(_buildCountRow),
          const SizedBox(height: 16),
          SectionHeader(
            title: 'Active Geofences',
            icon: Icons.gpp_good_outlined,
            trailingCount: state.activeGeofences.length,
          ),
          const SizedBox(height: 8),
          if (state.activeGeofences.isEmpty)
            const EmptySectionLabel(message: 'No active geofences.')
          else
            ...state.activeGeofences.map(_buildGeofenceCard),
          const SizedBox(height: 16),
          SectionHeader(
            title: 'Inactive Geofences',
            icon: Icons.history_toggle_off_outlined,
            trailingCount: state.inactiveGeofences.length,
          ),
          const SizedBox(height: 8),
          if (state.inactiveGeofences.isEmpty)
            const EmptySectionLabel(message: 'No inactive geofences.')
          else
            ...state.inactiveGeofences.map(_buildGeofenceCard),
          if (state.status == GeofencesStatus.error &&
              state.errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                state.errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCountRow(GeofenceVehicleCount count) {
    return CountTile(count: count);
  }

  Widget _buildGeofenceCard(GeofenceListItem item) {
    return GeofenceCard(
      item: item,
      onEdit: item.isActive ? () => onEditPressed(item) : null,
      onDeactivate: item.isActive ? () => onDeactivatePressed(item) : null,
    );
  }
}
