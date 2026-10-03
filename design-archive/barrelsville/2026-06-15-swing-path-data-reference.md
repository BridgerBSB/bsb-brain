# Swing-Path Data Reference — GC2 Bat/Swing Tracking (Discovery Findings)

Companion to `2026-06-15-swing-path-postgame-design.md`. Captures EVERYTHING the
2026-06-15/16 discovery surfaced about internal bat/swing tracking, with explicit
confidence levels and an open-questions list. Source: `sql-queries/swing-path-discovery.sql`
(results in Zac's `b1.tsv … b9.tsv`).

Confidence legend:  ✅ confirmed · 🟡 inferred (sample-consistent) · ❓ unknown.

---

## A. Coordinate frame (✅)

- One frame everywhere: **origin = back tip of home plate; +Y toward pitcher;
  +Z up; X across (catcher's view); FEET.**
- Velocities in **ft/s**. **Bat speed mph = v_ftps × 0.681818.**
- Cross-checked: `x_peak/y_peak/z_peak` ≈ `batx/y/z_con` ≈ `Swing_Shapes.x0/y0/z0`
  (all land in the contact cluster).

---

## B. Tables we USE for the swing path

### B1. `Astros.Bat_Tracking_Metrics`  (Astros schema; ~90–99% coverage MLB→A) ✅
Join: `ON sched_id, pitch_id`. One row per swing. Bat state at **4 kinematic
timestamps**, each a full block of `{time_, x_, y_, z_, vx_, vy_, vz_, v_, yaw_,
roll_, distance_}`:

| phase | meaning (🟡) | extra cols |
|---|---|---|
| `activation` | swing initiation region | `adj_horz_activation` |
| `pitcher_face` | bat face squared to pitcher (downswing) | `adj_aa_pitcher_face`, `adj_vba_pitcher_face` |
| `true_peak` | true max bat speed | — |
| `peak` | peak (alt definition; often ≈ true_peak) | — |

Plus `time_at_swing_start` (✅ early, ~0.19s) — **time only, NO position cols.**

- `x_/y_/z_` = a single tracked bat point per phase (🟡 sweet-spot/barrel — NOT
  confirmed which; see ❓Q4). The 4 phases' **times cluster ~0.40–0.45s** (within
  ~10ms of contact) → positions sit in the contact zone, NOT across the full swing. ✅
- `v_` ×0.681818 → bat speed mph. ✅
- `yaw_`/`roll_` (deg) → bat orientation per phase (→ HAA/VAA). 🟡 conventions/zero-ref unverified (❓Q5).
- `distance_` (≈7–8.5 ft, monotonic across phases) = **cumulative bat-head path length** → swing-length proxy. 🟡 (vs Savant's to-contact definition; ❓Q6).
- `adj_aa_pitcher_face` / `adj_vba_pitcher_face` = location-adjusted attack / vertical bat angle at pitcher-face. ✅ (GC2 uses these.)

### B2. `groundcontroltracking.tracking.Swing_Contact_Values`  (~50–80%) ✅
Join: `plays(sched_id, astros_pitch_id=pitch_id)` → `scv(sched_id, tracking_play_id)`.
Exact **contact-frame** state:
- `t_con` (contact time). ✅
- `batx/y/z_con` = bat point at contact (🟡 sweet-spot/impact). `batvx/y/z_con` = bat velocity at contact (ft/s). ✅
- `headx/y/z_con` = a **second bat point** at contact (🟡 barrel-tip or knob; ~10″ from bat_con in real rows). ❓Q4.
- `e1x/y/z_con` = **unit vector along bat long axis** (|e1|≈1 ✅). Direction sign (toward barrel vs knob) ❓Q4.
- `con_loc_axis`, `con_loc_perp` = contact location on the barrel (axial/perp). ✅ (GC2 ×12 → inches.)
- `ballx/y/z_con`, `ballvx/y/z_con` = ball state at contact. ✅
- GC2 contact metrics derived from these (canonical, ✅): HAA = `atn2(e1y,e1x)` (handedness-flipped), VAA = `90−acos(e1z_con)`, AA = `90−acos(batvz/|batv|)`, bat speed = `|batv|×0.681818`.

### B3. `groundcontroltracking.tracking.Swing_Shapes`  (~50–80%) ✅ columns / ❓ geometry
Join: `scv`-style on `(sched_id, tracking_play_id)`. The **arc-shape** source.
**PROVENANCE (confirmed by TWO biomechanists, 2026-06-17):** Bradley Moore —
`Swing_Shapes` (+ `Swing_Damage_Windows`) are derived from the tracking API's
**`batrotation` endpoint** (the same data behind the GC2 "damage window" visual).
Adam Brodie — for mapping swing paths use **`swing_shapes`** (+ `swing_contact_values`
"depending on the application"). Both independently named the exact pair our true-arc
reconstruction uses: `swing_shapes` (the `Km*` arc shape) + `swing_contact_values`
(contact point / `e1` / `batv` — our anchor + bat). So it's built on the official
source, not a cobbled proxy. `Swing_Damage_Windows.damage_window` = a cherry for later.
- `Km30, Km15, K0, K15, K30, K45` = **curvature (1/ft)** at bat-rotation stations
  −30…+45°; **radius(ft) = 1/Kx** (✅ — GC2: `SwingRadius{X}degAvg = 1/Kx`). Real
  rows: radii ≈ 2.5–4.5 ft.
- `loft` (≈ −20…27.5), `tilt` (≈ 0…65) = swing-plane orientation angles (✅ exist;
  `tilt` = the "Path Tilt" metric). Exact axis definition 🟡.
- `plane_p0/p1/p2` = swing-plane equation coefficients. ❓Q2 (form unknown — does
  NOT fit `z=p0+p1x+p2y` on sample).
- `x0/y0/z0` = an anchor position (lands near contact / pitcher_face). ❓Q3 (which
  phase it anchors).
- **Open: how the stations map into the plate frame (where 0° sits, sweep
  direction).** This is the core ❓Q1 blocking a faithful curvature arc.

### B4. `groundcontroltracking.tracking.plays` ✅
The bridge: `astros_pitch_id = Pitches_View.pitch_id`, exposes `tracking_play_id`
for all `swing_*` joins. (Also `Hawkeye_Plays`, `Statcast_Plays`, `Trackman_Plays`,
`Player_Tracking_Plays` are source-specific variants.)

---

## C. Hands / bat geometry — what we have vs not

| Want | Have? | Source |
|---|---|---|
| Full bat (hands→barrel) **at contact** | ✅ derivable | `bat{x,y,z}_con` + `e1_con` (orientation) + 28″/6″ split; `head_con` = 2nd measured point |
| Bat orientation **per phase** | 🟡 | `yaw_`/`roll_` per phase (angles, not a 2nd point) |
| **Continuous hand/handle track** through swing | ❌ | not in any table |
| Body joints (wrist/elbow/torso) **at swing-start** | ✅ angles only | `Hitter_Kinematics` (see D) |

So "hand positioning" = **available at contact** (measured point + orientation),
**derivable-but-not-measured per phase** (via orientation), and **not available as
a continuous track**.

---

## D. Biomech — `Hitter_Kinematics` (+ `Staging_Hitter_Kinematics`) 🟡
Surfaced in b2 (NOT a full dump yet — ❓Q8). Known columns: `batter_id`,
`lead_wrist_rot_at_swing_start`, `lead_wrist_tilt_at_swing_start`,
`lead_elbow_rot_at_swing_start`, `lead_elbow_tilt_at_swing_start`,
`torso_flexion_at_swing_start`, `torso_rotation_at_swing_start`,
`torso_tilt_at_swing_start`. Angles at swing-start only; no 3D joint positions
seen. Join key + full column set still to be dumped.

---

## E. All tracking tables found (b3a) — purpose + confidence
Bat/swing-relevant in **bold**.

| Table | Purpose | Conf |
|---|---|---|
| **Swing_Contact_Values** | contact-frame bat/ball state | ✅ |
| **Swing_Shapes** | swing arc curvature + plane | ✅cols/❓geom |
| **Swing_Damage_Windows** | `damage_window`, `t_in/out_dmg_win` (time bat in damage zone) | 🟡 |
| **Hitter_Kinematics / Staging_Hitter_Kinematics** | body biomech at swing-start | 🟡 |
| **(Astros) Bat_Tracking_Metrics** | per-phase bat snapshots | ✅ |
| Ball_Tracking | per-timestamp BALL x/y/z/v (+seams) | ✅ |
| Ball_Trajectories | ball trajectory polys / landing | ✅ |
| Hawkeye_Pitch_Hit_Trajectories / Pitch_Hit_Trajectories(_Corrected) | pitch+hit trajectory, `hit_launch_speed` (EV!), `hit_launch_angle`, `hit_sweet_spot_deviation_*`, `hit_before_sweet_spot_*` | 🟡 (EV source candidate) |
| LK_Kinematic_Timestamps | lookup: timestamp_id → label/still | ✅ |
| LK_Kinematic_Segments | lookup: body segment defs + `length_ratio` | 🟡 |
| LK_Ball_Trajectory_Types / LK_Tracking_Sources | lookups (`bat_order`, `batrotation_order`) | 🟡 |
| Pitcher_Kinematics / Staging | pitcher biomech at release | ✅ (not our scope) |
| Pitch_Driveline_Info | per-pitch driveline shape metrics | 🟡 (not our scope) |
| Plays / Hawkeye_Plays / Statcast_Plays / Trackman_Plays / Player_Tracking_Plays | play bridges (source variants) | ✅ |
| Player_Tracking_ByPos | per-timestamp FIELDER/runner x/y (not bat) | ✅ |
| Baserun_/INF_/OF_Tracking_* | fielding/baserunning tracking | ✅ (not our scope) |
| Timestamps / Measurements / Play_Events / Play_Event_Markers | per-timestamp infra | 🟡 |
| Games / Calibration_Data / Blob_Upload_Log / Messages / Pitches_Unofficial | infra / housekeeping | — |

**Finding (✅): NO per-frame BAT trajectory table exists.** Ball + fielders are
tracked per-timestamp; the bat is only the 4 snapshots + contact + curvature.

---

## F. Coverage (b8) — has_swing_shapes / has_bat_tracking, 2026
MLB 81%/99% · AAA 53%/93% · AA 76%/81% · A+ 72%/76% · A 53%/73% · FCL 26%/36% ·
DSL 10%/12% · College 1%/2%. → **affiliate-wide; bat_tracking ≫ swing_shapes.**
(2024/2025 similar; full matrix in b8.tsv.)

---

## G. OPEN QUESTIONS — what we are explicitly UNSURE about
1. **Q1 (blocker for curvature arc) — ✅ RESOLVED 2026-06-19 by the GC2 Swing
   Factors Explainer (§L).** The stations are **HBA** (Horizontal Bat Angle),
   window = HBA [−30°,+45°]. **0° = "pitcher face" (bat ∥ plate front), NOT
   contact** — contact sits at `HBA_con` inside the window. The plane is **given by
   loft + tilt** (pitcher-view / hitter-view angles), not fit. The arc is the
   sweet-spot trajectory with Rc=1/Km vs HBA. See §L2/L3/L8. (Our shipped
   `build_arc` anchored 0°↔contact and guessed the plane → wrong.)
2. **Q2 — ✅ MOOT (2026-06-19).** Plane orientation comes from **loft + tilt**
   (§L3); `plane_p0/p1/p2` is not needed for the reconstruction. Its exact algebraic
   form remains undecoded but no longer blocks anything.
3. **Q3:** which phase does `Swing_Shapes.x0/y0/z0` anchor (peak? pitcher_face?).
4. **Q4 (AUTHORITATIVELY RESOLVED 2026-06-17 by biomechanist Adam Brodie):**
   - `head(x,y,z)_con` = **where the bat HEAD is at contact.**
   - `e1(x,y,z)_con` = **the direction the HANDLE is from the head** (the bat's
     long axis). **Assume the hands are ~27–28″ from the head along this axis.**
   - This is **only at contact**, where "contact" = actual contact **OR the
     nearest-pass on a whiff** (so whiff swings also have a contact frame).
   - **Data relationship:** `head_con = bat_con + con_loc_axis · e1` (bat_con =
     impact point; they differ by the axial contact offset).
   - **SIGN GOTCHA (validated visually):** in OUR data the stored `e1` points
     toward the **barrel**, not the handle — so hands = `contact − ~28″·e1`
     (subtract). `contact + 28″·e1` puts the hands 4 ft out toward the pitcher
     (wrong). The current bat draws `sweet − 28″·e1`, which lands up-and-inside =
     correct (Zac-approved). For flush contact `sweet`≈`head` (within `con_loc_axis`),
     so it matches Brodie's "28″ from the head"; for off-end contact, anchoring on
     `head_con` exactly would be marginally more correct.
   - **Still true:** no per-frame measured hand exists; the hands are this
     contact-frame extension along the measured bat axis (only the ~28″ length is
     assumed). Impl: `swing_path_data.py::_add_bat_on_arc`.
5. **Q5 — ✅ DEFINITIONS RESOLVED (2026-06-19, §L1).** GC2 defines VBA (bat axis vs
   ground, +=head high), HBA (bat axis vs plate front, 0=pitcher-face), AA (sweet-spot
   velocity vs ground, +=up). These evolve through the swing (no single value). The
   per-phase `yaw_`/`roll_` zero-reference still wants an empirical check, but the
   angle *meanings* are now nailed.
6. **Q6:** is `distance_peak` (or distance-at-contact) the right **Swing Length**
   definition vs Savant's? Confirm against a Savant cross-check name.
7. **Q7 (cherries):** canonical **EV** column — `Pitches_View` here lacks
   `hit_exit_speed`; candidate = `Hawkeye_Pitch_Hit_Trajectories.hit_launch_speed`.
   Also confirm pitch-speed for squared-up % (`plate_speed`/`release_speed` exist).
8. **Q8:** full `Hitter_Kinematics` schema + join key (only the bat-ish subset
   dumped so far).
9. **Q9:** does `peak` ever differ meaningfully from `true_peak`? (identical on
   one sample swing.)

---

## G2. GC2 production query finding (2026-06-16) — reframes the decode

Read the captured GC2 production queries (`sql-queries/Player Hitting Tracking -
Top Table.sql` + `Daily Swing Tracking.sql`). **GC2 never reconstructs the swing
path in 3D.** It consumes `Km30…K45` only as **scalar per-station radii**
(`SwingRadius{X}degAvg = 1/Kx`) and `loft`/`tilt` as scalar plane angles. There is
**no station→3D-frame mapping, no `plane_p0/1/2` usage, and no `x0/y0/z0` anchor
logic anywhere in GC2.** So Q1–Q3 are NOT a recipe we can look up — decoding "the
whole path" means *building* a curvature-integration model (Km* through the
loft/tilt plane, anchored at `x0/y0/z0`) and validating its near-contact segment
against the measured snapshot points. That is genuinely beyond what Savant/GC2
display.

GC2's per-station sanity bands (use as the decode/cleaning gates — a station out
of band ⇒ drop that station, don't trust the radius):

| station | 1/Kx band (ft) |  | scalar | band |
|---|---|---|---|---|
| Km30 (−30°) | 1.0–5.0 | | loft | −20.0…27.5 |
| Km15 (−15°) | 1.0–4.0 | | tilt | 0.0…65.0 |
| K0 (0°) | 1.0–4.0 | | | |
| K15 (+15°) | 2.0–4.0 | | | |
| K30 (+30°) | 2.0–5.0 | | | |
| K45 (+45°) | 3.0–7.0 | | | |

Radius rises monotonically with station (1–4 ft near contact → 3–7 ft at +45°),
consistent with the bat-head arc widening as the bat rotates past contact. The
GC2 `swing_shapes` validity filter is also `loft ∈ (−30,30) AND tilt ∈ (0,60)`
(from `Daily Swing Tracking.sql`). Bat-tracking phase sanity (from the agg query):
`time_pitcher_face/peak ∈ (.2,.6)`, `yaw_pitcher_face ∈ (−5,5)`, `roll_* ∈ (−60,0)`,
`v_peak ∈ (70,155)`, peak/pitcher-face attack-angle ∈ (−30,40). Contact-frame
AA/VBA/HBA formulas + the L-handed `e1x` flip = exactly what `swing_path_data.py`
already uses (verified identical).

EV for cherries (Q7) is confirmed available: `pitch_hit_trajectories.hit_launch_speed`
(EV), `hit_launch_angle` (LA), `hit_launch_direction` (spray) join on
`(sched_id, tracking_play_id)`; `astros.hits.hit_exit_speed`/`hit_vertical_angle`
drive GC2's Barrel + Damage formulas (both spelled out in `Daily Swing Tracking.sql`).

## I. BIOMECH / SKELETON DISCOVERY (2026-06-16) — measured hands + plane exist ✅

GC2's batter skeleton is real Hawkeye pose data, and it carries what we need.
Source: `sql-queries/skeleton-discovery.sql` results (`1.tsv`, `2.tsv`, `3a–3d`,
`4a–4c`).

### I1. `groundcontroltracking.Tracking.Biomechanics_Tracking` — EAV, the key table ✅
Schema: `sched_id int, pitch_id smallint, metric_id int, groundcontrol_id int,
value float`. **Tall/EAV: one row per (swing, metric, person).** Two rows per
metric per swing — batter AND pitcher — so **filter `groundcontrol_id = batter_id`**.
Joins straight to `Pitches_View` on `(sched_id, pitch_id)` (NOT tracking_play_id —
that's why skeleton-discovery §5 errored). `metric_id` → `LK_Biomechanics_Metrics_Types`
(564 metrics). Coverage TBD vs swing_shapes (likely MLB-heavy; verify empirically).

### I2. The metric_id catalog — measured 3D geometry we can use (all at CONTACT, one value/swing)
| metric_id | name | use |
|---|---|---|
| 63/64/65 | `wrist_x/y/z` | **MEASURED HANDS** — replaces the derived 28in knob (Q4 fully closed) |
| 36/37/38 | `elbow_x/y/z` | measured lead elbow |
| 6/7/8 | `bat_head_x/y/z` | barrel tip (= `head_con`) |
| 9/10/11 | `bat_ss_x/y/z` | sweet-spot (= `bat_con`) |
| 12/13/14 | `bat_velo_unit_x/y/z` | contact velocity unit (= `batv_con` dir) |
| 50–58 | `pc1_*`,`pc2_*`,`pc3_*` | **swing-path principal axes = MEASURED swing plane** (cracks Q1/Q2 — no more batv×e1 guess) |
| 15/16/17 | `centers_vec_unit_*` | hands→bat center vector |
| 2 / 24 / 62 / 39 | attack / descent / vert / face angle @ contact | measured contact angles |
| 20 / 22 | `contact_distance_from_head` / `contact_time` | |
| 18/19/21/60 | closest_approach / collision_quality / contact+sweet-spot velo | |
| 25–32 | `dist_traveled_hand/wrist (+xyz)` | hand/wrist travel (summary) |
| 69–119, 120–564 | hip/elbow/wrist/torso rot+tilt+vel at swing stations (load/sit/footplant/swing_start/commit/accel_50…400/release) | full biomech kinematics (cherries) |

These are single-value-per-swing (contact frame + swing summary), NOT per-frame.

### I3. Skeleton joints + segments ✅
`LK_Joint_Types` = 29 joints (l/r ankle ear elbow eye hip knee shoulder wrist,
neck nose mid-hip, l/r heel/bigtoe/smalltoe/thumb/pinky) with hawkeye/statcast/
kinatrax aliases. `LK_Kinematic_Segments` = body segments + mass_ratio/length_ratio
(forearm = elbow→wrist len 0.43; hands seg mass .006 len .506; torso = shoulders→hips).
Per-joint POSITIONS over time are NOT in Biomechanics_Tracking → candidate =
`Measurements` (per-timestamp EAV: `sched_id, tracking_play_id, timecode,
measurement_id, target_id, target_gc_id, value, value_numeric`). **Open: does
`Measurements` hold per-frame joint/bat XYZ?** If yes = the real full-swing path
(skeleton-discovery §6 checks this).

### I4. What this changes — CORRECTED 2026-06-16 after §7 pivot (see deep-dive doc)
**The §7 pivot (Justin Thomas 170147, a MiLB prospect) overturned the optimistic
read:** `wrist_x/y/z`, `elbow_x/y/z`, and `pc1/2/3` are **NULL on every swing** —
they need POSE tracking, which is **MLB-only** (`Measurements` flags it as MLB
StatsAPI biomechanics, ids 946–973). For our MiLB prospects:
- **Hands stay DERIVED** — no measured wrist. Keep head_con→bat_con direction +
  assumed length (current impl). The "measured hands" win does not apply to prospects.
- **Swing plane stays MODELED** — `pc1/2/3` unavailable; keep `batv_con × e1` / Swing_Shapes.
- `bat_ss`/`bat_head`/`bat_velo_unit` just **duplicate `Swing_Contact_Values`** — no new bat geometry.
- **Real new win = `Measurements`** (target_id=10): the Statcast cherries —
  squared-up % (984), swing length (974), bat speed (943), attack angle (942),
  EV (11), distance-from-sweet-spot (963), hit-trajectory JSON (109). Build after
  the arc; verify level coverage first.
- Full-doc: **`docs/plans/2026-06-16-biomech-measurements-schema-reference.md`**.

## J. SWING_DUMP DECODE (2026-06-16, `swing_dump_170147.tsv`, 5 swings + 3 PNGs)

Real numbers in hand. Decisive findings:

1. **`head_con` is the ball-IMPACT point, NOT the barrel tip.** `||head_con −
   bat_con|| ≈ con_loc_axis` exactly on every swing (0.36in on a flush CU, 6.4in
   on a 6.4in-off mishit, 17.7in on a foul-tip). So `head_con→bat_con` is a noisy
   near-zero/off-axis vector — useless as the bat axis. **Bat axis = `e1_con`** (the
   measured unit long-axis; |e1|≈1.000 on clean swings).
2. **(+e1_con) points toward the BARREL (Q4 sign closed).** `head_con − bat_con =
   +con_loc_axis · e1` (positive dot on every clean swing). ⇒ hands = `bat_con −
   28in·e1`, barrel tip = `bat_con + 6in·e1`. Wired in `_add_bat_on_arc`. Hands land
   up-and-inside (3B side, higher) for a RHB — matches the validated PNGs.
3. **The 4 snapshots are a ±~20 ms window around contact, and which side varies:**
   CU swing (1295083/324) — all snapshots BEFORE contact (downswing); FT swings
   (1295077/242, 1295082/232) — activation just before, pitcher_face/true_peak/peak
   AFTER (follow-through). Either way they cover only ~±2–3 ft of bat travel around
   contact. **The load→downswing arc is NOT measured.**
4. **Swing_Shapes radii (1/Kx) are sane** (e.g. CU: −30°2.98, −15°2.56, 0°2.43,
   +15°2.65, +30°3.28, +45°4.36 ft — min near contact, widening past it). But the
   station→plate-frame mapping (Q1) still can't be pinned: the measured points only
   span the ±20 ms contact window, so any backswing reconstruction is unvalidatable
   against ground truth. `plane_p0/1/2` ≈ (0.21, ~0.02, ~−0.01) consistently;
   `loft`≈6–9°, `tilt`≈29–33° — form still not decoded (doesn't fit z=p0+p1x+p2y).

**Conclusion (UPDATED 2026-06-17):** the contact-zone is real, AND — using the
measured **curvature profile `Km30…K45`** (not just K0) — we reconstruct the real
swing-arc *shape* over ~75° of bat rotation and it **threads the measured dots
(0.03–0.30 ft on clean swings)**. So the visible arc is a *measured* shape, not a
fabricated one (see `swing_path_true_arc.py` + the design-doc "TRUE ARC" update).
The only still-modeled part is the deepest load beyond the measured curvature span
(per-frame body lives in blobs, §K). Remaining work: port the true arc into the app,
then the **cherries** (Measurements: squared-up %, swing length, bat speed, attack
angle, EV) + PDF.

## K. POSE-FRAME HUNT — DEFINITIVE (2026-06-16, `qu1/qu2/qu2b/qu31/qu4/qu5`)

**The full per-frame batter skeleton exists, but it is NOT in queryable SQL — it
is stored as Hawkeye BLOB files.** This closes the "map the whole swing" question.

Evidence:
- **`Blob_Upload_Log` (qu31) = the proof.** Hawkeye uploads tracking as blobs by
  `tracking_type`: **`ball`, `bat`, `player`, and `biomech`** (source e.g.
  `hawkeye-hfr-BCPP-SkeletalConfig-2025-01-07-v2`, `hawkeye-lfr-scale-body29-v10`
  — **body29 = the 29-joint skeleton**). The raw per-frame pose lives in those
  blob files; the log only records that they were uploaded. GC2 renders the
  skeleton from the blobs, not from relational rows.
- **No pose table / column (qu2):** only `LK_Joint_Types` + `LK_Kinematic_Segments`
  carry joint *names*; nothing carries per-frame joint *positions*.
- **No pose measurement (qu2b/qu4):** `LK_Measurement_Types` has only "Batter
  Biomechanics" (boolean available) + "Pose Tracking Completeness" (%). The only
  per-frame JSON for the batter is `Hit Trajectory` (id 109) = the **ball** path.
- **Summary joints sparse/unusable (qu1/qu5):** `wrist_x/y/z` exist for a few
  plays but are **NULL for CJ Alexander's swings** (rok + mlb sampled), and where
  present sit in a non-plate frame (y≈54 ft) — not drop-in usable.

**Conclusion (final):** From our SQL connection the swing-path ceiling is the
**through-contact bat arc + derived hands + the ball trajectory** — all real. The
**full rendered skeleton would require reading the Hawkeye biomech BLOBs** (object
store), a separate data-access pipeline (IT/Hawkeye), NOT a query. No further SQL
pull changes this. Decision point: (a) ship the SQL-ceiling visual, or (b) open a
blob-access track to get the body29 pose frames.

## H. Follow-up discovery to resolve G (next work-laptop pass)
- **Run `scripts/exploration/swing_path_decode_prototype.py --batter-id <id> --n 5`
  → it now writes `output/swing_dump_<id>.tsv` (full precision, every raw column).
  Send that TSV back** — it is the artifact to decode Q1–Q3 from (Swing_Shapes
  numbers + measured phase positions + contact frame, unrounded).
- Dump `Swing_Shapes` for a swing **alongside** the reconstructed measured arc to
  reverse-engineer station geometry (Q1–Q3).
- Plot `bat_con`, `head_con`, and `bat_con ± L·e1` to settle Q4 visually.
- One **Savant cross-check** hitter: compare our bat speed / attack angle / swing
  length / swing tilt to Savant's published values (Q5/Q6).
- `SELECT * FROM groundcontroltracking.INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='Hitter_Kinematics'` + a row dump (Q8).
- `INFORMATION_SCHEMA` + row dump of `Hawkeye_Pitch_Hit_Trajectories.hit_launch_speed/angle` joined for a known BIP (Q7).

---

## L. GC2 "SWING FACTORS" OFFICIAL EXPLAINER (2026-06-19) — ⭐ SOURCE OF TRUTH ⭐

Zac supplied GC2's own **Swing Factors Explainer** (the doc behind `Swing_Shapes`
+ `Swing_Contact_Values` + `Swing_Damage_Windows`). **This is authoritative and
overrides every earlier inference in §A–K where they conflict.** Figures saved in
`assets/swing-factors/`. It resolves the curvature-arc blocker (Q1/Q2) and corrects
the reconstruction we shipped. Swing Factors describe the **bat trajectory** only —
NOT batter biomechanics.

### L0. Three families
- **Swing Shapes** — the bat path / "bat-path" through the zone (`Swing_Shapes`).
- **Contact Quantities** — bat & ball state at contact, or closest approach on a
  whiff (`Swing_Contact_Values`).
- **Damage Window** — how the swing shape interacts with the pitch shape
  (`Swing_Damage_Windows`).

### L1. The three bat angles (they EVOLVE through the swing — no single value)
- **VBA (Vertical Bat Angle):** angle of the bat axis vs the **ground**. `+` = head
  higher than handle, `0` = bat level, `−` = head below handle. (Orientation.)
- **HBA (Horizontal Bat Angle):** angle of the bat axis vs the **front of the
  plate**. `−` = handle "in front of" the head; `+` = the opposite; **`0` = head &
  handle aligned so the bat axis is parallel to the plate front — "pitcher face."**
- **AA (Attack Angle):** angle of the **velocity vector** of a point on the bat
  (usually the sweet spot) vs the ground. `+` = bat moving up. (Direction, not
  orientation — distinct from VBA.)

### L2. ⭐ THE STATIONS ARE HBA — and 0° IS NOT CONTACT ⭐
- **Swing Window = HBA ∈ [−30°, +45°].** This is exactly the `Km30…K45` station
  span. **The stations are degrees of HBA, not time, not "bat rotation," not a
  contact offset.** (Window covers ~95% of contact, ~98% of fair contact, ~all
  hard-hit balls.)
- **`K0` = HBA 0° = "pitcher face" (bat axis parallel to plate front).** It is a
  fixed *orientation milestone*, **NOT the moment of contact.** Contact happens at
  **`HBA_con`** (a Contact Quantity), which sits *somewhere inside* the window and
  **varies per swing**.
- ⇒ **Our shipped `build_arc` is wrong at the root:** it anchors station 0 at
  `bat_con` and integrates the tangent from `batv_con` *at station 0*. Correct:
  anchor the contact point at **HBA = `HBA_con`**, and `batv_con` is the path
  tangent at that station, not at 0°.

### L3. Swing Plane — GIVEN by loft + tilt (do NOT fit/guess it)
- **Swing Plane** = a plane fit to the **sweet-spot trajectory** (sweet spot = **6″
  below the bat head**) across the swing window. The bat moves in 3D but is very
  well approximated as moving in this 2D plane.
- **Loft** = angle the swing plane makes with the ground **as seen by the pitcher.**
- **Tilt** = angle the swing plane makes with the ground **as seen by the hitter.**
  (Example swing: loft 12°, tilt 34°. Fig `loft-tilt-rc-definitions.png`.)
- ⇒ **Loft + Tilt orient the plane analytically.** Our SVD-fit-to-dots plane + the
  "bend toward hands"/"concave-up" sign heuristics were **reinventing data GC2 hands
  us**, and badly. Replace them with the loft/tilt plane. `plane_p0/1/2` (Q2) is no
  longer needed for orientation.

### L4. Radius of Curvature (Rc) = our `1/Km`
- **Rc** = radius of the circle fitting the **sweet-spot trajectory** at a station;
  big Rc = straighter, small Rc = more curved. **Sampled every 15° of HBA** across
  the window. GC2's example table is identical in form to ours:

  | HBA° | −30 | −15 | 0 | +15 | +30 | +45 |
  |---|---|---|---|---|---|---|
  | Rc (ft) | 3.38 | 2.91 | **2.72** | 2.86 | 3.44 | 4.58 |

  Min near contact-ish, widening toward +45° — matches our observed `1/Km`. So the
  **radii are right; only how we *placed* them (station↔contact, plane) was wrong.**

### L5. Swing Volume (for Damage Window + contact-quality, not the path line)
- 3D region the bat sweeps in the window: **±2.5″ along the bat from the sweet spot
  + 1″ perpendicular** to the bat axis. Isolates the high-quality-contact region.

### L6. Contact Quantities (authoritative names)
At `tcon` (contact, or closest approach on a whiff):
- `bat-head-rcon` (head position), **`bat-rcon`** (center of bat at the contact
  location = our `bat*_con`), `e1con` (bat-axis direction), `bat-vcon` (velocity of
  the contact location; sweet-spot velocity if no contact), `ball-rcon`, `ball-vcon`.
- Derived: **`con_loc_axis`** (along bat axis), **`con_loc_perp`** (perp, **WORLD**
  frame, vs ground), **`con_loc_perp_bat`** (perp, **BAT** frame, vs bat velocity),
  **`HBA_con`** (HBA at contact — the anchor station we need, see L2).
- **World vs bat frame matters:** in the **bat** frame, on-axis contact is launched
  at the swing's **attack angle** (≈11° population avg); in the **world** frame
  on-axis = 0° launch. Hardest-hit balls = above-axis (world) / on-axis (bat). So
  `con_loc_perp_bat` is the more physically meaningful contact-quality coordinate.
- GC2 caveat (verbatim intent): individual-play contact-position data has outliers;
  trust large-scale trends, sanity-check single plays against how the ball launched.

### L7. Damage Window
- Time the **pitch** spends inside the **swing volume** (≈10 ms typical) = (pitch
  path length through the volume) ÷ plate speed. Computed as if no contact occurred,
  so the full volume exists even on early contact. Contact **inside** the damage
  window ⇒ much higher EV distribution; outside ⇒ poor quality expected. A big
  damage window = more time to make solid contact, but does NOT guarantee contact
  (timing can still miss). `Swing_Damage_Windows.damage_window` + `t_in/out_dmg_win`.

### L8. ⇒ Corrected reconstruction recipe (FUTURE add — what build_arc SHOULD do)

**STATUS: curvature true-arc is a FUTURE GC2 addition (deferred, Zac 2026-06-19).**
Not being built now. The shipped `build_arc` stays known-wrong until this pass; the
GC2 doc is captured, not yet wired into the app/PNGs. Recipe below is the plan.
1. Parameterize the curve by **HBA from −30° to +45°** (NOT by a contact-anchored
   tangent sweep).
2. Build the planar curve from **Rc(HBA) = 1/Km** (integrate curvature vs HBA).
3. Orient that plane by **loft + tilt** (given) — drop the SVD/bend-sign heuristics.
4. **Anchor at contact via `HBA_con`**: place `bat_rcon` at the HBA=`HBA_con` point
   on the curve; `batv_con` should match the curve tangent *there* (a validation,
   not the construction).
5. The sweet-spot curve is the line; the bat at contact + derived hands sit on it at
   `HBA_con`.
- **`HBA_con` is COMPUTED, not stored:** `DEGREES(ATN2(e1y_con, e1x_con))` RHB /
  flip `e1x` for LHB (band −90..80), exactly like `vba_con`/`aa_con` we already
  ship — already implemented in `swing_path_data.py` + `tracker_data._HBA_QUERY`.
  (Corrects an earlier wrong "is it a stored column?" note.) Everything else
  (`Km*`, `loft`, `tilt`, contact frame) we already pull.
- Savant cross-check (tilt / AA / swing length) is now **validation**, not the decode
  mechanism — GC2 already told us what loft/tilt are.

### L9. Figures (saved `assets/swing-factors/`)
- `loft-tilt-rc-definitions.png` — loft (pitcher view) vs tilt (hitter view) + the Rc circle.
- `rc-comparison-two-swings.png` — two swings, straighter vs more-curved, Rc per HBA.
- `swing-plane-and-volume.png` — sweet-spot path inside the plane; the volume.
- `contact-frame-bat-ball.png` — bat/ball at contact (the Contact Quantities).
- `damage-window-swing-volume-3d.png` — pitch path through the swing volume.
