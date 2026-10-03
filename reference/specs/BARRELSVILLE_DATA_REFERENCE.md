# Barrelsville Data Reference

## gcOBA Formula (from GC2 Production — Event-Level Query)

The gcOBA (GroundControl OBA) formula is computed at the PA/event level and uses league OBP as a scaling factor.

### Formula
```
gcOBA = league_OBP * (
    0.50 * K_rate
    + 1.49 * BB_HBP_rate
    + 0.11 * zero_swing_rate
    + 0.08 * one_swing_rate
    + -0.10 * two_swing_rate
    + -0.10 * three_plus_swing_rate
    + BIP_rate * (
        1.70 * barrel_rate_on_bip
        + 1.09 * avg_useful_ev_on_bip / 100.0
    )
)
```

### Component Definitions
- **league_OBP**: From `mlbam.YTD_Team_Batting_Stats` — MLB level, regular season, split_id=0, team_id=0 (all teams). If current year and before May, uses prior year.
- **K_rate**: `AVG(CASE WHEN pa=1 THEN CASE WHEN so=1 THEN 1.0 ELSE 0.0 END END)` — strikeout rate per PA
- **BB_HBP_rate**: `AVG(CASE WHEN pa=1 THEN CASE WHEN (bb|hbp=0) THEN 0.0 ELSE 1.0 END END)` — walk/HBP rate per PA
- **Swing count rates**: GC2 uses `CurEvents.pitches` string column (counts S/W/T characters). We compute from pitch-level `did_swing` counts per PA instead.
  - zero_swing_rate: Rate of PAs with exactly 0 swings
  - one_swing_rate: Rate of PAs with exactly 1 swing
  - two_swing_rate: Rate of PAs with exactly 2 swings
  - three_plus_swing_rate: Rate of PAs with 3+ swings
- **BIP_rate**: `AVG(CASE WHEN pa=1 THEN CASE WHEN (bb|hbp|so=0) THEN 1.0 ELSE 0.0 END END)` — rate of PAs ending in ball in play
- **barrel_rate_on_bip**: Barrel rate on BIP using GC2 LINEAR barrel formula (NOT parabolic):
  - `EV*1.5 - LA >= 117 AND EV + LA >= 124 AND EV >= 98 AND LA > 4 AND LA < 50`
  - ISNULL'd to 0.0 when no tracking data
- **avg_useful_ev_on_bip**: `AVG(hit_useful_exit_speed)` on BIP from Astros.Hits
  - `hit_useful_exit_speed` is a separate column from `hit_exit_speed` in Astros.Hits
  - ISNULL'd to 0.0 when no tracking data

### HitsNoBunts Filter (from GC2 production)
When joining Astros.Hits for gcOBA, apply these filters:
- `pitch_result_id IN (12, 13, 14)` — BIP only
- `hit_trajectory_id NOT IN (2, 3, 4) OR hit_trajectory_id IS NULL` — exclude bunts (from Events_View)
- `hit_exit_speed < 125` — cap outliers
- `NOT (hit_vertical_angle < -25 AND level_code IN ('hsb', 'sum', 'bbc'))` — exclude extreme negatives at amateur levels

### GC2 Barrel Formula (LINEAR — matches production)
```
EV * 1.5 - LA >= 117
AND EV + LA >= 124
AND EV >= 98
AND LA > 4
AND LA < 50
```
Note: Our current code uses a parabolic barrel formula (`EV >= 0.011*LA^2 - 0.91*LA + 95`). We should migrate to the GC2 linear formula to match production.

### Key Tables for gcOBA
| Table | Purpose |
|-------|---------|
| `mlbam.YTD_Team_Batting_Stats` | League OBP (season, level='mlb', gm_type='r', split_id=0, team_id=0) |
| `Astros.Events_View` | PA-level outcomes, hit_trajectory_id for bunt filter |
| `Astros.Hits` | `hit_useful_exit_speed`, `hit_exit_speed`, `hit_vertical_angle` for barrel + EV |
| `Astros.Pitches_View` | Pitch-level data for swing counts |

---

## Bat Speed (Apr 26 2026 — switched to at-contact)

- **Source:** `groundcontroltracking.tracking.swing_contact_values` via `tracking.plays`
- **Formula:** `SQRT(batvx_con² + batvy_con² + batvz_con²) * 0.681818 = mph`
- **Contains:** Per-contact-event vectors. Whiffs absent (no row). BIP + fouls + foul tips included.
- **Conclusion:** SCV is the ONLY in-game bat speed source. `v_true_peak` (peak) is retired.

