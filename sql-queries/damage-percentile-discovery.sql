-- =============================================================================
-- DAMAGE PERCENTILE DISCOVERY QUERIES
-- Run on work laptop (gcsql02) to verify MLBAM.Hit_fx columns
-- =============================================================================

-- Q1: Check MLBAM.Hit_fx columns (the VIEW version of MLBAM.Hits)
-- This view should have batter_id + hit_initial_speed + hit_vertical_angle
SELECT COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'MLBAM' AND TABLE_NAME = 'Hit_fx'
ORDER BY ORDINAL_POSITION;

-- Q2: Sample rows from Hit_fx to verify data exists and columns work
SELECT TOP 5 *
FROM MLBAM.Hit_fx
WHERE hit_initial_speed IS NOT NULL
  AND hit_initial_speed < 125;

-- Q3: Test the actual Damage percentile query at AA level
-- Should return one row per batter with their avg Damage%
SELECT TOP 10 hf.batter_id,
    AVG(CASE WHEN hf.hit_initial_speed IS NOT NULL AND hf.hit_vertical_angle IS NOT NULL
             AND hf.hit_initial_speed < 125
        THEN 1.6 * POWER(1.3,
            COS(-0.34) * (hf.hit_initial_speed - 98.0)
            - SIN(-0.34) * (hf.hit_vertical_angle - 27.0)
            - 0.02 * POWER(2 + SIN(-0.34) * (hf.hit_initial_speed - 98.0)
                             + COS(-0.34) * (hf.hit_vertical_angle - 27.0), 2))
        / (7.0 + POWER(1.3,
            COS(-0.34) * (hf.hit_initial_speed - 98.0)
            - SIN(-0.34) * (hf.hit_vertical_angle - 27.0)
            - 0.02 * POWER(2 + SIN(-0.34) * (hf.hit_initial_speed - 98.0)
                             + COS(-0.34) * (hf.hit_vertical_angle - 27.0), 2)))
        ELSE NULL END) AS Damage_Pct,
    COUNT(*) AS BIP
FROM MLBAM.Hit_fx hf
JOIN MLBAM.Schedule ms ON hf.game_pk = ms.GAME_PK
WHERE ms.SPORT = 'aax' AND ms.year = 2025
    AND hf.hit_initial_speed IS NOT NULL
    AND hf.hit_initial_speed < 125
GROUP BY hf.batter_id
HAVING COUNT(*) >= 30
ORDER BY Damage_Pct DESC;

-- Q4: Verify stuff_grade works for pitcher percentiles
SELECT TOP 5 pitcher_id, AVG(stuffrelvel_grade_2080) as avg_stuff
FROM MLBAM.Pitch_fx
WHERE year = 2025 AND stuffrelvel_grade_2080 IS NOT NULL
GROUP BY pitcher_id
HAVING COUNT(*) >= 200;

-- Q5: Count how many batters at AA have enough BIP for Damage percentile
SELECT COUNT(*) AS batters_with_30_bip
FROM (
    SELECT hf.batter_id
    FROM MLBAM.Hit_fx hf
    JOIN MLBAM.Schedule ms ON hf.game_pk = ms.GAME_PK
    WHERE ms.SPORT = 'aax' AND ms.year = 2025
        AND hf.hit_initial_speed IS NOT NULL
        AND hf.hit_initial_speed < 125
    GROUP BY hf.batter_id
    HAVING COUNT(*) >= 30
) sub;
