-- DJ Engle ask (6:22 PM, 6/23):
--   "All the pitchers from our org who pitched in the DSL in '25 who are
--    still in our org in '26 and show their year-to-year fastball velos."
--
-- FINAL READING (per Zac, 6/24):
--   POPULATION = pitchers who threw a 2025 DSL regular-season game for HOU
--   AND still show up in EBIS (MLB_eBis.PP_MASTER) under ORG_LK='HOU'.
--   The 2026 side is whatever level they're at NOW — DSL all the way up to
--   MLB. They do NOT have to be back in the DSL in 2026, and they do NOT
--   have to have pitched much in 2026 yet (season is young). Show '25 FF
--   velo vs '26 FF velo side by side.
--
--   Anchor years are FIXED: first year = 2025 (DSL), second year = 2026
--   (any level). This is NOT the min->max "first DSL year to last DSL year"
--   logic in hou-dsl-ff-velo-jump-2yr.sql — that's a different deliverable.
--
-- Mechanics (same conventions as the velo-jump queries):
--   * 2025 anchor: gc2_level_code='dsl', sched_type='R', year=2025,
--     org=HOU via ev.fielding_team_id -> MLBAM.Teams.
--   * "Still in our org" = EBIS roster: MLB_eBis.PP_MASTER.ORG_LK='HOU',
--     joined pm.player_id = Astros.Players.ebis_id (groundcontrol_id ->
--     ebis_id -> PP_MASTER). NOT a game-based gate.
--   * 2026 FF velo: ANY level (junk excluded), sched_type='R', org=HOU.
--     LEFT JOIN — a roster kid with little/no 2026 data still lists, with
--     a blank 2026 velo.
--   * FF only (pv.pitch_type='FF'). For all fastballs use IN ('FF','FT','SI')
--     in BOTH temp tables.
--   * Velo sanity cap 60-110 mph (HawkEye glitch guard).
--   * Velo-reliability gates: >=10 FF in '25, >=5 FF in '26 (both tunable,
--     n shown so DJ can judge). DJ said "at least an inning" -> low gates.
--   * HOU is not an org-canon mismatch org (CHI/LA/NY/OAK) -> no CASE remap.
--
-- Result Set 3 (org rank) DOES go league-wide, so it applies the standard
-- org-code canon (CHI/LA/NY/OAK->ATH) on the PP_MASTER<->MLBAM join, same
-- as every other cross-org rollup. It uses CTEs, not temp tables, so it's
-- fully self-contained and safe to run on its own.

IF OBJECT_ID('tempdb..#y25') IS NOT NULL DROP TABLE #y25;
IF OBJECT_ID('tempdb..#y26') IS NOT NULL DROP TABLE #y26;

