import 'package:flutter/material.dart';

import '../../models/alert_models.dart';
import 'severity_chip.dart';

class AlertsListItem extends StatelessWidget {
  const AlertsListItem({
    required this.alert,
    required this.onDismissPressed,
    super.key,
  });

  final ActiveAlertRow alert;
  final VoidCallback onDismissPressed;

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
                    alert.regNumber,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                SeverityChip(severity: alert.severity),
              ],
            ),
            const SizedBox(height: 4),
            Text(alert.model),
            const SizedBox(height: 8),
            Text(
              alertReasonLabel(
                type: alert.type,
                severity: alert.severity,
              ),
            ),
            const SizedBox(height: 4),
            Text('Vehicle: ${alert.vehicleId}'),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton(
                onPressed: onDismissPressed,
                child: const Text('Dismiss'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}