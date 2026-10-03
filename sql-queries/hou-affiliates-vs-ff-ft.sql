-- HOU affiliates vs FF + FT (pooled) — xSLG / xBA / xwOBAcon
-- ============================================================
-- One row per HOU affiliate level. BIPs only (at-contact metrics).
-- HOU batters at each level batting against any FF or FT pitch.
--
-- Metrics:
--   xSLG     = Hits_Probabilities expected SLG on contact
--   xBA      = Hits_Probabilities expected BA on contact
--   xwOBAcon = Hits_Probabilities expected wOBA on contact (CANONICAL —
--              matches postgame_data._enrich_season_heatmap formula,
--              which matches GC2). Same Hits_Probabilities + hit_specs
--              exponent model as xSLG/xBA, weighted by wOBA linear
--              weights (w_1b/w_2b/w_3b/w_hr) instead of total bases /
--              0-or-1. This is the "x" form — should have been the
--              metric from day one; original wOBAcon (actual outcomes ×
--              weights) was the wrong choice.
--
-- Filters: canonical BIP gate + EV cap + bunt exclusion + LA NOT NULL +
-- per-batter EV misread filter.
--
-- To change scope:
--   :season           -> default 2026, edit DECLARE below
--   :pitch_types_ff   -> defaults to ('FF', 'FT')

DECLARE @season int = 2026;

