-- =============================================================================
-- Org 2B→3B SB Ranking by Level — One-off baserunning request
-- =============================================================================
-- Purpose: Rank every org at each MiLB level (AAA, AA, A+, A) by 2B→3B SB
-- count, with PL@2B and SL@2B context columns. Boss request, one-off PDF.
--
-- Filters applied (per db-columns.md "Lead filter standard" + "SB/SBA Count Rule"):
--   SB count:
--     - Events_View.event_result_id = 43 (stolen_base_3b only)
--     - sched_type = 'R'
--     - Org attribution via batting_team_id → MLBAM.Teams.org_abbrev
--   2B leads (PL + SL):
--     - pbl.occupied_base = 2
--     - pbl.ignore_flag = 0
--     - pv.pitch_id > 0
--     - Exclude pitches with a runner already on 3B (LEFT JOIN IS NULL pattern)
--     - PL: NO runner_going filter (all leads count — pre-pitch position)
--     - SL: runner_going = 0 only (stealing runner is mid-sprint at secondary,
--           inflates the increment)
--     - SL definition = secondary_distance - primary_distance (the additional
--           lead gained, NOT total secondary distance — matches existing PD
--           Goals / Intangibles BR reports)
--   No 1B fielder-≤10 gate — that's a 1B-only rule.
-- =============================================================================

DECLARE @season int = 2026;

WITH sb_counts AS (
    SELECT
        sv.level_code,
        UPPER(t.org_abbrev) AS org,
        SUM(CASE WHEN ev.event_result_id = 43 THEN 1 ELSE 0 END) AS sb_2to3,
        SUM(CASE WHEN ev.event_result_id IN (5, 30) THEN 1 ELSE 0 END) AS cs_2to3
    FROM Astros.Events_View ev
    JOIN Astros.Schedule_View sv ON ev.sched_id = sv.sched_id
    JOIN MLBAM.Teams t ON ev.batting_team_id = t.team_id
                       AND sv.year = t.season
    WHERE sv.year = @season
      AND sv.sched_type = 'R'
      AND sv.level_code IN ('aaa', 'aax', 'afa', 'afx')
      AND (ev.sb | ev.cs) = 1
      AND ev.event_result_id IN (42, 43, 44, 4, 5, 6, 7, 29, 30, 31)
    GROUP BY sv.level_code, t.org_abbrev
),
leads_2b AS (
    SELECT
        sv.level_code,
        UPPER(t.org_abbrev) AS org,
        SUM(CAST(pbl.primary_distance_from_occupied_base AS float)) AS pl_sum,
        COUNT(pbl.primary_distance_from_occupied_base) AS n_pl_pitches,
        SUM(CASE WHEN pbl.runner_going = 0
                 THEN CAST(pbl.secondary_distance_from_occupied_base
                         - pbl.primary_distance_from_occupied_base AS float)
            END) AS sl_sum,
        SUM(CASE WHEN pbl.runner_going = 0
                  AND pbl.secondary_distance_from_occupied_base IS NOT NULL
                  AND pbl.primary_distance_from_occupied_base IS NOT NULL
                 THEN 1 ELSE 0 END) AS n_sl_pitches
    FROM Astros.Pitches_Baserunner_Leads pbl
    JOIN Astros.Pitches_View pv
        ON pbl.sched_id = pv.sched_id AND pbl.pitch_id = pv.pitch_id
    JOIN Astros.Events_View aev
        ON aev.sched_id = pv.sched_id AND aev.event_id = pv.ab_event_id
    JOIN Astros.Schedule_View sv ON pv.sched_id = sv.sched_id
    JOIN MLBAM.Teams t ON aev.batting_team_id = t.team_id
                       AND sv.year = t.season
    WHERE sv.year = @season
      AND sv.sched_type = 'R'
      AND sv.level_code IN ('aaa', 'aax', 'afa', 'afx')
      AND pbl.occupied_base = 2
      AND pbl.ignore_flag = 0
      AND pv.pitch_id > 0
      -- Exclude pitches where someone is already on 3B (next-base-occupied)
      AND NOT EXISTS (
          SELECT 1
          FROM Astros.Pitches_Baserunner_Leads pbl3
          WHERE pbl3.sched_id = pbl.sched_id
            AND pbl3.pitch_id = pbl.pitch_id
            AND pbl3.occupied_base = 3
      )
    GROUP BY sv.level_code, t.org_abbrev
)
SELECT
    sb.level_code,
    sb.org,
    sb.sb_2to3,
    sb.cs_2to3,
    l.pl_sum,
    l.n_pl_pitches,
    l.sl_sum,
    l.n_sl_pitches,
    CAST(ROUND(l.pl_sum / NULLIF(l.n_pl_pitches, 0), 1) AS decimal(5,1)) AS pl_2b_ft,
    CAST(ROUND(l.sl_sum / NULLIF(l.n_sl_pitches, 0), 1) AS decimal(5,1)) AS sl_2b_ft
FROM sb_counts sb
LEFT JOIN leads_2b l
    ON l.level_code = sb.level_code AND l.org = sb.org
ORDER BY
    CASE sb.level_code
        WHEN 'aaa' THEN 1
        WHEN 'aax' THEN 2
        WHEN 'afa' THEN 3
        WHEN 'afx' THEN 4
    END,
    sb.sb_2to3 DESC,
    sb.org;

-- =============================================================================
-- Expected output: ~120 rows (4 levels × ~30 orgs each)
-- Sort: AAA first (sb_2to3 DESC, then org), then AA, A+, A
-- HOU rows can be visually picked out by the PDF generator
-- =============================================================================
