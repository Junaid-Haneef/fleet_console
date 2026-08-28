import '../../../core/database/app_database.dart';

class TripsRepository {
  TripsRepository(this._database);

  final AppDatabase _database;

  Future<void> recomputeTripsFromConfirmedTransitions() async {
    final rows = await _database.query(_orderedTransitionsSql());
    final transitions = rows
        .map(_TransitionRow.fromRow)
        .toList(growable: true)
      ..sort(_compareTransitions);

    final derivedTrips = _deriveTrips(transitions);

    await _database.execute('BEGIN TRANSACTION');
    try {
      for (final trip in derivedTrips) {
        await _database.execute(_upsertTripSql(trip));
      }

      await _database.execute(_deleteStaleTripsSql(derivedTrips));
      await _database.execute('COMMIT');
    } catch (_) {
      await _database.execute('ROLLBACK');
      rethrow;
    }
  }

  List<_DerivedTrip> _deriveTrips(List<_TransitionRow> transitions) {
    final trips = <_DerivedTrip>[];
    _DerivedTrip? activeTrip;
    String? activeVehicleId;

    for (final transition in transitions) {
      if (activeVehicleId != transition.vehicleId) {
        if (activeTrip != null) {
          trips.add(activeTrip);
        }
        activeTrip = null;
        activeVehicleId = transition.vehicleId;
      }

      if (transition.transitionType == 'EXIT') {
        if (transition.geofenceId == null || activeTrip != null) {
          continue;
        }
        activeTrip = _DerivedTrip.start(transition);
        continue;
      }

      if (transition.transitionType == 'ENTER' && activeTrip != null) {
        trips.add(activeTrip.complete(transition));
        activeTrip = null;
      }
    }

    if (activeTrip != null) {
      trips.add(activeTrip);
    }

    return trips;
  }

  int _compareTransitions(_TransitionRow left, _TransitionRow right) {
    final vehicleOrder = left.vehicleId.compareTo(right.vehicleId);
    if (vehicleOrder != 0) {
      return vehicleOrder;
    }

    final eventOrder = left.eventTime.compareTo(right.eventTime);
    if (eventOrder != 0) {
      return eventOrder;
    }

    // For a same-timestamp boundary change, process EXIT before ENTER so the
    // next ENTER can complete the newly opened trip deterministically.
    final leftRank = left.transitionType == 'EXIT' ? 0 : 1;
    final rightRank = right.transitionType == 'EXIT' ? 0 : 1;
    final typeOrder = leftRank.compareTo(rightRank);
    if (typeOrder != 0) {
      return typeOrder;
    }

    return left.transitionId.compareTo(right.transitionId);
  }

  String _orderedTransitionsSql() {
    return '''
      SELECT
        transition_id,
        vehicle_id,
        transition_type,
        geofence_id,
        geofence_version_id,
        event_time
      FROM geofence_transitions
      ORDER BY
        vehicle_id ASC,
        event_time ASC,
        CASE WHEN transition_type = 'EXIT' THEN 0 ELSE 1 END,
        transition_id ASC
    ''';
  }

  String _upsertTripSql(_DerivedTrip trip) {
    return '''
      INSERT INTO trips (
        trip_id,
        vehicle_id,
        active_trip_vehicle_id,
        exit_transition_id,
        origin_geofence_id,
        origin_geofence_version_id,
        start_event_time,
        entry_transition_id,
        destination_geofence_id,
        destination_geofence_version_id,
        end_event_time,
        status,
        updated_at
      )
      VALUES (
        '${_escape(trip.tripId)}',
        '${_escape(trip.vehicleId)}',
        ${trip.status == 'IN_PROGRESS' ? "'${_escape(trip.vehicleId)}'" : 'NULL'},
        '${_escape(trip.exitTransitionId)}',
        '${_escape(trip.originGeofenceId)}',
        ${trip.originGeofenceVersionId == null ? 'NULL' : "'${_escape(trip.originGeofenceVersionId!)}'"},
        TIMESTAMP '${_escape(trip.startEventTime.toUtc().toIso8601String())}',
        ${trip.entryTransitionId == null ? 'NULL' : "'${_escape(trip.entryTransitionId!)}'"},
        ${trip.destinationGeofenceId == null ? 'NULL' : "'${_escape(trip.destinationGeofenceId!)}'"},
        ${trip.destinationGeofenceVersionId == null ? 'NULL' : "'${_escape(trip.destinationGeofenceVersionId!)}'"},
        ${trip.endEventTime == null ? 'NULL' : "TIMESTAMP '${_escape(trip.endEventTime!.toUtc().toIso8601String())}'"},
        '${trip.status}',
        TIMESTAMP '${_escape(trip.updatedAt.toUtc().toIso8601String())}'
      )
      ON CONFLICT (trip_id) DO UPDATE
        SET active_trip_vehicle_id = EXCLUDED.active_trip_vehicle_id,
          exit_transition_id = EXCLUDED.exit_transition_id,
          origin_geofence_id = EXCLUDED.origin_geofence_id,
          origin_geofence_version_id = EXCLUDED.origin_geofence_version_id,
          start_event_time = EXCLUDED.start_event_time,
          entry_transition_id = EXCLUDED.entry_transition_id,
          destination_geofence_id = EXCLUDED.destination_geofence_id,
          destination_geofence_version_id = EXCLUDED.destination_geofence_version_id,
          end_event_time = EXCLUDED.end_event_time,
          status = EXCLUDED.status,
          updated_at = EXCLUDED.updated_at
    ''';
  }

