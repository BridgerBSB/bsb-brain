-- AA (Corpus Christi) HOU group vs FF — All FF + FF >= 95 mph (2026)
-- =====================================================================
-- Built for Ricky Rivera (AA manager): "how has our whole group performed
-- vs FF's, and then vs FF's > 95?"  Whole 2026 season, AA only.
--
-- METRICS (all are pitch / contact level — valid to slice by pitch type):
--   Whiff%   = whiffs / swings on FF                (swing-decision / bat-to-ball)
--   Contact% = 1 - Whiff%  (contact / swings on FF) (swing-decision / bat-to-ball)
--   xwOBAcon = expected wOBA ON CONTACT, BIP only   (contact quality)
--   Damage%  = mean per-BIP logistic damage prob    (contact quality)
--   + avg EV / avg LA / sample sizes for context
--
-- WHY xwOBAcon, NOT plain xwOBA (Ricky asked which):
--   xwOBA is a PA-level outcome (denom = AB+BB+HBP+SF). A walk / strikeout
--   can't be attributed to "the fastball" — a PA sees multiple pitch types.
--   Slicing a PA metric by ONE pitch type is ill-defined. xwOBAcon is
--   contact-only, so every value is attributable to the exact FF that was
--   put in play. This is the apples-to-apples "how do we do ON the FF" number.
--   (xwOBAcon formula here is canonical — matches sql-queries/hou-affiliates-
--    vs-ff-ft.sql / postgame_data._enrich_season_heatmap, which matches GC2.)
--
-- SAMPLE-SIZE CAVEAT: FF >= 95 at AA is a MUCH smaller pool (most AA heaters
--   sit upper-80s/low-90s) — n is returned on every line so the small-sample
--   buckets are obvious. xwOBAcon / Damage% on tiny BIP counts are noisy.
--
-- Definitions pulled from the canonical tracker (barrelsville/src/tracker_data.py):
--   WHIFF_CODES = (10,16,21,22,23,25); Damage% logistic; n_bip EV-misread filter.
-- Contact metrics here use ONE clean tracked-BIP set (BIP 12/13/14 + EV bounds +
--   LA-not-null + bunt-excluded + per-batter EV-misread filter) for xwOBAcon,
--   Damage%, EV, LA and n_bip — internally consistent for a one-off comparison.
--
-- Two result sets: (1) AA GROUP totals; (2) per-player breakout.
--
-- To change scope: @season / @level below. To POOL sinkers + two-seamers as
-- "fastballs", change  pv.pitch_type = 'FF'  ->  pv.pitch_type IN ('FF','FT','SI').

DECLARE @season int = 2026;
DECLARE @level  varchar(8) = 'aax';   -- AA = Corpus Christi (MLBAM SPORT code)

