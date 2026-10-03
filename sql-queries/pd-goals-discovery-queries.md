# PD Goals — DB Discovery Queries

All queries used during DB exploration for the pd-goals project.
Run on work laptop against gcsql02 / GroundControl2 (Windows Auth).

---

## Round 1: Initial Discovery (db_discovery_extract.py)

See `pd-goals/db_discovery_extract.py` for the full automated script.
Results saved to `pd-goals/DB_DISCOVERY_RESULTS.md`.

---

## Round 2: Follow-Up Queries (Jan 31, 2026)

### Q1: Bat Tracking — Find rows with actual data
```sql
SELECT TOP 10 * FROM Astros.Bat_Tracking_Metrics WHERE v_true_peak IS NOT NULL
```
**Status:** CONFIRMED — data IS populated. `v_true_peak` bat speed values exist.

### Q2: Events_View via Pitches_View join (CONFIRMED WORKING)
```sql
SELECT TOP 10 ev.*, pv.batter_id, pv.pitcher_id
FROM Astros.Events_View ev
JOIN Astros.Pitches_View pv ON ev.sched_id = pv.sched_id AND ev.event_id = pv.cur_event_id
WHERE pv.batter_id = 78084
```

### Q3: Hits_Probabilities via pitch_id join (CONFIRMED WORKING)
```sql
SELECT TOP 10 hp.*, pv.batter_id
FROM Astros.Hits_Probabilities hp
JOIN Astros.Pitches_View pv ON hp.sched_id = pv.sched_id AND hp.pitch_id = pv.pitch_id
WHERE pv.batter_id = 78084
```

### Q4: Pitches_Grades via pitch_id join (join works, data NULL for tested pitchers)
```sql
-- Original query used pitcher_id=793745 which wasn't found
-- Ran without the WHERE or with different pitcher_ids; grades were all NULL
SELECT TOP 10 pg.*, pv.pitcher_id, pv.pitch_type
FROM Astros.Pitches_Grades pg
JOIN Astros.Pitches_View pv ON pg.sched_id = pv.sched_id AND pg.pitch_id = pv.pitch_id
```
**Note:** Stuff grades exist directly in Pitches_View — use those instead.

### Q5: INF_Ability_Metrics columns (CONFIRMED)
```sql
SELECT COLUMN_NAME, DATA_TYPE FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'Astros' AND TABLE_NAME = 'INF_Ability_Metrics'
ORDER BY ORDINAL_POSITION
```
**Result:** 18 columns — season, groundcontrol_id, level_code, n_plays, n_outs, acceleration_chest_down, acceleration_chest_up, top_speed, n_arm_strength_plays, arm_strength, n_exchange_plays, exchange_time, reaction_time_4mph, useful_reaction_4mph, reaction_time_radius, reaction_accuracy_radius, pred_deflections, hands_rate.

### Q6: OF_Ability_Metrics columns (CONFIRMED)
```sql
SELECT COLUMN_NAME, DATA_TYPE FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'Astros' AND TABLE_NAME = 'OF_Ability_Metrics'
ORDER BY ORDINAL_POSITION
```
**Result:** 18 columns — identical structure to INF_Ability_Metrics.

### Q7: Tracking_Defensive_Metrics columns (CONFIRMED)
```sql
SELECT COLUMN_NAME, DATA_TYPE FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'Astros' AND TABLE_NAME = 'Tracking_Defensive_Metrics'
ORDER BY ORDINAL_POSITION
```
**Result:** 21 columns — sched_id, pitch_id, tracking_play_id, pos_id, event_id, groundcontrol_id, out_made, competitive_play, competitive_throw, reaction_4mph, reaction_radius, reaction_accuracy_radius, useful_reaction_4mph, acceleration_chest_down, acceleration_chest_up, top_speed, arm_strength, exchange, pop_time, exchange_dp, top_speed_flag.

### Q8: Schedule_View columns (CONFIRMED)
```sql
SELECT COLUMN_NAME, DATA_TYPE FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'Astros' AND TABLE_NAME = 'Schedule_View'
ORDER BY ORDINAL_POSITION
```
**Result:** 20+ columns — sched_id, sched_date (date), year (smallint), level_id, sched_type_id, league_id, away_team_mlbam_id, home_team_mlbam_id, mlbam_game_pk, description, gc2_level_id, is_pro_level, is_pro_level_and_winter, is_amateur_level, is_int_level, level_code, level_display, league, sched_type, gc2_level_code.

### Q9: Guts.woba_lwts columns and data (CONFIRMED)
```sql
-- Column check
SELECT COLUMN_NAME, DATA_TYPE FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'Guts' AND TABLE_NAME = 'woba_lwts'

-- Data (get most recent)
SELECT TOP 3 * FROM Guts.woba_lwts ORDER BY year DESC
```
**Result:** 30 columns — year (int), level_code, league, run_BB, run_HB, run_1b, run_2b, run_3b, run_HR, run_SB, run_CS, run_Minus, run_Plus, wOBA, wOBA_scale, wOBA_BB, wOBA_HB, wOBA_1B, wOBA_2B, wOBA_3B, wOBA_HR, wOBA_SB, wOBA_CS, runs_per_out, runs_per_pa, runs_total, outs_total, pa_total, lgERA, FIPconstant.

**Note:** Data is keyed by `year + level_code + league`. The original `ORDER BY year DESC` error was likely caused by running both queries in one batch with `hit_specs_ratios` (which may not have `year`).

