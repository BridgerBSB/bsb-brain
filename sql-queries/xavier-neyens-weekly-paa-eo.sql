-- ==========================================================================
-- Xavier Neyens (gc_id 244959) — Weekly PAA/EO + React (P25)
-- ==========================================================================
-- One-off ask: week-by-week PAA/EO + Reaction Time starting wk of 2026-03-28.
--
-- Shape: ONE row per ISO week (Mon-Sun). PAA/EO pooled across every
-- defensive position he played that week; React (P25 of reaction_time) is
-- IF-only and computed per-week from TDM with the canonical Tier 1 6-term
-- competitive-play gate. A FULL OUTER JOIN unions the two so weeks with
-- only one side still appear.
--
-- CAVEATS — IMPORTANT
-- 1. React is IF-only (pos_ids 3-6). PAA/EO spans 3-9 (IF + OF). Weeks
--    where Neyens played OF have PAA/EO populated but React NULL.
-- 2. Tier 1 gate is the canonical 6-term mix (DCBP.out_made +
--    DCBP.CP + DCBP.CT + TDM.CP + TDM.CT + arm>=70) per rules/fielding.md.
--    Different sample than PAA/EO (which uses out_prob > 0 on DCBP only).
-- 3. HawkEye sparsity. TDM only populates at HawkEye venues — ~50%
--    sparse at non-HawkEye MiLB stops per rules/tracking-schema.md.
--    React-NULL week could be coverage gap, not no-play.
-- 4. P25 from 2-8 plays per week is jittery by definition. n_react column
--    surfaces the sample so you can read past the noise.
--
-- Canonical sources mirrored:
--   PAA/EO: intangibles/src/paa_eo_matrix_data.py::_FIELDING_PER_LEVEL_QUERY
--   React:  intangibles/src/fielding_tracker_data.py::_TRACKING_AGG_QUERY
--           (lines 475-583, IF arm_floor=70)
-- ==========================================================================

SET DATEFIRST 1;   -- Mon = 1, so DATEPART(weekday, d) returns 1..7 Mon..Sun

DECLARE @season     INT  = 2026;
DECLARE @gc_id      INT  = 244959;          -- Xavier Neyens
DECLARE @start_date DATE = '2026-03-28';    -- per ask
DECLARE @arm_lo     INT  = 70;              -- IF arm floor (fielding_base.py)

-- ----- PAA/EO: per-(week, pos_id) then SUM across positions ---------------
WITH paa_per_week_pos AS (
    SELECT
        DATEADD(day,
            -(DATEPART(weekday, sv.sched_date) - 1),
            CAST(sv.sched_date AS DATE))                        AS week_start,
        dcbp.pos_id,
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
      AND dcbp.pos_id IN (3, 4, 5, 6, 7, 8, 9)   -- 1B/2B/3B/SS/LF/CF/RF
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
),
paa_weekly AS (
    SELECT
        week_start,
        CASE WHEN SUM(expected_outs) > 0
             THEN SUM(paa_cal) / SUM(expected_outs)
             ELSE NULL
        END AS paa_eo
    FROM paa_per_week_pos
    GROUP BY week_start
),

-- ----- React: IF-only, Tier 1 6-term gate, P25 per ISO week --------------
react_base AS (
    SELECT
        DATEADD(day,
            -(DATEPART(weekday, sv.sched_date) - 1),
            CAST(sv.sched_date AS DATE))                        AS week_start,
        tdm.reaction_4mph                                       AS reaction_time
    FROM Astros.Tracking_Defensive_Metrics tdm
    JOIN Astros.Schedule_View sv
        ON tdm.sched_id = sv.sched_id
    JOIN Astros.Events_View ev
        ON tdm.sched_id = ev.sched_id
       AND tdm.event_id = ev.event_id
    LEFT JOIN Astros.Defense_Combined_By_Pos dcbp
        ON tdm.sched_id = dcbp.sched_id
       AND tdm.event_id = dcbp.event_id
       AND tdm.pos_id = dcbp.pos_id
       AND tdm.groundcontrol_id = dcbp.groundcontrol_id
    WHERE tdm.groundcontrol_id = @gc_id
      AND tdm.pos_id IN (3, 4, 5, 6)               -- IF only
      AND (sv.level_code IN ('aaa', 'aax', 'afa', 'afx')
           OR sv.gc2_level_code IN ('dsl', 'rok'))
      AND YEAR(sv.sched_date) = @season
      AND sv.sched_type = 'R'
      AND CAST(sv.sched_date AS DATE) >= @start_date
      -- Tier 1 6-term gate (canonical, rules/fielding.md):
      AND (CAST(ISNULL(dcbp.out_made, 0) AS int)
           + CAST(ISNULL(dcbp.competitive_play, 0) AS int)
           + CAST(ISNULL(dcbp.competitive_throw, 0) AS int)
           + CAST(ISNULL(tdm.competitive_play, 0) AS int)
           + CAST(ISNULL(tdm.competitive_throw, 0) AS int)
           + CASE WHEN tdm.arm_strength >= @arm_lo THEN 1 ELSE 0 END) > 0
),
react_weekly AS (
    SELECT DISTINCT
        week_start,
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY reaction_time)
            OVER (PARTITION BY week_start) AS react,
        COUNT(reaction_time) OVER (PARTITION BY week_start) AS n_react
    FROM react_base
)

-- ----- Stitch ------------------------------------------------------------
SELECT
    ISNULL(p.week_start, r.week_start)              AS week_start,
    DATEADD(day, 6, ISNULL(p.week_start, r.week_start)) AS week_end,
    CAST(p.paa_eo AS DECIMAL(6, 3))                 AS paa_eo,
    CAST(r.react  AS DECIMAL(6, 3))                 AS react,
    r.n_react
FROM paa_weekly p
FULL OUTER JOIN react_weekly r
    ON p.week_start = r.week_start
ORDER BY ISNULL(p.week_start, r.week_start);