WITH
-- Canonical EV-misread filter — per-batter P95 EV (>=20 BIP), season-wide all
-- levels. Below 20 BIP the LEFT JOIN misses and ISNULL falls back to 105.
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
-- Year + level wOBA linear weights (AVG across leagues per level)
woba_lwts_avg AS (
    SELECT year, level_code,
           AVG(woba_1b) AS w_1b, AVG(woba_2b) AS w_2b,
           AVG(woba_3b) AS w_3b, AVG(woba_hr) AS w_hr
    FROM Guts.woba_lwts
    WHERE year = @season
    GROUP BY year, level_code
),
-- Hits_Probabilities exponents (global per season)
exponents AS (
    SELECT season,
           AVG(exp_1b) AS exp_1b, AVG(exp_2b) AS exp_2b, AVG(exp_3b) AS exp_3b,
           AVG(exp_hr) AS exp_hr, AVG(exp_fo) AS exp_fo
    FROM Guts.hit_specs_ratios
    WHERE season = @season
    GROUP BY season
),
-- Per-FF-pitch rows for HOU AA batters: swing/whiff flags + powered outcome
-- probabilities + linear weights, plus the tracked-BIP flag.
ff_base AS (
    SELECT
        pv.batter_id,
        r.first_name, r.last_name,
        -- velo bucket
        CASE WHEN pv.release_speed >= 95 THEN 1 ELSE 0 END AS is_95,
        -- swing (ignore_flag FF pitches are excluded upstream — when
        -- ignore_flag=1, pitch_type is NULL, so pv.pitch_type='FF' drops them;
        -- did_swing is therefore always populated here).
        CASE WHEN pv.did_swing = 1 THEN 1 ELSE 0 END AS is_swing,
        -- whiff (WHIFF_CODES; codes already imply a swing)
        CASE WHEN pv.pitch_result_id IN (10,16,21,22,23,25) THEN 1 ELSE 0 END AS is_whiff,
        -- tracked BIP: canonical gate (BIP + EV bounds + LA not null + bunt
        -- excluded + per-batter EV-misread filter)
        CASE WHEN pv.pitch_result_id IN (12,13,14)
              AND h.hit_exit_speed > 0 AND h.hit_exit_speed < 125
              AND h.hit_vertical_angle IS NOT NULL
              AND (aev.hit_trajectory_id NOT IN (2,3,4) OR aev.hit_trajectory_id IS NULL)
              AND NOT (h.hit_exit_speed >= 100 AND h.hit_vertical_angle < -35
                       AND h.hit_exit_speed > ISNULL(bp95.p95_ev, 105))
             THEN 1 ELSE 0 END AS is_bip_tracked,
        h.hit_exit_speed     AS ev,
        h.hit_vertical_angle AS la,
        -- powered outcome probabilities (xwOBAcon model)
        POWER(ISNULL(hp.prob_inf_1b,0) + ISNULL(hp.prob_of_1b,0), ex.exp_1b) AS pp_1b,
        POWER(ISNULL(hp.prob_2b,0), ex.exp_2b) AS pp_2b,
        POWER(ISNULL(hp.prob_3b,0), ex.exp_3b) AS pp_3b,
        POWER(ISNULL(hp.prob_hr,0), ex.exp_hr) AS pp_hr,
        POWER(ISNULL(hp.prob_inf_out,0) + ISNULL(hp.prob_of_out,0)
              + ISNULL(hp.prob_inf_error,0) + ISNULL(hp.prob_of_error,0), ex.exp_fo) AS pp_fo,
        wl.w_1b, wl.w_2b, wl.w_3b, wl.w_hr
    FROM Astros.Pitches_View pv
    JOIN Astros.Schedule_View sv ON pv.sched_id = sv.sched_id
    -- ab_event_id (always populated) for batting team + bunt trajectory
    LEFT JOIN Astros.Events_View aev
        ON aev.sched_id = pv.sched_id AND aev.event_id = pv.ab_event_id
    -- HOU batting team (game-level org, not roster)
    JOIN MLBAM.Teams bt
        ON bt.team_id = aev.batting_team_id AND bt.season = sv.year
    LEFT JOIN Astros.Hits h
        ON h.sched_id = pv.sched_id AND h.pitch_id = pv.pitch_id
    LEFT JOIN Astros.Hits_Probabilities hp
        ON hp.sched_id = pv.sched_id AND hp.pitch_id = pv.pitch_id AND hp.actual_shift = 1
    LEFT JOIN batter_ev_p95 bp95 ON bp95.batter_id = pv.batter_id
    LEFT JOIN woba_lwts_avg wl ON wl.year = sv.year AND wl.level_code = sv.level_code
    LEFT JOIN exponents ex ON ex.season = sv.year
    LEFT JOIN Astros.Players r ON r.groundcontrol_id = pv.batter_id
    WHERE sv.year = @season
      AND sv.sched_type = 'R'
      AND sv.level_code = @level          -- AA only
      AND bt.org_abbrev = 'HOU'           -- our hitters
      AND pv.pitch_type = 'FF'            -- four-seam fastballs
      AND pv.pitch_id > 0
)
-- Materialize per-pitch rows (with xwOBAcon + Damage% computed) so both
-- result sets read the same set without re-running the CTE chain.
SELECT
    batter_id, first_name, last_name,
    is_95, is_swing, is_whiff, is_bip_tracked,
    CASE WHEN is_bip_tracked = 1 THEN ev END AS ev,
    CASE WHEN is_bip_tracked = 1 THEN la END AS la,
    -- xwOBAcon per BIP (canonical)
    CASE
        WHEN is_bip_tracked = 1 AND (pp_1b + pp_2b + pp_3b + pp_fo) > 0 THEN
            (1.0 - pp_hr) * (pp_1b * w_1b + pp_2b * w_2b + pp_3b * w_3b)
                / (pp_1b + pp_2b + pp_3b + pp_fo)
            + pp_hr * w_hr
        WHEN is_bip_tracked = 1 THEN pp_hr * w_hr
        ELSE NULL
    END AS x_wobacon,
    -- Damage% per BIP (canonical logistic on rotated EV/LA, centered 98/27)
    CASE WHEN is_bip_tracked = 1 THEN
        1.6 * POWER(1.3,
            COS(-0.34) * (ev - 98.0) - SIN(-0.34) * (la - 27.0)
            - 0.02 * POWER(2 + SIN(-0.34) * (ev - 98.0) + COS(-0.34) * (la - 27.0), 2)
        ) / (7.0 + POWER(1.3,
            COS(-0.34) * (ev - 98.0) - SIN(-0.34) * (la - 27.0)
            - 0.02 * POWER(2 + SIN(-0.34) * (ev - 98.0) + COS(-0.34) * (la - 27.0), 2)
        ))
    ELSE NULL END AS dmg
