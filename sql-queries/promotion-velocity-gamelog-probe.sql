-- =========================================================================
-- promotion-velocity-gamelog-probe.sql
-- Confirm MLBAM.Gamelog_Batting/_Pitching as the per-game source for the
-- promotion-velocity rewrite (fixes PA undercount + detector dates + org).
-- Join chain: Gamelog.game_pk = Schedule_View.mlbam_game_pk;
--             Gamelog.player_id = Astros.Players.mlbam_id (per ip-calculation.md).
-- Test players: Yordan 75884 (H, expect DSL 2016 = 57), Mayer 176229 (P).
-- Run + paste back A, B, C, D, E.
-- =========================================================================
SET NOCOUNT ON;

-- A. Full column list — Gamelog_Batting (need: pa, team_id, level?, gm_type?)
SELECT COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'MLBAM' AND TABLE_NAME = 'Gamelog_Batting'
ORDER BY ORDINAL_POSITION;

-- B. Full column list — Gamelog_Pitching (confirm outs + team_id)
SELECT COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'MLBAM' AND TABLE_NAME = 'Gamelog_Pitching'
ORDER BY ORDINAL_POSITION;

-- C. Yordan per (season, gc2_level) PA via Gamelog->Schedule_View, regular
--    season only. EXPECT: 2016 dsl = 57 (vs our pitch-derived 19).
--    NOTE: if Gamelog_Batting has no `pa`, this errors -> A tells us the
--    real column name; re-run with it.
SELECT sv.year AS season,
       sv.gc2_level_code AS level,
       sv.sched_type,
       SUM(CAST(glb.pa AS int)) AS pa,
       COUNT(*) AS games
FROM MLBAM.Gamelog_Batting glb
JOIN Astros.Players ply ON ply.mlbam_id = glb.player_id
JOIN Astros.Schedule_View sv ON sv.mlbam_game_pk = glb.game_pk
WHERE ply.groundcontrol_id = 75884
GROUP BY sv.year, sv.gc2_level_code, sv.sched_type
ORDER BY sv.year, sv.gc2_level_code;

-- D. Per-GAME peek for Yordan (one row per game) — confirms we have
--    sched_date + level + a team id for per-game org attribution.
--    Adjust SELECTed cols if A shows different names (team_id may be
--    'team_id' or absent -> then derive org from Schedule home/away).
SELECT TOP 25
       sv.sched_date, sv.year, sv.gc2_level_code AS level, sv.sched_type,
       glb.team_id,
       glb.pa
FROM MLBAM.Gamelog_Batting glb
JOIN Astros.Players ply ON ply.mlbam_id = glb.player_id
JOIN Astros.Schedule_View sv ON sv.mlbam_game_pk = glb.game_pk
WHERE ply.groundcontrol_id = 75884
ORDER BY sv.sched_date;

-- E. Mayer pitcher per (season, gc2_level) IP (outs/3) via Gamelog_Pitching.
--    Confirms pitcher path stays correct on the same source.
SELECT sv.year AS season,
       sv.gc2_level_code AS level,
       sv.sched_type,
       SUM(CAST(glp.outs AS int)) AS outs,
       COUNT(*) AS appearances
FROM MLBAM.Gamelog_Pitching glp
JOIN Astros.Players ply ON ply.mlbam_id = glp.player_id
JOIN Astros.Schedule_View sv ON sv.mlbam_game_pk = glp.game_pk
WHERE ply.groundcontrol_id = 176229
GROUP BY sv.year, sv.gc2_level_code, sv.sched_type
ORDER BY sv.year, sv.gc2_level_code;
