import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubit/vehicle_detail_cubit.dart';
import 'actions/vehicle_detail_page_actions.dart';
import 'widgets/vehicle_detail_content.dart';

class VehicleDetailPage extends StatefulWidget {
  const VehicleDetailPage({super.key, required this.vehicleId});

  final String vehicleId;

  @override
  State<VehicleDetailPage> createState() => _VehicleDetailPageState();
}

class _VehicleDetailPageState extends State<VehicleDetailPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.read<VehicleDetailCubit>().load(widget.vehicleId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vehicle Detail'),
        actions: [
          IconButton(
            onPressed: () => VehicleDetailPageActions.openAlerts(context),
            icon: const Icon(Icons.warning_amber_outlined),
            tooltip: 'Open alerts',
          ),
          IconButton(
            onPressed: () => context.read<VehicleDetailCubit>().refresh(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: const VehicleDetailContent(),
    );
  }
}
