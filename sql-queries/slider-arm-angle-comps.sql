-- Find pitchers with slider arm angle 33-38, SL velo > 85, avg FF velo < 95
-- Comp group for Jason Alexander (gcid 79537, ~35° SL arm angle)
WITH arm_angle_calc AS (
    SELECT
        pv.pitcher_id,
        p.first_name + ' ' + p.last_name AS pitcher_name,
        p.throws,
        sv.gc2_level_code,
        AVG(
            -16.4 +
            1.1 * (90.0 -
                CASE WHEN p.throws = 'L' THEN 180.0/PI() ELSE -180.0/PI() END *
                ATN2(pht.pitch_release_pos_x - pos.x_at_pitch_release,
                     pht.pitch_release_pos_z -
                     SQRT(CASE WHEN
                        POWER((CAST(mp.height_feet AS float) + CAST(mp.height_inches AS float)/12.0) * 0.75, 2) -
                        POWER((60.5 - pos.y_at_pitch_release) * 0.85, 2) < 0
                     THEN 0 ELSE
                        POWER((CAST(mp.height_feet AS float) + CAST(mp.height_inches AS float)/12.0) * 0.75, 2) -
                        POWER((60.5 - pos.y_at_pitch_release) * 0.85, 2)
                     END))
            + -0.001 * POWER(90.0 -
                CASE WHEN p.throws = 'L' THEN 180.0/PI() ELSE -180.0/PI() END *
                ATN2(pht.pitch_release_pos_x - pos.x_at_pitch_release,
                     pht.pitch_release_pos_z -
                     SQRT(CASE WHEN
                        POWER((CAST(mp.height_feet AS float) + CAST(mp.height_inches AS float)/12.0) * 0.75, 2) -
                        POWER((60.5 - pos.y_at_pitch_release) * 0.85, 2) < 0
                     THEN 0 ELSE
                        POWER((CAST(mp.height_feet AS float) + CAST(mp.height_inches AS float)/12.0) * 0.75, 2) -
                        POWER((60.5 - pos.y_at_pitch_release) * 0.85, 2)
                     END)), 2)
        ) AS sl_arm_angle,
        AVG(pv.release_speed) AS avg_sl_velo,
        COUNT(*) AS sl_pitches
    FROM Astros.Pitches_View pv
    JOIN Astros.Schedule_View sv ON pv.sched_id = sv.sched_id
    JOIN Astros.Players p ON pv.pitcher_id = p.groundcontrol_id
    JOIN groundcontroltracking.tracking.pitch_hit_trajectories pht
        ON pht.sched_id = pv.sched_id AND pht.tracking_play_id = pv.pitch_id
    JOIN groundcontroltracking.tracking.play_starting_positions pos
        ON pos.sched_id = pv.sched_id AND pos.pitch_id = pv.pitch_id
        AND pos.groundcontrol_id = pv.pitcher_id
    JOIN mlbam.players mp ON p.mlbam_id = mp.player_id
    WHERE pv.pitch_type = 'SL'
      AND pv.pitch_id > 0
      AND YEAR(sv.sched_date) = 2025
      AND sv.sched_type = 'R'
    GROUP BY pv.pitcher_id, p.first_name, p.last_name, p.throws, sv.gc2_level_code
    HAVING COUNT(*) >= 30
),
ff_velo AS (
    SELECT
        pv.pitcher_id,
        AVG(pv.release_speed) AS avg_ff_velo,
        COUNT(*) AS ff_pitches
    FROM Astros.Pitches_View pv
    JOIN Astros.Schedule_View sv ON pv.sched_id = sv.sched_id
    WHERE pv.pitch_type IN ('FF', 'FA')
      AND pv.pitch_id > 0
      AND YEAR(sv.sched_date) = 2025
      AND sv.sched_type = 'R'
    GROUP BY pv.pitcher_id
)
SELECT
    a.pitcher_id,
    a.pitcher_name,
    a.throws,
    a.gc2_level_code,
    ROUND(a.sl_arm_angle, 1) AS sl_arm_angle,
    ROUND(a.avg_sl_velo, 1) AS avg_sl_velo,
    a.sl_pitches,
    ROUND(f.avg_ff_velo, 1) AS avg_ff_velo,
    f.ff_pitches
FROM arm_angle_calc a
JOIN ff_velo f ON a.pitcher_id = f.pitcher_id
WHERE a.sl_arm_angle BETWEEN 33 AND 38
  AND a.avg_sl_velo > 85
  AND f.avg_ff_velo < 95
ORDER BY a.sl_arm_angle
