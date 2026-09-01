import 'package:flutter/material.dart';

import '../../models/alert_models.dart';

class SeverityChip extends StatelessWidget {
  const SeverityChip({required this.severity, super.key});

  final AlertSeverity severity;

  @override
  Widget build(BuildContext context) {
    final isCritical = severity == AlertSeverity.critical;
    final color = isCritical ? Colors.red : Colors.amber;
    final text = isCritical ? 'Critical' : 'Warning';

    return Chip(
      backgroundColor: color.withValues(alpha: 0.15),
      side: BorderSide(color: color.withValues(alpha: 0.35)),
      label: Text(
        text,
        style: TextStyle(
          color: color.shade700,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}