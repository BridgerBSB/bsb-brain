-- ===========================================================================
-- Pitcher InZ% by Release-Height Bucket — 2025 vs 2026 + Total
-- ===========================================================================
-- Use case: mechanical analysis. Bucket a pitcher's pitches by release_z
-- (release height in ft) in 0.2-ft increments, compute InZ% (AVG of
-- called_strike_chance_mlb) per bucket per year.
--
-- Default range: 5.0–7.0 ft (covers most over-the-top to high-3/4 RHPs).
-- Pitchers with lower slots will land in [<5.0]; outliers above land in [7.0+].
-- If you need a wider/tighter range for a submarine / very tall pitcher,
-- copy the CASE expressions and adjust thresholds.
--
-- Three result rows: 2025, 2026, Total. 12 bucket columns + pitch count.
--
-- Swap @pid for any pitcher's groundcontrol_id.
-- Joan Ogando = 212631 (default)
-- ===========================================================================

DECLARE @pid INT = 212631;

WITH base AS (
    SELECT
        CAST(YEAR(sv.sched_date) AS VARCHAR(10)) AS yr_lbl,
        pv.release_z AS rh,
        pv.called_strike_chance_mlb AS csc
    FROM Astros.Pitches_View pv
    JOIN Astros.Schedule_View sv ON pv.sched_id = sv.sched_id
    WHERE pv.pitcher_id = @pid
      AND sv.sched_type = 'R'
      AND pv.pitch_id > 0
      AND YEAR(sv.sched_date) IN (2025, 2026)
      AND pv.release_z IS NOT NULL
      AND pv.called_strike_chance_mlb IS NOT NULL
),
per_yr AS (
    SELECT yr_lbl, rh, csc FROM base
    UNION ALL
    SELECT 'Total' AS yr_lbl, rh, csc FROM base
)
SELECT
    [Year] = yr_lbl,
    [N]    = COUNT(*),
    [<5.0]    = ROUND(100.0 * AVG(CASE WHEN rh <  5.0 THEN csc END), 1),
    [5.0-5.2] = ROUND(100.0 * AVG(CASE WHEN rh >= 5.0 AND rh < 5.2 THEN csc END), 1),
    [5.2-5.4] = ROUND(100.0 * AVG(CASE WHEN rh >= 5.2 AND rh < 5.4 THEN csc END), 1),
    [5.4-5.6] = ROUND(100.0 * AVG(CASE WHEN rh >= 5.4 AND rh < 5.6 THEN csc END), 1),
    [5.6-5.8] = ROUND(100.0 * AVG(CASE WHEN rh >= 5.6 AND rh < 5.8 THEN csc END), 1),
    [5.8-6.0] = ROUND(100.0 * AVG(CASE WHEN rh >= 5.8 AND rh < 6.0 THEN csc END), 1),
    [6.0-6.2] = ROUND(100.0 * AVG(CASE WHEN rh >= 6.0 AND rh < 6.2 THEN csc END), 1),
    [6.2-6.4] = ROUND(100.0 * AVG(CASE WHEN rh >= 6.2 AND rh < 6.4 THEN csc END), 1),
    [6.4-6.6] = ROUND(100.0 * AVG(CASE WHEN rh >= 6.4 AND rh < 6.6 THEN csc END), 1),
    [6.6-6.8] = ROUND(100.0 * AVG(CASE WHEN rh >= 6.6 AND rh < 6.8 THEN csc END), 1),
    [6.8-7.0] = ROUND(100.0 * AVG(CASE WHEN rh >= 6.8 AND rh < 7.0 THEN csc END), 1),
    [7.0+]    = ROUND(100.0 * AVG(CASE WHEN rh >= 7.0 THEN csc END), 1)
FROM per_yr
GROUP BY yr_lbl
ORDER BY CASE WHEN yr_lbl = 'Total' THEN 2 ELSE 1 END, yr_lbl;

-- ===========================================================================
-- N counts per bucket (sanity-check sparse buckets) — uncomment to also run
-- ===========================================================================
-- SELECT
--     [Year] = yr_lbl,
--     [n_<5.0]    = SUM(CASE WHEN rh <  5.0 THEN 1 ELSE 0 END),
--     [n_5.0-5.2] = SUM(CASE WHEN rh >= 5.0 AND rh < 5.2 THEN 1 ELSE 0 END),
--     [n_5.2-5.4] = SUM(CASE WHEN rh >= 5.2 AND rh < 5.4 THEN 1 ELSE 0 END),
--     [n_5.4-5.6] = SUM(CASE WHEN rh >= 5.4 AND rh < 5.6 THEN 1 ELSE 0 END),
--     [n_5.6-5.8] = SUM(CASE WHEN rh >= 5.6 AND rh < 5.8 THEN 1 ELSE 0 END),
--     [n_5.8-6.0] = SUM(CASE WHEN rh >= 5.8 AND rh < 6.0 THEN 1 ELSE 0 END),
--     [n_6.0-6.2] = SUM(CASE WHEN rh >= 6.0 AND rh < 6.2 THEN 1 ELSE 0 END),
--     [n_6.2-6.4] = SUM(CASE WHEN rh >= 6.2 AND rh < 6.4 THEN 1 ELSE 0 END),
--     [n_6.4-6.6] = SUM(CASE WHEN rh >= 6.4 AND rh < 6.6 THEN 1 ELSE 0 END),
--     [n_6.6-6.8] = SUM(CASE WHEN rh >= 6.6 AND rh < 6.8 THEN 1 ELSE 0 END),
--     [n_6.8-7.0] = SUM(CASE WHEN rh >= 6.8 AND rh < 7.0 THEN 1 ELSE 0 END),
--     [n_7.0+]    = SUM(CASE WHEN rh >= 7.0 THEN 1 ELSE 0 END)
-- FROM per_yr
-- GROUP BY yr_lbl
-- ORDER BY CASE WHEN yr_lbl = 'Total' THEN 2 ELSE 1 END, yr_lbl;
