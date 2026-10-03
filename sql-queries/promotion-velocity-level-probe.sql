-- =========================================================================
-- promotion-velocity-level-probe.sql
-- (1) Find the gc2_level_code for short-season A ("A-") so we can map it to A.
--     Hunter Brown climbed through Tri-City (NY-Penn, A-) in 2019 -> his full
--     level history (NO level filter) reveals the code.
-- (2) Confirm WHY Trammell pins to HOU: show his complex/below-A games + org +
--     dates -> expect a recent HOU FCL rehab stint (the bug the dev-org fix kills).
-- Run + paste back 0, 1, 2.
-- =========================================================================
SET NOCOUNT ON;

-- 0. Resolve Hunter Brown ids (exact match; expect the HOU RHP)
SELECT groundcontrol_id, mlbam_id, first_name, last_name, throws
FROM Astros.Players
WHERE first_name = 'Hunter' AND last_name = 'Brown';

-- 1. Hunter Brown FULL level history, ALL gc2_level_codes (no IN filter) via pitching
--    gamelog. Look for the 2019 short-season row -> that gc2_level_code is "A-".
SELECT sv.year, sv.gc2_level_code, sv.level_code, sv.sched_type,
       UPPER(mt.org_abbrev) AS org,
       COUNT(*) AS games, MIN(sv.sched_date) AS first_g, MAX(sv.sched_date) AS last_g
FROM MLBAM.Gamelog_Pitching glp
JOIN Astros.Players p        ON p.mlbam_id = glp.player_id
JOIN Astros.Schedule_View sv ON sv.mlbam_game_pk = glp.game_pk
LEFT JOIN MLBAM.Teams mt     ON mt.team_id = glp.team_id AND mt.season = sv.year
WHERE p.first_name = 'Hunter' AND p.last_name = 'Brown'
GROUP BY sv.year, sv.gc2_level_code, sv.level_code, sv.sched_type, UPPER(mt.org_abbrev)
ORDER BY sv.year, sv.gc2_level_code;

-- 2. Trammell (gc 73618) FULL level history, ALL gc2_level_codes via batting gamelog.
--    Expect: 2016-17 CIN complex/rookie (his real developer) AND a recent HOU complex
--    (rok) rehab game -> the latter is what wrongly pinned him to HOU pre-fix.
SELECT sv.year, sv.gc2_level_code, sv.level_code, sv.sched_type,
       UPPER(mt.org_abbrev) AS org,
       COUNT(*) AS games, MIN(sv.sched_date) AS first_g, MAX(sv.sched_date) AS last_g
FROM MLBAM.Gamelog_Batting glb
JOIN Astros.Players p        ON p.mlbam_id = glb.player_id
JOIN Astros.Schedule_View sv ON sv.mlbam_game_pk = glb.game_pk
LEFT JOIN MLBAM.Teams mt     ON mt.team_id = glb.team_id AND mt.season = sv.year
WHERE p.groundcontrol_id = 73618
GROUP BY sv.year, sv.gc2_level_code, sv.level_code, sv.sched_type, UPPER(mt.org_abbrev)
ORDER BY sv.year, sv.gc2_level_code;
