# fleet_console

Local-first Fleet Console for Bytebeam's Flutter take-home assignment.

## Project docs

- [Project context and rules](CLAUDE.md)
- [Architecture and ambiguity decisions](DECISIONS.md)

## Current phase status

- Phase 0: decisions doc established and actively maintained.
- Phase 1: scaffold + DuckDB bootstrap complete.
- Phase 2: telemetry schema + synthetic flaky-link replay complete.
- Phase 3: fleet home complete (SQL status chips + SQL live filter counts).
- Phase 4: vehicle detail complete (readings register + SOC event-log history).
- Phase 5: alerts complete (escalation, dismissal reason sheet, 5-second undo, self-heal).
- Phase 6: geofences complete (create/edit/deactivate, forward-only versions, confirmed transitions).
- Phase 7: trips complete for required scope:
	- trips derived from confirmed transitions,
	- one active trip per vehicle DB constraint,
	- late-packet/event-time deterministic recompute,
	- recent trips visible in vehicle detail (no dedicated trips page by design).
- Phase 8: pending (500 vehicles / 2M+ backfill + measurements).
- Phase 9: pending consolidation pass.
- Phase 10: pending final README tour polish + log packaging.

## Run

```bash
flutter pub get
flutter run -d android
```

## Test

```bash
flutter test
```

## Scope note

Trips are surfaced inside vehicle detail rather than via a dedicated trips page.
This is an intentional scope choice because Feature E requires deterministic,
idempotent trip derivation semantics, not a separate top-level navigation page.