WITH
-- Canonical EV misread filter — matches barrelsville/src/database.py::EV_MISREAD_CTE
-- Per-batter P95 across R+S+E + all live levels, gated to >=20 BIPs/batter.
-- Below 20 BIPs the LEFT JOIN finds nothing and ISNULL falls back to 105 mph.
batter_ev_p95 AS (
    SELECT sub.batter_id, sub.p95_ev
    FROM (
        SELECT DISTINCT pv2.batter_id,
               PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY h2.hit_exit_speed)
                   OVER (PARTITION BY pv2.batter_id) AS p95_ev,
               COUNT(*) OVER (PARTITION BY pv2.batter_id) AS n_bip
        FROM Astros.Pitches_View pv2
        JOIN Astros.Schedule_View sv2 ON pv2.sched_id = sv2.sched_id
        JOIN Astros.Hits h2 ON h2.sched_id = pv2.sched_id AND h2.pitch_id = pv2.pitch_id
        WHERE pv2.pitch_result_id IN (12, 13, 14)
          AND h2.hit_exit_speed > 0 AND h2.hit_exit_speed < 125
          AND pv2.pitch_id > 0
          AND sv2.sched_type IN ('R', 'S', 'E')
          AND YEAR(sv2.sched_date) = @season
          AND (sv2.level_code IN ('mlb','aaa','aax','afa','afx')
               OR sv2.gc2_level_code IN ('rok','dsl'))
    ) sub
    WHERE sub.n_bip >= 20
),
-- Year-level wOBA weights, AVG'd across leagues per level
woba_lwts_avg AS (
    SELECT year, level_code,
           AVG(woba_1b) AS w_1b,
           AVG(woba_2b) AS w_2b,
           AVG(woba_3b) AS w_3b,
           AVG(woba_hr) AS w_hr
    FROM Guts.woba_lwts
    WHERE year = @season
    GROUP BY year, level_code
),
-- Exponents (global per season)
exponents AS (
    SELECT season,
           AVG(exp_1b) AS exp_1b,
           AVG(exp_2b) AS exp_2b,
           AVG(exp_3b) AS exp_3b,
           AVG(exp_hr) AS exp_hr,
           AVG(exp_fo) AS exp_fo
    FROM Guts.hit_specs_ratios
    WHERE season = @season
    GROUP BY season
),
-- Per-BIP rows with all model + outcome columns. NOTE: now pulls ALL orgs
-- (not just HOU) so we can compute rank-at-level via window function.
per_bip AS (
    SELECT
        -- Use gc2_level_code so DSL splits out as 'dsl' instead of being
        -- bundled into 'rok'. Other levels: gc2_level_code = level_code.
        sv.gc2_level_code AS level_code,
        UPPER(bt.org_abbrev) AS org,
        sv.year,
        h.hit_exit_speed AS ev,
        h.hit_vertical_angle AS la,
        -- Hits_Probabilities outcome probabilities
        ISNULL(hp.prob_inf_1b, 0) + ISNULL(hp.prob_of_1b, 0) AS p_1b,
        ISNULL(hp.prob_2b, 0) AS p_2b,
        ISNULL(hp.prob_3b, 0) AS p_3b,
        ISNULL(hp.prob_hr, 0) AS p_hr,
        ISNULL(hp.prob_inf_out, 0) + ISNULL(hp.prob_of_out, 0)
        + ISNULL(hp.prob_inf_error, 0) + ISNULL(hp.prob_of_error, 0) AS p_fo,
        wl.w_1b, wl.w_2b, wl.w_3b, wl.w_hr,
        ex.exp_1b, ex.exp_2b, ex.exp_3b, ex.exp_hr, ex.exp_fo
    FROM Astros.Pitches_View pv
    JOIN Astros.Schedule_View sv ON pv.sched_id = sv.sched_id
    -- Event-level joins per dual-join pattern (ab_event for team, cur_event for outcome)
    LEFT JOIN Astros.Events_View aev
        ON aev.sched_id = pv.sched_id AND aev.event_id = pv.ab_event_id
    -- HOU batters only
    JOIN MLBAM.Teams bt
        ON bt.team_id = aev.batting_team_id
       AND bt.season = sv.year
    JOIN Astros.Hits h
        ON pv.sched_id = h.sched_id AND pv.pitch_id = h.pitch_id
    LEFT JOIN Astros.Hits_Probabilities hp
        ON hp.sched_id = pv.sched_id AND hp.pitch_id = pv.pitch_id
       AND hp.actual_shift = 1
    LEFT JOIN batter_ev_p95 bp95 ON bp95.batter_id = pv.batter_id
    LEFT JOIN woba_lwts_avg wl
        ON wl.year = sv.year AND wl.level_code = sv.level_code
    LEFT JOIN exponents ex ON ex.season = sv.year
    WHERE sv.year = @season
      AND sv.sched_type = 'R'
      -- Level filter: gc2_level_code splits FCL ('rok') from DSL ('dsl').
      -- sv.level_code='rok' would bundle them, so DSL games would mislabel
      -- as ROK (per level-codes.md).
      AND (sv.level_code IN ('mlb', 'aaa', 'aax', 'afa', 'afx')
           OR sv.gc2_level_code IN ('rok', 'dsl'))
      -- ALL orgs (HOU filter applied at the end after ranking)
      AND bt.org_abbrev IS NOT NULL
      -- FF + FT pooled
      AND pv.pitch_type IN ('FF', 'FT')
      -- BIP only
      AND pv.pitch_result_id IN (12, 13, 14)
      AND h.hit_exit_speed > 0
      AND h.hit_exit_speed < 125
      AND h.hit_vertical_angle IS NOT NULL
      AND (aev.hit_trajectory_id NOT IN (2, 3, 4) OR aev.hit_trajectory_id IS NULL)
      AND pv.pitch_id > 0
      -- Canonical EV misread filter (database.py::EV_MISREAD_EXCLUDE)
      AND NOT (
            h.hit_exit_speed >= 100
            AND h.hit_vertical_angle < -35
            AND h.hit_exit_speed > ISNULL(bp95.p95_ev, 105)
          )
),
-- Per-BIP metric values
per_bip_metrics AS (
    SELECT
        level_code,
        org,
        ev,
        la,
        -- Powered probabilities
        POWER(p_1b, exp_1b) AS pp_1b,
        POWER(p_2b, exp_2b) AS pp_2b,
        POWER(p_3b, exp_3b) AS pp_3b,
        POWER(p_hr, exp_hr) AS pp_hr,
        POWER(p_fo, exp_fo) AS pp_fo,
        w_1b, w_2b, w_3b, w_hr
    FROM per_bip
),
per_bip_calc AS (
    SELECT
        level_code,
        org,
        ev, la,
        -- xSLG: per-BIP expected total bases
        CASE WHEN (pp_1b + pp_2b + pp_3b + pp_fo) > 0 THEN
            (1.0 - pp_hr) * (pp_1b * 1.0 + pp_2b * 2.0 + pp_3b * 3.0)
                / (pp_1b + pp_2b + pp_3b + pp_fo)
            + pp_hr * 4.0
        END AS x_slg,
        -- xBA: per-BIP expected hit
        CASE WHEN (pp_1b + pp_2b + pp_3b + pp_fo) > 0 THEN
            (1.0 - pp_hr) * (pp_1b + pp_2b + pp_3b)
                / (pp_1b + pp_2b + pp_3b + pp_fo)
            + pp_hr
        END AS x_ba,
        -- xwOBAcon: per-BIP expected wOBA on contact (CANONICAL — matches
        -- postgame_data._enrich_season_heatmap formula). Same model as
        -- xSLG/xBA but weighted by wOBA linear weights instead of total
        -- bases / 0-or-1.
        CASE
            WHEN (pp_1b + pp_2b + pp_3b + pp_fo) > 0 THEN
                (1.0 - pp_hr)
                * (pp_1b * w_1b + pp_2b * w_2b + pp_3b * w_3b)
                / (pp_1b + pp_2b + pp_3b + pp_fo)
                + pp_hr * w_hr
            ELSE
                -- Fallback: no non-HR contact probability — only HR mass left.
                pp_hr * w_hr
        END AS x_wobacon
    FROM per_bip_metrics
),
-- Aggregate per (level, org) — every org at every level
per_org_agg AS (
    SELECT
        level_code,
        org,
        COUNT(*) AS n_bips,
        AVG(ev)        AS avg_ev,
        AVG(la)        AS avg_la,
        AVG(x_slg)     AS xslg,
        AVG(x_ba)      AS xba,
        AVG(x_wobacon) AS xwobacon
    FROM per_bip_calc
    GROUP BY level_code, org
),
-- Rank every org at each level (1 = best). Higher metric = better hitter
-- performance, so ORDER BY DESC. DENSE_RANK so ties don't skip.
ranked AS (
    SELECT
        *,
        DENSE_RANK() OVER (PARTITION BY level_code ORDER BY xslg     DESC) AS r_xslg,
        DENSE_RANK() OVER (PARTITION BY level_code ORDER BY xba      DESC) AS r_xba,
        DENSE_RANK() OVER (PARTITION BY level_code ORDER BY xwobacon DESC) AS r_xwobacon
    FROM per_org_agg
)
-- Materialize into a #temp so both result sets below read from the same
-- ranked output without re-running the entire CTE chain twice.
SELECT * INTO #ranked FROM ranked;


