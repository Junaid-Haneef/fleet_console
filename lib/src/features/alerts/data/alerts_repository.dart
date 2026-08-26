import '../../../core/database/app_database.dart';
import '../models/alert_models.dart';

typedef UtcNow = DateTime Function();

class AlertsRepository {
  AlertsRepository(this._database, {UtcNow? utcNow})
    : _utcNow = utcNow ?? (() => DateTime.now().toUtc());

  final AppDatabase _database;
  final UtcNow _utcNow;

  Future<void> recomputeActiveAlertsFromLatestReadings() async {
    final now = _utcNow();
    final nowIso = now.toIso8601String();
    final staleCutoffIso = now.subtract(const Duration(minutes: 15)).toIso8601String();

    await _database.execute('BEGIN TRANSACTION');
    try {
      await _database.execute('''
        CREATE TEMP TABLE tmp_prev_alerts AS
        SELECT
          vehicle_id,
          alert_type,
          severity,
          source_event_time,
          active_since,
          updated_at
        FROM active_alerts
      ''');

      await _database.execute('''
        CREATE TEMP TABLE tmp_candidate_alerts AS
        SELECT *
        FROM (
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
              MAX(CASE WHEN signal_name = 'soc' THEN event_time END) AS soc_event_time,
              MAX(CASE WHEN signal_name = 'battery_temp' THEN value END) AS battery_temp,
              MAX(CASE WHEN signal_name = 'battery_temp' THEN event_time END) AS battery_temp_event_time
            FROM latest_signals
            WHERE rn = 1
            GROUP BY vehicle_id
          ),
          active_soc AS (
            SELECT
              vehicle_id,
              'battery_soc' AS alert_type,
              CASE WHEN soc < 10 THEN 'CRITICAL' ELSE 'WARNING' END AS severity,
              soc_event_time AS source_event_time,
              TIMESTAMP '${_escape(nowIso)}' AS active_since,
              TIMESTAMP '${_escape(nowIso)}' AS updated_at
            FROM latest_scalar
            WHERE soc_event_time IS NOT NULL
              AND soc_event_time >= TIMESTAMP '${_escape(staleCutoffIso)}'
              AND soc < 20
          ),
          active_temp AS (
            SELECT
              vehicle_id,
              'battery_temp' AS alert_type,
              'CRITICAL' AS severity,
              battery_temp_event_time AS source_event_time,
              TIMESTAMP '${_escape(nowIso)}' AS active_since,
              TIMESTAMP '${_escape(nowIso)}' AS updated_at
            FROM latest_scalar
            WHERE battery_temp_event_time IS NOT NULL
              AND battery_temp_event_time >= TIMESTAMP '${_escape(staleCutoffIso)}'
              AND battery_temp > 45
          ),
          candidate_alerts AS (
            SELECT * FROM active_soc
            UNION ALL
            SELECT * FROM active_temp
          )
          SELECT
            c.vehicle_id,
            c.alert_type,
            c.severity,
            c.source_event_time,
            c.active_since,
            c.updated_at
          FROM candidate_alerts c
          LEFT JOIN dismissal_undo_windows d
            ON d.vehicle_id = c.vehicle_id
           AND d.alert_type = c.alert_type
          WHERE d.vehicle_id IS NULL
             OR c.source_event_time > d.dismissed_source_event_time
        )
      ''');

      await _database.execute('''
        INSERT INTO alert_events (
          event_id,
          vehicle_id,
          alert_type,
          transition,
          severity_before,
          severity_after,
          source_event_time,
          event_time,
          reason
        )
        SELECT
          c.vehicle_id
            || '|'
            || c.alert_type
            || '|FIRED|'
            || strftime(c.source_event_time, '%Y-%m-%dT%H:%M:%S.%fZ')
            || '|'
            || c.severity,
          c.vehicle_id,
          c.alert_type,
          'FIRED',
          NULL,
          c.severity,
          c.source_event_time,
          TIMESTAMP '${_escape(nowIso)}',
          NULL
        FROM tmp_candidate_alerts c
        LEFT JOIN tmp_prev_alerts p
          ON p.vehicle_id = c.vehicle_id
         AND p.alert_type = c.alert_type
        WHERE p.vehicle_id IS NULL
        ON CONFLICT (event_id) DO NOTHING
      ''');

      await _database.execute('''
        INSERT INTO alert_events (
          event_id,
          vehicle_id,
          alert_type,
          transition,
          severity_before,
          severity_after,
          source_event_time,
          event_time,
          reason
        )
        SELECT
          c.vehicle_id
            || '|'
            || c.alert_type
            || '|ESCALATED|'
            || strftime(c.source_event_time, '%Y-%m-%dT%H:%M:%S.%fZ')
            || '|CRITICAL',
          c.vehicle_id,
          c.alert_type,
          'ESCALATED',
          p.severity,
          c.severity,
          c.source_event_time,
          TIMESTAMP '${_escape(nowIso)}',
          NULL
        FROM tmp_candidate_alerts c
        JOIN tmp_prev_alerts p
          ON p.vehicle_id = c.vehicle_id
         AND p.alert_type = c.alert_type
        WHERE p.severity = 'WARNING'
          AND c.severity = 'CRITICAL'
        ON CONFLICT (event_id) DO NOTHING
      ''');

      await _database.execute('''
        INSERT INTO alert_events (
          event_id,
          vehicle_id,
          alert_type,
          transition,
          severity_before,
          severity_after,
          source_event_time,
          event_time,
          reason
        )
        SELECT
          c.vehicle_id
            || '|'
            || c.alert_type
            || '|DEESCALATED|'
            || strftime(c.source_event_time, '%Y-%m-%dT%H:%M:%S.%fZ')
            || '|WARNING',
          c.vehicle_id,
          c.alert_type,
          'DEESCALATED',
          p.severity,
          c.severity,
          c.source_event_time,
          TIMESTAMP '${_escape(nowIso)}',
          NULL
        FROM tmp_candidate_alerts c
        JOIN tmp_prev_alerts p
          ON p.vehicle_id = c.vehicle_id
         AND p.alert_type = c.alert_type
        WHERE p.severity = 'CRITICAL'
          AND c.severity = 'WARNING'
        ON CONFLICT (event_id) DO NOTHING
      ''');

      await _database.execute('''
        INSERT INTO alert_events (
          event_id,
          vehicle_id,
          alert_type,
          transition,
          severity_before,
          severity_after,
          source_event_time,
          event_time,
          reason
        )
        SELECT
          p.vehicle_id
            || '|'
            || p.alert_type
            || '|RESOLVED|'
            || strftime(p.source_event_time, '%Y-%m-%dT%H:%M:%S.%fZ')
            || '|'
            || p.severity,
          p.vehicle_id,
          p.alert_type,
          'RESOLVED',
          p.severity,
          'NONE',
          p.source_event_time,
          TIMESTAMP '${_escape(nowIso)}',
          NULL
        FROM tmp_prev_alerts p
        LEFT JOIN tmp_candidate_alerts c
          ON c.vehicle_id = p.vehicle_id
         AND c.alert_type = p.alert_type
        WHERE c.vehicle_id IS NULL
        ON CONFLICT (event_id) DO NOTHING
      ''');

      await _database.execute('''
        DELETE FROM dismissal_undo_windows d
        USING tmp_candidate_alerts c
        WHERE c.vehicle_id = d.vehicle_id
          AND c.alert_type = d.alert_type
          AND c.source_event_time > d.dismissed_source_event_time
      ''');

      await _database.execute('''
        DELETE FROM active_alerts
      ''');

      await _database.execute('''
        INSERT INTO active_alerts (
          vehicle_id,
          alert_type,
          severity,
          source_event_time,
          active_since,
          updated_at
        )
        SELECT
          vehicle_id,
          alert_type,
          severity,
          source_event_time,
          active_since,
          updated_at
        FROM tmp_candidate_alerts
      ''');

      await _database.execute('''
        DROP TABLE tmp_prev_alerts
      ''');

      await _database.execute('''
        DROP TABLE tmp_candidate_alerts
      ''');

      await _database.execute('COMMIT');
    } catch (_) {
      await _database.execute('ROLLBACK');
      rethrow;
    }
  }

