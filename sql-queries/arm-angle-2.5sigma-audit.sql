-- Arm Angle 2.5σ Cleanup Audit — exploratory queries
-- ================================================================
-- Purpose: see whether the 2.5σ per-pitcher trim (Step 2 of the
-- arm-angle cleanup spec in .claude/rules/data-cleaning.md) is too
-- aggressive in practice. User suspects we're trimming legit pitches.
--
-- Three result sets:
--   1. Per-pitcher summary (2025 + 2026): mean, σ, min, max, n_above_90,
--      n_outside_2.5σ, % outside.
--   2. League-wide σ distribution — what's "typical" for a pitcher's σ.
--   3. Specific outlier pitches for high-trim pitchers — eyeball the
--      individual reads being dropped.
--
-- All scoped to HOU MiLB pitchers, 2025+2026, R-season only.
-- Brodie formula matches bullpen-report/src/postgame_data.py exactly.
-- ================================================================

-- Explicit DB context — this query joins both GroundControl2.Astros.*
-- and groundcontroltracking.tracking.*, so make sure the session is
-- anchored on GroundControl2 (where two-part `Astros.Pitches_View`
-- references resolve). Without this, you get
-- "Invalid object name 'Astros.Pitches_View'".
USE GroundControl2;
GO


-- =====================================================================
-- COMMON CTE — per-pitch Brodie arm angle (HOU pitchers, 2025+2026, R)
-- Saves to a #temp table so the 3 result sets below run quickly.
-- Run this block ONCE, then run any of the three SELECT blocks below.
-- =====================================================================

IF OBJECT_ID('tempdb..#per_pitch_arm') IS NOT NULL DROP TABLE #per_pitch_arm;

SELECT
    pv.pitcher_id,
    sv.year,
    p.first_name,
    p.last_name,
    p.throws,
    pv.sched_id,
    pv.pitch_id,
    sv.sched_date,
    sv.level_code,
    pv.pitch_type,
    -- Brodie formula (matches postgame_data.py::get_arm_angle)
    -16.4 +
    1.1 * (90.0 -
        CASE WHEN p.throws = 'L' THEN 180.0/PI() ELSE -180.0/PI() END *
        ATN2(pht.pitch_release_pos_x - pos.x_at_pitch_release,
             pht.pitch_release_pos_z -
             SQRT(CASE WHEN
                POWER((CAST(mp.height_feet AS float) + CAST(mp.height_inches AS float)/12.0) * 0.75, 2) -
                POWER((60.5 - pos.y_at_pitch_release) * 0.85, 2) < 0
             THEN 0
             ELSE
                POWER((CAST(mp.height_feet AS float) + CAST(mp.height_inches AS float)/12.0) * 0.75, 2) -
                POWER((60.5 - pos.y_at_pitch_release) * 0.85, 2)
             END)))
    + -0.001 * POWER(90.0 -
        CASE WHEN p.throws = 'L' THEN 180.0/PI() ELSE -180.0/PI() END *
        ATN2(pht.pitch_release_pos_x - pos.x_at_pitch_release,
             pht.pitch_release_pos_z -
             SQRT(CASE WHEN
                POWER((CAST(mp.height_feet AS float) + CAST(mp.height_inches AS float)/12.0) * 0.75, 2) -
                POWER((60.5 - pos.y_at_pitch_release) * 0.85, 2) < 0
             THEN 0
             ELSE
                POWER((CAST(mp.height_feet AS float) + CAST(mp.height_inches AS float)/12.0) * 0.75, 2) -
                POWER((60.5 - pos.y_at_pitch_release) * 0.85, 2)
             END)), 2)
    AS arm_angle
INTO #per_pitch_arm
FROM Astros.Pitches_View pv
JOIN Astros.Schedule_View sv ON pv.sched_id = sv.sched_id
JOIN Astros.Players p ON pv.pitcher_id = p.groundcontrol_id
JOIN MLB_eBis.PP_MASTER pm ON pm.player_id = p.ebis_id
JOIN groundcontroltracking.tracking.pitch_hit_trajectories pht
    ON pht.sched_id = pv.sched_id AND pht.tracking_play_id = pv.pitch_id
JOIN groundcontroltracking.tracking.play_starting_positions pos
    ON pos.sched_id = pv.sched_id AND pos.pitch_id = pv.pitch_id
    AND pos.groundcontrol_id = pv.pitcher_id
