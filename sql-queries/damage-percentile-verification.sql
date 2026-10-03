-- Damage Percentile Verification Query (CORRECTED filters)
-- Run this at A+ (afa) level to verify percentile calculations
-- Shows where Tyler Whitaker's Damage ranks among all A+ batters
--
-- IMPORTANT FILTERS:
-- - pitch_result IN ('X','D','E'): balls in play only (excludes fouls 'F')
-- - EV < 125 mph: exclude tracking errors
-- - NO launch angle restrictions: Damage formula handles all angles

-- Step 1: Get all qualifying batters at A+ (afa) for 2025 with their avg Damage
WITH BatterDamage AS (
    SELECT
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
    WHERE ms.SPORT = 'afa'  -- A+ High-A
        AND ms.year = 2025
        AND hf.pitch_result IN ('X', 'D', 'E')  -- BIP only, no fouls
        AND hf.hit_initial_speed IS NOT NULL
        AND hf.hit_initial_speed < 125  -- exclude tracking errors
        AND hf.hit_vertical_angle IS NOT NULL
    GROUP BY hf.batter_id
    HAVING COUNT(*) >= 30  -- Minimum 30 batted balls to qualify
)
SELECT
    batter_id,
    batted_balls,
    avg_damage,
    -- Calculate percentile rank (0-100)
    ROUND(PERCENT_RANK() OVER (ORDER BY avg_damage ASC) * 100, 0) AS pctile_low_better,
    ROUND(PERCENT_RANK() OVER (ORDER BY avg_damage DESC) * 100, 0) AS pctile_high_better
FROM BatterDamage
ORDER BY avg_damage DESC;

-- Step 2: Count total qualifying batters (BIP only, no fouls)
SELECT COUNT(*) AS qualifying_batters_afa_2025
FROM (
    SELECT hf.batter_id
    FROM MLBAM.Hit_fx hf
    JOIN MLBAM.Schedule ms ON hf.game_pk = ms.GAME_PK
    WHERE ms.SPORT = 'afa'
        AND ms.year = 2025
        AND hf.pitch_result IN ('X', 'D', 'E')
        AND hf.hit_initial_speed IS NOT NULL
        AND hf.hit_initial_speed < 125
        AND hf.hit_vertical_angle IS NOT NULL
    GROUP BY hf.batter_id
    HAVING COUNT(*) >= 30
) sub;

-- Step 3: Show batters with damage in Tyler's range (0.065 - 0.080)
WITH BatterDamage AS (
    SELECT
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
        AND hf.pitch_result IN ('X', 'D', 'E')
        AND hf.hit_initial_speed IS NOT NULL
        AND hf.hit_initial_speed < 125
        AND hf.hit_vertical_angle IS NOT NULL
    GROUP BY hf.batter_id
    HAVING COUNT(*) >= 30
),
RankedBatters AS (
    SELECT
        batter_id,
        batted_balls,
        avg_damage,
        ROW_NUMBER() OVER (ORDER BY avg_damage DESC) AS rank_desc,
        COUNT(*) OVER () AS total_batters
    FROM BatterDamage
)
SELECT *,
    ROUND(100.0 * (total_batters - rank_desc) / NULLIF(total_batters - 1, 0), 0) AS percentile
FROM RankedBatters
WHERE avg_damage BETWEEN 0.065 AND 0.085  -- Tyler's range (expanded)
ORDER BY avg_damage DESC;

-- Interpretation:
-- If Tyler's Damage = 0.0719 and percentile = 100, it means he's the BEST (highest)
-- among all qualifying A+ batters in 2025. That's actually correct for "higher is better"!
--
-- The color mapping in the PDF:
-- - RED = better (high percentile for higher-is-better metrics like Damage)
-- - BLUE = worse (low percentile)
--
-- So 100th percentile Damage should show a RED bar - that's the expected behavior.
