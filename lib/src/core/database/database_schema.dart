import 'schema/alerts_schema.dart';
import 'schema/core_schema.dart';
import 'schema/geofences_schema.dart';
import 'schema/telemetry_schema.dart';

const String schemaVersion = 'phase6';

/// Applies all feature schemas. Every statement is CREATE/ALTER IF NOT
/// EXISTS, so re-running on an existing database is a no-op.
Future<void> applyDatabaseSchema(dynamic conn) async {
  await createCoreSchema(conn);
  await createTelemetrySchema(conn);
  await createGeofencesSchema(conn);
  await createAlertsSchema(conn);
}

/// Records the current schema version. Called last during bootstrap so the
/// stamp implies schema and seed both completed.
Future<void> stampSchemaVersion(dynamic conn) async {
  await conn.execute('''
    INSERT INTO app_meta (key, value)
    VALUES ('schema_version', '$schemaVersion')
    ON CONFLICT (key) DO UPDATE
    SET value = EXCLUDED.value, updated_at = now()
  ''');
}