-- =========================================================================
-- RESULT SET 1: HOU rows only — friendly affiliate name + rank vs 30 orgs
-- =========================================================================
SELECT
    -- Sort key for natural level ordering
    CASE level_code
        WHEN 'mlb' THEN 1 WHEN 'aaa' THEN 2 WHEN 'aax' THEN 3
        WHEN 'afa' THEN 4 WHEN 'afx' THEN 5 WHEN 'rok' THEN 6
        WHEN 'dsl' THEN 7 ELSE 99 END AS sort_key,
    -- Friendly affiliate name
    CASE level_code
        WHEN 'mlb' THEN 'Houston Astros (MLB)'
        WHEN 'aaa' THEN 'Sugar Land Space Cowboys (AAA)'
        WHEN 'aax' THEN 'Corpus Christi Hooks (AA)'
        WHEN 'afa' THEN 'Asheville Tourists (A+)'
        WHEN 'afx' THEN 'Fayetteville Woodpeckers (A)'
        WHEN 'rok' THEN 'FCL Astros (Rookie)'
        WHEN 'dsl' THEN 'DSL Astros'
        ELSE level_code
    END AS affiliate,
    level_code,
    n_bips,
    CAST(avg_ev   AS decimal(5,1)) AS avg_ev,
    CAST(avg_la   AS decimal(5,1)) AS avg_la,
    CAST(xslg     AS decimal(5,3)) AS xslg,
    CAST(xba      AS decimal(5,3)) AS xba,
    CAST(xwobacon AS decimal(5,3)) AS xwobacon,
    r_xslg,
    r_xba,
    r_xwobacon
FROM #ranked
WHERE org = 'HOU'
ORDER BY sort_key;


-- =========================================================================
-- RESULT SET 2: Full 30-org leaderboard per level (sorted xwobacon DESC)
-- =========================================================================
SELECT
    CASE level_code
        WHEN 'mlb' THEN 1 WHEN 'aaa' THEN 2 WHEN 'aax' THEN 3
        WHEN 'afa' THEN 4 WHEN 'afx' THEN 5 WHEN 'rok' THEN 6
        WHEN 'dsl' THEN 7 ELSE 99 END AS sort_key,
    level_code,
    org,
    CASE WHEN org = 'HOU' THEN 1 ELSE 0 END AS is_hou,
    n_bips,
    CAST(avg_ev   AS decimal(5,1)) AS avg_ev,
    CAST(avg_la   AS decimal(5,1)) AS avg_la,
    CAST(xslg     AS decimal(5,3)) AS xslg,
    CAST(xba      AS decimal(5,3)) AS xba,
    CAST(xwobacon AS decimal(5,3)) AS xwobacon,
    r_xslg,
    r_xba,
    r_xwobacon
FROM #ranked
ORDER BY sort_key, xwobacon DESC;


DROP TABLE #ranked;
