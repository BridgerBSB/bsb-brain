-- =========================================================================
-- DSL pitcher IZ% on FF + FT, all 30 orgs, 2024 + 2025 + Combined
-- =========================================================================
-- Why 2024 + 2025: 2026 DSL hasn't started yet (per user May 26 2026).
-- IZ% = AVG(called_strike_chance_mlb) × 100 per .claude/rules/gc2-metrics.md
--       canonical InZ% formula (continuous AVG; NEVER binary CSC > 0.5).
-- FF + FT are POOLED into one fastball-shape signal (user direction:
-- "FF and FT all together"). Pool is per-pitch; SI is intentionally
-- excluded since user only asked for FF and FT.
--
-- BLOCKING: DSL detection via sv.gc2_level_code = 'dsl' per
-- .claude/rules/level-codes.md (DSL games store sv.level_code = 'rok'
-- so a level_code = 'dsl' filter matches ZERO rows).
--
-- Org canon: OAK -> ATH collapsed (Athletics rebrand 2024) per
-- .claude/rules/org-codes.md so the franchise shows as one row.
-- Pitcher attribution via fielding team -> MLBAM.Teams.org_abbrev (HOU
-- DSL Astros Blue + Orange both fall under HOU automatically).
--
-- Output: 30 orgs × 3 scopes (2024, 2025, Combined) = 90 rows total.
-- Each scope is independently ranked 1-30 by IZ% DESC. Ordered by
-- scope (2024, 2025, Combined) then IZ% DESC within each scope, so
-- the leaderboard reads top-to-bottom per year.
-- =========================================================================

WITH ff_ft_pitches AS (
    SELECT
        sv.year,
        CASE UPPER(mt.org_abbrev)
            WHEN 'OAK' THEN 'ATH'
            ELSE UPPER(mt.org_abbrev)
        END AS org,
        pv.called_strike_chance_mlb AS csc
    FROM Astros.Pitches_View pv
    JOIN Astros.Schedule_View sv ON sv.sched_id = pv.sched_id
    JOIN Astros.Events_View ev
        ON ev.sched_id = pv.sched_id
       AND ev.event_id = pv.ab_event_id
    JOIN MLBAM.Teams mt
        ON mt.team_id = ev.fielding_team_id
       AND mt.season = sv.year
    WHERE sv.year IN (2024, 2025)
      AND sv.sched_type = 'R'
      AND sv.gc2_level_code = 'dsl'        -- BLOCKING per level-codes.md
      AND pv.pitch_type IN ('FF', 'FT')
      AND pv.pitch_id > 0
      AND pv.called_strike_chance_mlb IS NOT NULL
),
per_org_scope AS (
    -- GROUPING SETS gives both per-year rows AND a "year-combined"
    -- (per-org) row in one pass. GROUPING(year) = 1 on the combined row.
    SELECT
        org,
        CASE WHEN GROUPING(year) = 1
             THEN 'Combined'
             ELSE CAST(year AS varchar(10))
        END AS scope,
        GROUPING(year) AS is_combined,
        100.0 * AVG(csc) AS iz_pct,
        COUNT(*)        AS n_pitches
    FROM ff_ft_pitches
    GROUP BY GROUPING SETS (
        (org, year),   -- per-org per-year
        (org)          -- per-org combined across both years
    )
)
SELECT
    org,
    scope,
    CAST(iz_pct AS decimal(5,2)) AS iz_pct,
    n_pitches,
    RANK() OVER (PARTITION BY scope ORDER BY iz_pct DESC) AS rank_in_dsl
FROM per_org_scope
ORDER BY
    is_combined,        -- 2024 + 2025 first, then Combined block
    scope,              -- '2024', '2025', 'Combined'
    iz_pct DESC;        -- leaderboard within each scope