  String _deleteStaleTripsSql(List<_DerivedTrip> derivedTrips) {
    if (derivedTrips.isEmpty) {
      return 'DELETE FROM trips';
    }

    final ids = derivedTrips
        .map((trip) => "'${_escape(trip.tripId)}'")
        .join(', ');
    return 'DELETE FROM trips WHERE trip_id NOT IN ($ids)';
  }

  String _escape(String input) => input.replaceAll("'", "''");
}

class _TransitionRow {
  const _TransitionRow({
    required this.transitionId,
    required this.vehicleId,
    required this.transitionType,
    required this.geofenceId,
    required this.geofenceVersionId,
    required this.eventTime,
  });

  factory _TransitionRow.fromRow(List<Object?> row) {
    return _TransitionRow(
      transitionId: row[0] as String,
      vehicleId: row[1] as String,
      transitionType: row[2] as String,
      geofenceId: row[3] as String?,
      geofenceVersionId: row[4] as String?,
      eventTime: _asDateTime(row[5]),
    );
  }

  final String transitionId;
  final String vehicleId;
  final String transitionType;
  final String? geofenceId;
  final String? geofenceVersionId;
  final DateTime eventTime;
}

class _DerivedTrip {
  const _DerivedTrip({
    required this.tripId,
    required this.vehicleId,
    required this.exitTransitionId,
    required this.originGeofenceId,
    required this.originGeofenceVersionId,
    required this.startEventTime,
    required this.entryTransitionId,
    required this.destinationGeofenceId,
    required this.destinationGeofenceVersionId,
    required this.endEventTime,
    required this.status,
    required this.updatedAt,
  });

  factory _DerivedTrip.start(_TransitionRow transition) {
    final tripId = '${transition.vehicleId}|${transition.transitionId}';
    return _DerivedTrip(
      tripId: tripId,
      vehicleId: transition.vehicleId,
      exitTransitionId: transition.transitionId,
      originGeofenceId: transition.geofenceId!,
      originGeofenceVersionId: transition.geofenceVersionId,
      startEventTime: transition.eventTime,
      entryTransitionId: null,
      destinationGeofenceId: null,
      destinationGeofenceVersionId: null,
      endEventTime: null,
      status: 'IN_PROGRESS',
      updatedAt: transition.eventTime,
    );
  }

  final String tripId;
  final String vehicleId;
  final String exitTransitionId;
  final String originGeofenceId;
  final String? originGeofenceVersionId;
  final DateTime startEventTime;
  final String? entryTransitionId;
  final String? destinationGeofenceId;
  final String? destinationGeofenceVersionId;
  final DateTime? endEventTime;
  final String status;
  final DateTime updatedAt;

  _DerivedTrip complete(_TransitionRow entryTransition) {
    return _DerivedTrip(
      tripId: tripId,
      vehicleId: vehicleId,
      exitTransitionId: exitTransitionId,
      originGeofenceId: originGeofenceId,
      originGeofenceVersionId: originGeofenceVersionId,
      startEventTime: startEventTime,
      entryTransitionId: entryTransition.transitionId,
      destinationGeofenceId: entryTransition.geofenceId,
      destinationGeofenceVersionId: entryTransition.geofenceVersionId,
      endEventTime: entryTransition.eventTime,
      status: 'COMPLETED',
      updatedAt: entryTransition.eventTime,
    );
  }
}

DateTime _asDateTime(Object? value) {
  if (value is DateTime) {
    return value.toUtc();
  }
  if (value is String) {
    return DateTime.parse(value).toUtc();
  }
  throw StateError('Unsupported datetime value: ${value.runtimeType}');
}
