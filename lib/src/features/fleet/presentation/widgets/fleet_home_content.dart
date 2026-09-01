import 'package:flutter/material.dart';

import '../../cubit/fleet_home_cubit.dart';
import '../../models/fleet_home_models.dart';
import 'empty_fleet_state.dart';
import 'fleet_filter_chips.dart';
import 'fleet_vehicle_tile.dart';

class FleetHomeContent extends StatelessWidget {
  const FleetHomeContent({
    required this.state,
    required this.onVehicleTap,
    super.key,
  });

  final FleetHomeState state;
  final ValueChanged<FleetVehicleRow> onVehicleTap;

  @override
  Widget build(BuildContext context) {
    if (state.status == FleetHomeStatus.loading && state.allRows.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        FleetFilterChips(state: state),
        if (state.status == FleetHomeStatus.loading)
          const LinearProgressIndicator(minHeight: 2),
        if (state.status == FleetHomeStatus.error && state.errorMessage != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Text(
              state.errorMessage!,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        Expanded(
          child: state.visibleRows.isEmpty
              ? const EmptyFleetState()
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: state.visibleRows.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final row = state.visibleRows[index];
                    return FleetVehicleTile(
                      row: row,
                      onTap: () => onVehicleTap(row),
                    );
                  },
                ),
        ),
      ],
    );
  }
}