  Future<List<ActiveAlertRow>> fetchActiveAlerts() async {
    final rows = await _database.query('''
      SELECT
        a.vehicle_id,
        v.reg_number,
        v.model,
        a.alert_type,
        a.severity,
        a.source_event_time
      FROM active_alerts a
      JOIN vehicles v ON v.vehicle_id = a.vehicle_id
      ORDER BY
        CASE a.severity
          WHEN 'CRITICAL' THEN 0
          ELSE 1
        END,
        a.updated_at DESC,
        v.reg_number ASC
    ''');

    return rows.map((row) {
      return ActiveAlertRow(
        vehicleId: row[0] as String,
        regNumber: row[1] as String,
        model: row[2] as String,
        type: _typeFromSql(row[3] as String),
        severity: _severityFromSql(row[4] as String),
        sourceEventTime: row[5] as DateTime,
      );
    }).toList(growable: false);
  }

  Future<int> fetchActiveAlertCount() async {
    final rows = await _database.query('SELECT COUNT(*) FROM active_alerts');
    if (rows.isEmpty || rows.first.isEmpty) {
      return 0;
    }

    final value = rows.first.first;
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

    throw StateError('Unsupported count value: ${value.runtimeType}');
  }

  Future<DateTime?> dismissAlert({
    required String vehicleId,
    required AlertType alertType,
    required AlertDismissReason reason,
  }) async {
    final now = _utcNow();
    final expiresAt = now.add(const Duration(seconds: 5));
    final alertTypeSql = _alertTypeToSql(alertType);

    await _database.execute('BEGIN TRANSACTION');
    try {
      final rows = await _database.query('''
        SELECT COUNT(*)
        FROM active_alerts
        WHERE vehicle_id = '${_escape(vehicleId)}'
          AND alert_type = '${_escape(alertTypeSql)}'
      ''');

      final count = _asInt(rows.first.first);
      if (count <= 0) {
        await _database.execute('COMMIT');
        return null;
      }

      final nowIso = now.toIso8601String();
      final expiresIso = expiresAt.toIso8601String();
      final eventId = _eventId(
        vehicleId: vehicleId,
        alertType: alertTypeSql,
        transition: 'DISMISSED',
        at: now,
      );

      await _database.execute('''
        INSERT INTO alert_events (
          event_id,
          vehicle_id,
          alert_type,
          transition,
          severity_before,
          severity_after,
          source_event_time,
          event_time,
          reason
        )
        VALUES (
          '${_escape(eventId)}',
          '${_escape(vehicleId)}',
          '${_escape(alertTypeSql)}',
          'DISMISSED',
          (
            SELECT severity
            FROM active_alerts
            WHERE vehicle_id = '${_escape(vehicleId)}'
              AND alert_type = '${_escape(alertTypeSql)}'
            LIMIT 1
          ),
          'NONE',
          (
            SELECT source_event_time
            FROM active_alerts
            WHERE vehicle_id = '${_escape(vehicleId)}'
              AND alert_type = '${_escape(alertTypeSql)}'
            LIMIT 1
          ),
          TIMESTAMP '${_escape(nowIso)}',
          '${_escape(alertDismissReasonLabel(reason))}'
        )
      ''');

      await _database.execute('''
        INSERT INTO dismissal_undo_windows (
          vehicle_id,
          alert_type,
          reason,
          dismissed_severity,
          dismissed_source_event_time,
          dismissed_at,
          expires_at
        )
        SELECT
          vehicle_id,
          alert_type,
          '${_escape(alertDismissReasonLabel(reason))}',
          severity,
          source_event_time,
          TIMESTAMP '${_escape(nowIso)}',
          TIMESTAMP '${_escape(expiresIso)}'
        FROM active_alerts
        WHERE vehicle_id = '${_escape(vehicleId)}'
          AND alert_type = '${_escape(alertTypeSql)}'
        ON CONFLICT (vehicle_id, alert_type)
        DO UPDATE SET
          reason = EXCLUDED.reason,
          dismissed_severity = EXCLUDED.dismissed_severity,
          dismissed_source_event_time = EXCLUDED.dismissed_source_event_time,
          dismissed_at = EXCLUDED.dismissed_at,
          expires_at = EXCLUDED.expires_at
      ''');

      await _database.execute('''
        DELETE FROM active_alerts
        WHERE vehicle_id = '${_escape(vehicleId)}'
          AND alert_type = '${_escape(alertTypeSql)}'
      ''');

      await _database.execute('COMMIT');
      return expiresAt;
    } catch (_) {
      await _database.execute('ROLLBACK');
      rethrow;
    }
  }

