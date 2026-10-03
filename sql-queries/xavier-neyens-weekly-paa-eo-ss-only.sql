-- ==========================================================================
-- Xavier Neyens (gc_id 244959) — Weekly PAA/EO at SS ONLY
-- ==========================================================================
-- Variant of xavier-neyens-weekly-paa-eo.sql scoped to ONLY shortstop
-- plays (pos_id = 6). One row per ISO Mon-Sun week starting 2026-03-28.
--
-- Difference vs the parent file:
--   - pos_id IN (3,4,5,6,7,8,9)  ->  pos_id = 6
--   - No React/IF join (this is a single-position query)
--
-- CAVEATS
--   - Weeks where Neyens played 2B/3B/1B/OF but NOT SS will not appear.
--   - Small-sample noise is real. comp_plays surfaced so you can read
--     past thin weeks (1-3 plays).
--
-- Canonical PAA/EO formula mirrored from:
--   intangibles/src/paa_eo_matrix_data.py::_FIELDING_PER_LEVEL_QUERY
-- ==========================================================================

SET DATEFIRST 1;   -- Mon = 1, so DATEPART(weekday, d) returns 1..7 Mon..Sun

DECLARE @season     INT  = 2026;
DECLARE @gc_id      INT  = 244959;          -- Xavier Neyens
DECLARE @start_date DATE = '2026-03-28';    -- per ask
DECLARE @pos_id     INT  = 6;               -- SS only

WITH per_week_pos AS (
    SELECT
        -- Monday of the ISO week containing this game's sched_date
        DATEADD(day,
            -(DATEPART(weekday, sv.sched_date) - 1),
            CAST(sv.sched_date AS DATE))                        AS week_start,
        dcbp.pos_id,
        SUM(CAST(dcbp.competitive_play AS int))                 AS comp_plays,
        SUM(dcbp.out_prob) * AVG(paaeo.eo_scalar)               AS expected_outs,
        (SUM(dcbp.paa) / NULLIF(SUM(dcbp.out_prob), 0)
            - AVG(paaeo.paaeo_offset))
            * SUM(dcbp.out_prob) * AVG(paaeo.eo_scalar)         AS paa_cal
    FROM Astros.Defense_Combined_By_Pos dcbp
    JOIN Astros.Schedule_View sv
        ON dcbp.sched_id = sv.sched_id
    JOIN Astros.Events_View ev
        ON dcbp.sched_id = ev.sched_id
       AND dcbp.event_id = ev.event_id
    LEFT JOIN guts.PAA_EO_Position_Calibration paaeo
        ON paaeo.pos_id     = dcbp.pos_id
       AND paaeo.positional = dcbp.positional
       AND paaeo.season     = @season
    WHERE dcbp.groundcontrol_id = @gc_id
      AND dcbp.pos_id = @pos_id              -- <<< SS only
      AND (sv.level_code IN ('aaa', 'aax', 'afa', 'afx')
           OR sv.gc2_level_code IN ('dsl', 'rok'))
      AND YEAR(sv.sched_date) = @season
      AND sv.sched_type = 'R'
      AND CAST(sv.sched_date AS DATE) >= @start_date
    GROUP BY
        DATEADD(day,
            -(DATEPART(weekday, sv.sched_date) - 1),
            CAST(sv.sched_date AS DATE)),
        dcbp.pos_id,
        dcbp.positional
    HAVING SUM(dcbp.out_prob) > 0
)
SELECT
    week_start,
    DATEADD(day, 6, week_start)                                 AS week_end,
    SUM(comp_plays)                                             AS comp_plays_ss,
    CASE WHEN SUM(expected_outs) > 0
         THEN CAST(SUM(paa_cal) / SUM(expected_outs) AS DECIMAL(6,3))
         ELSE NULL
    END                                                         AS paa_eo_ss
FROM per_week_pos
GROUP BY week_start
ORDER BY week_start;
