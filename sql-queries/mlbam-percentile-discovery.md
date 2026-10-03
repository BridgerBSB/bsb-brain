# MLBAM Percentile Verification Queries

Run on work laptop against gcsql02 / GroundControl2 to verify join paths for league-wide percentiles.

---

## Q1: MLBAM.Schedule columns (does it have level?)
```sql
SELECT COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'MLBAM' AND TABLE_NAME = 'Schedule'
ORDER BY ORDINAL_POSITION
```

## Q2: MLBAM.Schedule sample (check for level, all teams)
```sql
SELECT TOP 10 * FROM MLBAM.Schedule WHERE year = 2025
```

## Q3: How many teams in MLBAM.Schedule?
```sql
SELECT COUNT(DISTINCT home_team_id) as n_teams, year
FROM MLBAM.Schedule
WHERE year = 2025
GROUP BY year
```

## Q4: Does MLBAM.Pitch_fx have game_pk?
```sql
SELECT TOP 5 game_pk, batter_id, pitcher_id, called_strike_chance_mlb, did_swing
FROM MLBAM.Pitch_fx
```

## Q5: Pitch_fx columns (verify column names)
```sql
SELECT COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'MLBAM' AND TABLE_NAME = 'Pitch_fx'
  AND COLUMN_NAME IN ('game_pk', 'batter_id', 'pitcher_id', 'called_strike_chance_mlb',
    'did_swing', 'pitch_result_id', 'swing_decision_score', 'stuff_grade_2080',
    'stuffrelvel_grade_2080', 'pitcher_throws', 'bat_side', 'level')
ORDER BY ORDINAL_POSITION
```

## Q6: Test Pitch_fx → MLBAM.Schedule join for level filtering
```sql
SELECT TOP 5 pf.batter_id, pf.called_strike_chance_mlb, ms.*
FROM MLBAM.Pitch_fx pf
JOIN MLBAM.Schedule ms ON pf.game_pk = ms.game_pk
WHERE ms.year = 2025
```

## Q7: MLBAM.Hits column names (verify hit_angle vs hit_vertical_angle)
```sql
SELECT COLUMN_NAME
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'MLBAM' AND TABLE_NAME = 'Hits'
ORDER BY ORDINAL_POSITION
```

## Q8: Test full percentile pipeline — Chase% at AA, 2025
```sql
SELECT pf.batter_id,
    AVG(CASE WHEN pf.called_strike_chance_mlb < 0.01
        THEN CASE WHEN pf.did_swing = 1 THEN 1.0 ELSE 0.0 END
        ELSE NULL END) AS chase_pct,
    COUNT(*) as n_pitches
FROM MLBAM.Pitch_fx pf
JOIN MLBAM.Schedule ms ON pf.game_pk = ms.game_pk
WHERE ms.level = 'aax' AND ms.year = 2025
GROUP BY pf.batter_id
HAVING COUNT(*) >= 200
ORDER BY chase_pct
```

## Q9: Verify SplitsBat K% percentile (should match Q29 from earlier)
```sql
SELECT player_id,
    CAST(so AS FLOAT) / NULLIF(ab + bb + hbp + sf, 0) AS k_pct,
    PERCENT_RANK() OVER (ORDER BY CAST(so AS FLOAT) / NULLIF(ab + bb + hbp + sf, 0)) AS k_pctl
FROM MLBAM.SplitsBat
WHERE sit_code = 'vl' AND level = 'aax' AND year = 2025
  AND (ab + bb + hbp + sf) >= 50
ORDER BY k_pctl DESC
```

---

## Round 2: Pitch Movement/Velo Columns + Whitaker Debug

## Q10: MLBAM.Pitch_fx — check for movement, velocity, spin, pitch_type columns
```sql
SELECT COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'MLBAM' AND TABLE_NAME = 'Pitch_fx'
  AND (
    COLUMN_NAME LIKE '%break%'
    OR COLUMN_NAME LIKE '%induced%'
    OR COLUMN_NAME LIKE '%pfx%'
    OR COLUMN_NAME LIKE '%release%'
    OR COLUMN_NAME LIKE '%speed%'
    OR COLUMN_NAME LIKE '%velo%'
    OR COLUMN_NAME LIKE '%spin%'
    OR COLUMN_NAME LIKE '%extension%'
    OR COLUMN_NAME LIKE '%pitch_type%'
    OR COLUMN_NAME LIKE '%count%'
    OR COLUMN_NAME LIKE '%balls%'
    OR COLUMN_NAME LIKE '%strikes%'
  )
ORDER BY ORDINAL_POSITION
```