| Table | Notes | Source for |
|---|---|---|
| `groundcontroltracking.tracking.swing_contact_values` | **In-game, HawkEye venues only.** Per-contact event. | Bat speed at contact, AA, VBA. |
| `Astros.Bat_Tracking_Metrics` | **In-game, HawkEye venues. Retired for in-game bat speed.** | (Now: only `adj_aa_pitcher_face` for back-compat references — preferred is SCV at-contact AA.) |
| `BlastMotion.Series_Metrics_View` | Separate system from Hawkeye. Bat-sensor data (knob attachment), used in **both practice and games**. | Sensor-derived swing metrics (separate pipeline from SCV at-contact). |

### Historical context (peak bat speed — RETIRED)
Previously the Astros canonical was `Astros.Bat_Tracking_Metrics.v_true_peak` (speed of sweet spot at interpolated peak, in FPS) × 0.682 → MPH. As of Apr 26 2026, all in-game bat speed surfaces switched to **at-contact** (SCV). `Bat_Tracking_Metrics` remains in-database for historical analysis and `adj_aa_pitcher_face` back-compat references, but `v_true_peak` is no longer used in any live report or app.

### SCV (swing_contact_values) join + columns
**Join path:** `Pitches_View pv → tracking.plays tp ON sched_id+astros_pitch_id → swing_contact_values scv ON sched_id+tracking_play_id`

| SCV column | Purpose |
|---|---|
| `batvx_con`, `batvy_con`, `batvz_con` | Bat velocity vector at contact (FPS). Speed = `SQRT(vx²+vy²+vz²) * 0.681818` MPH. Required filter: `batvx_con IS NOT NULL`. |
| `e1z_con` | Vertical bat angle z-component. VBA = `90 - DEGREES(ACOS(e1z_con))`, range filter `BETWEEN -70 AND 10`. |
| `e1x_con`, `e1y_con` | Horizontal bat angle components. |
| `batx/y/z_con`, `ballx/y/z_con` | Spatial coords at contact. |

**Pool inclusion (Astros canonical):** any row where `batvx_con IS NOT NULL` (BIP + fouls + foul tips). Whiffs naturally absent. NO `pitch_result_id` whitelist.
**GC2 leaderboard divergence:** GC2 filters to `pitch_result_id IN (12,13,14,18,19,20)` (BIP only). Documented divergence in `.claude/rules/gc2-metrics.md`.

### Other Swing Tables (Astros schema)
- `Swing_Coefs`: Model coefficients per player per year (alpha, beta1, beta2 quantiles, by quad + framerate)
- `Time_At_Swing_Start`: Separate table with just `time_at_swing_start` per pitch (sched_id + pitch_id + groundcontrol_id)

### Pitches_View Swing Decision Columns (not currently used — potential future additions)
- `should_swing` (bit) — model says whether batter should have swung
- `swing_decision_grade_2080` (float) — swing decision quality on 20-80 scale
- `swing_decision_score` (float) — raw swing decision score
- `swing_decision_abs_grade_2080` (float) — absolute swing decision grade
- `swing_decision_abs_score` (float) — absolute swing decision score

---

## BlastMotion Data (Bat-Sensor System — Practice + In-Game)

**Schema:** `GroundControl2.BlastMotion`

**IMPORTANT:** BlastMotion is a **separate sensor system** from Hawkeye SCV — different pipeline, different metrics. Blast is a wearable bat sensor (knob attachment) that captures swing data **during BOTH practice AND in-game at-bats** (BP, cage work, tee work, AND game PAs where players wear it). Different from Hawkeye SCV (camera-based at-contact bat-ball collision vectors). Don't conflate the two systems — they coexist with different coverage and different metric definitions. The Apr 26 2026 SCV at-contact refactor did NOT touch any BlastMotion code/data.

### Key Tables
| Table | Purpose |
|-------|---------|
| `BlastMotion.Series_Metrics_View` | **TIME-SERIES** swing data — many rows per swing (one per timestamp). Position, velocity, angles at each moment. |
| `BlastMotion.Adv_Accel_Gyro_View` | Raw accelerometer + gyroscope sensor telemetry. Has `sensortimestamp` (datetime) + `groundcontrol_id`. |
| `BlastMotion.Adv_Accel_Gyro_View_RPM` | Same as above with RPM (rotational velocity) calculations. Has `sensortimestamp` + `groundcontrol_id`. |

