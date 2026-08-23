part of 'vehicle_detail_cubit.dart';

enum VehicleDetailStatus { initial, loading, ready }

class VehicleDetailState {
  const VehicleDetailState({
    required this.status,
    required this.vehicleId,
    required this.statusMessage,
  });

  const VehicleDetailState.initial({required this.vehicleId})
    : status = VehicleDetailStatus.initial,
      statusMessage = 'Not loaded';

  final VehicleDetailStatus status;
  final String? vehicleId;
  final String statusMessage;

  VehicleDetailState copyWith({
    VehicleDetailStatus? status,
    String? vehicleId,
    String? statusMessage,
  }) {
    return VehicleDetailState(
      status: status ?? this.status,
      vehicleId: vehicleId ?? this.vehicleId,
      statusMessage: statusMessage ?? this.statusMessage,
    );
  }
}
