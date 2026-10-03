-- Jase Mitchell (gc_id 1293257) -- FCL 2026 regular season
-- Game-by-game NetK (net, not per-pitch) + running season total.
--
-- NetK per game = SUM(pv.net_k) on edge-zone CALLED pitches:
--   called_strike_chance > 0.05 AND < 0.95, pitch_result_id IN (4,5,6),
--   pitch_id > 0, ignore_flag = 0.
-- Mirrors the canonical per-catcher NetK gate in
-- intangibles/src/catching_tracker_data.py (_NETK_QUERY / leaderboard
-- total_netk, line ~1222) -- raw called_strike_chance (NOT _mlb), pv.net_k.
-- So netk_after of the last game == his displayed FCL 2026 season NetK.
--
-- The edge/pitch_result gate is ONLY in the CASE (not the WHERE), so EVERY
-- regular-season FCL game he caught appears -- a game with no qualifying
-- edge pitches simply shows game_netk = 0 (no effect on the total that day).
-- FCL = gc2_level_code = 'rok'. Doubleheaders show as two rows (per sched_id).

WITH game_netk AS (
    SELECT
        sv.sched_id,
        CAST(sv.sched_date AS date) AS game_date,
        SUM(CASE WHEN pv.called_strike_chance > 0.05
                      AND pv.called_strike_chance < 0.95
                      AND pv.pitch_result_id IN (4, 5, 6)
                 THEN pv.net_k ELSE 0 END) AS game_netk,
        -- verification: total pitches he caught + how many qualified for NetK.
        -- edge_pitches = 0 => no framing data that game (likely non-HawkEye
        -- FCL venue), so game_netk = 0 is "no data", not "no impact".
        COUNT(*) AS pitches_caught,
        SUM(CASE WHEN pv.called_strike_chance > 0.05
                      AND pv.called_strike_chance < 0.95
                      AND pv.pitch_result_id IN (4, 5, 6)
                 THEN 1 ELSE 0 END) AS edge_pitches
    FROM Astros.Pitches_View pv
    JOIN Astros.Events_View ev
        ON pv.sched_id = ev.sched_id
        AND pv.ab_event_id = ev.event_id
    JOIN Astros.Schedule_View sv
        ON pv.sched_id = sv.sched_id
    WHERE ev.c_id = 1293257
      AND sv.gc2_level_code = 'rok'        -- FCL
      AND YEAR(sv.sched_date) = 2026
      AND sv.sched_type = 'R'              -- regular season
      AND pv.pitch_id > 0
      AND pv.ignore_flag = 0
    GROUP BY sv.sched_id, CAST(sv.sched_date AS date)
)
SELECT
    'Jase Mitchell' AS player,
    game_date,
    pitches_caught,
    edge_pitches,
    ROUND(game_netk, 2) AS game_netk,
    ROUND(ISNULL(SUM(game_netk) OVER (
        ORDER BY game_date, sched_id
        ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING), 0), 2) AS netk_before,
    ROUND(SUM(game_netk) OVER (
        ORDER BY game_date, sched_id
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW), 2) AS netk_after
FROM game_netk
ORDER BY game_date, sched_id;

-- Cross-check the GAME COUNT against his catching appearances (independent of
-- pitch data) -- run separately; should equal the row count above:
-- SELECT COUNT(DISTINCT pg.sched_id) AS catching_games
-- FROM Astros.Players_Games pg
-- JOIN Astros.Schedule_View sv ON pg.sched_id = sv.sched_id
-- WHERE pg.groundcontrol_id = 1293257 AND pg.pos_id = 2
--   AND sv.gc2_level_code = 'rok' AND YEAR(sv.sched_date) = 2026
--   AND sv.sched_type = 'R';
