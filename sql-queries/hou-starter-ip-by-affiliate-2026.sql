-- ============================================================================
-- HOU Starter Avg IP by Affiliate — 2026 R YTD
-- ============================================================================
-- Boss ask: average innings pitched by HOU starters at each of the 7 affiliates,
-- plus where HOU ranks vs the other orgs at each level (HiB — rank 1 = best).
--
-- Starter detection: pitcher of the FIRST pitch of inning 1 per half-inning
--   (top + bottom), via ROW_NUMBER over (sched_id, top_of_inning) ORDER BY
--   game_pitch_number. Canonical pattern — see mlb-starter-ff-ft-iz-pct.sql.
--
-- IP source: MLBAM.Gamelog_Pitching.outs (gold standard, per ip-calculation.md).
--   Display via canonical baseball notation: outs_int/3 + "." + outs_int%3.
--
-- Rank: RANK() OVER (PARTITION BY level_code ORDER BY avg_outs DESC) — pool all
--   orgs at the level, sort by avg outs/start descending, HOU's position is
--   the rank. Ties share rank; n_orgs shows how many orgs participated.
--
-- Scope: 2026 R only. No minimum start count.
-- ============================================================================

DECLARE @season INT = 2026;

WITH starters AS (
    -- One row per (sched_id, top_of_inning) — pitcher of the first pitch of
    -- inning 1, top and bottom halves. Works at every level w/ Pitches_View.
    SELECT sched_id, pitcher_id, top_of_inning
    FROM (
        SELECT pv.sched_id, pv.pitcher_id, ev.top_of_inning,
               ROW_NUMBER() OVER (
                   PARTITION BY pv.sched_id, ev.top_of_inning
                   ORDER BY pv.game_pitch_number
               ) AS rn
        FROM Astros.Pitches_View pv
        JOIN Astros.Schedule_View sv ON sv.sched_id = pv.sched_id
        JOIN Astros.Events_View ev
            ON ev.sched_id = pv.sched_id AND ev.event_id = pv.ab_event_id
        WHERE sv.year = @season
          AND sv.sched_type = 'R'
          AND pv.pitch_id > 0
          AND ev.inning = 1
    ) t
    WHERE rn = 1
),
all_starts AS (
    -- All orgs' starts (not just HOU) — required for league-wide ranking.
    SELECT
        sv.level_code,
        UPPER(bt.org_abbrev) AS org,
        s.sched_id,
        s.pitcher_id          AS gc_id,
        glp.outs
    FROM starters s
    JOIN Astros.Players ap         ON ap.groundcontrol_id = s.pitcher_id
    JOIN Astros.Schedule_View sv   ON sv.sched_id = s.sched_id
    JOIN MLBAM.Gamelog_Pitching glp
        ON glp.game_pk  = sv.mlbam_game_pk
       AND glp.player_id = ap.mlbam_id
    JOIN MLBAM.Teams bt
        ON bt.team_id   = glp.team_id
       AND bt.season    = sv.year
    WHERE sv.level_code IN ('mlb','aaa','aax','afa','afx','rok','dsl')
      AND glp.outs IS NOT NULL
      AND bt.org_abbrev IS NOT NULL
),
org_stats AS (
    SELECT
        level_code,
        org,
        COUNT(*)                 AS n_starts,
        COUNT(DISTINCT gc_id)    AS n_unique_starters,
        SUM(outs)                AS total_outs,
        AVG(CAST(outs AS float)) AS avg_outs
    FROM all_starts
    GROUP BY level_code, org
),
ranked AS (
    -- HiB ranking: highest avg outs/start at each level = rank 1.
    -- n_orgs = number of orgs participating at this level (e.g., DSL ~7).
    SELECT *,
        CAST(ROUND(avg_outs, 0) AS INT) AS avg_outs_int,
        RANK()  OVER (PARTITION BY level_code ORDER BY avg_outs DESC) AS lvl_rank,
        COUNT(*) OVER (PARTITION BY level_code)                       AS n_orgs
    FROM org_stats
)
SELECT
    level_code,
    n_starts,
    n_unique_starters,
    total_outs,
    CAST(avg_outs AS DECIMAL(5,2))                       AS avg_outs,
    CAST(avg_outs_int / 3 AS varchar(3))
        + '.'
        + CAST(avg_outs_int % 3 AS varchar(1))           AS avg_ip,
    lvl_rank,
    n_orgs
FROM ranked
WHERE org = 'HOU'
ORDER BY
    CASE level_code
        WHEN 'mlb' THEN 1
        WHEN 'aaa' THEN 2
        WHEN 'aax' THEN 3
        WHEN 'afa' THEN 4
        WHEN 'afx' THEN 5
        WHEN 'rok' THEN 6
        WHEN 'dsl' THEN 7
        ELSE 99
    END;

-- ============================================================================
-- Per-starter detail (optional — uncomment to see who's pulling each affiliate)
-- ============================================================================
-- SELECT
--     ast.level_code,
--     ast.gc_id,
--     p.full_name,
--     COUNT(*)                                                AS gs,
--     SUM(ast.outs)                                           AS total_outs,
--     CAST(AVG(CAST(ast.outs AS float)) / 3.0 AS DECIMAL(5,2)) AS avg_ip
-- FROM all_starts ast
-- LEFT JOIN Astros.Players p ON p.groundcontrol_id = ast.gc_id
-- WHERE ast.org = 'HOU'
-- GROUP BY ast.level_code, ast.gc_id, p.full_name
-- ORDER BY ast.level_code, gs DESC, avg_ip DESC;