INTO #ff
FROM ff_base;


-- =====================================================================
-- RESULT SET 1: AA GROUP totals — All FF vs FF >= 95
-- =====================================================================
SELECT
    'All FF'  AS bucket,
    COUNT(*)        AS n_ff_pitches,
    SUM(is_swing)   AS swings,
    SUM(is_whiff)   AS whiffs,
    CAST(100.0 * SUM(is_whiff) / NULLIF(SUM(is_swing), 0)                      AS decimal(5,1)) AS whiff_pct,
    CAST(100.0 * (SUM(is_swing) - SUM(is_whiff)) / NULLIF(SUM(is_swing), 0)    AS decimal(5,1)) AS contact_pct,
    SUM(is_bip_tracked) AS n_bip,
    CAST(AVG(ev)         AS decimal(5,1)) AS avg_ev,
    CAST(AVG(la)         AS decimal(5,1)) AS avg_la,
    CAST(AVG(x_wobacon)  AS decimal(5,3)) AS xwobacon,
    CAST(100.0 * AVG(dmg) AS decimal(5,1)) AS dmg_pct
FROM #ff
UNION ALL
SELECT
    'FF 95+',
    COUNT(*), SUM(is_swing), SUM(is_whiff),
    CAST(100.0 * SUM(is_whiff) / NULLIF(SUM(is_swing), 0)                      AS decimal(5,1)),
    CAST(100.0 * (SUM(is_swing) - SUM(is_whiff)) / NULLIF(SUM(is_swing), 0)    AS decimal(5,1)),
    SUM(is_bip_tracked),
    CAST(AVG(ev) AS decimal(5,1)), CAST(AVG(la) AS decimal(5,1)),
    CAST(AVG(x_wobacon) AS decimal(5,3)), CAST(100.0 * AVG(dmg) AS decimal(5,1))
FROM #ff
WHERE is_95 = 1;


-- =====================================================================
-- RESULT SET 2: per-player breakout (All-FF metrics + the 95+ heater column)
-- Gate: >= 10 FF seen. Sorted by FF volume.
-- =====================================================================
SELECT
    first_name + ' ' + last_name AS player,
    COUNT(*)      AS n_ff,
    SUM(is_swing) AS swings,
    CAST(100.0 * SUM(is_whiff) / NULLIF(SUM(is_swing), 0)                   AS decimal(5,1)) AS whiff_pct,
    CAST(100.0 * (SUM(is_swing) - SUM(is_whiff)) / NULLIF(SUM(is_swing), 0) AS decimal(5,1)) AS contact_pct,
    SUM(is_bip_tracked)  AS n_bip,
    CAST(AVG(x_wobacon)  AS decimal(5,3)) AS xwobacon,
    CAST(100.0 * AVG(dmg) AS decimal(5,1)) AS dmg_pct,
    CAST(AVG(ev)         AS decimal(5,1)) AS avg_ev,
    -- FF 95+ subset (smaller sample — heater-only)
    SUM(is_95)                                    AS n_ff95,
    SUM(CASE WHEN is_95 = 1 THEN is_swing ELSE 0 END) AS swings95,
    CAST(100.0 * SUM(CASE WHEN is_95 = 1 THEN is_whiff ELSE 0 END)
              / NULLIF(SUM(CASE WHEN is_95 = 1 THEN is_swing ELSE 0 END), 0) AS decimal(5,1)) AS whiff95_pct
FROM #ff
GROUP BY first_name, last_name
HAVING COUNT(*) >= 10
ORDER BY n_ff DESC;


DROP TABLE #ff;