JOIN mlbam.players mp ON p.mlbam_id = mp.player_id
WHERE pv.pitch_id > 0
  AND sv.year IN (2025, 2026)
  AND sv.sched_type = 'R'
  AND sv.level_code NOT IN ('nae','hsb','jcb','win','int','sum','bbc','min','ind')
  AND pm.ORG_LK = 'HOU'
  AND pm.POSITION_LK IN ('RHS','RHR','LHS','LHR');

CREATE INDEX ix_ppa_pitcher_year ON #per_pitch_arm (pitcher_id, year);


-- =====================================================================
-- RESULT 1 — Per-pitcher cleanup summary (the main view)
-- For each pitcher × year:
--   n_total       = total pitches with arm-angle data
--   n_above_90    = how many step 1 caps (Hawkeye glitches)
--   aa_mean/std   = computed AFTER step 1 (so trim baseline is clean)
--   aa_min/max    = absolute range of his post-step-1 arm angles
--   n_outside_2.5σ = how many step 2 would trim
--   pct_outside    = % of his data step 2 would remove
--
-- Only shows pitchers with >= 20 post-step-1 pitches in the year (the
-- min threshold for step 2 in clean_arm_angle).
-- Sort: highest % trimmed first — the pitchers most affected by step 2.
-- =====================================================================

WITH post_step1 AS (
    SELECT pitcher_id, year, first_name, last_name, throws,
           arm_angle,
           CASE WHEN arm_angle <= 90 THEN arm_angle END AS aa_capped
    FROM #per_pitch_arm
),
with_stats AS (
    SELECT *,
        AVG(aa_capped)   OVER (PARTITION BY pitcher_id, year) AS aa_mean,
        STDEV(aa_capped) OVER (PARTITION BY pitcher_id, year) AS aa_std,
        COUNT(aa_capped) OVER (PARTITION BY pitcher_id, year) AS n_post_step1
    FROM post_step1
)
SELECT
    pitcher_id,
    first_name + ' ' + last_name AS name,
    throws,
    year,
    COUNT(*) AS n_total,
    SUM(CASE WHEN arm_angle > 90 THEN 1 ELSE 0 END)   AS n_above_90,
    MIN(n_post_step1)                                 AS n_post_step1,
    CAST(MIN(aa_mean) AS DECIMAL(6,2))                AS aa_mean,
    CAST(MIN(aa_std)  AS DECIMAL(6,2))                AS aa_std,
    CAST(MIN(aa_capped) AS DECIMAL(6,2))              AS aa_min,
    CAST(MAX(aa_capped) AS DECIMAL(6,2))              AS aa_max,
    SUM(CASE
        WHEN aa_capped IS NOT NULL
         AND aa_std IS NOT NULL
         AND ABS(aa_capped - aa_mean) > 2.5 * aa_std
        THEN 1 ELSE 0 END) AS n_outside_2_5sigma,
    CAST(100.0 * SUM(CASE
        WHEN aa_capped IS NOT NULL
         AND aa_std IS NOT NULL
         AND ABS(aa_capped - aa_mean) > 2.5 * aa_std
        THEN 1 ELSE 0 END) / NULLIF(MIN(n_post_step1), 0) AS DECIMAL(5,2))
        AS pct_outside_2_5sigma,
    -- What the per-pitcher window looks like
    CAST(MIN(aa_mean) - 2.5 * MIN(aa_std) AS DECIMAL(6,2)) AS keep_lo_2_5sigma,
    CAST(MIN(aa_mean) + 2.5 * MIN(aa_std) AS DECIMAL(6,2)) AS keep_hi_2_5sigma
FROM with_stats
GROUP BY pitcher_id, year, first_name, last_name, throws
HAVING MIN(n_post_step1) >= 20
ORDER BY pct_outside_2_5sigma DESC, n_total DESC;


-- =====================================================================
-- RESULT 2 — League σ distribution
-- What's a "typical" arm-angle σ for an Astros pitcher? Helps judge
-- whether 2.5σ * (typical σ) is a reasonable absolute window.
-- =====================================================================

