part of '../app.dart';

class BootstrapErrorApp extends StatelessWidget {
  const BootstrapErrorApp({
    super.key,
    required this.error,
    required this.stackTrace,
  });

  final Object error;
  final StackTrace stackTrace;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Fleet Console - Startup Error')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Text(
              'DuckDB initialization failed.\n\n'
              'Error: $error\n\n'
              'Stack: $stackTrace',
            ),
          ),
        ),
      ),
    );
  }
}
