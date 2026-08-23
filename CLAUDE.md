# Bytebeam Fleet Console — Project Context

## What this is
A local-first Flutter take-home for a Flutter Engineer (SDE-3) role at Bytebeam.
A fleet operator with 500 electric trucks needs one screen answering:
**where are my vehicles, are they okay, what needs attention now.**

Vehicles emit telemetry over a flaky mobile link. Packets arrive late, out of
order, duplicated, or not at all. Vehicles park in basements for hours and then
dump a backlog on reconnect. The hard part of this assignment is not feature
volume — it's that the data model has genuinely ambiguous cases, and the
grading is on how well those are resolved and defended live.

Expected effort: 14–16 hours across a week, untimed. Grading standard:
**"A smaller scope done well beats everything done thinly — if you cut, say
what you cut and why."**

## AI-tooling condition (governs how I want you to work with me)
- AI assistance is expected and allowed, but two conditions follow:
  1. Conversation logs get shared **uncurated** — dead ends and corrections
     included, since that's explicitly called out as "the interesting part."
  2. Every decision must be **defended live** in front of the interviewer.
- Rule of thumb: **"Code you cannot explain counts against you more than code
  you did not write."** Never hand me generated code I can't walk through and
  justify line-by-line live. Prefer explaining the mechanism before or
  alongside generating code, not after.
- When you propose a non-obvious implementation, briefly say *why*, so I can
  actually defend it later without re-deriving it from scratch.

## Domain glossary
- **SOC** — battery state of charge, %.
- **Range** — estimated km remaining.
- **Odometer** — lifetime km (monotonic, never decreases).
- **Ignition** — vehicle electrically switched on (not necessarily moving).
- **Signal** — one named telemetry parameter (soc, speed, battery_temp, gps, …).
- **Packet** — one timestamped emission from one vehicle, carrying a subset of
  signals.
- **Stale** — last report too old to trust.

## Hard architecture constraints
- **Local-first over embedded DuckDB** (`dart_duckdb`, currently `^1.2.0` —
  ships its own binaries, works on Android).
- **The UI reads only from DuckDB.** It must never read from an in-memory list
  that DuckDB happens to shadow. If the app is killed and relaunched,
  everything it knew must come back off disk.
- **All logic must be event-time aware** — reason by when a reading happened
  (its timestamp), not when it arrived at the app.
- **All logic must be idempotent** — reprocessing packets, including
  duplicates and out-of-order arrivals, must never create duplicate state
  (duplicate alerts, duplicate trips, etc.).
- Filter counts and other list-level aggregates are **computed in SQL**, not
  in Dart, wherever the spec calls for "live counts."

## Features

### A — Fleet home
- List of all vehicles: reg number, model, SOC, range, alert badge, status
  chip.
- Status chip rule, **first match wins** (evaluate in this order):
  | Status | Rule |
  |---|---|
  | OFFLINE | vehicle-level last ping older than 10 min |
  | MOVING | speed > 0 |
  | IDLE | speed = 0 and ignition on |
  | STOPPED | ignition off |
- Filter chips: All / Moving / Idle / Stopped / Offline, with live counts
  computed in SQL. Empty results get an empty state.

### B — Vehicle detail
- A **readings register**: one row per signal — SOC, range, speed, battery
  temperature, odometer, last ping. Each row has label, value, its own age,
  and a verdict pill:
  - **NORMAL** — fresh, within threshold
  - **ALERT** — fresh, outside threshold
  - **STALE** — grey, too old to judge; makes no normal/alert claim
  - A signal that has **never reported** shows "—" with **no pill at all**
    (distinct from stale — do not conflate these two states).
- A history sparkline or table for **SOC** over the retained window, queried
  from the event log (proves the event log is actually queryable, not
  synthesized for display).

### C — Alerts, dismissal, undo
- Thresholds apply to **fresh readings only**:
  | Alert | Condition | Severity |
  |---|---|---|
  | Low battery | SOC < 20% | Warning |
  | Battery critically low | SOC < 10% | Critical |
  | Battery overheating | battery temp > 45°C | Critical |
- The two SOC alerts are **one escalating alert**, not two independent ones.
- Dismissal opens a reason sheet with options in this exact order:
  1. "I am on it"
  2. "Wrong alert"
  3. "Something else…"
  - Dismissing removes the alert and shows **UNDO for 5 seconds**.
- A condition that clears **resolves its alert independently of dismissal**
  (self-healing — not tied to the dismiss/undo flow).

