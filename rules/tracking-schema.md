---
paths:
  - "**/*.py"
  - "**/*.sql"
---

# `groundcontroltracking.Tracking` Schema Reference

Discovered Apr 30 2026 during IF catch-position investigation. **Most of
the fielder catch-position / fielder path / per-actor trajectory data
lives here, NOT in the `Astros.*` schema.** Only catcher setup
(`y_at_pitch_release`) had been used previously — there's far more in
this schema than the codebase reflects.

**HawkEye coverage caveat (BLOCKING — Apr 30 2026):** these tables
populate only when HawkEye recorded the play. Coverage is **broader
than just MLB + HOU home affiliates** — HawkEye is also installed at
the FCL complex and at many opposing MiLB parks. But it's NOT
universal: some opposing parks lack it, and event-level recording
quality varies even within HawkEye-installed venues. **Always verify
coverage empirically per query** (count populated rows vs total BIPs)
before assuming a target dataset is dense enough for a report. Trackman
fills some gaps via the `TRACKMAN_*` event types but coverage is
partial. Design for sparsity: counts not rates, per-game sparsity
legends, fall-back paths to `Astros.Hits` ball-flight when tracking
is missing.

---

## 1. Schema overview — every table

64 tables in `groundcontroltracking.Tracking.*`. Categorized:

### Position / coordinate data

| Table | Granularity | Notes |
|---|---|---|
| `Play_Starting_Positions` | per (sched_id, pitch_id, pos_id) | `(X_at_pitch_release, Y_at_pitch_release)` per fielder. **Today's catcher depth metric uses this filtered to `pos_id = 2`.** Sister table `Play_Starting_Positions_Rejected` for invalid setups. |
| **`Play_Event_Positions`** | per (sched_id, pitch_id, pos_id, tracking_play_event_id) | **`pos_x` + `pos_y` for every fielder at every play event.** This is the canonical table for "where the IF caught the ball." See §3. |
| `Player_Tracking_ByPos` | per (sched_id, tracking_play_id, tracking_timestamp_id) | WIDE format — one row per timestamp with **all 9 fielders + ball + 3 runners** as `x_<pos>, y_<pos>` columns. See §4 for column list. Massive table; use selectively. |

### Per-domain tracking metrics (NEW — never used in codebase)

| Table | Purpose |
|---|---|
| **`INF_Tracking_Metrics`** | Per-play scalar metrics for IF fielders — `time_to_field`, `field_dist`, full reaction suite. See §5. |
| `INF_Tracking_Speeds` | IF speed sub-metrics |
| **`OF_Tracking_Metrics`** | OF equivalent of INF_Tracking_Metrics |
| `OF_Tracking_Speeds` | OF speed sub-metrics |
| `Baserun_Tracking_Metrics` / `_Speeds` / `_Times` | Baserunning per-play metrics |
| `Hitter_Kinematics` / `Pitcher_Kinematics` | Biomech per-event kinematics |

### Event log + lookups

| Table | Purpose |
|---|---|
| **`LK_Play_Event_Types`** | Catalogs the 30 event types (`BALL_WAS_HIT`, `BALL_WAS_CAUGHT`, etc.). See §2. |
| `Play_Events` | The event log itself — per-(sched_id, tracking_play_id, tracking_play_event_id) timestamps |
| `Play_Event_Markers` | Sister metadata to `Play_Events` |
| `LK_Tracking_Sources` / `LK_Tracking_Types` | Tracking provider metadata |
| `LK_Player_Positions` / `LK_Player_Types` | Position + role lookups |
| `LK_Object_Origins` | Coordinate-system origin reference |

### Ball trajectories

| Table | Purpose |
|---|---|
| **`Ball_Trajectories`** | Generic ball-flight trajectory data |
| `Hawkeye_Pitch_Hit_Trajectories` | HawkEye pitch+hit trajectories |
| `Pitch_Hit_Trajectories` | Pitch+hit trajectories (mixed source) |
| `Pitch_Hit_Trajectories_Corrected` (VIEW) | Use this for clean trajectory data |
| `Pitch_Hit_Trajectories_Corrections` / `_ByPlay` | Audit log of corrections |

### Hitting + swing tracking (already used by hitting reports)

