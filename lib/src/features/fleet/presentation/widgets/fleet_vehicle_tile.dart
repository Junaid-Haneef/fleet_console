import 'package:flutter/material.dart';

import '../../models/fleet_home_models.dart';

class FleetVehicleTile extends StatelessWidget {
  const FleetVehicleTile({
    required this.row,
    required this.onTap,
    super.key,
  });

  final FleetVehicleRow row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
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
              const SizedBox(height: 4),
              Text('Geofence: ${row.currentGeofenceName}'),
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