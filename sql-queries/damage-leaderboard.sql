-- Damage leaderboard at A+ (Tyler Whitaker's level) for 2025
-- Shows top 10 players by average Damage to verify 100th percentile

SELECT TOP 10
    hf.batter_id,
    COUNT(*) AS batted_balls,
    AVG(
        CASE WHEN hf.hit_initial_speed IS NOT NULL AND hf.hit_vertical_angle IS NOT NULL
                  AND hf.hit_initial_speed < 125
            THEN 1.6 * POWER(1.3,
                COS(-0.34) * (hf.hit_initial_speed - 98.0)
                - SIN(-0.34) * (hf.hit_vertical_angle - 27.0)
                - 0.02 * POWER(2 + SIN(-0.34) * (hf.hit_initial_speed - 98.0)
                                 + COS(-0.34) * (hf.hit_vertical_angle - 27.0), 2))
            / (7.0 + POWER(1.3,
                COS(-0.34) * (hf.hit_initial_speed - 98.0)
                - SIN(-0.34) * (hf.hit_vertical_angle - 27.0)
                - 0.02 * POWER(2 + SIN(-0.34) * (hf.hit_initial_speed - 98.0)
                                 + COS(-0.34) * (hf.hit_vertical_angle - 27.0), 2)))
            ELSE NULL END
    ) AS avg_damage
FROM MLBAM.Hit_fx hf
JOIN MLBAM.Schedule ms ON hf.game_pk = ms.GAME_PK
WHERE ms.SPORT = 'A+'
    AND ms.year = 2025
    AND hf.hit_initial_speed IS NOT NULL
    AND hf.hit_initial_speed < 125
    AND hf.hit_vertical_angle IS NOT NULL
GROUP BY hf.batter_id
HAVING COUNT(*) >= 30
ORDER BY avg_damage DESC;

-- Also check: how many qualifying batters total at A+ 2025?
SELECT COUNT(*) AS qualifying_batters
FROM (
    SELECT hf.batter_id
    FROM MLBAM.Hit_fx hf
    JOIN MLBAM.Schedule ms ON hf.game_pk = ms.GAME_PK
    WHERE ms.SPORT = 'A+'
        AND ms.year = 2025
        AND hf.hit_initial_speed IS NOT NULL
        AND hf.hit_initial_speed < 125
        AND hf.hit_vertical_angle IS NOT NULL
    GROUP BY hf.batter_id
    HAVING COUNT(*) >= 30
) sub;
