/// Geofence tables. Geometry lives in versioned rows (geofence_versions) so
/// edits apply forward-only; transitions and per-vehicle state reference the
/// exact version that produced them.
Future<void> createGeofencesSchema(dynamic conn) async {
  await conn.execute('''
    CREATE TABLE IF NOT EXISTS geofences (
      geofence_id VARCHAR PRIMARY KEY,
      created_at TIMESTAMP NOT NULL DEFAULT now()
    )
  ''');

  await conn.execute('''
    CREATE TABLE IF NOT EXISTS geofence_versions (
      geofence_version_id VARCHAR PRIMARY KEY,
      geofence_id VARCHAR NOT NULL,
      name VARCHAR NOT NULL,
      center_lat DOUBLE NOT NULL,
      center_lon DOUBLE NOT NULL,
      radius_m DOUBLE NOT NULL,
      is_active BOOLEAN NOT NULL,
      effective_from TIMESTAMP NOT NULL,
      superseded_at TIMESTAMP,
      created_at TIMESTAMP NOT NULL DEFAULT now()
    )
  ''');

  await conn.execute('''
    CREATE INDEX IF NOT EXISTS idx_geofence_versions_geofence_effective
    ON geofence_versions (geofence_id, effective_from DESC)
  ''');

  await conn.execute('''
    CREATE INDEX IF NOT EXISTS idx_geofence_versions_active_effective
    ON geofence_versions (is_active, effective_from DESC)
  ''');

  await conn.execute('''
    CREATE TABLE IF NOT EXISTS geofence_transitions (
      transition_id VARCHAR PRIMARY KEY,
      vehicle_id VARCHAR NOT NULL,
      transition_type VARCHAR NOT NULL,
      geofence_id VARCHAR,
      geofence_version_id VARCHAR,
      event_time TIMESTAMP NOT NULL,
      recorded_at TIMESTAMP NOT NULL DEFAULT now()
    )
  ''');

  await conn.execute('''
    CREATE INDEX IF NOT EXISTS idx_geofence_transitions_vehicle_event_time
    ON geofence_transitions (vehicle_id, event_time DESC)
  ''');

  await conn.execute('''
    CREATE TABLE IF NOT EXISTS vehicle_geofence_state (
      vehicle_id VARCHAR PRIMARY KEY,
      current_geofence_id VARCHAR,
      current_geofence_version_id VARCHAR,
      source_event_time TIMESTAMP NOT NULL,
      updated_at TIMESTAMP NOT NULL
    )
  ''');

  await conn.execute('''
    CREATE INDEX IF NOT EXISTS idx_vehicle_geofence_state_current
    ON vehicle_geofence_state (current_geofence_id, source_event_time DESC)
  ''');
}
