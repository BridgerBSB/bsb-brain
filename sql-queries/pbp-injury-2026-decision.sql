-- ============================================================
-- DECISION queries — is MLBAM.PBP_Injury CURRENT? + close out BPro
-- ============================================================
-- Columns now confirmed (1table.tsv): game_pk, player_id (MLBAM id),
-- team_id, injury_type(varchar50). No date col -> season via Schedule join.
-- Run on work laptop, paste all 3 back.

-- §A — PBP_Injury rows per season. THE decider: does 2026 have volume?
--      (Schedule.year may be `season` on some installs — swap if it errors.)
SELECT sch.year AS season,
       COUNT(*)                    AS n_injury_events,
       COUNT(DISTINCT pi.player_id) AS n_players
FROM MLBAM.PBP_Injury pi
JOIN MLBAM.Schedule sch ON sch.game_pk = pi.game_pk
GROUP BY sch.year
ORDER BY sch.year DESC;

-- §B — 2026 region mix (only meaningful if §A shows real 2026 rows).
--      Tells us how granular/useful the injury_type label is right now.
SELECT pi.injury_type, COUNT(*) AS n
FROM MLBAM.PBP_Injury pi
JOIN MLBAM.Schedule sch ON sch.game_pk = pi.game_pk
WHERE sch.year = 2026
GROUP BY pi.injury_type
ORDER BY n DESC;

-- §C — definitively close out BPro: what's its real max year?
--      (Confirms the "frozen at 2014" finding — settles whether a future
--       historical retro is the only use.)
SELECT YEAR(date_on) AS yr, COUNT(*) AS n
FROM SportsMed.Injury_Data_BPro
GROUP BY YEAR(date_on)
ORDER BY yr DESC;
