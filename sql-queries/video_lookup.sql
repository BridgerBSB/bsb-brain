-- Video URL Lookup
-- ================
-- Query pitch video from Astros.Video_Network for any schedule IDs.
--
-- Camera angles (from assistant director's working "Nasty Opposing Pitch Grips" query):
--   'a' = CF Angle (primary broadcast camera)
--   'v' = CF Angle fallback (used when 'a' is NULL)
--   '5' = CF Edge (secondary angle)
--
-- CF Angle uses ISNULL pattern: try 'a' first, fall back to 'v'.
--
-- Join pattern: Video_Network ON sched_id + pitch_id
-- No dependency on GroundControlTracking tables.
--
-- NOTE: Bullpen sessions (sched_type='B') do NOT have video in the database.
-- Video is only available for game data (R, S, E, V, I schedule types).

-- Basic: all pitches with video for a given game
SELECT
    pv.sched_id,
    pv.pitch_id,
    pv.pitcher_pitch_number,
    pv.pitch_type,
    pv.release_speed,
    ISNULL(vn_a.video_url, vn_v.video_url)  AS cf_angle_url,
    vn_5.video_url                           AS cf_edge_url
FROM Astros.Pitches_View pv
JOIN Astros.Schedule_View sv ON pv.sched_id = sv.sched_id
LEFT JOIN Astros.Video_Network vn_a
    ON vn_a.sched_id = pv.sched_id
    AND vn_a.pitch_id = pv.pitch_id
    AND vn_a.angle = 'a'
LEFT JOIN Astros.Video_Network vn_v
    ON vn_v.sched_id = pv.sched_id
    AND vn_v.pitch_id = pv.pitch_id
    AND vn_v.angle = 'v'
LEFT JOIN Astros.Video_Network vn_5
    ON vn_5.sched_id = pv.sched_id
    AND vn_5.pitch_id = pv.pitch_id
    AND vn_5.angle = '5'
WHERE pv.pitcher_id = :pitcher_id          -- or batter_id for hitter view
  AND CAST(sv.sched_date AS DATE) = :game_date
  AND sv.sched_type IN ('R','S','E','V','I')
  AND pv.ignore_flag = 0
  AND pv.pitch_id > 0
ORDER BY pv.pitcher_pitch_number;
