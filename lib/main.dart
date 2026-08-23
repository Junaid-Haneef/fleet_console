import 'package:flutter/material.dart';

import 'src/app.dart';
import 'src/core/database/app_database.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final database = AppDatabase();

  try {
    await database.initialize();
    runApp(MainApp(database: database));
  } catch (error, stackTrace) {
    runApp(BootstrapErrorApp(error: error, stackTrace: stackTrace));
  }
}
