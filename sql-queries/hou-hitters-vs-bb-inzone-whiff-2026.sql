-- HOU Hitters vs Breaking Balls In-Zone — Whiff Rate (2026)
-- ============================================================
-- One row per HOU hitter who saw any BB in-zone pitch in 2026 R season,
-- gated to >=20 BB-in-zone swings for stability.
--
-- Breaking balls    = SL / CU / FC (per pitch-codes.md classification)
-- In-zone           = pv.called_strike_chance_mlb > 0.5 (CSC method,
--                     canonical zone definition — reference-impl-index.md)
-- Whiff             = pitch_result_id IN (10,16,21,22,23,25) WITH
--                     did_swing = 1 gate (BLOCKING rule #4: without the
--                     gate, Whf% can exceed 100% because foul tips +
--                     swinging strikes both flag whiff codes but only
--                     swings count)
-- Swing recovery    = ignore_flag = 1 + did_swing NULL + pitch_result_id
--                     in SWING_CODES (per pitfalls.md). Otherwise the
--                     ~5% of pitches with ignore_flag get silently
--                     dropped from both swings + whiffs.
--
-- Pool: one HOU hitter per row, pooled across MLB + 4 MiLB + Rookie +
-- DSL. Level column shows every level the player took a BB-in-zone
-- pitch at (e.g. "AAA/AA" for multi-level). Sorted whiff% DESC.
--
-- To flip to PITCHER side (HOU pitchers' BB-in-zone whiff% allowed):
--   1. Swap MLBAM.Teams JOIN: batting_team_id -> fielding_team_id
--   2. Swap groupby + name lookup: pv.batter_id -> pv.pitcher_id
--   3. Update level CROSS APPLY: pv2.batter_id -> pv2.pitcher_id

DECLARE @season int = 2026;
DECLARE @min_swings int = 20;

-- Leading `;` defensive — T-SQL requires a statement terminator before
-- WITH when CTEs follow other statements (DECLARE, etc.). Without it,
-- SSMS misparses the batch and may report "could not find stored
-- procedure '<final ORDER BY alias>'" because the parser bails out
-- mid-batch and tries to EXEC the trailing identifier.
;WITH pitches_classified AS (
    -- All pitches faced by HOU batters this season (NO IZ/pitch_type
    -- filter — we tag is_bb / is_iz / is_ooz so the aggregation splits
    -- 4 buckets in one pass: BB-IZ, total-IZ, BB-OOZ, total-OOZ).
    SELECT
        pv.batter_id,
        CASE WHEN pv.pitch_type IN ('SL', 'CU', 'FC') THEN 1 ELSE 0 END AS is_bb,
        -- In/Out of zone via CSC (canonical, reference-impl-index.md).
        -- NULL CSC pitches drop from BOTH buckets (no zone classification).
        CASE WHEN pv.called_strike_chance_mlb >  0.5 THEN 1 ELSE 0 END AS is_iz,
        CASE WHEN pv.called_strike_chance_mlb <= 0.5 THEN 1 ELSE 0 END AS is_ooz,
        -- is_swing with ignore_flag recovery (pitfalls.md)
        CASE WHEN pv.did_swing = 1
              OR (pv.ignore_flag = 1 AND pv.did_swing IS NULL
                  AND pv.pitch_result_id IN (7,8,9,10,12,13,14,16,18,19,20,21,22,23,25))
             THEN 1 ELSE 0 END AS is_swing,
        -- is_whiff with did_swing gate (BLOCKING rule #4)
        CASE WHEN pv.pitch_result_id IN (10, 16, 21, 22, 23, 25)
              AND (pv.did_swing = 1
                   OR (pv.ignore_flag = 1 AND pv.did_swing IS NULL
                       AND pv.pitch_result_id IN (7,8,9,10,12,13,14,16,18,19,20,21,22,23,25)))
             THEN 1 ELSE 0 END AS is_whiff
    FROM Astros.Pitches_View pv
    JOIN Astros.Schedule_View sv ON pv.sched_id = sv.sched_id
    LEFT JOIN Astros.Events_View ev
        ON pv.sched_id = ev.sched_id AND pv.ab_event_id = ev.event_id
    LEFT JOIN MLBAM.Teams bt
        ON ev.batting_team_id = bt.team_id AND sv.year = bt.season
    WHERE sv.year = @season
      AND sv.sched_type = 'R'
      -- Junk levels excluded (level-codes.md). Includes amateur (bbc,
      -- hsb, jcb, sum), winter (win), independent (ind), unknown (nae),
      -- internal (int — DSL bullpen V games, not R).
      AND sv.level_code NOT IN ('bbc','win','int','sum','nae','hsb','ind','jcb')
      AND bt.org_abbrev = 'HOU'
      AND pv.pitch_id > 0
),
agg AS (
    -- One row per batter. All 4 buckets (BB-IZ / total-IZ / BB-OOZ /
    -- total-OOZ) computed in a single GROUP BY pass.
    SELECT
        batter_id,
        -- Pitch-count denominators for swing% (BB-IZ + BB-OOZ buckets)
        SUM(CASE WHEN is_bb=1  AND is_iz=1  THEN 1        ELSE 0 END) AS bb_iz_pitches,
        SUM(CASE WHEN is_bb=1  AND is_ooz=1 THEN 1        ELSE 0 END) AS bb_ooz_pitches,
        -- Swings + whiffs per bucket
        SUM(CASE WHEN is_bb=1  AND is_iz=1  THEN is_swing ELSE 0 END) AS bb_iz_swings,
        SUM(CASE WHEN is_bb=1  AND is_iz=1  THEN is_whiff ELSE 0 END) AS bb_iz_whiffs,
        SUM(CASE WHEN              is_iz=1  THEN is_swing ELSE 0 END) AS total_iz_swings,
        SUM(CASE WHEN              is_iz=1  THEN is_whiff ELSE 0 END) AS total_iz_whiffs,
        SUM(CASE WHEN is_bb=1  AND is_ooz=1 THEN is_swing ELSE 0 END) AS bb_ooz_swings,
        SUM(CASE WHEN is_bb=1  AND is_ooz=1 THEN is_whiff ELSE 0 END) AS bb_ooz_whiffs,
        SUM(CASE WHEN              is_ooz=1 THEN is_swing ELSE 0 END) AS total_ooz_swings,
        SUM(CASE WHEN              is_ooz=1 THEN is_whiff ELSE 0 END) AS total_ooz_whiffs
    FROM pitches_classified
    GROUP BY batter_id
    HAVING SUM(CASE WHEN is_bb=1 AND is_iz=1 THEN is_swing ELSE 0 END) >= @min_swings
)
SELECT
    CONCAT(r.first_name, ' ', r.last_name) AS name,
    lvl.level,
    CAST(100.0 * a.bb_iz_whiffs    / NULLIF(a.bb_iz_swings, 0)    AS decimal(5,1))
        AS bb_iz_whiff_pct,
    CAST(100.0 * a.total_iz_whiffs / NULLIF(a.total_iz_swings, 0) AS decimal(5,1))
        AS total_iz_whiff_pct,
    CAST(100.0 * a.total_ooz_whiffs / NULLIF(a.total_ooz_swings, 0) AS decimal(5,1))
        AS ooz_whiff_pct,
    CAST(100.0 * a.bb_ooz_whiffs    / NULLIF(a.bb_ooz_swings, 0)    AS decimal(5,1))
        AS bb_ooz_whiff_pct,
    -- BB swing rates — context for the whiff%s above. Chase rate = sw%
    -- on BB-OOZ; zone-swing rate on BB = sw% on BB-IZ.
    CAST(100.0 * a.bb_ooz_swings / NULLIF(a.bb_ooz_pitches, 0) AS decimal(5,1))
        AS bb_ooz_sw_pct,
    CAST(100.0 * a.bb_iz_swings  / NULLIF(a.bb_iz_pitches,  0) AS decimal(5,1))
        AS bb_iz_sw_pct,
    -- BB-IZ whiff% minus total-IZ whiff%. Positive = batter whiffs MORE
    -- on BB-IZ than on IZ overall (BB is a relative weakness). Sort key.
    CAST(
        (100.0 * a.bb_iz_whiffs    / NULLIF(a.bb_iz_swings, 0))
      - (100.0 * a.total_iz_whiffs / NULLIF(a.total_iz_swings, 0))
        AS decimal(5,1)
    ) AS bb_minus_total_pp
FROM agg a
LEFT JOIN Astros.Players r ON r.groundcontrol_id = a.batter_id
CROSS APPLY (
    SELECT STRING_AGG(lv, '/') AS level
    FROM (
        SELECT DISTINCT
            CASE sv2.gc2_level_code
                WHEN 'mlb' THEN 'MLB' WHEN 'aaa' THEN 'AAA' WHEN 'aax' THEN 'AA'
                WHEN 'afa' THEN 'A+'  WHEN 'afx' THEN 'A'
                WHEN 'rok' THEN 'FCL' WHEN 'dsl' THEN 'DSL'
                ELSE UPPER(sv2.gc2_level_code)
            END AS lv
        FROM Astros.Pitches_View pv2
        JOIN Astros.Schedule_View sv2 ON pv2.sched_id = sv2.sched_id
        WHERE pv2.batter_id = a.batter_id
          AND sv2.year = @season
          AND sv2.sched_type = 'R'
          AND sv2.level_code NOT IN ('bbc','win','int','sum','nae','hsb','ind','jcb')
          AND pv2.pitch_id > 0
    ) lvls
) lvl
ORDER BY bb_minus_total_pp DESC, bb_iz_whiff_pct DESC, a.bb_iz_swings DESC;
