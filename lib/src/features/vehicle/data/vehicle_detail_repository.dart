import '../../../core/database/app_database.dart';
import '../models/vehicle_detail_models.dart';

typedef UtcNow = DateTime Function();

class VehicleDetailRepository {
  VehicleDetailRepository(this._database, {UtcNow? utcNow})
    : _utcNow = utcNow ?? (() => DateTime.now().toUtc());

  final AppDatabase _database;
  final UtcNow _utcNow;

  Future<VehicleDetailSnapshot> fetchSnapshot(String vehicleId) async {
    final nowIso = _utcNow().toIso8601String();

    final detailsRows = await _database.query(_detailsSql(vehicleId, nowIso));
    if (detailsRows.isEmpty) {
      throw StateError('Vehicle not found: $vehicleId');
    }

    final socHistoryRows = await _database.query(_socHistorySql(vehicleId));
    final tripRows = await _database.query(_recentTripsSql(vehicleId));

    return VehicleDetailSnapshot(
      identity: VehicleIdentity(
        vehicleId: detailsRows.first[0] as String,
        regNumber: detailsRows.first[1] as String,
        model: detailsRows.first[2] as String,
      ),
      currentGeofenceName: detailsRows.first[3] as String,
      readings: _mapReadings(detailsRows.first),
      socHistory: _mapSocHistory(socHistoryRows),
      recentTrips: _mapTrips(tripRows),
    );
  }

