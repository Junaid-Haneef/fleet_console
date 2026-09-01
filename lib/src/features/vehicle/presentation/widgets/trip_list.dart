import 'package:flutter/material.dart';

import '../../models/vehicle_detail_models.dart';
import '../utils/vehicle_detail_formatters.dart';

class TripList extends StatelessWidget {
  const TripList({required this.trips, super.key});

  final List<VehicleTripRow> trips;

  @override
  Widget build(BuildContext context) {
    if (trips.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Text('No trips derived yet from confirmed transitions.'),
      );
    }

    return ListView(
      children: trips.map((trip) => _TripCard(trip: trip)).toList(growable: false),
    );
  }
}

class _TripCard extends StatelessWidget {
  const _TripCard({required this.trip});

  final VehicleTripRow trip;

  @override
  Widget build(BuildContext context) {
    final statusLabel = trip.status == VehicleTripStatus.completed
        ? 'COMPLETED'
        : 'IN PROGRESS';
    final statusColor = trip.status == VehicleTripStatus.completed
        ? Colors.green
        : Colors.orange;

    final destination = trip.destinationGeofenceName ?? 'Pending entry';

    return Card(
      key: ValueKey('trip-row-${trip.tripId}'),
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${trip.originGeofenceName} -> $destination',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: statusColor.withValues(alpha: 0.35)),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Start: ${formatVehicleUtcTimestamp(trip.startEventTime)}'),
            Text(
              trip.endEventTime == null
                  ? 'End: -'
                  : 'End: ${formatVehicleUtcTimestamp(trip.endEventTime!)}',
            ),
          ],
        ),
      ),
    );
  }
}