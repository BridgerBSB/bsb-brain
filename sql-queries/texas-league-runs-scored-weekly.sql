-- =========================================================================
-- Texas League -- Runs Scored leaders, THIS WEEK  (Sam ask, Jun 2026)
-- Source: MLBAM.Gamelog_Batting (per-game R) -> MLBAM.Schedule (date + league)
--   gamelog.player_id = Astros.Players.mlbam_id  (names; LEFT JOIN, league-wide)
--   gamelog.team_id   = MLBAM.Teams.team_id (+season)  (team label)
-- "Runs scored" = batter R (not RBI). AA = SPORT 'aax'; Texas League is ONE
-- of three AA leagues (also Southern + Eastern).
-- Discriminate on MLBAM.Schedule.LEAGUE_ID = 109 (Texas League). The char
-- LEAGUE column is NOT 'TL' -- confirmed Jun 2026, use the numeric id.
-- ASCII-only (non-ASCII comment chars can break some SQL clients).
-- =========================================================================
SET NOCOUNT ON;

-- Window: default = last 7 days. Set to the exact Tue-Sun if you prefer.
DECLARE @start date = DATEADD(day, -6, CAST(GETDATE() AS date));
DECLARE @end   date = CAST(GETDATE() AS date);
DECLARE @league_id int = 109;   -- Texas League (AA)

SELECT
    COALESCE(ply.first_name + ' ' + ply.last_name, CONCAT('mlbam ', glb.player_id)) AS player,
    tm.name_abbrev           AS team,
    SUM(CAST(glb.r  AS int)) AS runs,
    SUM(CAST(glb.h  AS int)) AS hits,
    SUM(CAST(glb.hr AS int)) AS hr,
    SUM(CAST(glb.bb AS int)) AS bb,
    SUM(CAST(glb.pa AS int)) AS pa,
    COUNT(*)                 AS games
FROM MLBAM.Gamelog_Batting glb
JOIN MLBAM.Schedule sch ON sch.GAME_PK = glb.game_pk
LEFT JOIN MLBAM.Teams tm ON tm.team_id = glb.team_id AND tm.season = sch.[YEAR]
LEFT JOIN Astros.Players ply ON ply.mlbam_id = glb.player_id
WHERE sch.LEAGUE_ID = @league_id
  AND sch.GAME_TYPE = 'R'                       -- regular season only
  AND sch.GAMEDATE BETWEEN @start AND @end
GROUP BY ply.first_name, ply.last_name, glb.player_id, tm.name_abbrev
ORDER BY runs DESC, hr DESC, pa ASC;


-- =========================================================================
-- TEAM / ORG runs-scored rank -- same window + league.
-- runs = SUM of every batter's R for that club (= team runs scored).
-- =========================================================================
DECLARE @start2 date = DATEADD(day, -6, CAST(GETDATE() AS date));
DECLARE @end2   date = CAST(GETDATE() AS date);
DECLARE @league_id2 int = 109;   -- Texas League (AA)

SELECT
    tm.name_abbrev          AS team,
    tm.org_abbrev           AS org,
    COUNT(DISTINCT glb.game_pk) AS games,
    SUM(CAST(glb.r AS int)) AS runs,
    RANK() OVER (ORDER BY SUM(CAST(glb.r AS int)) DESC) AS [rank]
FROM MLBAM.Gamelog_Batting glb
JOIN MLBAM.Schedule sch ON sch.GAME_PK = glb.game_pk
JOIN MLBAM.Teams tm ON tm.team_id = glb.team_id AND tm.season = sch.[YEAR]
WHERE sch.LEAGUE_ID = @league_id2
  AND sch.GAME_TYPE = 'R'
  AND sch.GAMEDATE BETWEEN @start2 AND @end2
GROUP BY tm.name_abbrev, tm.org_abbrev
ORDER BY runs DESC;
