-- Kyle Funkhouser (TEX AAA) — INT level audit for advance diagnostics
-- Purpose: before deciding whether to relax Barrelsville's advance int-level
-- filter, check whether Funkhouser has ANY int pitches in the last year
-- (and what sched_types they fall under).
--
-- Run on: GCSQL02 / GroundControl2 (work laptop)
-- Convention: pv.pitcher_id = Astros.Players.groundcontrol_id (NOT mlbam_id).
--             See .claude/rules/db-columns.md.
-- ---------------------------------------------------------------------------

-- =====================================================================
-- Step 1 — Confirm who we have (guard against duplicates / typos)
-- =====================================================================
SELECT TOP 5
    groundcontrol_id,
    ebis_id,
    mlbam_id,
    first_name,
    last_name,
    birthdate,
    throws
FROM Astros.Players
WHERE first_name = 'Kyle'
  AND last_name  = 'Funkhouser'
ORDER BY groundcontrol_id;


-- =====================================================================
-- Step 2 — Last-year pitch activity by (year, level, sched_type)
-- Shows EVERY level+sched bucket so we can see what int actually contains.
-- =====================================================================
SELECT
    sv.year,
    sv.level_code,
    sv.gc2_level_code,
    sv.sched_type,
    COUNT(*)                    AS pitches,
    COUNT(DISTINCT pv.sched_id) AS games,
    MIN(sv.sched_date)          AS first_date,
    MAX(sv.sched_date)          AS last_date
FROM Astros.Pitches_View  pv
JOIN Astros.Schedule_View sv ON sv.sched_id = pv.sched_id
JOIN Astros.Players       p  ON p.groundcontrol_id = pv.pitcher_id
WHERE p.first_name = 'Kyle'
  AND p.last_name  = 'Funkhouser'
  AND sv.sched_date >= DATEADD(YEAR, -1, GETDATE())
GROUP BY sv.year, sv.level_code, sv.gc2_level_code, sv.sched_type
ORDER BY sv.year DESC, sv.level_code, sv.sched_type;


-- =====================================================================
-- Step 3 — INT-only game list (only runs if step 2 shows int rows)
-- Gives you a feel for what these games actually are (venue, opponent).
-- =====================================================================
SELECT TOP 50
    sv.year,
    sv.sched_date,
    sv.sched_type,
    sv.level_code,
    sv.gc2_level_code,
    sv.sched_id,
    sv.home_team_mlbam_id,
    sv.away_team_mlbam_id,
    COUNT(*) AS pitches
FROM Astros.Pitches_View  pv
JOIN Astros.Schedule_View sv ON sv.sched_id = pv.sched_id
JOIN Astros.Players       p  ON p.groundcontrol_id = pv.pitcher_id
WHERE p.first_name = 'Kyle'
  AND p.last_name  = 'Funkhouser'
  AND sv.level_code = 'int'
  AND sv.sched_date >= DATEADD(YEAR, -1, GETDATE())
GROUP BY sv.year, sv.sched_date, sv.sched_type, sv.level_code,
         sv.gc2_level_code, sv.sched_id, sv.home_team_mlbam_id, sv.away_team_mlbam_id
ORDER BY sv.sched_date DESC;