| Table | Purpose |
|---|---|
| `Plays` | Master tracking play table — joined to `Astros.Pitches_View` via `(sched_id, astros_pitch_id)` |
| `Plays_RealTime` | Live-game version |
| `Player_Tracking_Plays` (VIEW) | Tracking-coverage flags per play |
| `Swing_Contact_Values` | Bat speed / VBA / contact metrics — used by Barrelsville |
| `Swing_Damage_Windows` | Per-swing damage window data |
| `Swing_Shapes` | Bat path shape metrics |
| `Bat_Tracking_Metrics` (Astros side) | Maps to this schema's swing tables |

### Multi-source play tables

| Table | Purpose |
|---|---|
| `Hawkeye_Plays` | HawkEye-only plays |
| `Trackman_Plays` | Trackman-only plays |
| `Statcast_Plays` | Statcast-only plays |
| `Pitches_Unofficial` | Unofficial / staging pitches |

### Operational / audit

| Table | Purpose |
|---|---|
| `Bad_Throws` | Throws excluded from tracking metrics |
| `Bad_Tracking` | Plays excluded entirely |
| `Calibration_Data` | Sensor calibration |
| `Field_FX_Offsets` | Field-FX coordinate system offsets |
| `Games` | Game metadata |
| `Blob_Upload_Log`, `Messages` | System logs |
| `Driveline_SVGs`, `Pitch_Driveline_Info` | Driveline integration |
| `Biomechanics_Tracking`, `Staging_*` | Biomech raw + staging |
| `Measurements`, `Timestamps` | Generic measurement / time refs |

---

## 2. `LK_Play_Event_Types` — full lookup (memorize this)

This is the lookup that turns event-type-id integers into human meaning.
Most useful events for fielding analysis are highlighted.

| id | tracking_play_event_type | hawkeye_event_type |
|---|---|---|
| 0 | BEGIN_OF_PLAY | Start |
| 1 | PITCHER_GOING_TO_WINDUP | NULL |
| 2 | BALL_WAS_PITCHED | Pitch |
| 3 | **BALL_WAS_HIT** | Hit |
| **4** | **BALL_WAS_CAUGHT** | **Catch** |
| **5** | **BALL_WAS_CAUGHT_OUT** | **Flyout** |
| 6 | BALL_WAS_RELEASED | Throw |
| 7 | BALL_WAS_DEFLECTED | NULL |
| 8 | TAG_WAS_APPLIED | NULL |
| 9 | PICK_OFF_BALL_RELEASED | NULL |
| 10 | END_OF_PLAY | End |
| 11 | REMOVED | NULL |
| 12 | TRACKMAN_BALL_WAS_RELEASED | NULL |
| 13 | TRACKMAN_BALL_WAS_DEFLECTED | NULL |
| 14 | TRACKMAN_BALL_WAS_CATCHER_RELEASED | NULL |
| 15 | TRACKING_PICK_OFF_BALL_RELEASED | NULL |
| 16 | TRACKMAN_BALL_BOUNCE | NULL |
| **17** | **BALL_WAS_FIELDED** | **Field** |
| 18 | BALL_BOUNCE | Bounce |
| 19 | OPERATOR_INPUT_NOT_FOUND | NULL |
| 20 | TRACKMAN_PICK_OFF_BALL_RELEASED | NULL |
| 21 | OFF_THE_WALL | NULL |
| 22 | PITCHER_FIRST_MOVEMENT | NULL |
| 23 | NULL | Swing |
| 24 | NULL | Nearest |
| 25-30 | END_OF_PLAY_CLOCK | NULL |

### Key event ids for fielding

| Use case | Event ids to filter |
|---|---|
| Where IF fielded a grounder | `tracking_play_event_type_id = 17` (BALL_WAS_FIELDED) |
| Where any fielder caught a fly/line drive | `tracking_play_event_type_id = 4` (BALL_WAS_CAUGHT) or `5` (BALL_WAS_CAUGHT_OUT) |
| All "ball-touched-fielder" events combined | `tracking_play_event_type_id IN (4, 5, 17)` |
| Where ball was thrown to a base | `tracking_play_event_type_id = 6` (BALL_WAS_RELEASED) — combine with `event_fielder` to get destination |
| Tag plays | `tracking_play_event_type_id = 8` (TAG_WAS_APPLIED) |

---

## 3. `Play_Event_Positions` — the catch-position table

```
sched_id, tracking_play_id, tracking_play_event_id,
pos_id, pitch_id, groundcontrol_id,
tracking_play_event_type_id,
ms_from_pitch_release,
event_fielder,
pos_x (decimal),  -- canonical "where this fielder was at this event"
pos_y (decimal)
```

### Canonical query — IF catch position by hit

