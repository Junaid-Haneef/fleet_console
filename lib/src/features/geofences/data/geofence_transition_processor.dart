import 'dart:math' as math;

import '../../../core/database/app_database.dart';

const Duration _maxConfirmationGap = Duration(seconds: 60);

class GeofenceTransitionProcessor {
  GeofenceTransitionProcessor(this._database);

  final AppDatabase _database;

  Future<void> recomputeConfirmedTransitions() async {
    final geofenceRows = await _database.query(_geofenceVersionsSql());
    final locationRows = await _database.query(_locationHistorySql());

    final geofenceVersions = geofenceRows.map(_GeofenceVersion.fromRow).toList(growable: false);
    final readingsByVehicle = <String, List<_LocationReading>>{};
    for (final row in locationRows) {
      final reading = _LocationReading.fromRow(row);
      readingsByVehicle.putIfAbsent(reading.vehicleId, () => []).add(reading);
    }

    final transitions = <_GeofenceTransition>[];
    for (final entry in readingsByVehicle.entries) {
      transitions.addAll(_processVehicle(entry.key, entry.value, geofenceVersions));
    }

    await _database.execute('BEGIN TRANSACTION');
    try {
      for (final transition in transitions) {
        await _database.execute(_insertTransitionSql(transition));
      }

      await _database.execute('DELETE FROM vehicle_geofence_state');

      final latestRows = await _database.query(_latestTransitionsSql());
      for (final row in latestRows) {
        final latest = _LatestVehicleTransition.fromRow(row);
        await _database.execute(_upsertVehicleStateSql(latest));
      }

      await _database.execute('COMMIT');
    } catch (_) {
      await _database.execute('ROLLBACK');
      rethrow;
    }
  }

  List<_GeofenceTransition> _processVehicle(
    String vehicleId,
    List<_LocationReading> readings,
    List<_GeofenceVersion> geofenceVersions,
  ) {
    readings.sort((left, right) => left.eventTime.compareTo(right.eventTime));

    final transitions = <_GeofenceTransition>[];
    String? confirmedGeofenceId;
    String? confirmedGeofenceVersionId;
    _PendingCandidate? pending;
    DateTime? lastTrustedReadingTime;

    for (final reading in readings) {
      if (reading.accuracyM > 50) {
        continue;
      }

      if (lastTrustedReadingTime != null &&
          reading.eventTime.difference(lastTrustedReadingTime) > _maxConfirmationGap) {
        pending = null;
      }
      lastTrustedReadingTime = reading.eventTime;

      final candidate = _resolveCandidate(reading, geofenceVersions);
      if (candidate.geofenceId == confirmedGeofenceId) {
        pending = null;
        continue;
      }

      if (pending != null && pending.matches(candidate)) {
        pending = pending.next(reading.eventTime);
      } else {
        pending = _PendingCandidate.fromCandidate(candidate, reading.eventTime);
      }

      if (!pending.isConfirmed(reading.eventTime)) {
        continue;
      }

      if (confirmedGeofenceId != null) {
        transitions.add(
          _GeofenceTransition(
            vehicleId: vehicleId,
            transitionType: 'EXIT',
            geofenceId: confirmedGeofenceId,
            geofenceVersionId: confirmedGeofenceVersionId,
            eventTime: reading.eventTime,
          ),
        );
      }

      if (candidate.geofenceId != null) {
        transitions.add(
          _GeofenceTransition(
            vehicleId: vehicleId,
            transitionType: 'ENTER',
            geofenceId: candidate.geofenceId,
            geofenceVersionId: candidate.geofenceVersionId,
            eventTime: reading.eventTime,
          ),
        );
      }

      confirmedGeofenceId = candidate.geofenceId;
      confirmedGeofenceVersionId = candidate.geofenceVersionId;
      pending = null;
    }

    return transitions;
  }

  _ResolvedCandidate _resolveCandidate(
    _LocationReading reading,
    List<_GeofenceVersion> geofenceVersions,
  ) {
    final candidates = geofenceVersions.where((version) {
      if (!version.isActive) {
        return false;
      }
      if (version.effectiveFrom.isAfter(reading.eventTime)) {
        return false;
      }
      if (version.supersededAt != null && !reading.eventTime.isBefore(version.supersededAt!)) {
        return false;
      }
      return _distanceMeters(
            reading.lat,
            reading.lon,
            version.centerLat,
            version.centerLon,
          ) <=
          version.radiusM;
    }).toList(growable: false)
      ..sort((left, right) {
        final radiusOrder = left.radiusM.compareTo(right.radiusM);
        if (radiusOrder != 0) {
          return radiusOrder;
        }
        return left.geofenceCreatedAt.compareTo(right.geofenceCreatedAt);
      });

    if (candidates.isEmpty) {
      return const _ResolvedCandidate.none();
    }

    final winner = candidates.first;
    return _ResolvedCandidate(
      geofenceId: winner.geofenceId,
      geofenceVersionId: winner.geofenceVersionId,
    );
  }