### Series_Metrics_View Schema (verified Feb 19, 2026)
| Column | Type | Notes |
|--------|------|-------|
| `actionid` | varchar | UUID per swing — groups all time-series rows for one swing |
| `timestamp` | decimal | Time offset within the swing (NOT datetime — use Adv views for dates) |
| `bat_position_x/y/z` | float | Bat position at this moment |
| `bat_velocity_x/y/z` | float | Bat velocity components |
| `hand_position_x/y/z` | float | Hand position |
| `hand_velocity_x/y/z` | float | Hand velocity components |
| `bat_speed` | float | Bat speed magnitude — **units TBD** (~1.4-1.5 values, NOT mph) |
| `hand_speed` | float | Hand speed magnitude — **units TBD** (~0.2 values) |
| `attack_angle` | float | Likely **radians** (~0.14 = ~8 degrees) |
| `hinge_angle` | float | Hinge angle (wrist/elbow) |
| `vertical_bat_angle` | float | VBA at this moment |
| `bat_direction` | float | Bat direction |
| *(more columns below row 20 — not yet captured)* | | |

### Important Notes
- `sensortimestamp` exists in Adv_Accel_Gyro views (datetime), NOT in Series_Metrics_View
- `groundcontrol_id` exists in Adv_Accel_Gyro views — need to confirm join path to Series_Metrics_View (likely via `actionid`)
- To get per-swing peak bat speed: `SELECT actionid, MAX(bat_speed) FROM ... GROUP BY actionid`
- **Units for bat_speed are TBD** — values ~1.4-1.5, not directly mph. Ask JJ/Bradley Moore for conversion.
- attack_angle appears to be in radians (× 57.2958 = degrees)

### Query Examples
```sql
-- Adv views have sensortimestamp + groundcontrol_id (use for date/player filtering)
SELECT TOP 10 * FROM GroundControl2.BlastMotion.Adv_Accel_Gyro_View
WHERE groundcontrol_id = 138501
  AND sensortimestamp >= '2025-02-06'

-- Series_Metrics_View has NO sensortimestamp — filter by actionid
-- Get peak bat speed per swing
SELECT TOP 20 actionid, MAX(bat_speed) AS peak_bat_speed,
       MAX(hand_speed) AS peak_hand_speed, COUNT(*) AS n_samples
FROM GroundControl2.BlastMotion.Series_Metrics_View
GROUP BY actionid ORDER BY MAX(bat_speed) DESC

-- List all BlastMotion tables
SELECT TABLE_SCHEMA, TABLE_NAME
FROM GroundControl2.INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'BlastMotion'
ORDER BY TABLE_NAME

-- Find which tables have groundcontrol_id (for player-level joins)
SELECT TABLE_NAME, COLUMN_NAME
FROM GroundControl2.INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'BlastMotion' AND COLUMN_NAME = 'groundcontrol_id'
```

### Bat Speed Data Sources Summary (Apr 26 2026 — switched to at-contact)
| Source | Context | Data |
|--------|---------|------|
| `groundcontroltracking.tracking.swing_contact_values` | **In-game, HawkEye venues only** | At-contact bat speed: `SQRT(batvx_con²+batvy_con²+batvz_con²) * 0.681818 = mph`. Also AA + VBA at contact. **CANONICAL SOURCE.** |
| `Astros.Bat_Tracking_Metrics` | **In-game, HawkEye venues** | RETIRED for bat speed. `adj_aa_pitcher_face` retained for back-compat AA references only. |
| `BlastMotion.Series_Metrics_View` | **Practice + In-Game** (separate sensor system from Hawkeye) | Bat speed, attack angle, time to contact, etc. from wearable bat-sensor (knob attachment). Captures both BP/cage/tee work AND in-game at-bats. Untouched by Apr 26 refactor — different data pipeline. |
| TrackMan venues | In-game | **No bat tracking** — BS and AA columns show dashes |

### Competitive Swing Flag
There is **NO competitive swing flag** for hitters. `competitive_play` and `competitive_throw` exist only in defensive fielding tables (e.g., was a fielding play routine vs difficult). No way to filter non-competitive swings (check swings, protect swings) from tracking data.

---

## Video Angles for Hitter Reports

