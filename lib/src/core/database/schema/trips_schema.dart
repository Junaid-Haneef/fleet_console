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

  await conn.execute('''
    CREATE INDEX IF NOT EXISTS idx_trips_vehicle_start
    ON trips (vehicle_id, start_event_time DESC)
  ''');

  await conn.execute('''
    CREATE INDEX IF NOT EXISTS idx_trips_status_updated
    ON trips (status, updated_at DESC)
  ''');

  await conn.execute('''
    CREATE UNIQUE INDEX IF NOT EXISTS idx_trips_single_active_per_vehicle
    ON trips (vehicle_id)
    WHERE status = 'IN_PROGRESS'
  ''');
}