### Q9b: Guts.hit_specs_ratios (PERMISSION DENIED — not a blocker)
```sql
SELECT COLUMN_NAME, DATA_TYPE FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'Guts' AND TABLE_NAME = 'hit_specs_ratios'

SELECT TOP 3 * FROM Guts.hit_specs_ratios
```
**Result:** `SELECT permission was denied on the object 'Hit_Specs_Ratios', database 'GroundControl2', schema 'Guts'`. Not needed for MVP.

---

## Production Query Templates

### Hitter K% and BB%
```sql
SELECT
    SUM(CAST(ev.so AS INT)) * 100.0 / NULLIF(SUM(CAST(ev.pa AS INT)), 0) AS k_pct,
    SUM(CAST(ev.bb AS INT)) * 100.0 / NULLIF(SUM(CAST(ev.pa AS INT)), 0) AS bb_pct,
    SUM(CAST(ev.pa AS INT)) AS pa
FROM Astros.Events_View ev
JOIN Astros.Pitches_View pv ON ev.sched_id = pv.sched_id AND ev.event_id = pv.cur_event_id
JOIN Astros.Schedule_View sv ON ev.sched_id = sv.sched_id
WHERE pv.batter_id = @player_id
  AND sv.sched_date BETWEEN @start_date AND @end_date
```

### Pitcher K% and BB% (against)
```sql
SELECT
    SUM(CAST(ev.so AS INT)) * 100.0 / NULLIF(SUM(CAST(ev.pa AS INT)), 0) AS k_pct,
    SUM(CAST(ev.bb AS INT)) * 100.0 / NULLIF(SUM(CAST(ev.pa AS INT)), 0) AS bb_pct,
    SUM(CAST(ev.pa AS INT)) AS bf
FROM Astros.Events_View ev
JOIN Astros.Pitches_View pv ON ev.sched_id = pv.sched_id AND ev.event_id = pv.cur_event_id
JOIN Astros.Schedule_View sv ON ev.sched_id = sv.sched_id
WHERE pv.pitcher_id = @player_id
  AND sv.sched_date BETWEEN @start_date AND @end_date
```

### CSW% (Called Strike + Whiff)
```sql
SELECT
    SUM(CASE WHEN pitch_result_id IN (6,3,24,30,31,10,16,21,22,23) THEN 1 ELSE 0 END) * 100.0
    / NULLIF(COUNT(*), 0) AS csw_pct
FROM Astros.Pitches_View pv
JOIN Astros.Schedule_View sv ON pv.sched_id = sv.sched_id
WHERE pv.pitcher_id = @player_id
  AND sv.sched_date BETWEEN @start_date AND @end_date
```

### FPS% (First Pitch Strike)
```sql
SELECT
    SUM(CASE WHEN pitch_result_id IN (6,3,24,30,31,10,16,21,22,23,7,8,9,12,13,14,18,19,20,25) THEN 1 ELSE 0 END) * 100.0
    / NULLIF(COUNT(*), 0) AS fps_pct
FROM Astros.Pitches_View pv
JOIN Astros.Schedule_View sv ON pv.sched_id = sv.sched_id
WHERE pv.pitcher_id = @player_id
  AND pv.ab_pitch_number = 1
  AND sv.sched_date BETWEEN @start_date AND @end_date
```

### Pitch Metrics (Velo, Spin, Extension, iVB, HB) by Pitch Type
```sql
SELECT
    pitch_type,
    COUNT(*) AS n,
    AVG(release_speed) AS avg_velo,
    AVG(spin_rate) AS avg_spin,
    AVG(extension) AS avg_ext,
    AVG(inducedvertbreak) AS avg_ivb,
    AVG(horzbreak) AS avg_hb
FROM Astros.Pitches_View pv
JOIN Astros.Schedule_View sv ON pv.sched_id = sv.sched_id
WHERE pv.pitcher_id = @player_id
  AND sv.sched_date BETWEEN @start_date AND @end_date
GROUP BY pitch_type
```

### Stuff Grade (from Pitches_View directly)
```sql
SELECT
    AVG(stuffrelvel_grade_2080) AS avg_stuff_grade,
    AVG(swing_decision_grade_2080) AS avg_swdec_grade
FROM Astros.Pitches_View pv
JOIN Astros.Schedule_View sv ON pv.sched_id = sv.sched_id
WHERE pv.pitcher_id = @player_id
  AND sv.sched_date BETWEEN @start_date AND @end_date
```

### xwOBA (from Hits_Probabilities + Guts coefficients)
```sql
-- Step 1: Get wOBA coefficients for the year/level
-- SELECT * FROM Guts.woba_lwts WHERE year = @year AND level_code = @level

-- Step 2: Calculate xwOBA per batted ball event
SELECT
    AVG(
        (hp.prob_inf_1b + hp.prob_of_1b) * @w1B
        + hp.prob_2b * @w2B
        + hp.prob_3b * @w3B
        + hp.prob_hr * @wHR
        + (hp.prob_inf_out + hp.prob_of_out) * 0  -- outs contribute 0 to wOBA numerator
    ) AS xwobacon
FROM Astros.Hits_Probabilities hp
JOIN Astros.Pitches_View pv ON hp.sched_id = pv.sched_id AND hp.pitch_id = pv.pitch_id
JOIN Astros.Schedule_View sv ON hp.sched_id = sv.sched_id
WHERE pv.batter_id = @player_id
  AND sv.sched_date BETWEEN @start_date AND @end_date
```
