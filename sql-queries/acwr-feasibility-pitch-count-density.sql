-- ACWR Workload Monitor — FEASIBILITY / DATA-DENSITY DIAGNOSTIC
-- =============================================================================
-- Question: can we build a COUNT-BASED Acute:Chronic Workload Ratio for HOU MiLB
-- pitchers from per-appearance pitch counts, BEFORE building anything?
--
-- Run on the WORK LAPTOP (DB access). Personal laptop has no DB.
-- Verify every column against .claude/rules/db-columns.md before trusting output.
-- HOU is NOT one of the 4 org-canon remap orgs (CHI/LA/NY/OAK) so a literal
-- 'HOU' filter is safe here (see rules/org-codes.md).
-- =============================================================================

-- STEP 1 — per-appearance pitch counts for HOU MiLB pitchers, 2025-2026 R games.
-- Drives FROM Pitches_View (one row per pitch), joins aev on ab_event_id for the
-- fielding (= pitching) team -> MLBAM.Teams for the HOU org filter (db-joins.md).
WITH appearances AS (
    SELECT
        pv.pitcher_id,
        sv.sched_date,
        sv.gc2_level_code              AS level_code,   -- gc2 = DSL/FCL split
        COUNT(*)                       AS pitches
    FROM Astros.Pitches_View pv
    JOIN Astros.Schedule_View sv
        ON pv.sched_id = sv.sched_id
    JOIN Astros.Events_View aev
        ON aev.sched_id = pv.sched_id
       AND aev.event_id = pv.ab_event_id               -- ab_event_id, NOT cur_event_id
    JOIN MLBAM.Teams t
        ON t.team_id = aev.fielding_team_id             -- pitcher's team = fielding team
       AND t.season  = sv.year
    WHERE sv.year IN (2025, 2026)
      AND sv.sched_type = 'R'
      AND sv.level_code NOT IN ('win','bbc','int','sum','nae','hsb','ind','jcb')
      AND t.org_abbrev = 'HOU'
      AND pv.pitch_id > 0
    GROUP BY pv.pitcher_id, sv.sched_date, sv.gc2_level_code
)

-- Density summary BY LEVEL: do we have countable per-appearance load everywhere
-- (incl. DSL/FCL)? If DSL/FCL rows are sparse, the monitor ships AAA->A first.
SELECT
    level_code,
    COUNT(DISTINCT pitcher_id)                          AS pitchers,
    COUNT(*)                                            AS appearances,
    SUM(pitches)                                        AS total_pitches,
    MIN(sched_date)                                     AS first_game,
    MAX(sched_date)                                     AS last_game,
    CAST(AVG(CAST(pitches AS float)) AS decimal(5,1))   AS avg_pitches_per_app,
    MAX(pitches)                                        AS max_pitches_in_an_app
FROM appearances
GROUP BY level_code
ORDER BY level_code;

-- -----------------------------------------------------------------------------
-- STEP 2 — VALIDATION SAMPLE: how many HOU pitcher ARM IL stints do we have to
-- test the thresholds against? (a spike is only useful if it precedes real injuries)
--
-- ⚠ DO NOT RUN AS-IS. SportsMed.DL_Stints column names are NOT yet verified in
-- this file. Before writing this query, grep the Injury Tracker (which already
-- reads DL_Stints) for the real columns:
--     pd-goals/injury_tracker/  +  sql-queries/dl-stints-discovery.sql
-- Confirm: player id key, stint start date, body_part / diagnosis, side.
-- Then count arm stints (shoulder/elbow/forearm/UCL) per pitcher per season and
-- LEFT JOIN to the `appearances` CTE windowed to the 7-14 days BEFORE each stint
-- to check whether an ACWR spike actually showed up pre-injury.
-- -----------------------------------------------------------------------------

-- STEP 3 (after density confirmed) — compute the ratio itself in Python or a
-- SQL window over `appearances`:
--   acute_load   = SUM(pitches) over the trailing 7-9 days
--   chronic_load = AVG of trailing ~28-day daily load
--   acwr         = acute_load / NULLIF(chronic_load, 0)
-- Flag acwr < 0.8 OR acwr > 1.3 (watch), acwr > 1.5 (spike). Guard the
-- low-chronic instability window (early season / just promoted / just off IL):
-- report acute & chronic as separate terms there, not just the raw ratio.
