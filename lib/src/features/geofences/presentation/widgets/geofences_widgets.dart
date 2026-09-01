import 'package:flutter/material.dart';

import '../../models/geofence_models.dart';

class ManagementHeaderCard extends StatelessWidget {
  const ManagementHeaderCard({
    required this.activeCount,
    required this.inactiveCount,
    required this.onCreatePressed,
    super.key,
  });

  final int activeCount;
  final int inactiveCount;
  final VoidCallback onCreatePressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.radar_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Geofence Management',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: onCreatePressed,
                  icon: const Icon(Icons.add),
                  label: const Text('Create'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  avatar: const Icon(Icons.gpp_good_outlined, size: 18),
                  label: Text('Active $activeCount'),
                ),
                Chip(
                  avatar: const Icon(
                    Icons.history_toggle_off_outlined,
                    size: 18,
                  ),
                  label: Text('Inactive $inactiveCount'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    required this.title,
    required this.icon,
    required this.trailingCount,
    super.key,
  });

  final String title;
  final IconData icon;
  final int trailingCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Chip(label: Text('$trailingCount')),
      ],
    );
  }
}

class CountTile extends StatelessWidget {
  const CountTile({required this.count, super.key});

  final GeofenceVehicleCount count;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(
          count.isNoGeofence
              ? Icons.location_off_outlined
              : Icons.location_on_outlined,
        ),
        title: Text(count.geofenceName),
        trailing: Chip(label: Text('${count.vehicleCount}')),
      ),
    );
  }
}

class GeofenceCard extends StatelessWidget {
  const GeofenceCard({
    required this.item,
    required this.onEdit,
    required this.onDeactivate,
    super.key,
  });

  final GeofenceListItem item;
  final VoidCallback? onEdit;
  final VoidCallback? onDeactivate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = item.isActive
        ? theme.colorScheme.primaryContainer.withValues(alpha: 0.25)
        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5);

    return Card(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: bgColor,
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Chip(label: Text(item.isActive ? 'ACTIVE' : 'INACTIVE')),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Center: ${item.centerLat.toStringAsFixed(6)}, ${item.centerLon.toStringAsFixed(6)}',
            ),
            Text('Radius: ${item.radiusM.toStringAsFixed(0)} m'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit'),
                ),
                OutlinedButton.icon(
                  onPressed: onDeactivate,
                  icon: const Icon(Icons.block_outlined),
                  label: const Text('Deactivate'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class EmptySectionLabel extends StatelessWidget {
  const EmptySectionLabel({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}
