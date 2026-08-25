# DECISIONS.md

This file is the single source of truth for every ambiguous or judgment-call
decision made on this project. The take-home brief is explicit that the data
model has genuinely ambiguous cases and that decisions need to be defensible
live — so every entry below states the question, the decision, the reasoning,
and what was considered and rejected. This is a living document: later phases
add to it rather than resolving everything up front.

Status legend:
- `LOCKED` — implemented as written, not expected to change without new evidence.
- `OPEN` — a reasonable default is in place, but flagged as worth revisiting
  out loud in the live defense session.

---

## 1. Packet / signal deduplication key

**Question:** Packets can arrive late, out of order, or duplicated. What makes
two incoming records "the same" reading, so a replay or retry doesn't double
the data?

**Decision:** Dedup is keyed at the *signal reading* level, not the packet
level, using the natural key:

```
(vehicle_id, signal_name, event_timestamp)
```

A packet is really just a bundle of signal readings that arrived together —
the bundle itself isn't a meaningful unit to store or dedupe against, because
two different packets could legitimately report the same signal at the same
event_timestamp (e.g. resend after a dropped ack).

Inserts use an "insert, ignore on key conflict" pattern (`INSERT ... ON
CONFLICT (vehicle_id, signal_name, event_timestamp) DO NOTHING`). Whichever
row hits that key first in the database is the one that's kept, permanently.

**Why this is idempotent:** because the outcome depends only on the key, not
on when or how many times you replay the data. Replaying the exact same
dataset one time or a hundred times produces the identical table contents.

**Edge case — same key, conflicting value:** extremely rare (e.g. a
recalibrated sensor re-reports the same timestamp with a different value).
Default: first-inserted value wins, conflicting duplicates are logged to a
`rejected_readings` table rather than silently dropped, so nothing vanishes
without a trace.

**Alternatives considered:** last-write-wins by ingestion time — rejected,
because it makes the stored result depend on arrival order, which is exactly
the non-determinism the flaky-link scenario is designed to expose.

**Status:** LOCKED (dedup grain and key), OPEN (conflict-logging table is a
nice-to-have, may be cut if time is tight — see scope cuts, section 10).

---

## 2. Per-signal staleness thresholds

**Question:** The brief only defines one staleness threshold explicitly —
10 minutes, for the vehicle-level OFFLINE status chip. The readings register
(Feature B) needs a STALE verdict per *signal*, and those signals don't all
change at the same natural rate.

**Decision:**

| Signal          | Staleness threshold | Reasoning                                                        |
|------------------|---------------------|-------------------------------------------------------------------|
| Last ping (GPS)  | 10 min (given)      | Matches the spec's OFFLINE rule exactly — one source of truth.   |
| Speed            | 2 min               | Drives MOVING/IDLE distinction; needs to be fresh to be trusted. |
| SOC              | 15 min              | Typical reporting cadence assumed ~5 min; 3x cadence as buffer.  |
| Battery temp     | 15 min              | Same cadence assumption as SOC.                                  |
| Range            | 15 min              | Derived from SOC; inherits its staleness window.                 |
| Odometer         | 30 min              | Monotonic and slow-changing — an old reading is still correct, just imprecise, so it can tolerate a longer window. |

**Important distinction:** vehicle-level OFFLINE (Feature A, based on last
ping) is separate from per-signal STALE (Feature B). A vehicle can be online
(pinged within 10 min) while an individual signal like battery_temp hasn't
reported in 20 min and shows STALE in the readings register. These are two
different questions — "is the vehicle reachable" vs "can I trust this
specific number" — and conflating them would hide real problems (e.g. a
sensor that's dead while the modem is fine).

**Status:** OPEN — the specific minute values are reasonable defaults, not
measured against real fleet telemetry. Worth saying out loud as an assumption.

---

## 3. Geofence overlap tie-break

**Question:** Geofences are circles and nothing stops two of them from
overlapping. If a vehicle's location falls inside more than one active
geofence at once, which one is "the" current geofence for status/count
purposes?

