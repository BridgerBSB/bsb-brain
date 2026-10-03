-- ===========================================================================
-- Pitcher InZ% by Release-Side Bucket — 2025 vs 2026 + Total
-- ===========================================================================
-- Use case: mechanical analysis. Bucket a pitcher's pitches by |release_x|
-- in 0.5-ft increments (0.0–0.5, 0.5–1.0, …, 3.0–3.5, 3.5+), compute InZ%
-- (AVG of called_strike_chance_mlb) per bucket per year.
--
-- Three result rows: 2025, 2026, Total. Eight bucket columns + pitch count.
--
-- Swap @pid for any pitcher's groundcontrol_id.
-- Joan Ogando = 212631 (default)
-- ===========================================================================

DECLARE @pid INT = 212631;

WITH base AS (
    SELECT
        CAST(YEAR(sv.sched_date) AS VARCHAR(10)) AS yr_lbl,
        ABS(pv.release_x) AS rs,
        pv.called_strike_chance_mlb AS csc
    FROM Astros.Pitches_View pv
    JOIN Astros.Schedule_View sv ON pv.sched_id = sv.sched_id
    WHERE pv.pitcher_id = @pid
      AND sv.sched_type = 'R'
      AND pv.pitch_id > 0
      AND YEAR(sv.sched_date) IN (2025, 2026)
      AND pv.release_x IS NOT NULL
      AND pv.called_strike_chance_mlb IS NOT NULL
),
per_yr AS (
    SELECT yr_lbl, rs, csc FROM base
    UNION ALL
    SELECT 'Total' AS yr_lbl, rs, csc FROM base
)
SELECT
    [Year] = yr_lbl,
    [N]    = COUNT(*),
    [0.0-0.5] = ROUND(100.0 * AVG(CASE WHEN rs <  0.5 THEN csc END), 1),
    [0.5-1.0] = ROUND(100.0 * AVG(CASE WHEN rs >= 0.5 AND rs < 1.0 THEN csc END), 1),
    [1.0-1.5] = ROUND(100.0 * AVG(CASE WHEN rs >= 1.0 AND rs < 1.5 THEN csc END), 1),
    [1.5-2.0] = ROUND(100.0 * AVG(CASE WHEN rs >= 1.5 AND rs < 2.0 THEN csc END), 1),
    [2.0-2.5] = ROUND(100.0 * AVG(CASE WHEN rs >= 2.0 AND rs < 2.5 THEN csc END), 1),
    [2.5-3.0] = ROUND(100.0 * AVG(CASE WHEN rs >= 2.5 AND rs < 3.0 THEN csc END), 1),
    [3.0-3.5] = ROUND(100.0 * AVG(CASE WHEN rs >= 3.0 AND rs < 3.5 THEN csc END), 1),
    [3.5+]    = ROUND(100.0 * AVG(CASE WHEN rs >= 3.5 THEN csc END), 1)
FROM per_yr
GROUP BY yr_lbl
ORDER BY CASE WHEN yr_lbl = 'Total' THEN 2 ELSE 1 END, yr_lbl;

-- ===========================================================================
-- N counts per bucket (sanity-check sparse buckets) — uncomment to also run
-- ===========================================================================
-- SELECT
--     [Year] = yr_lbl,
--     [n_0.0-0.5] = SUM(CASE WHEN rs <  0.5 THEN 1 ELSE 0 END),
--     [n_0.5-1.0] = SUM(CASE WHEN rs >= 0.5 AND rs < 1.0 THEN 1 ELSE 0 END),
--     [n_1.0-1.5] = SUM(CASE WHEN rs >= 1.0 AND rs < 1.5 THEN 1 ELSE 0 END),
--     [n_1.5-2.0] = SUM(CASE WHEN rs >= 1.5 AND rs < 2.0 THEN 1 ELSE 0 END),
--     [n_2.0-2.5] = SUM(CASE WHEN rs >= 2.0 AND rs < 2.5 THEN 1 ELSE 0 END),
--     [n_2.5-3.0] = SUM(CASE WHEN rs >= 2.5 AND rs < 3.0 THEN 1 ELSE 0 END),
--     [n_3.0-3.5] = SUM(CASE WHEN rs >= 3.0 AND rs < 3.5 THEN 1 ELSE 0 END),
--     [n_3.5+]    = SUM(CASE WHEN rs >= 3.5 THEN 1 ELSE 0 END)
-- FROM per_yr
-- GROUP BY yr_lbl
-- ORDER BY CASE WHEN yr_lbl = 'Total' THEN 2 ELSE 1 END, yr_lbl;
