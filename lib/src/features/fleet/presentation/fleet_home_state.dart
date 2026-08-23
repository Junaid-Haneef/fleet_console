part of 'fleet_home_cubit.dart';

enum FleetHomeStatus { initial, loading, ready }

class FleetHomeState {
  const FleetHomeState({required this.status, required this.statusMessage});

  const FleetHomeState.initial()
    : status = FleetHomeStatus.initial,
      statusMessage = 'Not loaded';

  final FleetHomeStatus status;
  final String statusMessage;

  FleetHomeState copyWith({FleetHomeStatus? status, String? statusMessage}) {
    return FleetHomeState(
      status: status ?? this.status,
      statusMessage: statusMessage ?? this.statusMessage,
    );
  }
}