/// Telemetry event log: per-signal readings and GPS locations, keyed by
/// event time so duplicate packets upsert into the same row (idempotent
/// ingestion).
Future<void> createTelemetrySchema(dynamic conn) async {
  await conn.execute('''
    CREATE TABLE IF NOT EXISTS signal_readings (
      vehicle_id VARCHAR NOT NULL,
      event_time TIMESTAMP NOT NULL,
      signal_name VARCHAR NOT NULL,
      value DOUBLE NOT NULL,
      packet_id VARCHAR,
      received_time TIMESTAMP NOT NULL,
      PRIMARY KEY (vehicle_id, event_time, signal_name)
    )
  ''');

  await conn.execute('''
    CREATE INDEX IF NOT EXISTS idx_signal_readings_latest
    ON signal_readings (vehicle_id, signal_name, event_time DESC)
  ''');

  await conn.execute('''
    CREATE TABLE IF NOT EXISTS location_readings (
      vehicle_id VARCHAR NOT NULL,
      event_time TIMESTAMP NOT NULL,
      lat DOUBLE NOT NULL,
      lon DOUBLE NOT NULL,
      accuracy_m DOUBLE NOT NULL,
      packet_id VARCHAR,
      received_time TIMESTAMP NOT NULL,
      PRIMARY KEY (vehicle_id, event_time)
    )
  ''');

  await conn.execute('''
    CREATE INDEX IF NOT EXISTS idx_location_readings_latest
    ON location_readings (vehicle_id, event_time DESC)
  ''');
}
