-- Sugar Land LA/EV matrix — venue verification
-- Run on work laptop to confirm the home-team filter actually pulls
-- Constellation Field games (and not some other AAA park).
--
-- Three checks:
-- 1. Schedule_View columns — does it have venue info on its own?
-- 2. List distinct venue names for the games we're pulling
-- 3. Per-year game counts at Constellation Field vs. anywhere else
--
-- If any games show up at a non-Sugar-Land venue, the home-team
-- filter has a hole. Otherwise we're clean.

-- 1. What columns does Schedule_View expose? Look for any venue/park/stadium.
SELECT COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'Astros' AND TABLE_NAME = 'Schedule_View'
  AND (
    COLUMN_NAME LIKE '%venue%'
    OR COLUMN_NAME LIKE '%park%'
    OR COLUMN_NAME LIKE '%stadium%'
    OR COLUMN_NAME LIKE '%location%'
  )
ORDER BY COLUMN_NAME;

-- 2. MLBAM.Schedule columns (likely the venue source)
SELECT COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'MLBAM' AND TABLE_NAME = 'Schedule'
  AND (
    COLUMN_NAME LIKE '%venue%'
    OR COLUMN_NAME LIKE '%park%'
    OR COLUMN_NAME LIKE '%stadium%'
    OR COLUMN_NAME LIKE '%location%'
  )
ORDER BY COLUMN_NAME;

-- 3. Distinct venue names for the games our matrix would pull
--    (replace `venue_name` below with whatever column the queries above surface)
--    This assumes MLBAM.Schedule has venue_name + matches sched_id via mlbam_game_pk.
SELECT
    DISTINCT
    sv.year,
    ms.venue_id,
    ms.venue_name,
    COUNT(DISTINCT sv.sched_id) AS games
FROM Astros.Schedule_View sv
JOIN MLBAM.Teams home_mt
    ON home_mt.team_id = sv.home_team_mlbam_id
   AND home_mt.season = sv.year
LEFT JOIN MLBAM.Schedule ms
    ON sv.mlbam_game_pk = ms.game_pk
WHERE sv.level_code = 'aaa'
  AND sv.sched_type = 'R'
  AND UPPER(home_mt.org_abbrev) = 'HOU'
  AND YEAR(sv.sched_date) BETWEEN 2021 AND 2026
GROUP BY sv.year, ms.venue_id, ms.venue_name
ORDER BY sv.year, games DESC;

-- 4. Per-year totals as a sanity check on game counts
--    (Sugar Land plays ~75 home regular-season games per year)
SELECT
    sv.year,
    COUNT(DISTINCT sv.sched_id) AS home_games,
    MIN(sv.sched_date) AS first_home_game,
    MAX(sv.sched_date) AS last_home_game
FROM Astros.Schedule_View sv
JOIN MLBAM.Teams home_mt
    ON home_mt.team_id = sv.home_team_mlbam_id
   AND home_mt.season = sv.year
WHERE sv.level_code = 'aaa'
  AND sv.sched_type = 'R'
  AND UPPER(home_mt.org_abbrev) = 'HOU'
  AND YEAR(sv.sched_date) BETWEEN 2021 AND 2026
GROUP BY sv.year
ORDER BY sv.year;
