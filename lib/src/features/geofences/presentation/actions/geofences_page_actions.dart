import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../cubit/geofences_cubit.dart';
import '../../models/geofence_models.dart';

class GeofencesPageActions {
  const GeofencesPageActions._();

  static Future<void> showEditorDialog(
    BuildContext context, {
    GeofenceListItem? existing,
  }) async {
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

    try {
      final save = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: Text(existing == null ? 'Create geofence' : 'Edit geofence'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _EditorField(
                    controller: nameController,
                    label: 'Name',
                    keyboardType: TextInputType.text,
                  ),
                  const SizedBox(height: 10),
                  _EditorField(
                    controller: latController,
                    label: 'Center latitude',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _EditorField(
                    controller: lonController,
                    label: 'Center longitude',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _EditorField(
                    controller: radiusController,
                    label: 'Radius meters',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
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
      if (name.isEmpty ||
          lat == null ||
          lon == null ||
          radius == null ||
          radius <= 0) {
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
    } finally {
      nameController.dispose();
      latController.dispose();
      lonController.dispose();
      radiusController.dispose();
    }
  }
}

class _EditorField extends StatelessWidget {
  const _EditorField({
    required this.controller,
    required this.label,
    required this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final TextInputType keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }
}
