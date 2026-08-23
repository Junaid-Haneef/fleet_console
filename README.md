# fleet_console

A new Flutter project.

## Project docs

- [Project context and rules](claude.md)
- [Architecture and ambiguity decisions](DECISIONS.md)
- [Flutter state-management decision](DECISIONS.md#9-flutter-state-management-architecture)

## Phase 1 status

Phase 1 is focused on scaffold plus DuckDB wiring.

- DuckDB is initialized before app UI boot.
- App startup is gated on DB readiness.
- App has explicit startup-error UI path.
- Hybrid state scaffolding follows `DECISIONS.md`:
	- Cubit skeleton for read-heavy screens.
	- Bloc skeleton for event-sequenced workflows.

## Run

```bash
flutter pub get
flutter run -d android
```

## Test

```bash
flutter test
```

Phase 1 tests cover DB initialization and idempotent bootstrap behavior.