### Camera Angle Selection (by BATTER handedness)
For hitting reports, side camera selection is based on **batter handedness** (bat_side), NOT pitcher handedness.

| Batter Hand | Primary Angle | Fallback | Reason |
|-------------|--------------|----------|--------|
| LHH (Left)  | H            | 6        | Shows swing path from behind |
| RHH (Right) | F            | 7        | Shows swing path from behind |

### All Available Angles
| Angle Code | Description |
|------------|-------------|
| `v` | CF Angle **(primary — personal-device safe; IT only allows V + sometimes A)** |
| `a` | CF Angle / broadcast (secondary fallback) |
| `M` | Behind-plate / field camera (tertiary — team devices only; usually IT-blocked on personal) |
| `5` | CF Edge (secondary) |
| `F` | Side angle — 1B side (RHP arm side) — use for RHH |
| `7` | Fallback for F |
| `E` | Side angle — 3B side (LHP arm side) |
| `6` | Fallback for E |
| `H` | Side angle — use for LHH |

### Implementation
- CF video (column label **V**): `ISNULL(angle 'v', ISNULL(angle 'a', angle 'M'))` — V first because IT blocks most angles on personal devices / Sporty Clips
- Side video: pick by `bat_side` column from Pitches_View (NO fallback to CF)
  - `bat_side = 'L'` → angle H (fallback 6)
  - `bat_side = 'R'` → angle F (fallback 7)
- Column order in per-swing table: `..., BS, V, Side` (V before Side)

---

## GC2 Production Query Reference (Event-Level)

The full GC2 production event-level batting query was provided on Feb 19, 2026. Key elements:

### Joins
```sql
FROM Astros.Events_View CurEvents
LEFT JOIN Astros.Pitches_View Pitches
    ON CurEvents.sched_id = Pitches.sched_id
    AND CurEvents.event_id = Pitches.cur_event_id  -- OK: final pitch of PA only
LEFT JOIN Astros.Schedule_View Schedule
    ON Pitches.sched_id = Schedule.sched_id
LEFT JOIN mlbam.YTD_Team_Batting_Stats YtdLeagueBatting
    ON season = (CASE WHEN year(getdate()) = Schedule.year AND month(getdate()) < 5
                      THEN Schedule.year-1 ELSE Schedule.year END)
    AND level = 'mlb' AND gm_type = 'r' AND split_id = 0 AND team_id = 0
LEFT JOIN mlbam.Schedule MlbamSchedule
    ON Schedule.mlbam_game_pk = MlbamSchedule.game_pk
LEFT JOIN Guts.woba_lwts Woba
    ON MlbamSchedule.year = Woba.year AND MlbamSchedule.league = Woba.league
LEFT JOIN Astros.Hits HitsNoBunts
    ON Pitches.sched_id = HitsNoBunts.sched_id
    AND Pitches.pitch_id = HitsNoBunts.pitch_id
    AND Pitches.pitch_result_id IN (12,13,14)
    AND (CurEvents.hit_trajectory_id NOT IN (2,3,4) OR CurEvents.hit_trajectory_id IS NULL)
    AND NOT (HitsNoBunts.hit_vertical_angle < -25 AND Schedule.level_code IN ('hsb','sum','bbc'))
    AND HitsNoBunts.hit_exit_speed < 125
```

### wOBA (standard, also in GC2)
```sql
(AVG(Woba.woba_BB)*SUM(BB-IBB) + AVG(Woba.woba_HB)*SUM(HBP)
 + AVG(Woba.woba_1B)*SUM(1B) + AVG(Woba.woba_2B)*SUM(2B)
 + AVG(Woba.woba_3B)*SUM(3B) + AVG(Woba.woba_HR)*SUM(HR))
/ NULLIF(SUM(AB + BB - IBB + SF + HBP), 0)
```

### wRC+
```sql
100.0 * ((wOBA - AVG(Woba.wOBA)) / AVG(Woba.wOBA_scale) + AVG(Woba.runs_per_pa))
       / AVG(Woba.runs_per_pa)
```

### Swing Count (GC2 method via pitches string)
GC2 counts swings from `CurEvents.pitches` column:
```sql
len(CurEvents.pitches) - len(replace(replace(replace(CurEvents.pitches, 'S', ''), 'W', ''), 'T', ''))
```
This counts 'S', 'W', 'T' characters = swing events.

Our implementation: we count swings from pitch-level data (`did_swing=1`) grouped by `ab_event_id`.
