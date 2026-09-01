import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../cubit/fleet_home_cubit.dart';
import '../../models/fleet_home_models.dart';

class FleetFilterChips extends StatelessWidget {
  const FleetFilterChips({required this.state, super.key});

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