import 'package:flutter/material.dart';

import '../../models/vehicle_detail_models.dart';
import '../utils/vehicle_detail_formatters.dart';

class SocHistoryTable extends StatelessWidget {
  const SocHistoryTable({required this.points, super.key});

  final List<SocHistoryPoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Text('No SOC history in retained event log.'),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Event time')),
          DataColumn(label: Text('SOC')),
        ],
        rows: points
            .map(
              (point) => DataRow(
                cells: [
                  DataCell(Text(formatVehicleUtcTimestamp(point.eventTime))),
                  DataCell(Text('${point.soc.toStringAsFixed(1)}%')),
                ],
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}