  String _detailsSql(String vehicleId, String nowIso) {
    final safeVehicleId = _escape(vehicleId);
    final safeNow = _escape(nowIso);

    return '''
      WITH latest_signals AS (
        SELECT
          vehicle_id,
          signal_name,
          value,
          event_time,
          ROW_NUMBER() OVER (
            PARTITION BY vehicle_id, signal_name
            ORDER BY event_time DESC
          ) AS rn
        FROM signal_readings
        WHERE vehicle_id = '$safeVehicleId'
      ),
      latest_scalar AS (
        SELECT
          vehicle_id,
          MAX(CASE WHEN signal_name = 'soc' THEN value END) AS soc_value,
          MAX(CASE WHEN signal_name = 'soc' THEN event_time END) AS soc_event_time,
          MAX(CASE WHEN signal_name = 'range' THEN value END) AS range_value,
          MAX(CASE WHEN signal_name = 'range' THEN event_time END) AS range_event_time,
          MAX(CASE WHEN signal_name = 'speed' THEN value END) AS speed_value,
          MAX(CASE WHEN signal_name = 'speed' THEN event_time END) AS speed_event_time,
          MAX(CASE WHEN signal_name = 'battery_temp' THEN value END) AS battery_temp_value,
          MAX(CASE WHEN signal_name = 'battery_temp' THEN event_time END) AS battery_temp_event_time,
          MAX(CASE WHEN signal_name = 'odometer' THEN value END) AS odometer_value,
          MAX(CASE WHEN signal_name = 'odometer' THEN event_time END) AS odometer_event_time
        FROM latest_signals
        WHERE rn = 1
        GROUP BY vehicle_id
      ),
      latest_ping AS (
        SELECT vehicle_id, MAX(event_time) AS last_ping_event_time
        FROM (
          SELECT vehicle_id, event_time FROM signal_readings WHERE vehicle_id = '$safeVehicleId'
          UNION ALL
          SELECT vehicle_id, event_time FROM location_readings WHERE vehicle_id = '$safeVehicleId'
        ) AS all_events
        GROUP BY vehicle_id
      ),
      current_geofence AS (
        SELECT
          vgs.vehicle_id,
          COALESCE(gv.name, 'No geofence') AS current_geofence_name
        FROM vehicle_geofence_state vgs
        LEFT JOIN geofence_versions gv
          ON gv.geofence_version_id = vgs.current_geofence_version_id
      )
      SELECT
        v.vehicle_id,
        v.reg_number,
        v.model,
        COALESCE(cg.current_geofence_name, 'No geofence') AS current_geofence_name,
        ls.soc_value,
        ls.soc_event_time,
        CASE
          WHEN ls.soc_event_time IS NULL THEN NULL
          ELSE date_diff('second', ls.soc_event_time, TIMESTAMP '$safeNow')
        END AS soc_age_seconds,
        CASE
          WHEN ls.soc_event_time IS NULL THEN 'NONE'
          WHEN date_diff('second', ls.soc_event_time, TIMESTAMP '$safeNow') > 900 THEN 'STALE'
          WHEN ls.soc_value < 20 THEN 'ALERT'
          ELSE 'NORMAL'
        END AS soc_verdict,
        ls.range_value,
        ls.range_event_time,
        CASE
          WHEN ls.range_event_time IS NULL THEN NULL
          ELSE date_diff('second', ls.range_event_time, TIMESTAMP '$safeNow')
        END AS range_age_seconds,
        CASE
          WHEN ls.range_event_time IS NULL THEN 'NONE'
          WHEN date_diff('second', ls.range_event_time, TIMESTAMP '$safeNow') > 900 THEN 'STALE'
          WHEN ls.soc_event_time IS NOT NULL
            AND date_diff('second', ls.soc_event_time, TIMESTAMP '$safeNow') <= 900
            AND ls.soc_value < 20
            THEN 'ALERT'
          ELSE 'NORMAL'
        END AS range_verdict,
        ls.speed_value,
        ls.speed_event_time,
        CASE
          WHEN ls.speed_event_time IS NULL THEN NULL
          ELSE date_diff('second', ls.speed_event_time, TIMESTAMP '$safeNow')
        END AS speed_age_seconds,
        CASE
          WHEN ls.speed_event_time IS NULL THEN 'NONE'
          WHEN date_diff('second', ls.speed_event_time, TIMESTAMP '$safeNow') > 120 THEN 'STALE'
          ELSE 'NORMAL'
        END AS speed_verdict,
        ls.battery_temp_value,
        ls.battery_temp_event_time,
        CASE
          WHEN ls.battery_temp_event_time IS NULL THEN NULL
          ELSE date_diff('second', ls.battery_temp_event_time, TIMESTAMP '$safeNow')
        END AS battery_temp_age_seconds,
        CASE
          WHEN ls.battery_temp_event_time IS NULL THEN 'NONE'
          WHEN date_diff('second', ls.battery_temp_event_time, TIMESTAMP '$safeNow') > 900 THEN 'STALE'
          WHEN ls.battery_temp_value > 45 THEN 'ALERT'
          ELSE 'NORMAL'
        END AS battery_temp_verdict,
        ls.odometer_value,
        ls.odometer_event_time,
        CASE
          WHEN ls.odometer_event_time IS NULL THEN NULL
          ELSE date_diff('second', ls.odometer_event_time, TIMESTAMP '$safeNow')
        END AS odometer_age_seconds,
        CASE
          WHEN ls.odometer_event_time IS NULL THEN 'NONE'
          WHEN date_diff('second', ls.odometer_event_time, TIMESTAMP '$safeNow') > 1800 THEN 'STALE'
          ELSE 'NORMAL'
        END AS odometer_verdict,
        NULL AS last_ping_value,
        lp.last_ping_event_time,
        CASE
          WHEN lp.last_ping_event_time IS NULL THEN NULL
          ELSE date_diff('second', lp.last_ping_event_time, TIMESTAMP '$safeNow')
        END AS last_ping_age_seconds,
        CASE
          WHEN lp.last_ping_event_time IS NULL THEN 'NONE'
          WHEN date_diff('second', lp.last_ping_event_time, TIMESTAMP '$safeNow') > 600 THEN 'STALE'
          ELSE 'NORMAL'
        END AS last_ping_verdict
      FROM vehicles v
      LEFT JOIN latest_scalar ls ON ls.vehicle_id = v.vehicle_id
      LEFT JOIN latest_ping lp ON lp.vehicle_id = v.vehicle_id
      LEFT JOIN current_geofence cg ON cg.vehicle_id = v.vehicle_id
      WHERE v.vehicle_id = '$safeVehicleId'
      LIMIT 1
    ''';
  }

  String _socHistorySql(String vehicleId) {
    final safeVehicleId = _escape(vehicleId);
    return '''
      SELECT event_time, value
      FROM signal_readings
      WHERE vehicle_id = '$safeVehicleId' AND signal_name = 'soc'
      ORDER BY event_time ASC
    ''';
  }

  String _recentTripsSql(String vehicleId) {
    final safeVehicleId = _escape(vehicleId);
    return '''
      SELECT
        t.trip_id,
        t.status,
        COALESCE(origin_v.name, t.origin_geofence_id, 'Unknown') AS origin_name,
        CASE
          WHEN t.destination_geofence_id IS NULL THEN NULL
          ELSE COALESCE(dest_v.name, t.destination_geofence_id)
        END AS destination_name,
        t.start_event_time,
        t.end_event_time
      FROM trips t
      LEFT JOIN geofence_versions origin_v
        ON origin_v.geofence_version_id = t.origin_geofence_version_id
      LEFT JOIN geofence_versions dest_v
        ON dest_v.geofence_version_id = t.destination_geofence_version_id
      WHERE t.vehicle_id = '$safeVehicleId'
      ORDER BY t.start_event_time DESC
      LIMIT 5
    ''';
  }

