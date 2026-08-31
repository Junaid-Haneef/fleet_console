import 'package:flutter/material.dart';

import 'src/app.dart';
import 'src/core/database/app_database.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _BootstrapApp());
}

class _BootstrapApp extends StatefulWidget {
  const _BootstrapApp();

  @override
  State<_BootstrapApp> createState() => _BootstrapAppState();
}

class _BootstrapAppState extends State<_BootstrapApp> {
  late final Future<AppDatabase> _databaseFuture;

  @override
  void initState() {
    super.initState();
    _databaseFuture = _initializeDatabase();
  }

  Future<AppDatabase> _initializeDatabase() async {
    final database = AppDatabase();
    await database.initialize();
    return database;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppDatabase>(
      future: _databaseFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return BootstrapErrorApp(
            error: snapshot.error!,
            stackTrace: snapshot.stackTrace ?? StackTrace.current,
          );
        }

        final database = snapshot.data;
        if (database == null) {
          return MaterialApp(
            home: Scaffold(
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text('Starting Fleet Console...'),
                  ],
                ),
              ),
            ),
          );
        }

        return MainApp(database: database);
      },
    );
  }
}
