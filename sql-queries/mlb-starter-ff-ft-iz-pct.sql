-- 2025 MLB Starters: Combined FF+FT Weighted IZ% (single number, all RHS+LHS)
-- "Starter" = pitcher on the first pitch of each team's pitching half in inning 1
--   (ROW_NUMBER keyed on sched_id + top_of_inning; avoids counting relievers
--    who entered mid-first-inning as starters)
-- IZ% = AVG(called_strike_chance) * 100 on that starter's FF/FT pitches
--   (weighted in-zone % by called strike chance, per astros-docs glossary)
-- Scope: MLB level, regular season, 2025, all 30 teams

WITH starters AS (
    SELECT sched_id, pitcher_id
    FROM (
        SELECT
            pv.sched_id,
            pv.pitcher_id,
            ROW_NUMBER() OVER (
                PARTITION BY pv.sched_id, ev.top_of_inning
                ORDER BY pv.game_pitch_number
            ) AS rn
        FROM Astros.Pitches_View pv
        JOIN Astros.Schedule_View sv
            ON sv.sched_id = pv.sched_id
        JOIN Astros.Events_View ev
            ON ev.sched_id = pv.sched_id
            AND ev.event_id = pv.ab_event_id
        WHERE sv.level_code = 'mlb'
          AND sv.sched_type = 'R'
          AND YEAR(sv.sched_date) = 2025
          AND pv.pitch_id > 0
          AND ev.inning = 1
    ) t
    WHERE rn = 1
)
SELECT
    AVG(pv.called_strike_chance) * 100.0 AS ff_ft_iz_pct,
    COUNT(*) AS total_pitches,
    COUNT(DISTINCT pv.pitcher_id) AS unique_starters
FROM Astros.Pitches_View pv
JOIN Astros.Schedule_View sv
    ON sv.sched_id = pv.sched_id
JOIN starters s
    ON s.sched_id = pv.sched_id
    AND s.pitcher_id = pv.pitcher_id
WHERE sv.level_code = 'mlb'
  AND sv.sched_type = 'R'
  AND YEAR(sv.sched_date) = 2025
  AND pv.pitch_id > 0
  AND pv.pitch_type IN ('FF', 'FT');
