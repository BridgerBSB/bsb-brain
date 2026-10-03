-- Damage Formula Test
-- Compare SQL formula output to expected Python formula output
-- Run this to verify the formulas match

-- Test Case 1: EV=100, LA=20 (slightly above average)
SELECT
    100.0 AS ev,
    20.0 AS la,
    1.6 * POWER(1.3,
        COS(-0.34) * (100.0 - 98.0)
        - SIN(-0.34) * (20.0 - 27.0)
        - 0.02 * POWER(2 + SIN(-0.34) * (100.0 - 98.0)
                         + COS(-0.34) * (20.0 - 27.0), 2))
    / (7.0 + POWER(1.3,
        COS(-0.34) * (100.0 - 98.0)
        - SIN(-0.34) * (20.0 - 27.0)
        - 0.02 * POWER(2 + SIN(-0.34) * (100.0 - 98.0)
                         + COS(-0.34) * (20.0 - 27.0), 2))) AS sql_damage;

-- Expected Python output for EV=100, LA=20:
-- import numpy as np
-- exp_term = np.cos(-0.34)*(100-98) - np.sin(-0.34)*(20-27) - 0.02*(2 + np.sin(-0.34)*(100-98) + np.cos(-0.34)*(20-27))**2
-- damage = 1.6 * np.power(1.3, exp_term) / (7.0 + np.power(1.3, exp_term))
-- Expected: ~0.2066

-- Test Case 2: Sample of actual Hit_fx rows with EV/LA and calculated damage
SELECT TOP 20
    hf.batter_id,
    hf.hit_initial_speed AS ev,
    hf.hit_vertical_angle AS la,
    1.6 * POWER(1.3,
        COS(-0.34) * (hf.hit_initial_speed - 98.0)
        - SIN(-0.34) * (hf.hit_vertical_angle - 27.0)
        - 0.02 * POWER(2 + SIN(-0.34) * (hf.hit_initial_speed - 98.0)
                         + COS(-0.34) * (hf.hit_vertical_angle - 27.0), 2))
    / (7.0 + POWER(1.3,
        COS(-0.34) * (hf.hit_initial_speed - 98.0)
        - SIN(-0.34) * (hf.hit_vertical_angle - 27.0)
        - 0.02 * POWER(2 + SIN(-0.34) * (hf.hit_initial_speed - 98.0)
                         + COS(-0.34) * (hf.hit_vertical_angle - 27.0), 2))) AS damage
FROM MLBAM.Hit_fx hf
JOIN MLBAM.Schedule ms ON hf.game_pk = ms.GAME_PK
WHERE ms.SPORT = 'afa'
    AND ms.year = 2025
    AND hf.pitch_result IN ('X', 'D', 'E')  -- BIP only, no fouls
    AND hf.hit_initial_speed IS NOT NULL
    AND hf.hit_initial_speed < 125
    AND hf.hit_initial_speed > 90  -- hard hit balls only (for this sample)
    AND hf.hit_vertical_angle IS NOT NULL
ORDER BY damage DESC;

-- Test Case 3: What's the damage range at A+?
SELECT
    MIN(damage) AS min_damage,
    AVG(damage) AS avg_damage,
    MAX(damage) AS max_damage,
    COUNT(*) AS sample_size
FROM (
    SELECT
        1.6 * POWER(1.3,
            COS(-0.34) * (hf.hit_initial_speed - 98.0)
            - SIN(-0.34) * (hf.hit_vertical_angle - 27.0)
            - 0.02 * POWER(2 + SIN(-0.34) * (hf.hit_initial_speed - 98.0)
                             + COS(-0.34) * (hf.hit_vertical_angle - 27.0), 2))
        / (7.0 + POWER(1.3,
            COS(-0.34) * (hf.hit_initial_speed - 98.0)
            - SIN(-0.34) * (hf.hit_vertical_angle - 27.0)
            - 0.02 * POWER(2 + SIN(-0.34) * (hf.hit_initial_speed - 98.0)
                             + COS(-0.34) * (hf.hit_vertical_angle - 27.0), 2))) AS damage
    FROM MLBAM.Hit_fx hf
    JOIN MLBAM.Schedule ms ON hf.game_pk = ms.GAME_PK
    WHERE ms.SPORT = 'afa'
        AND ms.year = 2025
        AND hf.pitch_result IN ('X', 'D', 'E')  -- BIP only, no fouls
        AND hf.hit_initial_speed IS NOT NULL
        AND hf.hit_initial_speed < 125
        AND hf.hit_vertical_angle IS NOT NULL
) sub;

-- Test Case 4: Show top 10 batters by avg damage at A+ 2025
SELECT TOP 10
    hf.batter_id,
    COUNT(*) AS batted_balls,
    AVG(
        1.6 * POWER(1.3,
            COS(-0.34) * (hf.hit_initial_speed - 98.0)
            - SIN(-0.34) * (hf.hit_vertical_angle - 27.0)
            - 0.02 * POWER(2 + SIN(-0.34) * (hf.hit_initial_speed - 98.0)
                             + COS(-0.34) * (hf.hit_vertical_angle - 27.0), 2))
        / (7.0 + POWER(1.3,
            COS(-0.34) * (hf.hit_initial_speed - 98.0)
            - SIN(-0.34) * (hf.hit_vertical_angle - 27.0)
            - 0.02 * POWER(2 + SIN(-0.34) * (hf.hit_initial_speed - 98.0)
                             + COS(-0.34) * (hf.hit_vertical_angle - 27.0), 2)))
    ) AS avg_damage
FROM MLBAM.Hit_fx hf
JOIN MLBAM.Schedule ms ON hf.game_pk = ms.GAME_PK
WHERE ms.SPORT = 'afa'
    AND ms.year = 2025
    AND hf.pitch_result IN ('X', 'D', 'E')  -- BIP only, no fouls
    AND hf.hit_initial_speed IS NOT NULL
    AND hf.hit_initial_speed < 125
    AND hf.hit_vertical_angle IS NOT NULL
GROUP BY hf.batter_id
HAVING COUNT(*) >= 30
ORDER BY avg_damage DESC;

-- WHAT TO CHECK:
-- 1. Test Case 1: Should output ~0.2066. If it outputs something very different, formula is wrong.
-- 2. Test Case 2: Individual rows should range from ~0.02 to ~0.23 depending on EV/LA combo
-- 3. Test Case 3: Check the avg_damage across all balls - should be around 0.06-0.10
-- 4. Test Case 4: Top batters should have avg damage in 0.07-0.10 range typically

-- If Tyler's 0.0719 is from the Python code using Astros.Hits_View, there might be a
-- difference between that table and MLBAM.Hit_fx. Check if they have the same data!

-- Test Case 5: Compare Tyler's data between Astros and MLBAM tables
-- Replace 812456 with Tyler's groundcontrol_id
-- This finds his MLBAM batter_id and shows his avg damage at A+