  double _distanceMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadiusM = 6371000.0;
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusM * c;
  }

  double _toRadians(double degrees) => degrees * math.pi / 180.0;

  String _geofenceVersionsSql() {
    return '''
      SELECT
        gv.geofence_id,
        gv.geofence_version_id,
        gv.center_lat,
        gv.center_lon,
        gv.radius_m,
        gv.is_active,
        gv.effective_from,
        gv.superseded_at,
        g.created_at
      FROM geofence_versions gv
      JOIN geofences g ON g.geofence_id = gv.geofence_id
      ORDER BY gv.geofence_id ASC, gv.effective_from ASC
    ''';
  }

  String _locationHistorySql() {
    return '''
      SELECT vehicle_id, event_time, lat, lon, accuracy_m
      FROM location_readings
      ORDER BY vehicle_id ASC, event_time ASC
    ''';
  }

  String _insertTransitionSql(_GeofenceTransition transition) {
    final eventTimeIso = transition.eventTime.toUtc().toIso8601String();
    // final geofenceId = transition.geofenceId == null
    //     ? 'NONE'
    //     : _escape(transition.geofenceId!);
    final geofenceVersionId = transition.geofenceVersionId == null
        ? 'NULL'
        : "'${_escape(transition.geofenceVersionId!)}'";

    return '''
      INSERT INTO geofence_transitions (
        transition_id,
        vehicle_id,
        transition_type,
        geofence_id,
        geofence_version_id,
        event_time
      )
      VALUES (
        '${_escape(transition.transitionId)}',
        '${_escape(transition.vehicleId)}',
        '${transition.transitionType}',
        ${transition.geofenceId == null ? 'NULL' : "'${_escape(transition.geofenceId!)}'"},
        $geofenceVersionId,
        TIMESTAMP '${_escape(eventTimeIso)}'
      )
      ON CONFLICT (transition_id) DO NOTHING
    ''';
  }

  String _latestTransitionsSql() {
    return '''
      WITH ranked_transitions AS (
        SELECT
          vehicle_id,
          transition_type,
          geofence_id,
          geofence_version_id,
          event_time,
          ROW_NUMBER() OVER (
            PARTITION BY vehicle_id
            ORDER BY event_time DESC,
              CASE WHEN transition_type = 'ENTER' THEN 0 ELSE 1 END
          ) AS rn
        FROM geofence_transitions
      )
      SELECT vehicle_id, transition_type, geofence_id, geofence_version_id, event_time
      FROM ranked_transitions
      WHERE rn = 1
    ''';
  }

  String _upsertVehicleStateSql(_LatestVehicleTransition transition) {
    return '''
      INSERT INTO vehicle_geofence_state (
        vehicle_id,
        current_geofence_id,
        current_geofence_version_id,
        source_event_time,
        updated_at
      )
      VALUES (
        '${_escape(transition.vehicleId)}',
        ${transition.transitionType == 'ENTER' && transition.geofenceId != null ? "'${_escape(transition.geofenceId!)}'" : 'NULL'},
        ${transition.transitionType == 'ENTER' && transition.geofenceVersionId != null ? "'${_escape(transition.geofenceVersionId!)}'" : 'NULL'},
        TIMESTAMP '${_escape(transition.eventTime.toUtc().toIso8601String())}',
        TIMESTAMP '${_escape(transition.eventTime.toUtc().toIso8601String())}'
      )
      ON CONFLICT (vehicle_id) DO UPDATE
      SET current_geofence_id = EXCLUDED.current_geofence_id,
          current_geofence_version_id = EXCLUDED.current_geofence_version_id,
          source_event_time = EXCLUDED.source_event_time,
          updated_at = EXCLUDED.updated_at
    ''';
  }

  String _escape(String input) => input.replaceAll("'", "''");
}

class _GeofenceVersion {
  const _GeofenceVersion({
    required this.geofenceId,
    required this.geofenceVersionId,
    required this.centerLat,
    required this.centerLon,
    required this.radiusM,
    required this.isActive,
    required this.effectiveFrom,
    required this.supersededAt,
    required this.geofenceCreatedAt,
  });

