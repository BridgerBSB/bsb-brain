# GC2 Biomech + Measurements Schema — In-Depth Reference (2026-06-16)

Deep dump of the two big undocumented tracking stores surfaced while hunting a
measured hand position for the swing-path tool. Source: `sql-queries/skeleton-discovery.sql`
results (`q1.tsv`, `2q`, `3q`, `4q`=metric catalog, `5q`, `6q`, `7q`, `8q`, `9q`,
`10`=Biomech kinematics sample, `11`=LK_Measurement_Types, `12`=Measurements
sample, `13`=§7 batter pivot). All in `groundcontroltracking.Tracking.*`.

> **Headline:** the rich pose data (3D wrist/elbow, PC swing plane) is **MLB-only**
> — NULL for our MiLB prospects. The broadly-available win is **`Measurements`**,
> which carries the Statcast batting cherries (squared-up %, swing length, bat
> speed, attack angle, EV, hit trajectory) per play.

---

## 1. `Biomechanics_Tracking` — EAV, one value per (swing, metric, person)

```
sched_id int, pitch_id smallint, metric_id int, groundcontrol_id int, value float
```
- Joins `Pitches_View` on **`(sched_id, pitch_id)`** (NOT tracking_play_id).
- **Two rows per metric per pitch** — batter AND pitcher — so **filter
  `groundcontrol_id = batter_id`** (or `= pitcher_id`).
- `metric_id` → `LK_Biomechanics_Metrics_Types` (`4q.tsv`, 564 metrics).
- One scalar `value` per metric per swing → **contact-frame + per-swing summary,
  NOT per-frame**.

### 1a. The 564 metric_id blocks
| metric_id | block | populated for MiLB? |
|---|---|---|
| 1–24 | contact geometry: `bat_head_xyz`(6-8), `bat_ss_xyz`(9-11), `bat_velo_unit_xyz`(12-14), `ball_xyz`(3-5), `attack_angle_contact`(2), `descent_angle_contact`(24), `contact_distance_from_head`(20), `contact_time`(22), `closest_approach_distance`(18), `collision_quality`(19), `apparent/objective_arm_axis`(1/48) | **YES (bat-tracking)** |
| 36–38, 63–65 | **`elbow_xyz`, `wrist_xyz`** (3D arm joints) | **NO — NULL for prospects (pose/MLB-only)** |
| 15–17, 25–47, 49–61 | `centers_vec_unit`, `dist_traveled_hand/wrist(+xyz)`, `max_velo_hand/wrist`, `mag.Hand_Proj`, `pc1/2/3_xyz`(50-58) (**PC swing plane**), `face_angle_contact`(39), `vert_angle_contact`(62), `sweet_spot_velo_contact`(60) | **MIXED — `face/vert_angle_contact` YES; pc/wrist/hand-proj NO (pose/MLB)** |
| 66–119 | swing event times + peak biomech (`swing_start/commit/accel_time`, `peak_hip_rot_vel`, `*_at_release`) | partial |
| 120–564 | full kinematics: hip/torso/lead-elbow/lead-wrist/shoulder/knee **rotation+tilt+flex (+vel)** at stations `load → sit → footplant → swing_start → swing_commit → swing_accel_50/_/200/300/400 → release` | **YES (broadly)** |

### 1b. CRITICAL coverage finding (Justin Thomas 170147, §7 `13`)
Every swing: `bat_ss`/`bat_head`/`bat_velo_unit`/`attack_angle_contact`/
`vert_angle_contact`/`face_angle_contact` **populated**; `wrist`/`elbow`/`pc1/2/3`
**NULL**. Same table+join+filter, different metric_id → those rows don't exist.
Some swings (e.g. 1344194/69) have NO 1–65 block at all, only kinematics (69+).
⇒ **3D hands (wrist) + PC swing plane require pose tracking = MLB-only.** For MiLB
prospects they're unavailable; the swing-path tool keeps deriving the hands.
⇒ `bat_ss`≈`scv.bat_con`, `bat_head`≈`scv.head_con`, `bat_velo_unit`≈`scv.batv_con`
(normalized) — **duplicates `Swing_Contact_Values`; no new bat geometry.**

---

## 2. `Measurements` — per-play EAV over the full Hawkeye metric catalog ✅ the real win

```
sched_id int, tracking_play_id smallint, timecode bigint, measurement_id smallint,
target_id smallint, target_gc_id int, value varchar, value_numeric decimal, timestamp datetime2
```
- Joins via `Plays` (`Pitches_View.pitch_id = Plays.astros_pitch_id`, then
  `Measurements.sched_id/tracking_play_id`).
- `measurement_id` → **`LK_Measurement_Types`** (`11`, 996 rows: name/unit/category/description).
- `value_numeric` = the number; `value` = raw string (also holds **JSON** for
  array metrics; numeric ones show `0.0` in value_numeric for JSON/string types).
- **Many rows per play** (one per measurement per target, at its event timecode).
  NOT a fixed per-frame skeleton — these are derived metrics + a few JSON arrays.

