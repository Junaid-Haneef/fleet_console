import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubit/geofences_cubit.dart';
import '../models/geofence_models.dart';

class GeofencesPage extends StatelessWidget {
  const GeofencesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GeofencesCubit, GeofencesState>(
      builder: (context, state) {
        if (state.status == GeofencesStatus.loading &&
            state.activeGeofences.isEmpty &&
            state.inactiveGeofences.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        return RefreshIndicator(
          onRefresh: () => context.read<GeofencesCubit>().refresh(),
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Geofences',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => _showEditorDialog(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Create'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Live Vehicle Counts',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              ...state.vehicleCounts.map(_buildCountRow),
              const SizedBox(height: 16),
              const Text(
                'Active Geofences',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              if (state.activeGeofences.isEmpty)
                const Text('No active geofences.')
              else
                ...state.activeGeofences.map((item) => _buildGeofenceCard(context, item)),
              const SizedBox(height: 16),
              const Text(
                'Inactive Geofences',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              if (state.inactiveGeofences.isEmpty)
                const Text('No inactive geofences.')
              else
                ...state.inactiveGeofences.map((item) => _buildGeofenceCard(context, item)),
              if (state.status == GeofencesStatus.error && state.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    state.errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCountRow(GeofenceVehicleCount count) {
    return Card(
      child: ListTile(
        title: Text(count.geofenceName),
        trailing: Text('${count.vehicleCount}'),
      ),
    );
  }

  Widget _buildGeofenceCard(BuildContext context, GeofenceListItem item) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Chip(
                  label: Text(item.isActive ? 'ACTIVE' : 'INACTIVE'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('Center: ${item.centerLat.toStringAsFixed(6)}, ${item.centerLon.toStringAsFixed(6)}'),
            Text('Radius: ${item.radiusM.toStringAsFixed(0)} m'),
            const SizedBox(height: 8),
            Row(
              children: [
                OutlinedButton(
                  onPressed: item.isActive
                      ? () => _showEditorDialog(context, existing: item)
                      : null,
                  child: const Text('Edit'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: item.isActive
                      ? () => context.read<GeofencesCubit>().deactivateGeofence(item.geofenceId)
                      : null,
                  child: const Text('Deactivate'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditorDialog(BuildContext context, {GeofenceListItem? existing}) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final latController = TextEditingController(
      text: existing == null ? '' : existing.centerLat.toString(),
    );
    final lonController = TextEditingController(
      text: existing == null ? '' : existing.centerLon.toString(),
    );
    final radiusController = TextEditingController(
      text: existing == null ? '' : existing.radiusM.toStringAsFixed(0),
    );

    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(existing == null ? 'Create geofence' : 'Edit geofence'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                TextField(
                  controller: latController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Center latitude'),
                ),
                TextField(
                  controller: lonController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Center longitude'),
                ),
                TextField(
                  controller: radiusController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Radius meters'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (save != true || !context.mounted) {
      return;
    }

    final name = nameController.text.trim();
    final lat = double.tryParse(latController.text.trim());
    final lon = double.tryParse(lonController.text.trim());
    final radius = double.tryParse(radiusController.text.trim());
    if (name.isEmpty || lat == null || lon == null || radius == null || radius <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid geofence values.')),
      );
      return;
    }

    final cubit = context.read<GeofencesCubit>();
    if (existing == null) {
      await cubit.createGeofence(
        name: name,
        centerLat: lat,
        centerLon: lon,
        radiusM: radius,
      );
      return;
    }

    await cubit.editGeofence(
      geofenceId: existing.geofenceId,
      name: name,
      centerLat: lat,
      centerLon: lon,
      radiusM: radius,
    );
  }
}
