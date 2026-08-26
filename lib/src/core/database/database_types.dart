/// Injection points for [AppDatabase], so tests can substitute fakes for the
/// real DuckDB bindings. The `dynamic` database/connection types are
/// intentional: dart_duckdb's concrete types would force tests to construct
/// real native handles.
typedef DatabasePathResolver = Future<String> Function();
typedef DuckDbOpen = Future<dynamic> Function(String path);
typedef DuckDbConnect = Future<dynamic> Function(dynamic database);
