import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubit/fleet_home_cubit.dart';
import 'actions/fleet_home_navigation.dart';
import 'widgets/fleet_home_content.dart';

class FleetHomePage extends StatelessWidget {
  const FleetHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FleetHomeCubit, FleetHomeState>(
      builder: (context, state) => FleetHomeContent(
        state: state,
        onVehicleTap: (row) {
          FleetHomeNavigation.openVehicleDetail(context, row.vehicleId);
        },
      ),
    );
  }
}
