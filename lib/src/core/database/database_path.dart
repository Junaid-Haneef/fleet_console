import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Resolves the on-disk location of the DuckDB file inside the platform's
/// application-support directory, creating the folder if needed.
Future<String> resolveDefaultDatabasePath() async {
  final supportDir = await getApplicationSupportDirectory();
  final fleetDir = Directory(p.join(supportDir.path, 'fleet_console'));
  if (!fleetDir.existsSync()) {
    fleetDir.createSync(recursive: true);
  }
  return p.join(fleetDir.path, 'fleet_console.duckdb');
}
