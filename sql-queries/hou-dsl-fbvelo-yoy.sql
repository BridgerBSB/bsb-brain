-- Sam's ask: HOU DSL org-avg FB Velo YoY (2023 → 2024 → 2025)
--             + rank among the other 29 DSL clubs each year.
-- Scope:
--   * Strictly DSL games (gc2_level_code='dsl' per level-codes.md DSL split)
--   * Regular season only (sched_type='R')
-- Aggregation:
--   * POOL — AVG(release_speed) across every fastball thrown at the org's DSL
--     level. Volume-weighted by definition. Matches the affiliates-vs-fastballs
--     boss-ask pattern (memory/affiliates-vs-fastballs-shipped.md).
-- Org canon:
--   * OAK→ATH collapsed (Athletics rebrand 2024 spans both forms in MLBAM.Teams
--     across the 3-yr window — without the CASE they appear as 2 orgs).
-- Fastball: pitch_type IN ('FF','FT','SI'), velo = release_speed.
-- HOU multi-team note: DSL Astros Blue + DSL Astros Orange both map to
-- org_abbrev='HOU' (via fielding_team_id → MLBAM.Teams). Both pools merge
-- into a single HOU row, which is the intended "org avg."

WITH fb_pitches AS (
    SELECT
        sv.year,
        CASE UPPER(mt.org_abbrev)
            WHEN 'OAK' THEN 'ATH'
            ELSE UPPER(mt.org_abbrev)
        END AS org,
        pv.release_speed
    FROM Astros.Pitches_View pv
    JOIN Astros.Schedule_View sv
        ON sv.sched_id = pv.sched_id
    JOIN Astros.Events_View ev
        ON ev.sched_id = pv.sched_id
       AND ev.event_id = pv.ab_event_id
    JOIN MLBAM.Teams mt
        ON mt.team_id = ev.fielding_team_id
       AND mt.season  = sv.year
    WHERE sv.year IN (2023, 2024, 2025)
      AND sv.sched_type = 'R'
      AND sv.gc2_level_code = 'dsl'
      AND pv.pitch_type IN ('FF','FT','SI')
      AND pv.release_speed BETWEEN 60 AND 110   -- sanity cap, drops tracker glitches
      AND pv.pitch_id > 0
),
per_org_yr AS (
    SELECT
        org,
        year,
        AVG(release_speed) AS avg_fb_velo,
        COUNT(*)           AS n_fb
    FROM fb_pitches
    GROUP BY org, year
),
ranked AS (
    SELECT
        org,
        year,
        avg_fb_velo,
        n_fb,
        RANK()       OVER (PARTITION BY year ORDER BY avg_fb_velo DESC) AS rank_in_dsl,
        COUNT(*)     OVER (PARTITION BY year)                          AS n_orgs,
        AVG(avg_fb_velo) OVER (PARTITION BY year)                      AS dsl_avg_year
    FROM per_org_yr
)
-- ============================================================
-- Result Set 1: HOU summary — 3 rows, one per year
-- ============================================================
SELECT
    year                                          AS [Year],
    CAST(avg_fb_velo  AS DECIMAL(5,1))            AS [HOU Avg FB Velo],
    n_fb                                          AS [#FB],
    rank_in_dsl                                   AS [DSL Rank],
    n_orgs                                        AS [Out Of],
    CAST(dsl_avg_year AS DECIMAL(5,1))            AS [DSL Avg]
FROM ranked
WHERE org = 'HOU'
ORDER BY year;


-- ============================================================
-- Result Set 2: Full 30-org leaderboard, all 3 years
--   (uncomment to run alongside the HOU summary)
-- ============================================================
-- SELECT
--     year                                  AS [Year],
--     org                                   AS [Org],
--     CAST(avg_fb_velo AS DECIMAL(5,1))     AS [Avg FB Velo],
--     n_fb                                  AS [#FB],
--     rank_in_dsl                           AS [Rank],
--     n_orgs                                AS [Out Of]
-- FROM ranked
-- ORDER BY year, rank_in_dsl;