```sql
SELECT
    pv.sched_id, pv.pitch_id, pv.batter_id,
    h.hit_bearing, h.hit_distance,           -- where ball LANDED
    pep.pos_id,                              -- which IF fielded it
    pep.pos_x AS catch_x,                    -- where fielder caught/fielded it
    pep.pos_y AS catch_y,
    pep.tracking_play_event_type_id,
    et.tracking_play_event_type
FROM Astros.Pitches_View pv
JOIN groundcontroltracking.Tracking.Plays pl
    ON pv.sched_id = pl.sched_id
   AND pv.pitch_id = pl.astros_pitch_id
JOIN groundcontroltracking.Tracking.Play_Event_Positions pep
    ON pl.sched_id = pep.sched_id
   AND pl.tracking_play_id = pep.tracking_play_id
JOIN groundcontroltracking.Tracking.LK_Play_Event_Types et
    ON pep.tracking_play_event_type_id = et.tracking_play_event_type_id
LEFT JOIN Astros.Hits h
    ON pv.sched_id = h.sched_id AND pv.pitch_id = h.pitch_id
WHERE pep.pos_id IN (3, 4, 5, 6)               -- IF only
  AND pep.tracking_play_event_type_id IN (4, 5, 17)  -- caught / caught_out / fielded
  AND pep.event_fielder = 1                     -- this fielder is the one who got the ball
```

### Coordinate convention

`pos_x` / `pos_y` use the same coordinate system as Astros baseball
plotting (per `coordinates.md`):