  List<VehicleReadingRow> _mapReadings(List<Object?> row) {
    return [
      VehicleReadingRow(
        signal: VehicleSignalKey.soc,
        label: 'SOC',
        value: _asDouble(row[4]),
        eventTime: _asDateTime(row[5]),
        ageSeconds: _asInt(row[6]),
        verdict: _verdictFromSql(row[7] as String),
      ),
      VehicleReadingRow(
        signal: VehicleSignalKey.rangeKm,
        label: 'Range',
        value: _asDouble(row[8]),
        eventTime: _asDateTime(row[9]),
        ageSeconds: _asInt(row[10]),
        verdict: _verdictFromSql(row[11] as String),
      ),
      VehicleReadingRow(
        signal: VehicleSignalKey.speed,
        label: 'Speed',
        value: _asDouble(row[12]),
        eventTime: _asDateTime(row[13]),
        ageSeconds: _asInt(row[14]),
        verdict: _verdictFromSql(row[15] as String),
      ),
      VehicleReadingRow(
        signal: VehicleSignalKey.batteryTemp,
        label: 'Battery temp',
        value: _asDouble(row[16]),
        eventTime: _asDateTime(row[17]),
        ageSeconds: _asInt(row[18]),
        verdict: _verdictFromSql(row[19] as String),
      ),
      VehicleReadingRow(
        signal: VehicleSignalKey.odometer,
        label: 'Odometer',
        value: _asDouble(row[20]),
        eventTime: _asDateTime(row[21]),
        ageSeconds: _asInt(row[22]),
        verdict: _verdictFromSql(row[23] as String),
      ),
      VehicleReadingRow(
        signal: VehicleSignalKey.lastPing,
        label: 'Last ping',
        value: _asDouble(row[24]),
        eventTime: _asDateTime(row[25]),
        ageSeconds: _asInt(row[26]),
        verdict: _verdictFromSql(row[27] as String),
      ),
    ];
  }

  List<SocHistoryPoint> _mapSocHistory(List<List<Object?>> rows) {
    return rows
        .map(
          (row) => SocHistoryPoint(
            eventTime: _asDateTime(row[0])!,
            soc: _asDouble(row[1])!,
          ),
        )
        .toList(growable: false);
  }

  List<VehicleTripRow> _mapTrips(List<List<Object?>> rows) {
    return rows
        .map(
          (row) => VehicleTripRow(
            tripId: row[0] as String,
            status: _tripStatusFromSql(row[1] as String),
            originGeofenceName: row[2] as String,
            destinationGeofenceName: row[3] as String?,
            startEventTime: _asDateTime(row[4])!,
            endEventTime: _asDateTime(row[5]),
          ),
        )
        .toList(growable: false);
  }

  DateTime? _asDateTime(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is DateTime) {
      return value.toUtc();
    }
    if (value is String) {
      return DateTime.parse(value).toUtc();
    }
    throw StateError('Unsupported date/time value: ${value.runtimeType}');
  }

  double? _asDouble(Object? value) {
    if (value == null) {
      return null;
    }
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

  int? _asInt(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is BigInt) {
      return value.toInt();
    }
    if (value is String) {
      return int.parse(value);
    }
    throw StateError('Unsupported integer value: ${value.runtimeType}');
  }

  VehicleReadingVerdict _verdictFromSql(String value) {
    switch (value) {
      case 'NONE':
        return VehicleReadingVerdict.none;
      case 'NORMAL':
        return VehicleReadingVerdict.normal;
      case 'ALERT':
        return VehicleReadingVerdict.alert;
      case 'STALE':
        return VehicleReadingVerdict.stale;
      default:
        throw StateError('Unknown verdict: $value');
    }
  }

  VehicleTripStatus _tripStatusFromSql(String value) {
    switch (value) {
      case 'IN_PROGRESS':
        return VehicleTripStatus.inProgress;
      case 'COMPLETED':
        return VehicleTripStatus.completed;
      default:
        throw StateError('Unknown trip status: $value');
    }
  }

  String _escape(String input) => input.replaceAll("'", "''");
}
