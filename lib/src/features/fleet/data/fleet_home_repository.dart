import '../../../core/database/app_database.dart';
import '../models/fleet_home_models.dart';

typedef UtcNow = DateTime Function();

class FleetHomeRepository {
  FleetHomeRepository(this._database, {UtcNow? utcNow})
    : _utcNow = utcNow ?? (() => DateTime.now().toUtc());

  final AppDatabase _database;
  final UtcNow _utcNow;

  Future<FleetSnapshot> fetchSnapshot() async {
    final cutoffIso = _utcNow().subtract(const Duration(minutes: 10)).toIso8601String();

    final rows = await _database.query(_fleetRowsSql(cutoffIso));
    final countsRows = await _database.query(_fleetCountsSql(cutoffIso));

    return FleetSnapshot(rows: _mapRows(rows), counts: _mapCounts(countsRows));
  }

  String _fleetBaseCte(String cutoffIso) {
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
      ),
      latest_scalar AS (
        SELECT
          vehicle_id,
          MAX(CASE WHEN signal_name = 'soc' THEN value END) AS soc,
          MAX(CASE WHEN signal_name = 'range' THEN value END) AS range_km,
          MAX(CASE WHEN signal_name = 'speed' THEN value END) AS speed,
          MAX(CASE WHEN signal_name = 'ignition' THEN value END) AS ignition,
          MAX(CASE WHEN signal_name = 'battery_temp' THEN value END) AS battery_temp
        FROM latest_signals
        WHERE rn = 1
        GROUP BY vehicle_id
      ),
      latest_ping AS (
        SELECT vehicle_id, MAX(event_time) AS last_ping_event_time
        FROM (
          SELECT vehicle_id, event_time FROM signal_readings
          UNION ALL
          SELECT vehicle_id, event_time FROM location_readings
        ) AS all_events
        GROUP BY vehicle_id
      ),
      latest_alert AS (
        SELECT
          vehicle_id,
          CASE
            WHEN MAX(CASE WHEN severity = 'CRITICAL' THEN 1 ELSE 0 END) = 1
              THEN 'CRITICAL'
            WHEN MAX(CASE WHEN severity = 'WARNING' THEN 1 ELSE 0 END) = 1
              THEN 'WARNING'
            ELSE 'NONE'
          END AS alert_severity
        FROM active_alerts
        GROUP BY vehicle_id
      ),
      current_geofence AS (
        SELECT
          vgs.vehicle_id,
          COALESCE(gv.name, 'No geofence') AS current_geofence_name
        FROM vehicle_geofence_state vgs
        LEFT JOIN geofence_versions gv
          ON gv.geofence_version_id = vgs.current_geofence_version_id
      ),
      fleet_projection AS (
        SELECT
          v.vehicle_id,
          v.reg_number,
          v.model,
          COALESCE(cg.current_geofence_name, 'No geofence') AS current_geofence_name,
          ls.soc,
          ls.range_km,
          CASE
            WHEN lp.last_ping_event_time IS NULL
              OR lp.last_ping_event_time < TIMESTAMP '${_escape(cutoffIso)}'
              THEN 'OFFLINE'
            WHEN COALESCE(ls.speed, 0) > 0 THEN 'MOVING'
            WHEN COALESCE(ls.speed, 0) = 0 AND COALESCE(ls.ignition, 0) > 0 THEN 'IDLE'
            ELSE 'STOPPED'
          END AS status,
          COALESCE(la.alert_severity, 'NONE') AS alert_severity
        FROM vehicles v
        LEFT JOIN latest_scalar ls ON ls.vehicle_id = v.vehicle_id
        LEFT JOIN latest_ping lp ON lp.vehicle_id = v.vehicle_id
        LEFT JOIN latest_alert la ON la.vehicle_id = v.vehicle_id
        LEFT JOIN current_geofence cg ON cg.vehicle_id = v.vehicle_id
      )
    ''';
  }

  String _fleetRowsSql(String cutoffIso) {
    return '''
      ${_fleetBaseCte(cutoffIso)}
      SELECT
        vehicle_id,
        reg_number,
        model,
        current_geofence_name,
        soc,
        range_km,
        status,
        alert_severity
      FROM fleet_projection
      ORDER BY reg_number ASC
    ''';
  }

  String _fleetCountsSql(String cutoffIso) {
    return '''
      ${_fleetBaseCte(cutoffIso)}
      SELECT
        COUNT(*) AS all_count,
        SUM(CASE WHEN status = 'MOVING' THEN 1 ELSE 0 END) AS moving_count,
        SUM(CASE WHEN status = 'IDLE' THEN 1 ELSE 0 END) AS idle_count,
        SUM(CASE WHEN status = 'STOPPED' THEN 1 ELSE 0 END) AS stopped_count,
        SUM(CASE WHEN status = 'OFFLINE' THEN 1 ELSE 0 END) AS offline_count
      FROM fleet_projection
    ''';
  }

  List<FleetVehicleRow> _mapRows(List<List<Object?>> rows) {
    return rows.map((row) {
      return FleetVehicleRow(
        vehicleId: row[0] as String,
        regNumber: row[1] as String,
        model: row[2] as String,
        currentGeofenceName: row[3] as String,
        soc: _asDouble(row[4]),
        rangeKm: _asDouble(row[5]),
        status: _statusFromSql(row[6] as String),
        alertSeverity: _alertFromSql(row[7] as String),
      );
    }).toList(growable: false);
  }

  FleetFilterCounts _mapCounts(List<List<Object?>> rows) {
    if (rows.isEmpty) {
      return const FleetFilterCounts.zero();
    }

    final row = rows.first;
    return FleetFilterCounts(
      all: _asInt(row[0]),
      moving: _asInt(row[1]),
      idle: _asInt(row[2]),
      stopped: _asInt(row[3]),
      offline: _asInt(row[4]),
    );
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

  int _asInt(Object? value) {
    if (value == null) {
      return 0;
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

  String _escape(String input) => input.replaceAll("'", "''");

  FleetVehicleStatus _statusFromSql(String status) {
    switch (status) {
      case 'OFFLINE':
        return FleetVehicleStatus.offline;
      case 'MOVING':
        return FleetVehicleStatus.moving;
      case 'IDLE':
        return FleetVehicleStatus.idle;
      case 'STOPPED':
        return FleetVehicleStatus.stopped;
      default:
        throw StateError('Unknown fleet status: $status');
    }
  }

  AlertBadgeSeverity _alertFromSql(String severity) {
    switch (severity) {
      case 'CRITICAL':
        return AlertBadgeSeverity.critical;
      case 'WARNING':
        return AlertBadgeSeverity.warning;
      case 'NONE':
        return AlertBadgeSeverity.none;
      default:
        throw StateError('Unknown alert severity: $severity');
    }
  }
}
