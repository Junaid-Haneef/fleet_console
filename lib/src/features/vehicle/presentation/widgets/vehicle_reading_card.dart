import 'package:flutter/material.dart';

import '../../models/vehicle_detail_models.dart';
import '../utils/vehicle_detail_formatters.dart';
import 'vehicle_verdict_pill.dart';

class VehicleReadingCard extends StatelessWidget {
  const VehicleReadingCard({required this.reading, super.key});

  final VehicleReadingRow reading;

  @override
  Widget build(BuildContext context) {
    final signalId = _signalId(reading.signal);

    return Card(
      key: ValueKey('reading-row-$signalId'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(reading.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    _valueText(reading),
                    key: ValueKey('reading-value-$signalId'),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _ageText(reading),
                    key: ValueKey('reading-age-$signalId'),
                    style: const TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
            if (reading.verdict != VehicleReadingVerdict.none)
              VehicleVerdictPill(
                key: ValueKey('reading-pill-$signalId'),
                verdict: reading.verdict,
              ),
          ],
        ),
      ),
    );
  }

  String _signalId(VehicleSignalKey signal) {
    switch (signal) {
      case VehicleSignalKey.soc:
        return 'soc';
      case VehicleSignalKey.rangeKm:
        return 'range';
      case VehicleSignalKey.speed:
        return 'speed';
      case VehicleSignalKey.batteryTemp:
        return 'battery_temp';
      case VehicleSignalKey.odometer:
        return 'odometer';
      case VehicleSignalKey.lastPing:
        return 'last_ping';
    }
  }

  String _valueText(VehicleReadingRow row) {
    if (!row.hasReported) {
      return '—';
    }

    final value = row.value;
    switch (row.signal) {
      case VehicleSignalKey.soc:
        return value == null ? '—' : '${value.toStringAsFixed(0)}%';
      case VehicleSignalKey.rangeKm:
        return value == null ? '—' : '${value.toStringAsFixed(0)} km';
      case VehicleSignalKey.speed:
        return value == null ? '—' : '${value.toStringAsFixed(0)} km/h';
      case VehicleSignalKey.batteryTemp:
        return value == null ? '—' : '${value.toStringAsFixed(1)} C';
      case VehicleSignalKey.odometer:
        return value == null ? '—' : '${value.toStringAsFixed(1)} km';
      case VehicleSignalKey.lastPing:
        return row.eventTime == null ? '—' : formatVehicleUtcTimestamp(row.eventTime!);
    }
  }

  String _ageText(VehicleReadingRow row) {
    if (!row.hasReported) {
      return 'Never reported';
    }

    final ageSeconds = row.ageSeconds;
    if (ageSeconds == null) {
      return 'Age unavailable';
    }

    return 'Age ${formatVehicleReadingAge(ageSeconds)}';
  }
}