  Future<bool> undoDismissal({
    required String vehicleId,
    required AlertType alertType,
  }) async {
    final now = _utcNow();
    final alertTypeSql = _alertTypeToSql(alertType);

    await _database.execute('BEGIN TRANSACTION');
    try {
      final nowIso = now.toIso8601String();
      final rows = await _database.query('''
        SELECT COUNT(*)
        FROM dismissal_undo_windows
        WHERE vehicle_id = '${_escape(vehicleId)}'
          AND alert_type = '${_escape(alertTypeSql)}'
          AND expires_at >= TIMESTAMP '${_escape(nowIso)}'
      ''');

      final count = _asInt(rows.first.first);
      if (count <= 0) {
        await _database.execute('COMMIT');
        return false;
      }

      await _database.execute('''
        INSERT INTO active_alerts (
          vehicle_id,
          alert_type,
          severity,
          source_event_time,
          active_since,
          updated_at
        )
        SELECT
          vehicle_id,
          alert_type,
          dismissed_severity,
          dismissed_source_event_time,
          TIMESTAMP '${_escape(nowIso)}',
          TIMESTAMP '${_escape(nowIso)}'
        FROM dismissal_undo_windows
        WHERE vehicle_id = '${_escape(vehicleId)}'
          AND alert_type = '${_escape(alertTypeSql)}'
          AND expires_at >= TIMESTAMP '${_escape(nowIso)}'
        ON CONFLICT (vehicle_id, alert_type)
        DO UPDATE SET
          severity = EXCLUDED.severity,
          source_event_time = EXCLUDED.source_event_time,
          updated_at = EXCLUDED.updated_at
      ''');

      final eventId = _eventId(
        vehicleId: vehicleId,
        alertType: alertTypeSql,
        transition: 'UNDONE',
        at: now,
      );

      await _database.execute('''
        INSERT INTO alert_events (
          event_id,
          vehicle_id,
          alert_type,
          transition,
          severity_before,
          severity_after,
          source_event_time,
          event_time,
          reason
        )
        VALUES (
          '${_escape(eventId)}',
          '${_escape(vehicleId)}',
          '${_escape(alertTypeSql)}',
          'UNDONE',
          'NONE',
          (
            SELECT dismissed_severity
            FROM dismissal_undo_windows
            WHERE vehicle_id = '${_escape(vehicleId)}'
              AND alert_type = '${_escape(alertTypeSql)}'
            LIMIT 1
          ),
          (
            SELECT dismissed_source_event_time
            FROM dismissal_undo_windows
            WHERE vehicle_id = '${_escape(vehicleId)}'
              AND alert_type = '${_escape(alertTypeSql)}'
            LIMIT 1
          ),
          TIMESTAMP '${_escape(nowIso)}',
          NULL
        )
      ''');

      await _database.execute('''
        DELETE FROM dismissal_undo_windows
        WHERE vehicle_id = '${_escape(vehicleId)}'
          AND alert_type = '${_escape(alertTypeSql)}'
      ''');

      await _database.execute('COMMIT');
      return true;
    } catch (_) {
      await _database.execute('ROLLBACK');
      rethrow;
    }
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

  AlertType _typeFromSql(String value) {
    switch (value) {
      case 'battery_soc':
        return AlertType.batterySoc;
      case 'battery_temp':
        return AlertType.batteryTemp;
      default:
        throw StateError('Unknown alert type: $value');
    }
  }

  String _alertTypeToSql(AlertType type) {
    switch (type) {
      case AlertType.batterySoc:
        return 'battery_soc';
      case AlertType.batteryTemp:
        return 'battery_temp';
    }
  }

  String _eventId({
    required String vehicleId,
    required String alertType,
    required String transition,
    required DateTime at,
  }) {
    return '$vehicleId|$alertType|$transition|${at.microsecondsSinceEpoch}';
  }

  AlertSeverity _severityFromSql(String value) {
    switch (value) {
      case 'WARNING':
        return AlertSeverity.warning;
      case 'CRITICAL':
        return AlertSeverity.critical;
      default:
        throw StateError('Unknown alert severity: $value');
    }
  }

  String _escape(String input) => input.replaceAll("'", "''");
}
