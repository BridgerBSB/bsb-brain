---
tags:
  - sql
  - mlbam
created: '2026-06-15'
---
# Texas League — Runs Scored (weekly)

One-off for [[Sam]] (Jun 2026). Canonical file:
`bsb-resources/sql-queries/texas-league-runs-scored-weekly.sql`.

**Gotcha (the whole reason it errored first):** AA = SPORT `'aax'` spans THREE
leagues (Texas / Southern / Eastern). Discriminate on **`MLBAM.Schedule.LEAGUE_ID = 109`**
(Texas League). The char `LEAGUE` column is **NOT** `'TL'` — confirmed empty; use the
numeric id. "Runs scored" = batter `R` (not RBI).

Source: `MLBAM.Gamelog_Batting` (per-game R) → `MLBAM.Schedule` (date + league),
`gamelog.player_id = Astros.Players.mlbam_id` (names), `gamelog.team_id = MLBAM.Teams.team_id (+season)`.

```sql
-- Player leaderboard, last 7 days
SET NOCOUNT ON;
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
  AND sch.GAME_TYPE = 'R'
  AND sch.GAMEDATE BETWEEN @start AND @end
GROUP BY ply.first_name, ply.last_name, glb.player_id, tm.name_abbrev
ORDER BY runs DESC, hr DESC, pa ASC;
```

A team/org rank variant (with `games` after `org`, `RANK() OVER (ORDER BY runs DESC)`)
is in the same canonical file.

Links: [[Sam]]
