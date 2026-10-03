-- ============================================================================
-- FCL / GCL single-season WALKS (BB) record — league-wide, all 30 orgs.
--   "Most walks by a hitter in one season at the Florida complex league."
--   FCL = current name; GCL (Gulf Coast League) = pre-2021 name, same lineage.
--   Jase Mitchell (gc 1293257) is sitting at ~40 BB in 2026 and chasing this.
-- ----------------------------------------------------------------------------
-- SOURCE: MLBAM.YTD_Player_Batting_Stats (official season totals, league-wide).
--   bb (col 36) = TOTAL walks (includes IBB). ibb shown separately so you can
--   read unintentional = bb - ibb if you prefer that definition.
--
-- FCL-vs-ACL SPLIT: FCL and ACL both sit under the complex-rookie level code, so
--   the ONLY clean discriminator is MLBAM.Teams.league. We filter to the FLORIDA
--   complex via league IN ('FCL','GCL'). gm_type='r' (reg season), split_id=0
--   (overall, not platoon splits). Trades within the FCL in one season are summed.
--
-- *** COVERAGE CAVEAT — READ FIRST ***  Your teammate found "42 in the 80s."
--   This DB's MLBAM season-stat history does NOT go back to the 1980s. SECTION 1
--   prints the earliest FCL/GCL season actually present. If that's well after the
--   '80s (likely), the true ALL-TIME record needs an external source
--   (Baseball-Reference MiLB / MLB.com) — this query gives the record only within
--   the DB's coverage window. Don't present a number here as the all-time record
--   until Section 1 confirms the data reaches that far back.
-- ============================================================================


-- SECTION 1 — COVERAGE + LEAGUE-LABEL CHECK -----------------------------------
-- Confirms (a) how far back FCL/GCL season data goes, and (b) which league
-- labels exist ('FCL' modern vs 'GCL' legacy; 'ACL'/'AZL' = Arizona, excluded).
SELECT  t.league,
        MIN(yb.season)        AS first_season,
        MAX(yb.season)        AS last_season,
        COUNT(DISTINCT yb.season) AS n_seasons,
        COUNT(*)              AS player_season_rows
FROM    MLBAM.YTD_Player_Batting_Stats yb
JOIN    MLBAM.Teams t
        ON t.team_id = yb.team_id AND t.season = yb.season
WHERE   yb.gm_type  = 'r'
  AND   yb.split_id = 0
  AND   t.league IN ('FCL','GCL','ACL','AZL')   -- all complex labels, to see what's stored
GROUP BY t.league
ORDER BY t.league;


-- SECTION 2 — THE LEADERBOARD (FCL/GCL single-season BB, top 50 in DB) ---------
WITH fcl_bb AS (
    SELECT
        yb.player_id,
        yb.season,
        SUM(CAST(yb.bb  AS int)) AS bb,      -- total walks (incl. IBB)
        SUM(CAST(yb.ibb AS int)) AS ibb,
        SUM(CAST(yb.pa  AS int)) AS pa,
        SUM(CAST(yb.so  AS int)) AS so,
        MAX(t.league)            AS league,
        MAX(t.org_abbrev)        AS org
    FROM    MLBAM.YTD_Player_Batting_Stats yb
    JOIN    MLBAM.Teams t
            ON t.team_id = yb.team_id AND t.season = yb.season
    WHERE   yb.gm_type  = 'r'
      AND   yb.split_id = 0
      AND   t.league IN ('FCL','GCL')          -- Florida complex only
    GROUP BY yb.player_id, yb.season            -- sum any in-season FCL team changes
)
SELECT TOP 50
    ROW_NUMBER() OVER (ORDER BY f.bb DESC, f.pa ASC) AS rk,
    LTRIM(RTRIM(ISNULL(r.first_name,'') + ' ' + ISNULL(r.last_name,''))) AS player,
    f.player_id AS mlbam_id,
    f.season,
    f.league,
    f.org,
    f.pa,
    f.bb,
    f.ibb,
    f.bb - f.ibb AS ubb,                       -- unintentional walks
    f.so
FROM        fcl_bb f
LEFT JOIN   Astros.Players r ON r.mlbam_id = f.player_id
ORDER BY    f.bb DESC, f.pa ASC;


-- SECTION 3 — JASE MITCHELL's CURRENT 2026 FCL LINE (live confirm) -------------
SELECT
    'Jase Mitchell' AS player,
    yb.season,
    MAX(t.league)            AS league,
    MAX(t.org_abbrev)        AS org,
    SUM(CAST(yb.pa  AS int)) AS pa,
    SUM(CAST(yb.bb  AS int)) AS bb,
    SUM(CAST(yb.ibb AS int)) AS ibb,
    SUM(CAST(yb.so  AS int)) AS so
FROM    MLBAM.YTD_Player_Batting_Stats yb
JOIN    MLBAM.Teams t
        ON t.team_id = yb.team_id AND t.season = yb.season
WHERE   yb.gm_type  = 'r'
  AND   yb.split_id = 0
  AND   yb.season   = 2026
  AND   yb.player_id = (SELECT mlbam_id FROM Astros.Players WHERE groundcontrol_id = 1293257)
GROUP BY yb.season;
