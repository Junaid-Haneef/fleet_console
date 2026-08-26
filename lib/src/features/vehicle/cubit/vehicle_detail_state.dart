part of 'vehicle_detail_cubit.dart';

const Object _noErrorMessageChange = Object();

enum VehicleDetailStatus { initial, loading, ready, error }

class VehicleDetailState {
  const VehicleDetailState({
    required this.status,
    required this.vehicleId,
    required this.statusMessage,
    required this.snapshot,
    required this.errorMessage,
  });

  const VehicleDetailState.initial({required this.vehicleId})
    : status = VehicleDetailStatus.initial,
      statusMessage = 'Not loaded',
      snapshot = null,
      errorMessage = null;

  final VehicleDetailStatus status;
  final String? vehicleId;
  final String statusMessage;
  final VehicleDetailSnapshot? snapshot;
  final String? errorMessage;

  VehicleDetailState copyWith({
    VehicleDetailStatus? status,
    String? vehicleId,
    String? statusMessage,
    VehicleDetailSnapshot? snapshot,
    Object? errorMessage = _noErrorMessageChange,
  }) {
    return VehicleDetailState(
      status: status ?? this.status,
      vehicleId: vehicleId ?? this.vehicleId,
      statusMessage: statusMessage ?? this.statusMessage,
      snapshot: snapshot ?? this.snapshot,
      errorMessage: identical(errorMessage, _noErrorMessageChange)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}
