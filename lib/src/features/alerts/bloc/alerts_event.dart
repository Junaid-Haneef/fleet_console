part of 'alerts_bloc.dart';

sealed class AlertsEvent {
  const AlertsEvent();
}

final class AlertsRefreshRequested extends AlertsEvent {
  const AlertsRefreshRequested(this.completer);

  final Completer<void> completer;
}

final class AlertDismissRequested extends AlertsEvent {
  const AlertDismissRequested({
    required this.alert,
    required this.reason,
    required this.completer,
  });

  final ActiveAlertRow alert;
  final AlertDismissReason reason;
  final Completer<DateTime?> completer;
}

final class AlertUndoRequested extends AlertsEvent {
  const AlertUndoRequested({required this.alert, required this.completer});

  final ActiveAlertRow alert;
  final Completer<bool> completer;
}
