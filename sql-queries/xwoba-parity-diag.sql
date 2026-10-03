-- Diagnostic: exact xwoba_numer and xwoba_pa pooled across 4 MiLB levels for HOU.
-- Run BOTH queries, compare numer + pa totals side-by-side.
-- If both match: 0.003 is floating-point accumulation, not a bug.
-- If numer differs: xwoba contribution math is diverging per-PA somewhere.
-- If pa differs: PA set is different.

-- Swap the weights values for current year/level as needed. Below are 2025 MiLB AVG.
-- Get the actual weight values via:
--   SELECT year, level_code, AVG(woba_bb), AVG(woba_hb), AVG(woba_1b),
--          AVG(woba_2b), AVG(woba_3b), AVG(woba_hr)
--   FROM Guts.woba_lwts
--   WHERE year = 2025 AND level_code IN ('aaa','aax','afa','afx')
--   GROUP BY year, level_code;

-- ============================================================================
-- VERSION A: Tracker pattern (per-level WHERE cur_event IS NOT NULL gated)
-- Run once per level, sum the results in a spreadsheet for HOU pool xwoba.
-- ============================================================================
DECLARE @level varchar(5) = 'aaa';  -- run 4 times, once per level
DECLARE @season int = 2026;

-- Look up weights for this level (use lookup_year 2025 since it's April)
DECLARE @w_bb float, @w_hbp float, @w_1b float, @w_2b float, @w_3b float, @w_hr float;
DECLARE @exp_1b float, @exp_2b float, @exp_3b float, @exp_hr float, @exp_fo float;

SELECT
    @w_bb  = AVG(woba_bb), @w_hbp = AVG(woba_hb), @w_1b = AVG(woba_1b),
    @w_2b  = AVG(woba_2b), @w_3b  = AVG(woba_3b), @w_hr = AVG(woba_hr)
FROM Guts.woba_lwts
WHERE year = 2025 AND level_code = @level;

SELECT @exp_1b = exp_1b, @exp_2b = exp_2b, @exp_3b = exp_3b,
       @exp_hr = exp_hr, @exp_fo = exp_fo
FROM Guts.hit_specs_ratios
WHERE season = @season;

SELECT
    @level AS level,
    UPPER(mt.org_abbrev) AS org,
    SUM(xwoba_contrib) AS xwoba_numer,
    COUNT(xwoba_contrib) AS xwoba_pa
FROM (
    SELECT
        UPPER(mt.org_abbrev) AS org,
        CASE
            WHEN CAST(ISNULL(cev.ibb, 0) AS int) = 1 THEN NULL
            WHEN CAST(ISNULL(cev.bb, 0) AS int) = 1
                 OR CAST(ISNULL(cev.hbp, 0) AS int) = 1 THEN @w_bb
            WHEN CAST(ISNULL(cev.ab, 0) AS int) = 1
                 OR CAST(ISNULL(cev.sf, 0) AS int) = 1
                THEN ISNULL(
                    (1.0 - POWER(hp.prob_hr, @exp_hr))
                    * (POWER(hp.prob_inf_1b + hp.prob_of_1b, @exp_1b) * @w_1b
                       + POWER(hp.prob_2b, @exp_2b) * @w_2b
                       + POWER(hp.prob_3b, @exp_3b) * @w_3b)
                    / NULLIF(POWER(hp.prob_inf_1b + hp.prob_of_1b, @exp_1b)
                             + POWER(hp.prob_2b, @exp_2b)
                             + POWER(hp.prob_3b, @exp_3b)
                             + POWER(hp.prob_inf_out + hp.prob_of_out
                                     + hp.prob_inf_error + hp.prob_of_error, @exp_fo), 0)
                    + POWER(hp.prob_hr, @exp_hr) * @w_hr,
                    CAST(ISNULL(cev.[1b], 0) AS float) * @w_1b
                    + CAST(ISNULL(cev.[2b], 0) AS float) * @w_2b
                    + CAST(ISNULL(cev.[3b], 0) AS float) * @w_3b
                    + CAST(ISNULL(cev.hr, 0) AS float) * @w_hr
                )
            ELSE 0.0
        END AS xwoba_contrib,
        mt.org_abbrev
    FROM Astros.Pitches_View pv
    JOIN Astros.Events_View aev
        ON aev.sched_id = pv.sched_id AND aev.event_id = pv.ab_event_id
    LEFT JOIN Astros.Events_View cev
        ON cev.sched_id = pv.sched_id AND cev.event_id = pv.cur_event_id
    LEFT JOIN Astros.Hits_Probabilities hp
        ON hp.sched_id = pv.sched_id AND hp.pitch_id = pv.pitch_id
        AND hp.actual_shift = 1
    JOIN Astros.Schedule_View sv ON pv.sched_id = sv.sched_id
    JOIN mlbam.teams mt
        ON mt.team_id = CASE WHEN aev.top_of_inning = 1
                             THEN sv.away_team_mlbam_id
                             ELSE sv.home_team_mlbam_id END
        AND mt.season = sv.year
    WHERE sv.level_code = @level
      AND YEAR(sv.sched_date) = @season
      AND sv.sched_type = 'R'
      AND pv.pitch_id > 0
      AND pv.cur_event_id IS NOT NULL
      AND (CAST(ISNULL(cev.pa, 0) AS int) = 1
           OR CAST(ISNULL(cev.ibb, 0) AS int) = 1)
) inner_q
JOIN mlbam.teams mt ON mt.org_abbrev = inner_q.org_abbrev
WHERE UPPER(mt.org_abbrev) = 'HOU'
GROUP BY UPPER(mt.org_abbrev);

-- ============================================================================
-- VERSION B: PD-Goals pattern (single query, all 4 MiLB levels, per-pitch JOIN)
-- Runs one query that pools across all 4 MiLB levels — mirrors _HITTING_ORG_QUERY.
-- ============================================================================
SELECT
    'all_4_milb' AS level,
    UPPER(mt.org_abbrev) AS org,
    SUM(xwoba_numer) AS xwoba_numer_total,
    SUM(xwoba_pa) AS xwoba_pa_total
FROM (
    SELECT
        UPPER(mt.org_abbrev) AS org,
        CASE WHEN pv.cur_event_id IS NOT NULL AND CAST(ISNULL(cev.pa, 0) AS int) = 1
                  AND CAST(ISNULL(cev.ibb, 0) AS int) = 0
             THEN 1 ELSE 0 END AS xwoba_pa,
        CASE WHEN pv.cur_event_id IS NOT NULL AND CAST(ISNULL(cev.pa, 0) AS int) = 1
                  AND CAST(ISNULL(cev.ibb, 0) AS int) = 0
             THEN
                CASE
                    WHEN CAST(ISNULL(cev.bb, 0) AS int) = 1
                         OR CAST(ISNULL(cev.hbp, 0) AS int) = 1
                        THEN wl.wl_bb
                    WHEN CAST(ISNULL(cev.ab, 0) AS int) = 1
                         OR CAST(ISNULL(cev.sf, 0) AS int) = 1
                        THEN ISNULL(
                            (1.0 - POWER(hp.prob_hr, hsr.exp_hr))
                            * (POWER(hp.prob_inf_1b + hp.prob_of_1b, hsr.exp_1b) * wl.wl_1b
                               + POWER(hp.prob_2b, hsr.exp_2b) * wl.wl_2b
                               + POWER(hp.prob_3b, hsr.exp_3b) * wl.wl_3b)
                            / NULLIF(POWER(hp.prob_inf_1b + hp.prob_of_1b, hsr.exp_1b)
                                     + POWER(hp.prob_2b, hsr.exp_2b)
                                     + POWER(hp.prob_3b, hsr.exp_3b)
                                     + POWER(hp.prob_inf_out + hp.prob_of_out
                                             + hp.prob_inf_error + hp.prob_of_error, hsr.exp_fo), 0)
                            + POWER(hp.prob_hr, hsr.exp_hr) * wl.wl_hr,
                            CAST(cev.[1b] AS float) * wl.wl_1b + CAST(cev.[2b] AS float) * wl.wl_2b
                            + CAST(cev.[3b] AS float) * wl.wl_3b + CAST(cev.hr AS float) * wl.wl_hr
                        )
                    ELSE 0.0
                END
             ELSE 0.0 END AS xwoba_numer,
        mt.org_abbrev
    FROM Astros.Pitches_View pv
    JOIN Astros.Schedule_View sv ON pv.sched_id = sv.sched_id
    JOIN Astros.Events_View aev
        ON aev.sched_id = pv.sched_id AND aev.event_id = pv.ab_event_id
    LEFT JOIN Astros.Events_View cev
        ON cev.sched_id = pv.sched_id AND cev.event_id = pv.cur_event_id
    LEFT JOIN Astros.Hits_Probabilities hp
        ON hp.sched_id = pv.sched_id AND hp.pitch_id = pv.pitch_id
        AND hp.actual_shift = 1
    LEFT JOIN (
        SELECT year, level_code,
               AVG(woba_bb) AS wl_bb, AVG(woba_hb) AS wl_hbp,
               AVG(woba_1b) AS wl_1b, AVG(woba_2b) AS wl_2b,
               AVG(woba_3b) AS wl_3b, AVG(woba_hr) AS wl_hr
        FROM Guts.woba_lwts
        GROUP BY year, level_code
    ) wl ON wl.year = 2025 AND wl.level_code = sv.level_code
    CROSS JOIN (
        SELECT exp_1b, exp_2b, exp_3b, exp_hr, exp_fo
        FROM Guts.hit_specs_ratios WHERE season = 2026
    ) hsr
    JOIN mlbam.teams mt
        ON mt.team_id = CASE WHEN aev.top_of_inning = 1
                             THEN sv.away_team_mlbam_id
                             ELSE sv.home_team_mlbam_id END
        AND mt.season = sv.year
    WHERE sv.level_code IN ('aaa','aax','afa','afx')
      AND sv.year = 2026
      AND sv.sched_type = 'R'
      AND pv.pitch_id > 0
) pitch_rows
JOIN mlbam.teams mt ON mt.org_abbrev = pitch_rows.org_abbrev
WHERE UPPER(mt.org_abbrev) = 'HOU'
GROUP BY UPPER(mt.org_abbrev);

-- After you run both:
-- Sum VERSION A's xwoba_numer across 4 levels → should equal VERSION B xwoba_numer_total
-- Sum VERSION A's xwoba_pa across 4 levels → should equal VERSION B xwoba_pa_total
-- If either doesn't, the drift is from that side (numer or denom).