### D — Geofences
- Create, edit, and deactivate persisted **circular** geofences (name, centre,
  radius, active state).
- Show each vehicle's current geofence, plus live vehicle counts per
  geofence.
- Seed at least **3** geofences.
- **Retain deactivated geofences** — never hard-delete, since trip history
  references them.
- Must determine entry/exit from **event-time location history** using a
  documented, deterministic strategy covering: duplicates, late packets, GPS
  jitter, inaccurate readings, overlaps, missing intervals, and geofence
  edits.
- Geofence **edits apply forward-only**, never retroactively to
  already-computed history.

### E — Automatic trips
- Built only from **confirmed** geofence transitions:
  | Transition | Result |
  |---|---|
  | Confirmed exit | Start a trip |
  | Next confirmed entry | Complete the active trip |
  | No confirmed entry | Keep it IN PROGRESS |
- Returning to the origin geofence is a valid trip.
- **One active trip per vehicle**, max.
- Must be **idempotent** and **event-time aware**: duplicate packets create
  nothing twice; late packets may **revise** trip boundaries/destination
  without producing duplicate trips.

## Scale exercise
- Ship a script or debug action that backfills **500 vehicles** and **at
  least 2 million signal rows**.
- Measure, on a real device or a named emulator, and report the numbers, the
  method, and the device:
  - Cold start → first painted fleet list
  - Fleet-list query, **p50 and p95**, warm
  - Memory at rest with the list open
- Honesty clause: **"If it is slow, say it is slow and say what you would
  do — a measured 900ms with a diagnosis beats an unmeasured claim of
  40ms."**
- State the retention/compaction policy: the append-only log grows forever —
  document what gets compacted or dropped, and what the app loses when it
  does.

## Tests
Comprehensive test suite, built alongside each feature as it's implemented —
not batched at the end. Each phase's commit should include its own tests.

## Deliverables
1. Private git repo, meaningful **incremental** commit history — **no single
   squashed commit** — commit messages in my own words.
2. `README.md` — how to run the app, how to run the tests, a 30-second
   feature tour. APK optional.
3. AI conversation logs, shared **uncurated**.

## Build plan (commit-per-phase)
0. `DECISIONS.md` — lock ambiguous-case resolutions before writing code
1. Project scaffold + DuckDB wiring
2. Schema + synthetic telemetry generator (simulates flaky arrival:
   late/duplicate/out-of-order/missing packets)
3. Fleet home (Feature A)
4. Vehicle detail (Feature B)
5. Alerts (Feature C)
6. Geofences (Feature D)
7. Trips (Feature E)
8. Scale exercise — backfill, measure, document retention policy
9. Test consolidation (tests are written alongside 3–7, this phase is
   cleanup/gap-filling, not first-time authoring)
10. README + AI conversation logs

## Open decisions to keep visible in DECISIONS.md
- Dedupe key for packets
- Per-signal staleness thresholds
- Geofence overlap tie-break rule
- No-geofence state handling
- Retention/compaction policy specifics

Do not silently resolve any of the above (or any other genuinely ambiguous
call) inline in code — surface it, propose a default, and once agreed, log it
in `DECISIONS.md` per the tagging convention below **before** implementing
the code that depends on it.

## Working style — how I want you to operate on this project
- **Explain domain/technical concepts in plain language before
  implementation.** I'm learning this domain (event-time processing,
  idempotent ingestion, DuckDB local-first patterns) while building it —
  don't skip straight to code.
- **Use diagrams when they'd clarify a mechanism** (e.g. geofence
  confirmation state machine, trip lifecycle, packet dedupe flow) rather than
  prose alone.
- **Surface ambiguous judgment calls explicitly, with a proposed default,
  rather than silently picking one.** This assignment is graded specifically
  on how well ambiguity is resolved and defended — silent choices are a
  liability, not a convenience.
- **Favor small, explainable, incremental commits** over large batched ones —
  every decision must be defensible live, and squashed commits are
  explicitly disallowed.
- **When scope is cut for time or clarity, say so explicitly** and record the
  reasoning (in `DECISIONS.md` or the relevant commit message) — don't cut
  silently.

## Reference
Full original spec PDF: `docs/spec.pdf` (or wherever it's placed in this
repo) — treat this CLAUDE.md as the working summary/ruleset; consult the PDF
directly for verbatim wording if a dispute arises about exact thresholds or
phrasing.