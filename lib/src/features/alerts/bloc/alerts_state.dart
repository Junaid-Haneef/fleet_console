part of 'alerts_bloc.dart';

const Object _noErrorMessageChange = Object();

enum AlertsStatus { initial, loading, ready, error }

class AlertsState {
  const AlertsState({
    required this.status,
    required this.alerts,
    required this.activeCount,
    required this.errorMessage,
  });

  const AlertsState.initial()
    : status = AlertsStatus.initial,
      alerts = const <ActiveAlertRow>[],
      activeCount = 0,
      errorMessage = null;

  final AlertsStatus status;
  final List<ActiveAlertRow> alerts;
  final int activeCount;
  final String? errorMessage;

  AlertsState copyWith({
    AlertsStatus? status,
    List<ActiveAlertRow>? alerts,
    int? activeCount,
    Object? errorMessage = _noErrorMessageChange,
  }) {
    return AlertsState(
      status: status ?? this.status,
      alerts: alerts ?? this.alerts,
      activeCount: activeCount ?? this.activeCount,
      errorMessage: identical(errorMessage, _noErrorMessageChange)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}
