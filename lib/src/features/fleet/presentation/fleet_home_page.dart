import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/fleet_home_models.dart';
import 'fleet_home_cubit.dart';

class FleetHomePage extends StatelessWidget {
  const FleetHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FleetHomeCubit, FleetHomeState>(
      builder: (context, state) {
        if (state.status == FleetHomeStatus.loading && state.allRows.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            _FleetFilterChips(state: state),
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
                  ? const _EmptyFleetState()
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: state.visibleRows.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final row = state.visibleRows[index];
                        return _FleetVehicleTile(row: row);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _FleetFilterChips extends StatelessWidget {
  const _FleetFilterChips({required this.state});

  final FleetHomeState state;

  @override
  Widget build(BuildContext context) {
    final filters = FleetFilter.values;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: filters
            .map(
              (filter) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text('${_labelForFilter(filter)} (${state.counts.forFilter(filter)})'),
                  selected: state.selectedFilter == filter,
                  onSelected: (_) => context.read<FleetHomeCubit>().selectFilter(filter),
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }

  String _labelForFilter(FleetFilter filter) {
    switch (filter) {
      case FleetFilter.all:
        return 'All';
      case FleetFilter.moving:
        return 'Moving';
      case FleetFilter.idle:
        return 'Idle';
      case FleetFilter.stopped:
        return 'Stopped';
      case FleetFilter.offline:
        return 'Offline';
    }
  }
}

class _FleetVehicleTile extends StatelessWidget {
  const _FleetVehicleTile({required this.row});

  final FleetVehicleRow row;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    row.regNumber,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                _StatusChip(status: row.status),
              ],
            ),
            const SizedBox(height: 4),
            Text(row.model),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: Text('SOC: ${_formatPercent(row.soc)}')),
                Expanded(child: Text('Range: ${_formatRange(row.rangeKm)}')),
                _AlertBadge(severity: row.alertSeverity),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatPercent(double? value) {
    if (value == null) {
      return '--';
    }
    return '${value.toStringAsFixed(0)}%';
  }

  String _formatRange(double? value) {
    if (value == null) {
      return '--';
    }
    return '${value.toStringAsFixed(0)} km';
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final FleetVehicleStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      FleetVehicleStatus.offline => Colors.grey,
      FleetVehicleStatus.moving => Colors.green,
      FleetVehicleStatus.idle => Colors.orange,
      FleetVehicleStatus.stopped => Colors.blueGrey,
    };

    final label = switch (status) {
      FleetVehicleStatus.offline => 'OFFLINE',
      FleetVehicleStatus.moving => 'MOVING',
      FleetVehicleStatus.idle => 'IDLE',
      FleetVehicleStatus.stopped => 'STOPPED',
    };

    return Chip(
      backgroundColor: color.withValues(alpha: 0.15),
      label: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
      side: BorderSide(color: color.withValues(alpha: 0.3)),
    );
  }
}

class _AlertBadge extends StatelessWidget {
  const _AlertBadge({required this.severity});

  final AlertBadgeSeverity severity;

  @override
  Widget build(BuildContext context) {
    if (severity == AlertBadgeSeverity.none) {
      return const SizedBox.shrink();
    }

    final isCritical = severity == AlertBadgeSeverity.critical;
    final color = isCritical ? Colors.red : Colors.amber;
    final text = isCritical ? 'Critical' : 'Warning';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color.shade700,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _EmptyFleetState extends StatelessWidget {
  const _EmptyFleetState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('No vehicles match this filter.'),
    );
  }
}
