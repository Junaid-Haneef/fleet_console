import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../cubit/vehicle_detail_cubit.dart';
import 'history_trips_tabs.dart';
import 'vehicle_detail_error_state.dart';
import 'vehicle_header_card.dart';
import 'vehicle_reading_card.dart';

class VehicleDetailContent extends StatelessWidget {
  const VehicleDetailContent({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VehicleDetailCubit, VehicleDetailState>(
      builder: (context, state) {
        final snapshot = state.snapshot;

        if (state.status == VehicleDetailStatus.loading && snapshot == null) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state.status == VehicleDetailStatus.error && snapshot == null) {
          return VehicleDetailErrorState(
            message: state.errorMessage ?? state.statusMessage,
            onRetry: () => context.read<VehicleDetailCubit>().refresh(),
          );
        }

        if (snapshot == null) {
          return const SizedBox.shrink();
        }

        return RefreshIndicator(
          onRefresh: () => context.read<VehicleDetailCubit>().refresh(),
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              VehicleHeaderCard(
                identity: snapshot.identity,
                currentGeofenceName: snapshot.currentGeofenceName,
              ),
              const SizedBox(height: 12),
              const Text(
                'Readings Register',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              ...snapshot.readings.map((reading) => VehicleReadingCard(reading: reading)),
              const SizedBox(height: 12),
              HistoryTripsTabs(
                socHistory: snapshot.socHistory,
                recentTrips: snapshot.recentTrips,
              ),
            ],
          ),
        );
      },
    );
  }
}