import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/database/app_database.dart';
import '../data/alerts_repository.dart';
import '../models/alert_models.dart';

part 'alerts_event.dart';
part 'alerts_state.dart';

class AlertsBloc extends Bloc<AlertsEvent, AlertsState> {
  AlertsBloc(
    AppDatabase database, {
    AlertsRepository? repository,
  }) : _repository = repository ?? AlertsRepository(database),
       super(const AlertsState.initial()) {
    on<AlertsRefreshRequested>(_onRefreshRequested);
    on<AlertDismissRequested>(_onDismissRequested);
    on<AlertUndoRequested>(_onUndoRequested);
  }

  final AlertsRepository _repository;

  Future<void> refresh() {
    final completer = Completer<void>();
    add(AlertsRefreshRequested(completer));
    return completer.future;
  }

  Future<DateTime?> dismissAlert(
    ActiveAlertRow alert,
    AlertDismissReason reason,
  ) {
    final completer = Completer<DateTime?>();
    add(
      AlertDismissRequested(
        alert: alert,
        reason: reason,
        completer: completer,
      ),
    );
    return completer.future;
  }

  Future<bool> undoDismissedAlert(ActiveAlertRow alert) {
    final completer = Completer<bool>();
    add(AlertUndoRequested(alert: alert, completer: completer));
    return completer.future;
  }

  Future<void> _onRefreshRequested(
    AlertsRefreshRequested event,
    Emitter<AlertsState> emit,
  ) async {
    emit(state.copyWith(status: AlertsStatus.loading, errorMessage: null));

    try {
      final alerts = await _repository.fetchActiveAlerts();
      final count = await _repository.fetchActiveAlertCount();

      emit(
        state.copyWith(
          status: AlertsStatus.ready,
          alerts: alerts,
          activeCount: count,
          errorMessage: null,
        ),
      );
      event.completer.complete();
    } catch (error) {
      emit(
        state.copyWith(
          status: AlertsStatus.error,
          errorMessage: error.toString(),
        ),
      );
      event.completer.completeError(error);
    }
  }

  Future<void> _onDismissRequested(
    AlertDismissRequested event,
    Emitter<AlertsState> emit,
  ) async {
    try {
      final expiresAt = await _repository.dismissAlert(
        vehicleId: event.alert.vehicleId,
        alertType: event.alert.type,
        reason: event.reason,
      );

      final alerts = await _repository.fetchActiveAlerts();
      final count = await _repository.fetchActiveAlertCount();

      emit(
        state.copyWith(
          status: AlertsStatus.ready,
          alerts: alerts,
          activeCount: count,
          errorMessage: null,
        ),
      );

      event.completer.complete(expiresAt);
    } catch (error) {
      emit(
        state.copyWith(
          status: AlertsStatus.error,
          errorMessage: error.toString(),
        ),
      );
      event.completer.complete(null);
    }
  }

  Future<void> _onUndoRequested(
    AlertUndoRequested event,
    Emitter<AlertsState> emit,
  ) async {
    try {
      final undone = await _repository.undoDismissal(
        vehicleId: event.alert.vehicleId,
        alertType: event.alert.type,
      );

      final alerts = await _repository.fetchActiveAlerts();
      final count = await _repository.fetchActiveAlertCount();

      emit(
        state.copyWith(
          status: AlertsStatus.ready,
          alerts: alerts,
          activeCount: count,
          errorMessage: null,
        ),
      );

      event.completer.complete(undone);
    } catch (error) {
      emit(
        state.copyWith(
          status: AlertsStatus.error,
          errorMessage: error.toString(),
        ),
      );
      event.completer.complete(false);
    }
  }
}
