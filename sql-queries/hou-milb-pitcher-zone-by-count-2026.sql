-- =========================================================================
-- HOU MiLB pitcher zone usage — 2026 regular season
-- =========================================================================
-- Scope: HOU affiliates AAA / AA / A+ / A / FCL / DSL (excludes MLB).
--        Regular-season only (sched_type = 'R'). Real pitches only
--        (pitch_id > 0, plate_x/z NOT NULL for zone classification).
--        HOU attribution via fielding team -> MLBAM.Teams.org_abbrev = 'HOU'.
--
-- Three result sets:
--   Q1 — Most HEART pitches in pitcher-ahead counts (0-1, 0-2, 1-2)
--        + 2K Proj column (pitcher's season 2K Proj as context)
--   Q2 — Most SHADOW pitches in pitcher-ahead counts (same scope)
--        + 2K Proj column
--   Q3 — Highest avg CSC on called BALLS (overall, all counts) —
--        "who misses the zone by the least" when they miss
--        + BB% column (pitcher's season BB% as context)
--
-- Tango Heart/Shadow definitions (per .claude/rules/visual-standards.md):
--   X bounds (FIXED, not hitter-dependent):
--     Heart  : |plate_x| <= 0.558 ft (6.7")
--     Shadow : |plate_x| <= 1.108 ft (13.3")
--   Z bounds (per-batter height h in feet):
--     Heart  Z: 0.313725 * h - 0.08375  ..  0.491275 * h + 0.08375
--     Shadow Z: 0.226075 * h - 0.16625  ..  0.578925 * h + 0.16625
--   h = batter height in feet from mlbam.players, fallback 6.0 if missing.
--
-- Classification is EXCLUSIVE — Shadow excludes the inner Heart box per
-- the canonical ordering. Implemented via NOT-Heart guard on the Shadow
-- CASE. Mirrors barrelsville/scripts/heart_zone_report.py _HEART_FILTER
-- + _NOT_HEART_FILTER pattern.
--
-- 2K Proj formula (per bullpen-report/src/tracker_data.py:597-598):
--   AVG(CASE WHEN strikes_before = 2 AND balls_before != 3
--            THEN ppg.fb_grade END)
-- Source: Astros.Projections_Pitches_Grades JOIN on (sched_id, pitch_id).
-- "Average projection grade on two-strike, non-3-ball pitches only."
-- Computed across ALL the pitcher's season pitches (not just the ahead-
-- count subset filtered in Q1/Q2) so it reads as season context.
--
-- BB% formula (per bullpen-report/src/pitcher_kpi_data.py:621):
--   100.0 * SUM(ev.bb) / SUM(ev.pa) where bf = SUM(pa) + SUM(ibb) per
--   .claude/rules/pitfalls.md (ev.pa = 0 on IBB rows in this schema).
-- ev.bb already includes IBB (ev.bb=1 AND ev.ibb=1 for IBBs).
--
-- Min-sample gates:
--   Q1/Q2: HAVING n_ahead_pitches >= 100
--   Q3:    HAVING n_called_balls >= 100
-- =========================================================================


-- =========================================================================
-- Temp 1 — per-pitch base. Every HOU MiLB regular-season pitch in 2026
-- with zone classification + count + ball-result + 2K Proj inputs.
-- =========================================================================
IF OBJECT_ID('tempdb..#hou_milb_pitches') IS NOT NULL DROP TABLE #hou_milb_pitches;

SELECT
    pv.sched_id,
    pv.pitch_id,
    pv.pitcher_id,
    p.first_name + ' ' + p.last_name AS pitcher_name,
    sv.level_code,
    sv.gc2_level_code,
    CAST(pv.balls_before AS int)  AS balls_before,
    CAST(pv.strikes_before AS int) AS strikes_before,
    pv.pitch_result_id,
    pv.plate_x,
    pv.plate_z,
    pv.called_strike_chance_mlb AS csc,
    COALESCE(mr.height_feet + mr.height_inches / 12.0, 6.0) AS h_ft,
    ppg.fb_grade AS proj_grade   -- for 2K Proj aggregation downstream
INTO #hou_milb_pitches
FROM Astros.Pitches_View pv
JOIN Astros.Events_View ev
    ON pv.sched_id = ev.sched_id
   AND pv.ab_event_id = ev.event_id
JOIN Astros.Schedule_View sv ON pv.sched_id = sv.sched_id
JOIN MLBAM.Teams mt
    ON mt.team_id = ev.fielding_team_id
   AND mt.season = sv.year
LEFT JOIN Astros.Players p ON p.groundcontrol_id = pv.pitcher_id
LEFT JOIN Astros.Players b ON b.groundcontrol_id = pv.batter_id
LEFT JOIN mlbam.players mr ON mr.player_id = b.mlbam_id
LEFT JOIN Astros.Projections_Pitches_Grades ppg
    ON ppg.sched_id = pv.sched_id AND ppg.pitch_id = pv.pitch_id
WHERE sv.year = 2026
  AND sv.sched_type = 'R'
  AND UPPER(mt.org_abbrev) = 'HOU'
  -- All HOU levels except MLB. DSL/FCL routed via gc2_level_code
  -- per .claude/rules/level-codes.md.
  AND (sv.level_code IN ('aaa','aax','afa','afx')
       OR sv.gc2_level_code IN ('rok','dsl'))
  AND sv.level_code <> 'mlb'
  AND pv.pitch_id > 0
  AND pv.plate_x IS NOT NULL
  AND pv.plate_z IS NOT NULL;

CREATE INDEX ix_tmp_pitcher ON #hou_milb_pitches (pitcher_id);


-- =========================================================================
-- Temp 2 — per-pitcher season 2K Proj.
-- Aggregated across ALL of each pitcher's pitches (NO ahead-count filter)
-- so it reads as a season-wide context column when JOINed onto Q1/Q2.
-- =========================================================================
IF OBJECT_ID('tempdb..#pitcher_two_k_proj') IS NOT NULL DROP TABLE #pitcher_two_k_proj;

SELECT
    pitcher_id,
    AVG(CASE WHEN strikes_before = 2 AND balls_before <> 3
             THEN proj_grade END) AS two_k_proj,
    SUM(CASE WHEN strikes_before = 2 AND balls_before <> 3
              AND proj_grade IS NOT NULL THEN 1 ELSE 0 END) AS n_2k_graded
INTO #pitcher_two_k_proj
FROM #hou_milb_pitches
GROUP BY pitcher_id;

CREATE INDEX ix_tmp_2kp_pitcher ON #pitcher_two_k_proj (pitcher_id);


-- =========================================================================
-- Temp 3 — per-pitcher season BB% (PA-anchored, event-driven).
-- Per .claude/rules/event-vs-pitch-anchored.md, BB% must drive FROM
-- Events_View to avoid PA inflation. Same scope (HOU MiLB 2026 R) as
-- Temp 1 but built from event-grain rows, not pitch-grain.
-- BB% canonical = 100.0 * SUM(bb) / (SUM(pa) + SUM(ibb))
-- per .claude/rules/pitfalls.md (ev.pa = 0 on IBB rows; ev.bb counts IBB).
-- =========================================================================
IF OBJECT_ID('tempdb..#pitcher_bb_pct') IS NOT NULL DROP TABLE #pitcher_bb_pct;

SELECT
    pv.pitcher_id,
    SUM(CAST(ev.bb AS int)) AS n_bb,
    SUM(CAST(ev.pa AS int)) + SUM(CAST(ISNULL(ev.ibb, 0) AS int)) AS n_bf,
    CAST(100.0 * SUM(CAST(ev.bb AS int))
         / NULLIF(SUM(CAST(ev.pa AS int))
                  + SUM(CAST(ISNULL(ev.ibb, 0) AS int)), 0)
         AS decimal(5,2)) AS bb_pct
INTO #pitcher_bb_pct
FROM Astros.Events_View ev
JOIN Astros.Schedule_View sv ON ev.sched_id = sv.sched_id
JOIN MLBAM.Teams mt
    ON mt.team_id = ev.fielding_team_id
   AND mt.season = sv.year
LEFT JOIN Astros.Pitches_View pv
    ON ev.sched_id = pv.sched_id AND ev.event_id = pv.cur_event_id
WHERE sv.year = 2026
  AND sv.sched_type = 'R'
  AND UPPER(mt.org_abbrev) = 'HOU'
  AND (sv.level_code IN ('aaa','aax','afa','afx')
       OR sv.gc2_level_code IN ('rok','dsl'))
  AND sv.level_code <> 'mlb'
  AND pv.pitcher_id IS NOT NULL
GROUP BY pv.pitcher_id;

CREATE INDEX ix_tmp_bb_pitcher ON #pitcher_bb_pct (pitcher_id);


-- =========================================================================
-- Q1 — MOST HEART PITCHES IN AHEAD COUNTS (0-1, 0-2, 1-2)
-- + 2K Proj column (season context, all-counts AVG per formula)
-- Sort: heart_pct DESC. Tie-break by raw count.
-- =========================================================================
SELECT TOP 50
    hp.pitcher_id,
    hp.pitcher_name,
    COUNT(*) AS n_ahead_pitches,
    SUM(CASE
            WHEN ABS(hp.plate_x) <= 0.558
             AND hp.plate_z BETWEEN 0.313725 * hp.h_ft - 0.08375
                                AND 0.491275 * hp.h_ft + 0.08375
            THEN 1 ELSE 0
        END) AS n_heart,
    CAST(100.0 * SUM(CASE
                         WHEN ABS(hp.plate_x) <= 0.558
                          AND hp.plate_z BETWEEN 0.313725 * hp.h_ft - 0.08375
                                             AND 0.491275 * hp.h_ft + 0.08375
                         THEN 1 ELSE 0
                     END) / NULLIF(COUNT(*), 0)
         AS decimal(5,2)) AS heart_pct,
    CAST(tkp.two_k_proj AS decimal(5,1)) AS two_k_proj,
    tkp.n_2k_graded
FROM #hou_milb_pitches hp
LEFT JOIN #pitcher_two_k_proj tkp ON tkp.pitcher_id = hp.pitcher_id
WHERE (hp.balls_before = 0 AND hp.strikes_before IN (1, 2))
   OR (hp.balls_before = 1 AND hp.strikes_before = 2)
GROUP BY hp.pitcher_id, hp.pitcher_name, tkp.two_k_proj, tkp.n_2k_graded
HAVING COUNT(*) >= 100
ORDER BY heart_pct DESC, n_heart DESC;


-- =========================================================================
-- Q2 — MOST SHADOW PITCHES IN AHEAD COUNTS (0-1, 0-2, 1-2)
-- Shadow = inside Shadow X+Z bounds AND NOT inside Heart (exclusive).
-- + 2K Proj column (season context)
-- Sort: shadow_pct DESC. Tie-break by raw count.
-- =========================================================================
SELECT TOP 50
    hp.pitcher_id,
    hp.pitcher_name,
    COUNT(*) AS n_ahead_pitches,
    SUM(CASE
            WHEN ABS(hp.plate_x) <= 1.108
             AND hp.plate_z BETWEEN 0.226075 * hp.h_ft - 0.16625
                                AND 0.578925 * hp.h_ft + 0.16625
             AND NOT (ABS(hp.plate_x) <= 0.558
                      AND hp.plate_z BETWEEN 0.313725 * hp.h_ft - 0.08375
                                         AND 0.491275 * hp.h_ft + 0.08375)
            THEN 1 ELSE 0
        END) AS n_shadow,
    CAST(100.0 * SUM(CASE
                         WHEN ABS(hp.plate_x) <= 1.108
                          AND hp.plate_z BETWEEN 0.226075 * hp.h_ft - 0.16625
                                             AND 0.578925 * hp.h_ft + 0.16625
                          AND NOT (ABS(hp.plate_x) <= 0.558
                                   AND hp.plate_z BETWEEN 0.313725 * hp.h_ft - 0.08375
                                                      AND 0.491275 * hp.h_ft + 0.08375)
                         THEN 1 ELSE 0
                     END) / NULLIF(COUNT(*), 0)
         AS decimal(5,2)) AS shadow_pct,
    CAST(tkp.two_k_proj AS decimal(5,1)) AS two_k_proj,
    tkp.n_2k_graded
FROM #hou_milb_pitches hp
LEFT JOIN #pitcher_two_k_proj tkp ON tkp.pitcher_id = hp.pitcher_id
WHERE (hp.balls_before = 0 AND hp.strikes_before IN (1, 2))
   OR (hp.balls_before = 1 AND hp.strikes_before = 2)
GROUP BY hp.pitcher_id, hp.pitcher_name, tkp.two_k_proj, tkp.n_2k_graded
HAVING COUNT(*) >= 100
ORDER BY shadow_pct DESC, n_shadow DESC;


-- =========================================================================
-- Q3 — HIGHEST AVG CSC ON CALLED BALLS
-- "Who misses the zone by the LEAST when they miss"
-- - pitch_result_id = 4 (Ball - Called by umpire) — pure miss signal
-- - Excludes auto/intent/pitchout/HBP balls (they aren't pitched-to-miss)
-- - csc = called_strike_chance_mlb (MLB-model CSC, per .claude/rules/db-columns.md)
-- + BB% column (season context — does "missing close" actually = fewer walks?)
--
-- All counts (not count-specific) per user direction. Future iteration may
-- scope to ahead-count subset — add the same WHERE clause from Q1/Q2.
-- =========================================================================
SELECT TOP 50
    hp.pitcher_id,
    hp.pitcher_name,
    COUNT(*) AS n_called_balls,
    CAST(100.0 * AVG(hp.csc) AS decimal(5,2)) AS avg_iz_pct_on_balls,
    CAST(AVG(hp.csc) AS decimal(6,4)) AS avg_csc_on_balls,
    bb.bb_pct,
    bb.n_bb,
    bb.n_bf
FROM #hou_milb_pitches hp
LEFT JOIN #pitcher_bb_pct bb ON bb.pitcher_id = hp.pitcher_id
WHERE hp.pitch_result_id = 4   -- Ball - Called (per .claude/rules/pitch-codes.md)
  AND hp.csc IS NOT NULL
GROUP BY hp.pitcher_id, hp.pitcher_name, bb.bb_pct, bb.n_bb, bb.n_bf
HAVING COUNT(*) >= 100
ORDER BY avg_csc_on_balls DESC;


-- Cleanup
DROP TABLE #hou_milb_pitches;
DROP TABLE #pitcher_two_k_proj;
DROP TABLE #pitcher_bb_pct;
