import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../fleet/cubit/fleet_home_cubit.dart';
import '../../bloc/alerts_bloc.dart';
import '../../models/alert_models.dart';
import '../widgets/alert_dismiss_reason_sheet.dart';

class AlertsPageActions {
  const AlertsPageActions._();

  static Future<void> onDismissPressed(BuildContext context, ActiveAlertRow alert) async {
    final messenger = ScaffoldMessenger.of(context);
    final reason = await showAlertDismissReasonSheet(context, alert);
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

  static Future<void> _refreshFleetIfAvailable(BuildContext context) async {
    try {
      await context.read<FleetHomeCubit>().refresh();
    } catch (_) {
      // AlertsPage tests can mount this widget without FleetHomeCubit.
    }
  }
}