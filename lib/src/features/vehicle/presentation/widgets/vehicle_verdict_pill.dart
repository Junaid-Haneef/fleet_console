import 'package:flutter/material.dart';

import '../../models/vehicle_detail_models.dart';

class VehicleVerdictPill extends StatelessWidget {
  const VehicleVerdictPill({super.key, required this.verdict});

  final VehicleReadingVerdict verdict;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (verdict) {
      VehicleReadingVerdict.none => ('', Colors.transparent),
      VehicleReadingVerdict.normal => ('NORMAL', Colors.green),
      VehicleReadingVerdict.alert => ('ALERT', Colors.red),
      VehicleReadingVerdict.stale => ('STALE', Colors.grey),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}