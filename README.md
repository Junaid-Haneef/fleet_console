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
- Phase 8: in progress.
	- Added dedicated Scale tab for operational reset + configurable replay presets.
	- Added script harness for deterministic backfill and warm fleet-query p50/p95 sampling.
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

## Phase 8 scale harness

In-app (developer controls):
- Open the `Scale` tab.
- Use `Preset: 1 vehicle correctness` for deterministic stress checks.
- Use `Preset: 500 vehicles / ~2M rows` for scale backfill.

Script/debug action:

```bash
flutter run -d windows -t tool/scale_exercise.dart
```

Optional arguments:

```bash
flutter run -d windows -t tool/scale_exercise.dart -- \
	--seed 42 \
	--vehicle-count 500 \
	--packets-per-vehicle 667 \
	--duplicate-rate 0.2 \
	--late-rate 0.25 \
	--missing-rate 0.0 \
	--query-runs 50
```

## Scope note

Trips are surfaced inside vehicle detail rather than via a dedicated trips page.
This is an intentional scope choice because Feature E requires deterministic,
idempotent trip derivation semantics, not a separate top-level navigation page.