## Q11: Sample movement/velo data for FF pitches (confirm column names + values)
```sql
SELECT TOP 20
    pf.pitcher_id, pf.pitch_type,
    pf.release_speed, pf.pfx_z, pf.pfx_x,
    pf.induced_vert_break, pf.inducedvertbreak,
    pf.spin_rate, pf.extension,
    pf.balls_before, pf.strikes_before
FROM MLBAM.Pitch_fx pf
WHERE pf.year = 2025 AND pf.pitch_type = 'FF'
```
(Some of these column names may not exist — that's the point of running this. Check which ones return data vs error.)

## Q12: Test FF Hop (iVB) league-wide percentile at AA, 2025
```sql
SELECT pf.pitcher_id,
    AVG(pf.pfx_z) AS avg_ivb,
    COUNT(*) AS n_ff
FROM MLBAM.Pitch_fx pf
JOIN MLBAM.Schedule ms ON pf.game_pk = ms.GAME_PK
WHERE ms.SPORT = 'aax' AND pf.year = 2025
  AND pf.pitch_type = 'FF'
GROUP BY pf.pitcher_id
HAVING COUNT(*) >= 50
ORDER BY avg_ivb DESC
```
(If pfx_z doesn't work, try induced_vert_break or inducedvertbreak based on Q10 results)

## Q13: Test FF Velo league-wide percentile at AA, 2025
```sql
SELECT pf.pitcher_id,
    AVG(pf.release_speed) AS avg_ff_velo,
    COUNT(*) AS n_ff
FROM MLBAM.Pitch_fx pf
JOIN MLBAM.Schedule ms ON pf.game_pk = ms.GAME_PK
WHERE ms.SPORT = 'aax' AND pf.year = 2025
  AND pf.pitch_type = 'FF'
GROUP BY pf.pitcher_id
HAVING COUNT(*) >= 50
ORDER BY avg_ff_velo DESC
```

## Q14: Whitaker debug — does groundcontrol_id 138501 have ANY pitch data in 2025?
```sql
SELECT COUNT(*) AS pitch_count,
    MIN(s.sched_date) AS first_date,
    MAX(s.sched_date) AS last_date
FROM Astros.Pitches_View p
JOIN Astros.Schedule_View s ON p.sched_id = s.sched_id
WHERE p.batter_id = 138501
  AND s.sched_date >= '2025-01-01' AND s.sched_date <= '2025-12-31'
```

## Q15: Whitaker — find his actual IDs in Players table
```sql
SELECT groundcontrol_id, ebis_id, first_name, last_name, mlbam_id
FROM Astros.Players
WHERE last_name = 'Whitaker' AND first_name = 'Tyler'
```

## Q16: Whitaker — check if ebis_id 5004974 has data instead
```sql
SELECT COUNT(*) AS pitch_count,
    MIN(s.sched_date) AS first_date,
    MAX(s.sched_date) AS last_date
FROM Astros.Pitches_View p
JOIN Astros.Schedule_View s ON p.sched_id = s.sched_id
WHERE p.batter_id = 5004974
  AND s.sched_date >= '2025-01-01' AND s.sched_date <= '2025-12-31'
```

## Q17: Whitaker — what level did he play at in 2025?
```sql
SELECT s.gc2_level_code, COUNT(*) AS pitches_seen
FROM Astros.Pitches_View p
JOIN Astros.Schedule_View s ON p.sched_id = s.sched_id
WHERE p.batter_id IN (138501, 5004974)
  AND s.sched_date >= '2025-01-01' AND s.sched_date <= '2025-12-31'
GROUP BY s.gc2_level_code
ORDER BY pitches_seen DESC
```
