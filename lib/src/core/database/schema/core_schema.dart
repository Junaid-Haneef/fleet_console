/// Core tables: app metadata and the vehicle registry.
Future<void> createCoreSchema(dynamic conn) async {
  await conn.execute('''
    CREATE TABLE IF NOT EXISTS app_meta (
      key VARCHAR PRIMARY KEY,
      value VARCHAR NOT NULL,
      updated_at TIMESTAMP NOT NULL DEFAULT now()
    )
  ''');

  await conn.execute('''
    CREATE TABLE IF NOT EXISTS vehicles (
      vehicle_id VARCHAR PRIMARY KEY,
      reg_number VARCHAR NOT NULL,
      model VARCHAR NOT NULL,
      created_at TIMESTAMP NOT NULL DEFAULT now()
    )
  ''');
}