WITH pitcher_std AS (
    SELECT pitcher_id, year,
        STDEV(CASE WHEN arm_angle <= 90 THEN arm_angle END) AS aa_std,
        COUNT(CASE WHEN arm_angle <= 90 THEN 1 END)         AS n_post_step1
    FROM #per_pitch_arm
    GROUP BY pitcher_id, year
    HAVING COUNT(CASE WHEN arm_angle <= 90 THEN 1 END) >= 20
)
SELECT
    year,
    COUNT(*) AS n_pitchers,
    CAST(AVG(aa_std) AS DECIMAL(5,2))    AS avg_std,
    CAST(MIN(aa_std) AS DECIMAL(5,2))    AS min_std,
    CAST(MAX(aa_std) AS DECIMAL(5,2))    AS max_std,
    CAST(PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY aa_std)
         OVER (PARTITION BY year) AS DECIMAL(5,2)) AS p25_std,
    CAST(PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY aa_std)
         OVER (PARTITION BY year) AS DECIMAL(5,2)) AS p50_std,
    CAST(PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY aa_std)
         OVER (PARTITION BY year) AS DECIMAL(5,2)) AS p75_std,
    CAST(PERCENTILE_CONT(0.90) WITHIN GROUP (ORDER BY aa_std)
         OVER (PARTITION BY year) AS DECIMAL(5,2)) AS p90_std
FROM pitcher_std
GROUP BY year, aa_std
ORDER BY year;


-- =====================================================================
-- RESULT 3 — Outlier pitches for top 5 most-trimmed pitchers
-- For each high-trim pitcher, show the actual pitches step 2 would drop.
-- Lets you eyeball whether they look like real outliers (slip pitch,
-- pickoff weirdness) or legit variance (e.g. dropping down on a CH).
-- =====================================================================

WITH post_step1 AS (
    SELECT *, CASE WHEN arm_angle <= 90 THEN arm_angle END AS aa_capped
    FROM #per_pitch_arm
),
with_stats AS (
    SELECT *,
        AVG(aa_capped)   OVER (PARTITION BY pitcher_id, year) AS aa_mean,
        STDEV(aa_capped) OVER (PARTITION BY pitcher_id, year) AS aa_std,
        COUNT(aa_capped) OVER (PARTITION BY pitcher_id, year) AS n_post_step1
    FROM post_step1
),
pitcher_trim_pct AS (
    SELECT pitcher_id, year, MIN(first_name + ' ' + last_name) AS name,
        MIN(aa_mean) AS aa_mean, MIN(aa_std) AS aa_std,
        MIN(n_post_step1) AS n,
        CAST(100.0 * SUM(CASE
            WHEN aa_capped IS NOT NULL AND aa_std IS NOT NULL
             AND ABS(aa_capped - aa_mean) > 2.5 * aa_std
            THEN 1 ELSE 0 END) / NULLIF(MIN(n_post_step1), 0) AS DECIMAL(5,2)) AS pct_trim
    FROM with_stats
    GROUP BY pitcher_id, year
    HAVING MIN(n_post_step1) >= 20
),
top_5_trimmed AS (
    SELECT TOP 5 pitcher_id, year FROM pitcher_trim_pct
    ORDER BY pct_trim DESC
)
SELECT
    ws.first_name + ' ' + ws.last_name AS name,
    ws.year,
    ws.sched_date,
    ws.level_code,
    ws.pitch_type,
    CAST(ws.arm_angle AS DECIMAL(6,2)) AS arm_angle,
    CAST(ws.aa_mean AS DECIMAL(6,2))   AS pitcher_mean,
    CAST(ws.aa_std  AS DECIMAL(5,2))   AS pitcher_std,
    CAST((ws.aa_capped - ws.aa_mean) / NULLIF(ws.aa_std, 0)
         AS DECIMAL(5,2)) AS z_score,
    CASE
        WHEN ws.arm_angle > 90 THEN 'STEP 1 CAP'
        WHEN ws.aa_std IS NOT NULL
         AND ABS(ws.aa_capped - ws.aa_mean) > 2.5 * ws.aa_std
        THEN 'STEP 2 TRIM'
        ELSE 'KEEP'
    END AS cleanup_action
FROM with_stats ws
JOIN top_5_trimmed t5 ON t5.pitcher_id = ws.pitcher_id AND t5.year = ws.year
WHERE ws.arm_angle > 90
   OR (ws.aa_std IS NOT NULL
       AND ABS(ws.aa_capped - ws.aa_mean) > 2.5 * ws.aa_std)
ORDER BY ws.pitcher_id, ws.year, ws.sched_date, ws.pitch_id;


-- =====================================================================
-- Cleanup
-- =====================================================================
-- DROP TABLE #per_pitch_arm;   -- uncomment when done exploring