-- ============================================================
-- 2025 HOU DSL FF velo (the anchor — pitched DSL for HOU in '25)
-- ============================================================
SELECT
    pv.pitcher_id,
    AVG(pv.release_speed) AS velo_2025_dsl,
    COUNT(*)              AS n_2025
INTO #y25
FROM Astros.Pitches_View pv
JOIN Astros.Schedule_View sv
    ON sv.sched_id = pv.sched_id
JOIN Astros.Events_View ev
    ON ev.sched_id = pv.sched_id
   AND ev.event_id = pv.ab_event_id
JOIN MLBAM.Teams mt
    ON mt.team_id = ev.fielding_team_id
   AND mt.season  = sv.year
WHERE sv.sched_type = 'R'
  AND sv.gc2_level_code = 'dsl'
  AND sv.year = 2025
  AND UPPER(mt.org_abbrev) = 'HOU'
  AND pv.pitch_type = 'FF'
  AND pv.release_speed BETWEEN 60 AND 110
  AND pv.pitch_id > 0
GROUP BY pv.pitcher_id
HAVING COUNT(*) >= 10;   -- <-- 2025 FF reliability gate (tunable)

-- ============================================================
-- 2026 HOU FF velo (ANY level — DSL up to MLB)
-- ============================================================
SELECT
    pv.pitcher_id,
    AVG(pv.release_speed) AS velo_2026,
    COUNT(*)              AS n_2026
INTO #y26
FROM Astros.Pitches_View pv
JOIN Astros.Schedule_View sv
    ON sv.sched_id = pv.sched_id
JOIN Astros.Events_View ev
    ON ev.sched_id = pv.sched_id
   AND ev.event_id = pv.ab_event_id
JOIN MLBAM.Teams mt
    ON mt.team_id = ev.fielding_team_id
   AND mt.season  = sv.year
WHERE sv.sched_type = 'R'
  AND sv.year = 2026
  AND UPPER(mt.org_abbrev) = 'HOU'
  AND sv.level_code NOT IN ('win','bbc','int','sum','nae','hsb','ind','jcb')
  AND pv.pitch_type = 'FF'
  AND pv.release_speed BETWEEN 60 AND 110
  AND pv.pitch_id > 0
GROUP BY pv.pitcher_id
HAVING COUNT(*) >= 5;    -- <-- 2026 FF reliability gate (low: young season, tunable)


-- ============================================================
-- Result Set 1 (DJ's ask): 2025 HOU DSL arms still in EBIS under HOU,
-- with 2025 DSL FF velo vs 2026 FF velo (any level).
-- ============================================================
SELECT
    CONCAT(pl.first_name, ' ', pl.last_name)        AS [Pitcher],
    y25.pitcher_id                                  AS [GC ID],
    CASE UPPER(pm.LEVELOFPLAY_LK)
        WHEN 'ML' THEN 'MLB' WHEN '3A' THEN 'AAA' WHEN '2A' THEN 'AA'
        WHEN '1A' THEN 'A+'  WHEN '1F' THEN 'A'    WHEN 'R'  THEN 'FCL'
        WHEN 'DS' THEN 'DSL' ELSE UPPER(pm.LEVELOFPLAY_LK)
    END                                             AS [EBIS Lvl Now],
    CAST(y25.velo_2025_dsl AS DECIMAL(5,1))         AS [2025 DSL FF],
    y25.n_2025                                      AS [#FF '25],
    lvl.levels_2026                                 AS [2026 Pitched At],
    CAST(y26.velo_2026 AS DECIMAL(5,1))             AS [2026 FF],
    y26.n_2026                                      AS [#FF '26],
    CAST(y26.velo_2026 - y25.velo_2025_dsl AS DECIMAL(5,2)) AS [YoY Change (mph)]
FROM #y25 y25
JOIN Astros.Players pl
    ON pl.groundcontrol_id = y25.pitcher_id
JOIN MLB_eBis.PP_MASTER pm
    ON pm.player_id = pl.ebis_id
   AND pm.ORG_LK   = 'HOU'           -- still in our org per EBIS
LEFT JOIN #y26 y26
    ON y26.pitcher_id = y25.pitcher_id
OUTER APPLY (
    -- Where he's actually thrown in 2026 (any pitch type, HOU, real levels)
    SELECT STRING_AGG(lv, '/') AS levels_2026
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
        JOIN Astros.Events_View ev2
            ON ev2.sched_id = pv2.sched_id AND ev2.event_id = pv2.ab_event_id
        JOIN MLBAM.Teams mt2
            ON mt2.team_id = ev2.fielding_team_id AND mt2.season = sv2.year
        WHERE pv2.pitcher_id = y25.pitcher_id
          AND sv2.year = 2026
          AND sv2.sched_type = 'R'
          AND UPPER(mt2.org_abbrev) = 'HOU'
          AND sv2.level_code NOT IN ('win','bbc','int','sum','nae','hsb','ind','jcb')
          AND pv2.pitch_id > 0
    ) lvls
) lvl
ORDER BY
    CASE WHEN y26.velo_2026 IS NULL THEN 1 ELSE 0 END,  -- has-'26-velo first
    [YoY Change (mph)] DESC;


-- ============================================================
-- Result Set 2: summary line (only arms with BOTH '25 and '26 FF velo)
-- ============================================================
SELECT
    COUNT(*)                                            AS [#Pitchers w/ Both Yrs],
    CAST(AVG(y25.velo_2025_dsl) AS DECIMAL(5,1))        AS [Avg 2025 DSL FF],
    CAST(AVG(y26.velo_2026)     AS DECIMAL(5,1))        AS [Avg 2026 FF],
    CAST(AVG(y26.velo_2026 - y25.velo_2025_dsl) AS DECIMAL(5,2)) AS [Avg YoY Change (mph)],
    CAST(MIN(y26.velo_2026 - y25.velo_2025_dsl) AS DECIMAL(5,2)) AS [Min Change],
    CAST(MAX(y26.velo_2026 - y25.velo_2025_dsl) AS DECIMAL(5,2)) AS [Max Change]
FROM #y25 y25
JOIN Astros.Players pl ON pl.groundcontrol_id = y25.pitcher_id
JOIN MLB_eBis.PP_MASTER pm ON pm.player_id = pl.ebis_id AND pm.ORG_LK = 'HOU'
JOIN #y26 y26 ON y26.pitcher_id = y25.pitcher_id;


-- ============================================================
-- Result Set 3: where HOU ranks among all clubs on avg FF velo GAINED.
-- Same population rule as the HOU pull, applied to every org: a 2025 DSL
-- arm for that org, STILL in that org per EBIS, with both a '25 and '26
-- FF velo. Ranked 1 = most velo gained. HOU flagged with <<< HOU.
-- Self-contained (CTEs, no temp tables) — safe to highlight + run alone.
-- ============================================================
WITH l25 AS (        -- 2025 DSL FF velo per (pitcher, org), every club
    SELECT
        pv.pitcher_id,
        CASE UPPER(mt.org_abbrev) WHEN 'OAK' THEN 'ATH'
                                  ELSE UPPER(mt.org_abbrev) END AS org,
        AVG(pv.release_speed) AS velo_2025_dsl
    FROM Astros.Pitches_View pv
    JOIN Astros.Schedule_View sv
        ON sv.sched_id = pv.sched_id
    JOIN Astros.Events_View ev
        ON ev.sched_id = pv.sched_id AND ev.event_id = pv.ab_event_id
    JOIN MLBAM.Teams mt
        ON mt.team_id = ev.fielding_team_id AND mt.season = sv.year
    WHERE sv.sched_type = 'R'
      AND sv.gc2_level_code = 'dsl'
      AND sv.year = 2025
      AND pv.pitch_type = 'FF'
      AND pv.release_speed BETWEEN 60 AND 110
      AND pv.pitch_id > 0
    GROUP BY pv.pitcher_id,
        CASE UPPER(mt.org_abbrev) WHEN 'OAK' THEN 'ATH'
                                  ELSE UPPER(mt.org_abbrev) END
    HAVING COUNT(*) >= 10          -- same 2025 gate as #y25
),
l26 AS (             -- 2026 FF velo per (pitcher, org), any level, every club
    SELECT
        pv.pitcher_id,
        CASE UPPER(mt.org_abbrev) WHEN 'OAK' THEN 'ATH'
                                  ELSE UPPER(mt.org_abbrev) END AS org,
        AVG(pv.release_speed) AS velo_2026
    FROM Astros.Pitches_View pv
    JOIN Astros.Schedule_View sv
        ON sv.sched_id = pv.sched_id
    JOIN Astros.Events_View ev
        ON ev.sched_id = pv.sched_id AND ev.event_id = pv.ab_event_id
    JOIN MLBAM.Teams mt
        ON mt.team_id = ev.fielding_team_id AND mt.season = sv.year
    WHERE sv.sched_type = 'R'
      AND sv.year = 2026
      AND sv.level_code NOT IN ('win','bbc','int','sum','nae','hsb','ind','jcb')
      AND pv.pitch_type = 'FF'
      AND pv.release_speed BETWEEN 60 AND 110
      AND pv.pitch_id > 0
      -- PERF: only the 2025 DSL arms can ever rank, so don't scan all of
      -- 2026 league-wide — restrict to those pitchers (cuts l26 from "every
      -- fastball in affiliated ball" to a few hundred pitchers).
      AND pv.pitcher_id IN (SELECT pitcher_id FROM l25)
    GROUP BY pv.pitcher_id,
        CASE UPPER(mt.org_abbrev) WHEN 'OAK' THEN 'ATH'
                                  ELSE UPPER(mt.org_abbrev) END
    HAVING COUNT(*) >= 5           -- same 2026 gate as #y26
),
per_org AS (         -- per org: avg gained velo across its qualifying arms
    SELECT
        l25.org,
        COUNT(*)                                AS n_pitchers,
        AVG(l25.velo_2025_dsl)                  AS avg_2025,
        AVG(l26.velo_2026)                      AS avg_2026,
        AVG(l26.velo_2026 - l25.velo_2025_dsl)  AS avg_gain
    FROM l25
    JOIN Astros.Players pl
        ON pl.groundcontrol_id = l25.pitcher_id
    JOIN MLB_eBis.PP_MASTER pm
        ON pm.player_id = pl.ebis_id
       AND CASE UPPER(pm.ORG_LK)        -- org-code canon -> MLBAM form
               WHEN 'CHI' THEN 'CHC' WHEN 'LA' THEN 'LAD'
               WHEN 'NY'  THEN 'NYM' WHEN 'OAK' THEN 'ATH'
               ELSE UPPER(pm.ORG_LK)
           END = l25.org                -- still in THAT org per EBIS
    JOIN l26
        ON l26.pitcher_id = l25.pitcher_id
       AND l26.org        = l25.org     -- 2026 velo with the same org
    GROUP BY l25.org
)
SELECT
    RANK() OVER (ORDER BY avg_gain DESC) AS [Rank],
    org                                  AS [Org],
    n_pitchers                           AS [#Arms (both yrs)],
    CAST(avg_2025 AS DECIMAL(5,1))       AS [Avg 2025 DSL FF],
    CAST(avg_2026 AS DECIMAL(5,1))       AS [Avg 2026 FF],
    CAST(avg_gain AS DECIMAL(5,2))       AS [Avg Gained (mph)],
    CASE WHEN org = 'HOU' THEN '<<< HOU' ELSE '' END AS [ ]
FROM per_org
ORDER BY [Rank], avg_gain DESC;


-- Cleanup
DROP TABLE #y25;
DROP TABLE #y26;
