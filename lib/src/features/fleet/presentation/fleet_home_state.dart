part of 'fleet_home_cubit.dart';

const Object _noErrorMessageChange = Object();

enum FleetHomeStatus { initial, loading, ready, error }

class FleetHomeState {
  const FleetHomeState({
    required this.status,
    required this.statusMessage,
    required this.selectedFilter,
    required this.allRows,
    required this.visibleRows,
    required this.counts,
    required this.errorMessage,
  });

  const FleetHomeState.initial()
    : status = FleetHomeStatus.initial,
      statusMessage = 'Not loaded',
      selectedFilter = FleetFilter.all,
      allRows = const <FleetVehicleRow>[],
      visibleRows = const <FleetVehicleRow>[],
      counts = const FleetFilterCounts.zero(),
      errorMessage = null;

  final FleetHomeStatus status;
  final String statusMessage;
  final FleetFilter selectedFilter;
  final List<FleetVehicleRow> allRows;
  final List<FleetVehicleRow> visibleRows;
  final FleetFilterCounts counts;
  final String? errorMessage;

  FleetHomeState copyWith({
    FleetHomeStatus? status,
    String? statusMessage,
    FleetFilter? selectedFilter,
    List<FleetVehicleRow>? allRows,
    List<FleetVehicleRow>? visibleRows,
    FleetFilterCounts? counts,
    Object? errorMessage = _noErrorMessageChange,
  }) {
    return FleetHomeState(
      status: status ?? this.status,
      statusMessage: statusMessage ?? this.statusMessage,
      selectedFilter: selectedFilter ?? this.selectedFilter,
      allRows: allRows ?? this.allRows,
      visibleRows: visibleRows ?? this.visibleRows,
      counts: counts ?? this.counts,
      errorMessage: identical(errorMessage, _noErrorMessageChange)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}