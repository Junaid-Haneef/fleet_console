import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubit/geofences_cubit.dart';
import 'actions/geofences_page_actions.dart';
import 'widgets/geofences_content.dart';

class GeofencesPage extends StatelessWidget {
  const GeofencesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GeofencesCubit, GeofencesState>(
      builder: (context, state) => GeofencesContent(
        state: state,
        onRefresh: () => context.read<GeofencesCubit>().refresh(),
        onCreatePressed: () => GeofencesPageActions.showEditorDialog(context),
        onEditPressed: (item) =>
            GeofencesPageActions.showEditorDialog(context, existing: item),
        onDeactivatePressed: (item) =>
            context.read<GeofencesCubit>().deactivateGeofence(item.geofenceId),
      ),
    );
  }
}