- Origin = home plate (or close to it — verify with `LK_Object_Origins`)
- Positive Y = toward CF (up the middle)
- Positive X = right field side / 1B side (catcher's view)
- Negative X = left field side / 3B side

This matches `coordinates.md` and the canonical PullAir% bearing
convention (negative = LEFT/3B/pull-for-RHH; positive = RIGHT/1B/pull-for-LHH).

### `event_fielder` flag

`event_fielder` flags whether THIS fielder is the one involved in the
event. For BALL_WAS_FIELDED, only the actual fielder has
`event_fielder = 1`; all other fielders have rows showing where they
were at that moment but `event_fielder = 0`. Filter `event_fielder = 1`
when you want catch position. Drop the filter when you want full team
positioning at the catch moment.

---

## 4. `Player_Tracking_ByPos` — full team trajectory per timestamp

```
sched_id, tracking_play_id, tracking_timestamp_id, game_date,
closest_ball_before/after_tracking_timestamp_id,
x_p, y_p,    -- pitcher
x_c, y_c,    -- catcher
x_1b, y_1b,  -- first baseman
x_2b, y_2b,
x_3b, y_3b,
x_ss, y_ss,
x_lf, y_lf,
x_cf, y_cf,
x_rf, y_rf,
x_b, y_b,    -- ball
x_r1, y_r1,  -- runner on 1st
x_r2, y_r2,  -- runner on 2nd
x_r3, y_r3
```

**One row per (play, timestamp).** A typical play has dozens of
timestamps (~30 fps). This is huge — billions of rows in production.

Use it for: replay overlays, route maps, fielder-trajectory
visualizations, "where the ball went vs where the fielder went" plots.

DO NOT scan it whole-table without strict `(sched_id, tracking_play_id)`
filter or a CTE that hits a single play first.

---

## 5. `INF_Tracking_Metrics` (and `OF_Tracking_Metrics`)

```
sched_id, tracking_play_id, tracking_player_position_id, groundcontrol_id,
acceleration_chest_down/up,
acceleration_chest_down_start/up_start,
top_speed, top_speed_start, max_speed,
deceleration_start,
reaction_time_radius, reaction_accuracy_radius,
reaction_time_4mph, useful_reaction_4mph,
split1, time_to_22, reactdist,
time_to_field,                -- NEW: time fielder took to reach the ball
field_dist                    -- NEW: scalar distance fielder traveled
```

**`time_to_field` + `field_dist`** are the two columns we never used.
Combined with `Play_Event_Positions` they give us a full picture of
each IF play:

- WHERE did the IF start? → `Play_Starting_Positions` (`X_at_pitch_release`, `Y_at_pitch_release`)
- WHERE did the IF catch the ball? → `Play_Event_Positions` (`pos_x`, `pos_y`) at event_type 17
- HOW FAR did they travel? → `INF_Tracking_Metrics.field_dist`
- HOW LONG did it take? → `INF_Tracking_Metrics.time_to_field`

`OF_Tracking_Metrics` should have an identical column structure for OF
fielders. Verify before using.

---

## 5b. Biomechanics_Tracking + Measurements (characterized Jun 16 2026)

Two big EAV stores, fully documented in
`barrelsville/docs/plans/2026-06-16-biomech-measurements-schema-reference.md`.

- **`Biomechanics_Tracking`** — EAV `(sched_id, pitch_id, metric_id, groundcontrol_id, value)`,
  joins `Pitches_View` on **`(sched_id, pitch_id)`** (NOT tracking_play_id), **two
  rows/metric (batter+pitcher) → filter `groundcontrol_id = batter_id`**. 564
  metrics via `LK_Biomechanics_Metrics_Types` (contact bat geometry, 3D arm joints,
  PC swing plane, full hip/torso/elbow/wrist kinematics at swing stations). One
  value per swing (contact + summary, NOT per-frame). **BLOCKING coverage caveat:
  the 3D `wrist`/`elbow` joints + `pc1/2/3` swing-plane are POSE-tracked = MLB-only
  (NULL for MiLB prospects). Bat-tracking metrics (bat_ss/bat_head/angles) are
  affiliate-wide but DUPLICATE `Swing_Contact_Values`.**
- **Per-frame batter SKELETON is NOT in SQL — it's a Hawkeye BLOB.** `Blob_Upload_Log`
  shows tracking uploaded as blobs typed `ball`/`bat`/`player`/`biomech` (skeletal
  config `body29` = 29 joints). The raw per-frame pose lives in those blob files;
  relational tables only carry derived summaries (sparse/NULL for our hitters) + the
  ball's per-frame `Hit Trajectory` (Measurements id 109). Drawing GC2's full
  skeleton needs blob/object-store access, not a query. (Confirmed Jun 16 2026 —
  swing-path data-ref §K.)
- **`Measurements`** — per-play EAV `(sched_id, tracking_play_id, timecode,
  measurement_id, target_id, target_gc_id, value, value_numeric, …)`; joins via
  `Plays`. `measurement_id` → **`LK_Measurement_Types`** (996 metrics). `target_id`:
  0=play, 1=P, 2=C, 3-9=fielders(1B..RF), **10=batter**, 11+=runners. Holds the
  Statcast batting cherries (EV=11, Attack Angle=942, Bat Speed=943, Swing Length=974,
  **Percent Squared Up=984**, Distance from Sweet Spot=963, Barreled Ball=108, Hit
  Trajectory JSON=109). **No raw per-frame skeleton is exposed** — only derived
  metrics + JSON arrays + completeness % (ids 969/973).

## 6. Standard join chain — Astros side ↔ Tracking side

```
Astros.Pitches_View pv
  -> JOIN groundcontroltracking.Tracking.Plays pl
       ON pv.sched_id = pl.sched_id
      AND pv.pitch_id = pl.astros_pitch_id
  -> JOIN <any tracking table> tt
       ON pl.sched_id = tt.sched_id
      AND pl.tracking_play_id = tt.tracking_play_id
```

`Pitches_View.pitch_id` = `Plays.astros_pitch_id` (NOT
`Plays.pitch_id` — those are different namespaces). Some tracking
tables ALSO have `pitch_id` for direct join, but always verify the
column meaning per table.

For tables keyed on `pos_id`, also AND on `pos_id` to scope to the
specific fielder of interest.

---

## 7. What's used in the codebase today

As of Apr 30 2026:

| What we use | Where | Coverage |
|---|---|---|
| `Play_Starting_Positions` filtered to `pos_id = 2` for catcher depth | `intangibles/src/catcher_data.py:1139-1192`, `catcher_percentiles.py:74` | Catcher only |
| `Plays` + `Swing_Contact_Values` for hitting (bat speed, VBA, HBA) | `barrelsville/src/tracker_data.py`, `pd-goals/src/drift_hitting.py` | Bat-tracking metrics |
| `Pitch_Hit_Trajectories_Corrected` | (referenced but unconfirmed in src) | Trajectory corrections |

**Never used as of Apr 30 2026** (all available, all populated where
HawkEye is installed):
- `Play_Event_Positions` (catch position for non-catcher fielders)
- `Player_Tracking_ByPos` (full team trajectory per timestamp)
- `INF_Tracking_Metrics` + `INF_Tracking_Speeds`
- `OF_Tracking_Metrics` + `OF_Tracking_Speeds`
- `Baserun_Tracking_Metrics` (we have BR metrics from `Astros.*` but this is finer-grained)
- `Ball_Trajectories` raw

---

## 8. Bug history

- **Apr 30 2026**: IF catch-position recon. User asked about replacing the
  IF spray (which uses `hit_bearing` + `hit_distance` from `Astros.Hits`)
  with where IF fielders actually caught the ball. Initial Astros.* recon
  came up empty — no catch-position columns on `Tracking_Defensive_Metrics`,
  `Events_View`, or `Hits`. Discovery proceeded into `groundcontroltracking.
  Tracking.*` (used previously only for catcher setup) and surfaced 64
  tables, 5 of which directly answer the question. This rules file prevents
  re-grepping the entire schema next time.

- **May 1 2026**: Empirical confirmations during IF bearing-divergence
  exploration. Three corrections to earlier guesses in this rule:
  1. **`pep.event_fielder = 1` does NOT filter to "THE" fielder.** It flags
     "this row represents a fielder" (vs ball / runner / coach). All 9
     fielders' positions are returned per event. To pin down THE fielder
     who got the ball, JOIN `pep.groundcontrol_id = ev.first_defender_id`
     (Events_View). Verified empirically with diagnostic SELECT showing
     all 9 pos_ids returned per BALL_WAS_FIELDED event.
  2. **`BALL_WAS_CAUGHT` (event id 4) fires for grounders too**, despite
     the name suggesting only fly-ball catches. Each fielded play often
     fires BOTH event 4 AND event 17, at slightly different
     timestamps/positions (event 17 first, event 4 after secure). For
     "where the IF picked up the ball" use event 17. For "where they
     secured / threw from" use event 4.
  3. **`INF_Tracking_Metrics.field_dist` is the FIELDER'S TRAVEL DISTANCE,
     not distance from HP.** Confirmed via diagnostic comparing field_dist
     to `SQRT(pos_x² + pos_y²)` from Play_Event_Positions for the same
     plays — they don't match (a SS catching a chopper at 30 ft from HP
     traveled 62 ft to get there). For "distance from HP to catch point"
     compute `SQRT(pos_x² + pos_y²)` from `Play_Event_Positions` directly.

