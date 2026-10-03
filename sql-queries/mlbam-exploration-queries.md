# MLBAM Table Exploration Queries

Purpose: Discover MLBAM table structures for league-wide percentile calculations.
Run on work laptop against gcsql02 / GroundControl2 (Windows Auth).

---

## Why MLBAM Tables?
- `Astros.*` tables = Astros org only (detailed tracking)
- `MLBAM.*` tables = ALL 30 MLB teams (league-wide data)
- Percentiles need league-wide pool by level — must come from MLBAM tables
- Join: `Astros.Players.mlbam_id → MLBAM.*.player_id`
- Join: `Schedule_View.mlbam_game_pk → MLBAM.*.game_pk`

---

## Q1: List all MLBAM tables
```sql
SELECT TABLE_NAME
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'MLBAM'
ORDER BY TABLE_NAME
```

## Q2: MLBAM.Hits columns (image confirmed table exists)
```sql
SELECT COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'MLBAM' AND TABLE_NAME = 'Hits'
ORDER BY ORDINAL_POSITION
```

## Q3: MLBAM.Pitches columns
```sql
SELECT COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'MLBAM' AND TABLE_NAME = 'Pitches'
ORDER BY ORDINAL_POSITION
```

## Q4: MLBAM.Hits sample data (check for player_id, game_pk, exit_velocity, launch_angle)
```sql
SELECT TOP 10 * FROM MLBAM.Hits
```

## Q5: MLBAM.Pitches sample data (check for player_id, game_pk, pitch metrics)
```sql
SELECT TOP 10 * FROM MLBAM.Pitches
```

## Q6: Check if MLBAM has game-level batting stats (gamelog_batting)
```sql
SELECT COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'MLBAM' AND TABLE_NAME = 'gamelog_batting'
ORDER BY ORDINAL_POSITION
```

## Q7: Check if MLBAM has game-level pitching stats (gamelog_pitching)
```sql
SELECT COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'MLBAM' AND TABLE_NAME = 'gamelog_pitching'
ORDER BY ORDINAL_POSITION
```

## Q8: MLBAM player ID mapping — confirm join works
```sql
-- Freuddy Batista: groundcontrol_id=78084, mlbam_id should be in Astros.Players
SELECT groundcontrol_id, mlbam_id, first_name, last_name
FROM Astros.Players
WHERE groundcontrol_id = 78084
```

## Q9: Test MLBAM.Hits join with Astros player
```sql
-- Use mlbam_id from Q8 result
SELECT TOP 10 h.*
FROM MLBAM.Hits h
WHERE h.player_id = (SELECT mlbam_id FROM Astros.Players WHERE groundcontrol_id = 78084)
```

## Q10: Check for MLBAM aggregate/percentile tables
```sql
-- Look for any pre-computed percentile or season-level tables
SELECT TABLE_NAME
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'MLBAM'
  AND (TABLE_NAME LIKE '%percentile%'
    OR TABLE_NAME LIKE '%season%'
    OR TABLE_NAME LIKE '%aggregate%'
    OR TABLE_NAME LIKE '%rank%'
    OR TABLE_NAME LIKE '%leader%')
ORDER BY TABLE_NAME
```

## Q11: Check for level/league info in MLBAM tables
```sql
-- Need to know if MLBAM tables have level_code or league for filtering by level
SELECT TOP 5 *
FROM MLBAM.Hits h
JOIN Astros.Schedule_View sv ON h.game_pk = sv.mlbam_game_pk
WHERE sv.level_code = 'AAA'
```

## Q12: Count MLBAM.Hits rows by year (gauge data volume)
```sql
SELECT
    sv.year,
    COUNT(*) AS n_hits
FROM MLBAM.Hits h
JOIN Astros.Schedule_View sv ON h.game_pk = sv.mlbam_game_pk
GROUP BY sv.year
ORDER BY sv.year DESC
```

---

## Round 2: Bat Speed & Swing Data Exploration

### Q13: Hitter_Swing_Type_Breakdown columns (likely has bat speed)
```sql
SELECT COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'MLBAM' AND TABLE_NAME = 'Hitter_Swing_Type_Breakdown'
ORDER BY ORDINAL_POSITION
```

### Q14: Hitter_Swing_Type_Breakdown_MILB columns (MiLB bat speed)
```sql
SELECT COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'MLBAM' AND TABLE_NAME = 'Hitter_Swing_Type_Breakdown_MILB'
ORDER BY ORDINAL_POSITION
```

### Q15: Sample data from Hitter_Swing_Type_Breakdown
```sql
SELECT TOP 10 * FROM MLBAM.Hitter_Swing_Type_Breakdown
```

### Q16: Sample data from Hitter_Swing_Type_Breakdown_MILB
```sql
SELECT TOP 10 * FROM MLBAM.Hitter_Swing_Type_Breakdown_MILB
```

