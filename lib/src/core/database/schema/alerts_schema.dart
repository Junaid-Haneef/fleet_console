/// Alert tables: current state (active_alerts), the append-only audit trail
/// (alert_events), and the 5-second dismissal undo window.
Future<void> createAlertsSchema(dynamic conn) async {
  await conn.execute('''
    CREATE TABLE IF NOT EXISTS active_alerts (
      vehicle_id VARCHAR NOT NULL,
      alert_type VARCHAR NOT NULL,
      severity VARCHAR NOT NULL,
      source_event_time TIMESTAMP NOT NULL,
      active_since TIMESTAMP NOT NULL,
      updated_at TIMESTAMP NOT NULL,
      PRIMARY KEY (vehicle_id, alert_type)
    )
  ''');

  await conn.execute('''
    CREATE INDEX IF NOT EXISTS idx_active_alerts_severity_updated
    ON active_alerts (severity, updated_at DESC)
  ''');

  await conn.execute('''
    CREATE TABLE IF NOT EXISTS alert_events (
      event_id VARCHAR PRIMARY KEY,
      vehicle_id VARCHAR NOT NULL,
      alert_type VARCHAR NOT NULL,
      transition VARCHAR NOT NULL,
      severity_before VARCHAR,
      severity_after VARCHAR,
      source_event_time TIMESTAMP,
      event_time TIMESTAMP NOT NULL,
      reason VARCHAR
    )
  ''');

  await conn.execute('''
    CREATE INDEX IF NOT EXISTS idx_alert_events_lookup
    ON alert_events (vehicle_id, alert_type, event_time DESC)
  ''');

  await conn.execute('''
    CREATE TABLE IF NOT EXISTS dismissal_undo_windows (
      vehicle_id VARCHAR NOT NULL,
      alert_type VARCHAR NOT NULL,
      reason VARCHAR NOT NULL,
      dismissed_severity VARCHAR NOT NULL,
      dismissed_source_event_time TIMESTAMP NOT NULL,
      dismissed_at TIMESTAMP NOT NULL,
      expires_at TIMESTAMP NOT NULL,
      PRIMARY KEY (vehicle_id, alert_type)
    )
  ''');

  // Migration for databases created before these columns existed; a no-op on
  // fresh installs.
  await conn.execute('''
    ALTER TABLE dismissal_undo_windows
    ADD COLUMN IF NOT EXISTS dismissed_severity VARCHAR
  ''');

  await conn.execute('''
    ALTER TABLE dismissal_undo_windows
    ADD COLUMN IF NOT EXISTS dismissed_source_event_time TIMESTAMP
  ''');

  await conn.execute('''
    CREATE INDEX IF NOT EXISTS idx_dismissal_undo_windows_expires
    ON dismissal_undo_windows (expires_at)
  ''');
}
