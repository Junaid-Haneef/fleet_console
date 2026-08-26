/// Seeds the three default geofences required by the spec. Fixed ids plus
/// ON CONFLICT DO NOTHING make the seed idempotent across relaunches, and
/// user edits are never overwritten because edits create new version rows
/// rather than touching these v1 rows.
Future<void> seedDefaultGeofences(dynamic conn) async {
  await conn.execute('''
    INSERT INTO geofences (geofence_id, created_at)
    VALUES
      ('gf_depot_north', TIMESTAMP '2026-01-01T00:00:00Z'),
      ('gf_charging_hub', TIMESTAMP '2026-01-01T00:01:00Z'),
      ('gf_service_yard', TIMESTAMP '2026-01-01T00:02:00Z')
    ON CONFLICT (geofence_id) DO NOTHING
  ''');

  await conn.execute('''
    INSERT INTO geofence_versions (
      geofence_version_id,
      geofence_id,
      name,
      center_lat,
      center_lon,
      radius_m,
      is_active,
      effective_from,
      superseded_at,
      created_at
    )
    VALUES
      (
        'gfv_depot_north_v1',
        'gf_depot_north',
        'Depot North',
        12.971600,
        77.594600,
        180.0,
        TRUE,
        TIMESTAMP '2026-01-01T00:00:00Z',
        NULL,
        TIMESTAMP '2026-01-01T00:00:00Z'
      ),
      (
        'gfv_charging_hub_v1',
        'gf_charging_hub',
        'Charging Hub',
        12.973200,
        77.599100,
        120.0,
        TRUE,
        TIMESTAMP '2026-01-01T00:01:00Z',
        NULL,
        TIMESTAMP '2026-01-01T00:01:00Z'
      ),
      (
        'gfv_service_yard_v1',
        'gf_service_yard',
        'Service Yard',
        12.968900,
        77.587900,
        150.0,
        TRUE,
        TIMESTAMP '2026-01-01T00:02:00Z',
        NULL,
        TIMESTAMP '2026-01-01T00:02:00Z'
      )
    ON CONFLICT (geofence_version_id) DO NOTHING
  ''');
}