  factory _GeofenceVersion.fromRow(List<Object?> row) {
    return _GeofenceVersion(
      geofenceId: row[0] as String,
      geofenceVersionId: row[1] as String,
      centerLat: _asDouble(row[2]),
      centerLon: _asDouble(row[3]),
      radiusM: _asDouble(row[4]),
      isActive: _asBool(row[5]),
      effectiveFrom: _asDateTime(row[6]),
      supersededAt: row[7] == null ? null : _asDateTime(row[7]),
      geofenceCreatedAt: _asDateTime(row[8]),
    );
  }

  final String geofenceId;
  final String geofenceVersionId;
  final double centerLat;
  final double centerLon;
  final double radiusM;
  final bool isActive;
  final DateTime effectiveFrom;
  final DateTime? supersededAt;
  final DateTime geofenceCreatedAt;
}

class _LocationReading {
  const _LocationReading({
    required this.vehicleId,
    required this.eventTime,
    required this.lat,
    required this.lon,
    required this.accuracyM,
  });

  factory _LocationReading.fromRow(List<Object?> row) {
    return _LocationReading(
      vehicleId: row[0] as String,
      eventTime: _asDateTime(row[1]),
      lat: _asDouble(row[2]),
      lon: _asDouble(row[3]),
      accuracyM: _asDouble(row[4]),
    );
  }

  final String vehicleId;
  final DateTime eventTime;
  final double lat;
  final double lon;
  final double accuracyM;
}

class _ResolvedCandidate {
  const _ResolvedCandidate({
    required this.geofenceId,
    required this.geofenceVersionId,
  });

  const _ResolvedCandidate.none()
    : geofenceId = null,
      geofenceVersionId = null;

  final String? geofenceId;
  final String? geofenceVersionId;
}

class _PendingCandidate {
  const _PendingCandidate({
    required this.geofenceId,
    required this.geofenceVersionId,
    required this.startTime,
    required this.sampleCount,
  });

  factory _PendingCandidate.fromCandidate(
    _ResolvedCandidate candidate,
    DateTime at,
  ) {
    return _PendingCandidate(
      geofenceId: candidate.geofenceId,
      geofenceVersionId: candidate.geofenceVersionId,
      startTime: at,
      sampleCount: 1,
    );
  }

  final String? geofenceId;
  final String? geofenceVersionId;
  final DateTime startTime;
  final int sampleCount;

  bool matches(_ResolvedCandidate candidate) {
    return geofenceId == candidate.geofenceId &&
        geofenceVersionId == candidate.geofenceVersionId;
  }

  _PendingCandidate next(DateTime at) {
    return _PendingCandidate(
      geofenceId: geofenceId,
      geofenceVersionId: geofenceVersionId,
      startTime: startTime,
      sampleCount: sampleCount + 1,
    );
  }

  bool isConfirmed(DateTime at) {
    if (sampleCount >= 3) {
      return true;
    }
    if (sampleCount < 2) {
      return false;
    }
    return at.difference(startTime) >= const Duration(seconds: 60);
  }
}

class _GeofenceTransition {
  const _GeofenceTransition({
    required this.vehicleId,
    required this.transitionType,
    required this.geofenceId,
    required this.geofenceVersionId,
    required this.eventTime,
  });

  final String vehicleId;
  final String transitionType;
  final String? geofenceId;
  final String? geofenceVersionId;
  final DateTime eventTime;

  String get transitionId {
    final geofenceToken = geofenceId ?? 'NONE';
    return '$vehicleId|$transitionType|$geofenceToken|${eventTime.toUtc().toIso8601String()}';
  }
}

class _LatestVehicleTransition {
  const _LatestVehicleTransition({
    required this.vehicleId,
    required this.transitionType,
    required this.geofenceId,
    required this.geofenceVersionId,
    required this.eventTime,
  });

  factory _LatestVehicleTransition.fromRow(List<Object?> row) {
    return _LatestVehicleTransition(
      vehicleId: row[0] as String,
      transitionType: row[1] as String,
      geofenceId: row[2] as String?,
      geofenceVersionId: row[3] as String?,
      eventTime: _asDateTime(row[4]),
    );
  }

  final String vehicleId;
  final String transitionType;
  final String? geofenceId;
  final String? geofenceVersionId;
  final DateTime eventTime;
}

bool _asBool(Object? value) {
  if (value is bool) {
    return value;
  }
  if (value is int) {
    return value != 0;
  }
  if (value is BigInt) {
    return value != BigInt.zero;
  }
  if (value is String) {
    return value.toUpperCase() == 'TRUE' || value == '1';
  }
  throw StateError('Unsupported boolean value: ${value.runtimeType}');
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

double _asDouble(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is BigInt) {
    return value.toDouble();
  }
  if (value is String) {
    return double.parse(value);
  }
  throw StateError('Unsupported numeric value: ${value.runtimeType}');
}
