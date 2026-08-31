import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/alert_models.dart';
import '../bloc/alerts_bloc.dart';
import '../../fleet/cubit/fleet_home_cubit.dart';

class AlertsPage extends StatelessWidget {
  const AlertsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AlertsBloc, AlertsState>(
      builder: (context, state) {
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
                        _SeverityChip(severity: alert.severity),
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
                        onPressed: () => _onDismissPressed(context, alert),
                        child: const Text('Dismiss'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _onDismissPressed(BuildContext context, ActiveAlertRow alert) async {
    final messenger = ScaffoldMessenger.of(context);
    final reason = await _showDismissReasonSheet(context, alert);
    if (reason == null || !context.mounted) {
      return;
    }

    final expiresAt = await context.read<AlertsBloc>().dismissAlert(alert, reason);
    if (expiresAt == null || !context.mounted) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Could not dismiss alert. Please try again.'),
        ),
      );
      return;
    }

    await _refreshFleetIfAvailable(context);
    final duration = const Duration(seconds: 5);

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        duration: duration,
        content: Text('${alert.regNumber} alert dismissed'),
        action: SnackBarAction(
          label: 'UNDO',
          onPressed: () {
            context.read<AlertsBloc>().undoDismissedAlert(alert).then((_) {
              if (context.mounted) {
                _refreshFleetIfAvailable(context);
              }
            });
          },
        ),
      ),
    );

    // Enforce closure after 5 seconds even when accessibility settings keep
    // action snackbars open longer than requested duration.
    Future<void>.delayed(duration, () {
      messenger.hideCurrentSnackBar();
    });
  }

  Future<void> _refreshFleetIfAvailable(BuildContext context) async {
    try {
      await context.read<FleetHomeCubit>().refresh();
    } catch (_) {
      // AlertsPage tests can mount this widget without FleetHomeCubit.
    }
  }

  Future<AlertDismissReason?> _showDismissReasonSheet(
    BuildContext context,
    ActiveAlertRow alert,
  ) {
    final reasons = [
      AlertDismissReason.iAmOnIt,
      AlertDismissReason.wrongAlert,
      AlertDismissReason.somethingElse,
    ];

    return showModalBottomSheet<AlertDismissReason>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text(
                  'Dismiss reason',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              ListTile(
                dense: true,
                title: Text(
                  alertReasonLabel(
                    type: alert.type,
                    severity: alert.severity,
                  ),
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: Text('Vehicle: ${alert.regNumber}'),
              ),
              ...reasons.map(
                (reason) => ListTile(
                  title: Text(alertDismissReasonLabel(reason)),
                  onTap: () => Navigator.of(sheetContext).pop(reason),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SeverityChip extends StatelessWidget {
  const _SeverityChip({required this.severity});

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