### 2a. `target_id` = role (inferred from the sample, matches scorekeeping pos)
`0` = play-level · `1` = pitcher · `2` = catcher · `3` = 1B · `4` = 2B · `5` = 3B ·
`6` = SS · `7` = LF · `8` = CF · `9` = RF · `10` = **batter** · `11`/`12`/… = runners.
`target_gc_id` = that person's groundcontrol_id (filter batter rows:
`target_id = 10 AND target_gc_id = batter_id`).

### 2b. Batter cherries (target_id = 10) — `LK_Measurement_Types` ids
| id | metric | unit |
|---|---|---|
| 11 | **Exit Velocity** | MPH |
| 10 / 150 | Launch Angle / Hit Launch Direction | deg |
| 942 | **Attack Angle** (bat path at impact) | deg |
| 943 | **Bat Speed** (sweetSpot pre-contact) | MPH |
| 974 | **Swing Length** (sweet-spot path to impact) | ft |
| 984 | **Percent Squared Up** (EV efficiency vs bat+pitch speed) | % |
| 963 | **Distance from Sweet Spot** (Hawkeye oval eq. in desc) | in |
| 108 | Barreled Ball | bool |
| 101 | Estimated Swing Speed | MPH |
| 109 | **Hit Trajectory** — JSON ball path `[{t,x,y,z}…]` (t=0,0.5,1…) | JSON |
| 149 / 271 | Projected Landing / Ball Location @300ft | JSON |
| 927/938 | Hit Landing Bearing | deg |
| 993/994/995/996 | Batter Depth in Box / Distance Off Plate / Between Feet / Stance Angle | in/deg |
| 975/978 | Sword Swing | bool |
| 946–962 | Batter Biomechanics availability (MLB StatsAPI flags) | bool |

These cover the planned **cherries** (squared-up %, swing length, smash factor via
EV÷bat-speed, ideal-AA) and a measured **EV** source — no need for the Hawkeye
trajectory tables. Coverage TBD (verify per level; likely MLB + Hawkeye venues).

### 2b-Q. "Can we show the HANDS through the swing?" — NO (three separate noes)
1. **3D hand position per-frame:** no raw skeleton-trajectory table exists anywhere.
2. **3D hand position even at contact:** `wrist_x/y/z` is NULL for MiLB prospects
   (pose = MLB-only) — zero measured hand XYZ for prospects, not even one point.
3. **Through the swing we only have ANGLES**, not positions: lead-wrist/elbow/hip/
   torso rotation/tilt/flex at ~10 stations (load→sit→footplant→swing_start→commit→
   swing_accel_50/200/300/400→release, metric_ids 120–564). Joint angles can't be
   turned into a hand *path* without a full skeleton + per-frame root we don't have.
   The only per-frame *path* in the data is the **ball** (`Measurements` id 109 Hit
   Trajectory), not the hands.
⇒ Hands stay a **contact-frame derivation** (head→bat dir + length); the bat *path*
through contact stays the **`Swing_Shapes` Km* curvature model**. That's GC2's ceiling.

### 2c. No raw per-frame skeleton
`LK_Measurement_Types` is all *derived* metrics (Launch Angle, Pop Time, etc.) +
JSON arrays (Hit Trajectory, Baserunner Markers, Distance Covered Breakdown).
`id 969 Player Tracking Completeness` + `id 973 Pose Tracking Completeness` =
**%-of-play** flags only. The raw per-frame joint/bat XYZ stream is **not exposed**
in these tables ⇒ a true frame-by-frame full-swing path can't be drawn from GC2.

---

## 3. `LK_Joint_Types` (29-joint skeleton) + `LK_Kinematic_Segments`
`LK_Joint_Types`: l/r ankle ear elbow eye hip knee shoulder wrist, neck nose
mid-hip, l/r heel/bigtoe/smalltoe/thumb/pinky — with `hawkeye`/`statcast`/`kinatrax`
aliases. `LK_Kinematic_Segments`: forearm = elbow→wrist (len .43), hands seg
(mass .006, len .506), torso = shoulders→hips, etc. These describe the pose model;
the per-joint POSITIONS feed `Biomechanics_Tracking` (MLB-only) — not a position
table we can query per frame.

---

## 4. What this means for the swing-path tool
1. **Hands stay derived for MiLB.** No measured wrist for prospects. Keep the
   head_con→bat_con direction + assumed length (current impl).
2. **Swing plane stays modeled for MiLB.** `pc1/2/3` MLB-only; keep `batv_con × e1`
   (or Swing_Shapes plane) for prospects.
3. **Bat geometry: no new data** — `Biomechanics_Tracking` bat block = SCV we have.
4. **Cherries are now sourced** from `Measurements` (target_id=10): squared-up %
   (984), swing length (974), bat speed (943), attack angle (942), EV (11),
   distance-from-sweet-spot (963), hit trajectory (109). Build these after the
   arc — verify level coverage first.
5. **Full-swing geometry** still comes from `Swing_Shapes` Km* curvature decode
   (the `swing_dump` pull) — unchanged by this discovery.