### Q17: Hit_fx columns (may have bat speed or swing tracking)
```sql
SELECT COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'MLBAM' AND TABLE_NAME = 'Hit_fx'
ORDER BY ORDINAL_POSITION
```

### Q18: Test Freuddy in MILB swing breakdown
```sql
SELECT TOP 10 *
FROM MLBAM.Hitter_Swing_Type_Breakdown_MILB
WHERE player_id = 673945
```

### Q19: YTD_Catcher_Defense columns (for catcher percentiles)
```sql
SELECT COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'MLBAM' AND TABLE_NAME = 'YTD_Catcher_Defense'
ORDER BY ORDINAL_POSITION
```

### Q20: Production_Percentile — full column list and sample
```sql
SELECT COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'MLBAM' AND TABLE_NAME = 'Production_Percentile'
ORDER BY ORDINAL_POSITION

-- Freuddy's history
SELECT * FROM MLBAM.Production_Percentile WHERE groundcontrol_id = 78084 ORDER BY season DESC
```

---

## Round 3: Platoon Split Tables (for platoon-specific percentiles)

### Q21: SplitsBat columns (likely has platoon splits pre-computed)
```sql
SELECT COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'MLBAM' AND TABLE_NAME = 'SplitsBat'
ORDER BY ORDINAL_POSITION
```

### Q22: SplitsBat sample data
```sql
SELECT TOP 20 * FROM MLBAM.SplitsBat WHERE player_id = 673945
```

### Q23: SplitsPit columns
```sql
SELECT COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'MLBAM' AND TABLE_NAME = 'SplitsPit'
ORDER BY ORDINAL_POSITION
```

### Q24: LR_Split_OPS_Batting columns and sample
```sql
SELECT COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'MLBAM' AND TABLE_NAME = 'LR_Split_OPS_Batting'
ORDER BY ORDINAL_POSITION

SELECT TOP 10 * FROM MLBAM.LR_Split_OPS_Batting WHERE player_id = 673945
```

### Q25: LR_Split_OPS_Pitching columns and sample
```sql
SELECT COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'MLBAM' AND TABLE_NAME = 'LR_Split_OPS_Pitching'
ORDER BY ORDINAL_POSITION
```

### Q26: Split_IDs lookup (what split types exist)
```sql
SELECT * FROM MLBAM.Split_IDs
```

---

## Round 4: Verify MLBAM.Pitches has CSC / swing fields (for league-wide Zcon/Oswing/Chase)

### Q27: Check if MLBAM.Pitches has called_strike_chance or zone probability columns
```sql
SELECT COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'MLBAM' AND TABLE_NAME = 'Pitches'
  AND (COLUMN_NAME LIKE '%strike%' OR COLUMN_NAME LIKE '%zone%'
    OR COLUMN_NAME LIKE '%swing%' OR COLUMN_NAME LIKE '%csc%'
    OR COLUMN_NAME LIKE '%chase%' OR COLUMN_NAME LIKE '%contact%')
ORDER BY ORDINAL_POSITION
```

### Q28: Check MLBAM.Pitches for swing/result fields
```sql
SELECT TOP 20
    pitch_type, initial_speed, spin_rate,
    -- Check if these columns exist:
    -- did_swing, pitch_result_id, called_strike_chance_mlb
    *
FROM MLBAM.Pitches
WHERE game_pk IN (SELECT TOP 1 mlbam_game_pk FROM Astros.Schedule_View WHERE year = 2025 AND level_code = 'AAA')
```

### Q29: SplitsBat platoon percentile test (K% vs LHP at AA, 2025)
```sql
SELECT
    player_id,
    CAST(so AS FLOAT) / NULLIF(ab + bb + hbp + sf, 0) * 100 AS k_pct_vs_l,
    PERCENT_RANK() OVER (ORDER BY CAST(so AS FLOAT) / NULLIF(ab + bb + hbp + sf, 0)) AS k_pctl
FROM MLBAM.SplitsBat
WHERE sit_code = 'vl' AND level = 'aax' AND year = 2025
  AND (ab + bb + hbp + sf) >= 50
ORDER BY k_pctl DESC
```

---

## After Running These Queries

Once we know the MLBAM table structures, we can build percentile queries like:
```sql
-- Example: K% percentile for all hitters at a given level
SELECT
    player_id,
    k_pct,
    PERCENT_RANK() OVER (ORDER BY k_pct) AS k_pct_percentile
FROM (
    -- aggregate K% per player from MLBAM tables
) sub
WHERE level_code = @level
  AND year = @year
```

Key decisions after exploration:
1. **Pre-compute nightly** — run percentile calcs in a batch job, store results
2. **Cache in Streamlit** — compute on first load per level/year, cache with `@st.cache_data`
3. **Use MLBAM aggregate tables** — if pre-computed tables exist, use directly (fastest)

Recommendation: Option 2 (Streamlit cache) for MVP, migrate to option 1 for production.