- **May 1 2026**: IF bearing-divergence findings (league-wide, 2024-2026,
  IF-zone BIPs LA<15 + dist<150, P/C/IF-fielded, pitcher-primary plays
  excluded). Headline: bearing of where ball "landed" vs where IF caught
  it diverges meaningfully on close/soft contact. Mean abs diff:
  - Overall: ~5.5° (~12.5 ft at 130 ft depth)
  - 0-30 ft hits: ~6.9° (~16 ft) — choppers / weak rollers
  - 100-150 ft hits: ~1.5° (~4 ft) — hard grounders to IF
  - Choppers (LA<-20°): ~11.0° (~25 ft)
  - Low liners (LA 0-15°): ~1.9° (~4 ft)
  Pattern: short / soft contact diverges most, hard grounders to IF
  depth diverge least. Drives the case for catch-position-based IF
  positioning over ball-flight. See project memory
  `if-catch-position-exploration.md` for full methodology + query
  template + prediction math.

---

## What NOT to do

- **Don't query `Player_Tracking_ByPos` without a `(sched_id, tracking_play_id)` filter** — it's the largest table in the schema and will time out / blow memory. Always pre-filter to a single play (or small list of plays) before SELECT.
- **Don't assume `pos_x` / `pos_y` orientation matches `hit_bearing` direction.** They use compatible coordinate systems (catcher's view, +Y up the middle), but always verify with a known-position sanity check before plotting (e.g. catcher's `pos_y` near 0, SS `pos_y` near 150 ft).
- **Don't use `tracking_play_event_type_id` integer literals without referencing `LK_Play_Event_Types`** — id meanings can change. Either JOIN to LK or hardcode with a comment naming the event (`= 17 -- BALL_WAS_FIELDED`).
- **Don't ignore the HawkEye coverage caveat.** Coverage varies by venue (MLB always, HOU affiliate home + complex usually, opposing parks variable). Verify empirically per dataset before designing a report on this data. Plan for sparsity: counts not rates, per-game sparsity legends, fall-back to `Astros.Hits` ball-flight when tracking is missing.
- **Don't substitute Trackman event ids (12-16) for HawkEye event ids (4, 5, 17).** They cover different play moments. Use the HawkEye ids for catch position, Trackman ids only as fallback.
- **Don't mix `Plays.pitch_id` and `Plays.astros_pitch_id` in joins** — they're different namespaces. Always join `Pitches_View.pitch_id = Plays.astros_pitch_id`.