**Decision:** Smallest radius wins (most specific/local geofence takes
precedence over a larger one that happens to contain it — e.g. a "loading
bay" circle inside a larger "depot" circle). If radii are exactly equal,
earliest-created geofence wins (by creation timestamp), as a final
deterministic tiebreak.

**Why:** this mirrors how humans would describe a truck's location — "it's at
the loading bay" is more useful than "it's at the depot" when both are true.
It's also fully deterministic and doesn't depend on scan order.

**Alternatives considered:** "assign to all overlapping geofences" — rejected
because Feature A/D want one status chip and one geofence count per vehicle,
not a set.

**Status:** OPEN — reasonable default, flagged as a judgment call to defend.

---

## 4. No-geofence state

**Question:** What happens when a vehicle isn't inside any active geofence?

**Decision:** This is a first-class, explicit state — not a null that
disappears from a count. It's stored as `current_geofence_id = NULL` and
rendered as "No geofence" in the UI, with its own bucket in the per-geofence
vehicle counts (rather than being silently excluded from the total).

**Why:** an operator looking at geofence counts needs to see "12 vehicles are
outside any known zone" as clearly as "8 vehicles are at the depot" — a
missing count is a worse UX than a zero-value one.

**Status:** LOCKED.

---

## 5. Confirmed geofence transition strategy (jitter, late packets, edits)

**Question:** GPS is noisy. A single reading crossing a geofence boundary
could be real movement or could be jitter from inaccurate positioning. The
brief requires "a documented deterministic strategy for duplicates, late
packets, GPS jitter, inaccurate readings, overlaps, missing intervals, and
geofence edits."

**Decision, piece by piece:**

- **Jitter filtering (confirmation rule):** a boundary crossing is only
  confirmed once *either* of these is true, whichever happens first:
  - 3 consecutive GPS readings (in event-time order) are on the new side of
    the boundary, with no reading back on the old side in between, or
  - the vehicle has remained on the new side for a continuous 60 seconds of
    event time.

  This means a single noisy ping that crosses the line and immediately
  crosses back is never confirmed as a transition — it takes either
  sustained readings or sustained time.

- **Inaccurate readings:** any GPS reading with a reported accuracy worse
  than 50 meters is excluded from the confirmation calculation entirely (it
  neither confirms nor breaks a streak). It's stored, just not trusted for
  transition logic.

- **Duplicates:** covered by the dedup key in section 1 — a duplicate
  reading never appears twice in the confirmation window in the first place.

- **Late packets:** confirmation logic runs in *event-time* order, not
  arrival order. A packet that arrives late but has an earlier
  event_timestamp gets inserted into its correct place in the sequence, and
  the confirmation window is recalculated over the corrected sequence. This
  can retroactively confirm a transition that was previously "pending," or
  in rare cases, invalidate a not-yet-confirmed one. **Once a transition is
  CONFIRMED, it is immutable** — a late packet can never delete or un-confirm
  a transition that's already been acted on (e.g. already spawned a trip).
  It can only refine still-pending state.

- **Overlaps:** resolved per section 3 (smallest-radius wins) before
  transition logic ever runs — transition logic only ever sees one
  "current geofence" candidate at a time per vehicle.

- **Missing intervals (gap in data, e.g. basement parking):** a gap is not
  itself a transition. When data resumes, the confirmation window simply
  starts fresh from the first post-gap reading; no transition is inferred
  purely from a data gap.

- **Geofence edits (radius/center changed, or deactivated):** edits apply
  **forward-only**. Changing a geofence's radius or center does not
  retroactively recompute historical transitions or trips computed under the
  old definition. A deactivated geofence is kept (not deleted) specifically
  so historical trips can still reference it by name/shape.

**Status:** OPEN — the 3-reading / 60-second confirmation numbers are
defaults chosen for reasonableness, not tuned against real GPS noise
characteristics. This is the single most important thing to defend live.

---

## 6. Trip creation, idempotency, and the "one active trip" rule

**Question:** Trips are derived automatically from confirmed transitions.
How do we guarantee reprocessing (replays, late packets) can't create
duplicate trips, and that a vehicle never ends up with two active trips?

**Decision:**
- A trip is keyed by `(vehicle_id, origin_geofence_id, exit_event_timestamp)`
  — i.e., the confirmed exit event that started it. Trip creation uses the
  same insert-ignore-on-conflict pattern as section 1: replaying the same
  confirmed exit event can never spawn a second trip for it.
- "One active trip per vehicle" is enforced as a real constraint (a unique
  index on `vehicle_id` where `status = 'IN_PROGRESS'`), not just an
  assumption in application code — so it holds even if application logic has
  a bug.
- A late packet that revises a trip's destination or boundary (e.g. the
  confirmed entry event's timestamp gets corrected) updates the *existing*
  trip row keyed by its origin exit event — it does not create a new trip.
- Returning to the origin geofence completes the trip normally (entry into
  *any* geofence, including the origin, satisfies "next confirmed entry").

**Status:** LOCKED (idempotency key and constraint), OPEN (exact revision
semantics for destination changes — worth walking through live with a
concrete late-packet example).

---

## 7. Escalating SOC alert — behavior across dismissal and severity change

**Question:** The brief says the low-battery and critical-battery SOC
alerts are "one escalating alert, not two." It doesn't say what happens if a
user dismisses the Warning-level alert and the vehicle later crosses into
Critical.

**Decision:** SOC alerts are modeled as a single alert entity per vehicle
(`alert_type = 'battery_soc'`) with a mutable `severity` field
(`warning` / `critical`) rather than two separate alert rows. Dismissing the
alert at Warning severity does **not** suppress it if it later escalates to
Critical — escalation always re-surfaces the alert, because Critical
represents a materially worse, undismissed situation. De-escalation (e.g.
SOC recovers from 8% back to 15%) does not auto-resolve the alert (still
below the Warning threshold) but does downgrade its displayed severity.
Full resolution (SOC back above 20%, fresh reading) clears the alert
independent of dismissal state, per the spec's "clears independently of
dismissal" rule.

**Status:** OPEN — the "escalation always re-notifies" choice is a judgment
call worth defending; the alternative (respect the dismissal until full
resolution) is arguably just as defensible and was considered.

---

## 8. Retention / compaction policy

**Question:** The event log is append-only and grows forever. What gets
compacted or dropped, and what does the app lose when it does?

**Decision:**
- Raw signal readings are kept at full resolution for **30 days**.
- Beyond 30 days, readings are compacted into **hourly rollups** per
  `(vehicle_id, signal_name, hour)` storing min/max/avg/last-value. Rollups
  are retained for up to **1 year**; raw rows beyond 30 days are dropped
  after the rollup is written.
- **Alert events** (the fact that an alert fired, escalated, or was
  dismissed, with reason) are stored in a separate, never-compacted
  `alert_log` table — these are the audit trail and are cheap relative to
  raw telemetry, so they're kept indefinitely.
- **Trips and geofences** are never compacted or dropped (deactivated
  geofences are retained per section 5).

**What's lost:** sub-hourly SOC sparkline resolution for history older than
30 days (Feature B's sparkline will show smoothed hourly points, not
per-packet detail, beyond that window). Exact battery-temp/speed readings
that triggered a since-cleared alert more than 30 days ago are no longer
individually inspectable — only the rollup and the alert log entry survive.

**Status:** OPEN — 30 days / 1 year are reasonable, unmeasured defaults;
this is exactly the kind of number the scale exercise (Phase 8) should
sanity-check against actual on-device storage growth at 2M+ rows.

---

## 9. Flutter state management architecture

**Question:** Should this app use BLoC/Cubit, and if yes, how should state be
split so local-first, event-time, and idempotency constraints stay enforceable?

**Decision:** Use a **hybrid BLoC/Cubit approach** with strict boundaries:

- **Cubit for read-heavy screen state** (simple query + refresh flows):
  - Fleet home queries and filter changes.
  - Vehicle detail queries and refresh.
- **Bloc for event-sequenced domain workflows** where ordering matters:
  - Alerts (dismissal, undo window, escalation/de-escalation, self-heal).
  - Geofence transition processing.
  - Trip lifecycle updates from confirmed transitions.
  - Telemetry ingest / replay / backfill orchestration.

**Hard rule:** DuckDB remains the **only source of truth** for domain data.
After any mutation, UI state is refreshed by re-querying DuckDB projections.
No in-memory "shadow" fleet/alert/trip state is treated as canonical.

**Why this choice:**
- Preserves deterministic outcomes under duplicate/out-of-order/late packets.
- Keeps invariants in SQL constraints + repository logic instead of widgets.
- Makes live defense easier: event flow is explicit and replayable in tests.

**Alternatives considered:**
- Cubit-only for everything — rejected because multi-step workflows (undo,
  transition confirmation, trip revision) are easier to reason about and test
  as explicit events.
- Bloc-only for everything — rejected as unnecessary ceremony for simple
  read/refresh screens.

**Status:** LOCKED — framework pattern and state-boundary rule are set before
Phase 1 implementation.

---

## 10. Feature B readings register verdict semantics

**Question:** Feature B defines verdict pills (`NORMAL`, `ALERT`, `STALE`) for
SOC, range, speed, battery temperature, odometer, and last ping, but only SOC
and battery temperature have explicit alert thresholds in the brief. How should
fresh non-threshold signals be classified, and how should range relate to SOC?

**Decision:**
- **SOC:** `ALERT` when fresh and SOC < 20%, else `NORMAL` when fresh.
- **Battery temperature:** `ALERT` when fresh and battery temp > 45C, else
  `NORMAL` when fresh.
- **Range:** when fresh, mirrors SOC verdict state (`ALERT` when fresh SOC is
  alerting, otherwise `NORMAL`).
- **Speed:** when fresh, always `NORMAL` (never independently `ALERT` in
  Feature B).
- **Odometer:** when fresh, always `NORMAL` (never independently `ALERT` in
  Feature B).
- **Last ping:** staleness-only verdict (`NORMAL` when <= 10 min old,
  `STALE` when older), never `ALERT`.
- **Never reported:** value renders as "-" and **no pill at all** for that row
  (distinct from stale).

**Why:** this keeps Feature B aligned with the spec's explicit alert semantics
without inventing undocumented thresholds for speed/odometer/last ping, while
preserving the user's chosen rule that range should track battery-risk context
via SOC.

**Status:** LOCKED for Phase 4.

---

## 11. Scope cuts (updated as the project proceeds)

### Phase 3 (Fleet home)

- **Clarification:** what counts as vehicle "last ping" for OFFLINE in Feature A.
  - **Decision:** use the latest `event_time` across both `signal_readings` and
    `location_readings` for each vehicle.
  - **Why:** this matches the app's current telemetry foundation where packets
    can carry scalar signals, location, or both; reachability should reflect
    the latest event-time telemetry evidence, not just GPS-specific rows.
  - **Status:** LOCKED for Phase 3.

- **Clarification:** how to classify MOVING/IDLE/STOPPED when speed or
  ignition readings are stale or missing but the vehicle is not OFFLINE.
  - **Decision:** Feature A uses latest-known speed/ignition values regardless
    of age once OFFLINE is ruled out.
  - **Why:** keeps status deterministic and avoids introducing a fifth
    "UNKNOWN" chip not in the spec's required set.
  - **Status:** LOCKED for Phase 3; can be revisited when Feature B's stale
    verdict UX is fully in place.

- **Clarification:** alert badge behavior in Fleet Home before Feature C alert
  lifecycle tables exist.
  - **Decision:** render a computed placeholder severity from fresh latest
    scalar values only:
    - `Critical` when SOC < 10 or battery temp > 45.
    - `Warning` when SOC < 20 (and not already critical).
    - No badge otherwise.
  - **Why:** satisfies Feature A's list-level badge signal now, while preserving
    the decision that dismissal/undo persistence belongs to Feature C.
  - **Status:** LOCKED for Phase 3 as a temporary behavior.

### Phase 2 (schema + synthetic telemetry ingest)

- **Cut:** defer conflict-logging (`rejected_readings`) for same-key,
  different-value duplicates.
  - **Why:** section 1 already locks idempotent first-write-wins semantics;
    keeping conflict logging out of Phase 2 keeps the foundation smaller and
    easier to defend live.
  - **Impact:** same-key conflicts are ignored after first insert in this
    phase; explicit conflict audit is postponed.

- **Cut:** do not create feature tables for geofences, transitions, trips, or
  alert dismissal metadata in Phase 2.
  - **Why:** these belong to later feature phases (D/E/C) and would add
    premature schema surface area before the event-time ingest foundation is
    proven.
  - **Impact:** Phase 2 schema is limited to telemetry foundation tables only.

- **Cut:** do not run the scale backfill target (500 vehicles / 2M+ rows) in
  Phase 2.
  - **Why:** scale exercise is explicitly Phase 8; Phase 2 focuses on
    correctness under flaky arrival behavior.
  - **Impact:** generator defaults stay small and deterministic for fast local
    verification.

---

*Last updated: Phase 2 start (scope cuts recorded before schema implementation).*
