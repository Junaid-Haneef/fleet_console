import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/database/app_database.dart';
import '../../../vehicle/cubit/vehicle_detail_cubit.dart';
import '../../../vehicle/data/vehicle_detail_repository.dart';
import '../../../vehicle/presentation/vehicle_detail_page.dart';

class FleetHomeNavigation {
  const FleetHomeNavigation._();

  static void openVehicleDetail(BuildContext context, String vehicleId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (routeContext) {
          final database = routeContext.read<AppDatabase>();
          final repository = routeContext.read<VehicleDetailRepository>();

          return BlocProvider<VehicleDetailCubit>(
            create: (_) => VehicleDetailCubit(
              database,
              repository: repository,
            ),
            child: VehicleDetailPage(vehicleId: vehicleId),
          );
        },
      ),
    );
  }
}