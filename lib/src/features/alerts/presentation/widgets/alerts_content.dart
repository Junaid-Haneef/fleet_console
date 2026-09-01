import 'package:fleet_console/src/features/alerts/bloc/alerts_bloc.dart';
import 'package:flutter/material.dart';

import '../../models/alert_models.dart';
import 'alerts_list_item.dart';

class AlertsContent extends StatelessWidget {
  const AlertsContent({
    required this.state,
    required this.onDismissPressed,
    super.key,
  });

  final AlertsState state;
  final ValueChanged<ActiveAlertRow> onDismissPressed;

  @override
  Widget build(BuildContext context) {
    if (state.status == AlertsStatus.loading && state.alerts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.status == AlertsStatus.error && state.alerts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            state.errorMessage ?? 'Failed to load alerts.',
            style: const TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (state.alerts.isEmpty) {
      return const Center(
        child: Text('No active alerts.'),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: state.alerts.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final alert = state.alerts[index];
        return AlertsListItem(
          alert: alert,
          onDismissPressed: () => onDismissPressed(alert),
        );
      },
    );
  }
}