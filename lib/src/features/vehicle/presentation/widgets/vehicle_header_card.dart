import 'package:flutter/material.dart';

import '../../models/vehicle_detail_models.dart';

class VehicleHeaderCard extends StatelessWidget {
  const VehicleHeaderCard({
    required this.identity,
    required this.currentGeofenceName,
    super.key,
  });

  final VehicleIdentity identity;
  final String currentGeofenceName;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(identity.regNumber, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(identity.model),
            const SizedBox(height: 8),
            Text('Current geofence: $currentGeofenceName'),
          ],
        ),
      ),
    );
  }
}