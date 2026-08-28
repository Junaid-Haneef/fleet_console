/// Trip tables derived from confirmed geofence transitions.
///
/// `trips` is the read model for Feature E. Identity is anchored to the
/// confirmed EXIT transition that starts a trip, so replays and late packets
/// update the same row rather than creating duplicates.
Future<void> createTripsSchema(dynamic conn) async {
  await conn.execute('''
    CREATE TABLE IF NOT EXISTS trips (
      trip_id VARCHAR PRIMARY KEY,
      vehicle_id VARCHAR NOT NULL,
      active_trip_vehicle_id VARCHAR,
      exit_transition_id VARCHAR NOT NULL,
      origin_geofence_id VARCHAR NOT NULL,
      origin_geofence_version_id VARCHAR,
      start_event_time TIMESTAMP NOT NULL,
      entry_transition_id VARCHAR,
      destination_geofence_id VARCHAR,
      destination_geofence_version_id VARCHAR,
      end_event_time TIMESTAMP,
      status VARCHAR NOT NULL,
      updated_at TIMESTAMP NOT NULL,
      created_at TIMESTAMP NOT NULL DEFAULT now(),
      UNIQUE (exit_transition_id),
      UNIQUE (entry_transition_id)
    )
  ''');

  // Migration for databases created before active_trip_vehicle_id existed.
  await conn.execute('''
    ALTER TABLE trips
    ADD COLUMN IF NOT EXISTS active_trip_vehicle_id VARCHAR
  ''');

  await conn.execute('''
    CREATE INDEX IF NOT EXISTS idx_trips_vehicle_start
    ON trips (vehicle_id, start_event_time DESC)
  ''');

  await conn.execute('''
    CREATE INDEX IF NOT EXISTS idx_trips_status_updated
    ON trips (status, updated_at DESC)
  ''');

  // DuckDB does not support partial indexes. Instead we keep a nullable
  // column active_trip_vehicle_id where IN_PROGRESS rows store vehicle_id and
  // COMPLETED rows store NULL. UNIQUE then enforces one active trip/vehicle.
  await conn.execute('''
    CREATE UNIQUE INDEX IF NOT EXISTS idx_trips_single_active_per_vehicle
    ON trips (active_trip_vehicle_id)
  ''');
}
