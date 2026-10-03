-- ============================================================
-- MLBAM.PBP_Injury — current-season coverage probe
-- ============================================================
-- Goal: decide if MLBAM.PBP_Injury is worth using for an "injury TYPE"
-- label on the Injury Tracker. Round-2 verdict was "injury_type only, no
-- days/RTP" but the exact columns + 2026 volume were never captured.
-- Run on the WORK LAPTOP (DB access). Paste §1 + §2 back; §3/§4 guess the
-- season path (game_pk -> MLBAM.Schedule) — if §1 shows a direct date/season
-- column instead, use the alt forms noted under each.

-- ------------------------------------------------------------
-- §1 — columns (confirms structure: which col is injury_type, which is
--      the date/game/season key, which is player/team)
-- ------------------------------------------------------------
SELECT COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'MLBAM' AND TABLE_NAME = 'PBP_Injury'
ORDER BY ORDINAL_POSITION;

-- ------------------------------------------------------------
-- §2 — total rows + a 30-row sample (eyeball injury_type text + which
--      column carries the date/game_pk/season and the player/team)
-- ------------------------------------------------------------
SELECT COUNT(*) AS n_rows FROM MLBAM.PBP_Injury;
SELECT TOP 30 * FROM MLBAM.PBP_Injury;

-- ------------------------------------------------------------
-- §3 — rows per season (is it CURRENT? does 2026 have meaningful volume?)
--      Primary form: PBP_Injury has game_pk -> MLBAM.Schedule.year
-- ------------------------------------------------------------
SELECT sch.year AS season, COUNT(*) AS n_injury_events
FROM MLBAM.PBP_Injury pi
JOIN MLBAM.Schedule sch ON sch.game_pk = pi.game_pk
GROUP BY sch.year
ORDER BY sch.year DESC;
-- ALT (if §1 shows a direct date col, e.g. game_date):
--   SELECT YEAR(game_date) AS season, COUNT(*) AS n
--   FROM MLBAM.PBP_Injury GROUP BY YEAR(game_date) ORDER BY season DESC;
-- ALT (if §1 shows a direct season/year col):
--   SELECT season, COUNT(*) AS n FROM MLBAM.PBP_Injury GROUP BY season ORDER BY season DESC;

-- ------------------------------------------------------------
-- §4 — distinct injury_type values for the current season (how granular?
--      body part? mechanism? or just "injury"/"day-to-day" junk?)
--      EDIT <injury_type_col> to the real name from §1 if it isn't injury_type.
-- ------------------------------------------------------------
SELECT pi.injury_type, COUNT(*) AS n
FROM MLBAM.PBP_Injury pi
JOIN MLBAM.Schedule sch ON sch.game_pk = pi.game_pk
WHERE sch.year = 2026
GROUP BY pi.injury_type
ORDER BY n DESC;
