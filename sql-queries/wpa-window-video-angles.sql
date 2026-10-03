/* ============================================================================
   WPA Window Leaderboard — ALL camera angles as separate URL columns
   ----------------------------------------------------------------------------
   Mirrors the `--2-week` HOU leaderboard PDF (generate_wpa_plays.py --2-week):
   the same top-N non-strikeout offensive + defensive HOU plays over a trailing
   window. But instead of ONE resolved video link, every camera angle gets its
   own column so you can copy/paste and hunt for a working clip when the M
   (Main CF) angle is missing.

   HOU MLB only. Edit @end / @top / level as needed.
   T-SQL (SQL Server / GroundControl2).
   ============================================================================ */

DECLARE @end   DATE = '2026-06-16';                 -- window end (inclusive)
DECLARE @start DATE = DATEADD(DAY, -13, @end);      -- 14-day window inclusive
DECLARE @top   INT  = 10;                            -- plays per side
DECLARE @level VARCHAR(8) = 'mlb';

;WITH hou_games AS (
    SELECT DISTINCT sv.sched_id
    FROM Astros.Schedule_View sv
    JOIN mlbam.teams t
        ON (t.team_id = sv.home_team_mlbam_id OR t.team_id = sv.away_team_mlbam_id)
       AND t.season = sv.year
    WHERE sv.sched_date BETWEEN @start AND @end
      AND sv.sched_type = 'R'
      AND sv.level_code = @level
      AND UPPER(t.org_abbrev) = 'HOU'
),
events AS (
    SELECT
        wp.sched_id, wp.event_id,
        CAST(sv.sched_date AS DATE) AS game_date,
        ev.inning, ev.top_of_inning,
        UPPER(bt.org_abbrev) AS org_bat,
        UPPER(ft.org_abbrev) AS org_fld,
        CAST(ISNULL(ev.so, 0) AS int) AS is_k,
        ev.play_by_play,
        CASE WHEN ev.top_of_inning = 1 THEN -wp.home_team_wpa
             ELSE  wp.home_team_wpa END AS bat_wpa,
        CASE WHEN ev.top_of_inning = 1 THEN  wp.home_team_wpa
             ELSE -wp.home_team_wpa END AS fld_wpa,
        lp.pitch_id, lp.batter_id, lp.pitcher_id
    FROM Astros.Win_Probability wp
    JOIN hou_games hg ON hg.sched_id = wp.sched_id
    JOIN Astros.Events_View ev
        ON ev.sched_id = wp.sched_id AND ev.event_id = wp.event_id
    JOIN Astros.Schedule_View sv ON sv.sched_id = wp.sched_id
    JOIN mlbam.teams bt ON bt.team_id = ev.batting_team_id  AND bt.season = sv.year
    JOIN mlbam.teams ft ON ft.team_id = ev.fielding_team_id AND ft.season = sv.year
    OUTER APPLY (
        SELECT TOP 1 pv.pitch_id, pv.batter_id, pv.pitcher_id
        FROM Astros.Pitches_View pv
        WHERE pv.sched_id = wp.sched_id
          AND pv.cur_event_id = wp.event_id
        ORDER BY pv.game_pitch_number DESC
    ) lp
    WHERE wp.home_team_wpa IS NOT NULL
),
top_off AS (   -- HOU batting, non-K, biggest positive bat_wpa
    SELECT TOP (@top) 'OFFENSE' AS side, e.*, e.bat_wpa AS wpa
    FROM events e
    WHERE e.org_bat = 'HOU' AND e.is_k = 0
    ORDER BY e.bat_wpa DESC
),
top_def AS (   -- HOU fielding, non-K, biggest positive fld_wpa
    SELECT TOP (@top) 'DEFENSE' AS side, e.*, e.fld_wpa AS wpa
    FROM events e
    WHERE e.org_fld = 'HOU' AND e.is_k = 0
    ORDER BY e.fld_wpa DESC
),
picks AS (
    SELECT * FROM top_off
    UNION ALL
    SELECT * FROM top_def
)
SELECT
    p.side,
    p.game_date,
    CASE WHEN p.side = 'OFFENSE' THEN p.org_bat ELSE p.org_fld END AS team,
    CASE WHEN p.side = 'OFFENSE' THEN p.org_fld ELSE p.org_bat END AS opp,
    CONCAT(CASE WHEN p.top_of_inning = 1 THEN 'T' ELSE 'B' END, p.inning) AS inn,
    CAST(p.wpa * 100.0 AS decimal(5,1)) AS wpa_pct,
    LTRIM(RTRIM(CONCAT(ISNULL(bp.first_name, ''), ' ',
                       ISNULL(bp.last_name, '')))) AS batter,
    LTRIM(RTRIM(CONCAT(ISNULL(pp.first_name, ''), ' ',
                       ISNULL(pp.last_name, '')))) AS pitcher,
    p.play_by_play AS [description],

    -- ===== Video URLs, one column per camera angle =====
    -- Resolution priority in the PDF: M -> B -> X -> sportyCF1 -> a -> v
    vn_m.video_url  AS url_M_mainCF,        -- Video_Network 'M'  (Sam's pick)
    vn_b.video_url  AS url_VN_B,            -- 1st fallback after M (MLB)
    vn_x.video_url  AS url_VN_X,            -- 2nd fallback after M (MLB)
    av1.video_url   AS url_sportyCF1,       -- Astros.Video angle_id=1 (always MLB)
    av2.video_url   AS url_sportyCF2,       -- Astros.Video angle_id=2
    vn_a.video_url  AS url_VN_a_CFbroadcast,
    vn_v.video_url  AS url_VN_v_CFbackup,
    vn_h.video_url  AS url_VN_H_highHome,
    vn_f.video_url  AS url_VN_F_1Bhigh,
    vn_7.video_url  AS url_VN_7_3Bhigh,
    vn_5.video_url  AS url_VN_5_sideMid1B,
    vn_6.video_url  AS url_VN_6_sideMid3B
FROM picks p
LEFT JOIN Astros.Players bp ON bp.groundcontrol_id = p.batter_id
LEFT JOIN Astros.Players pp ON pp.groundcontrol_id = p.pitcher_id
LEFT JOIN Astros.Video         av1  ON av1.sched_id  = p.sched_id AND av1.pitch_id  = p.pitch_id AND av1.angle_id = 1
LEFT JOIN Astros.Video         av2  ON av2.sched_id  = p.sched_id AND av2.pitch_id  = p.pitch_id AND av2.angle_id = 2
LEFT JOIN Astros.Video_Network vn_m ON vn_m.sched_id = p.sched_id AND vn_m.pitch_id = p.pitch_id AND vn_m.angle = 'M'
LEFT JOIN Astros.Video_Network vn_b ON vn_b.sched_id = p.sched_id AND vn_b.pitch_id = p.pitch_id AND vn_b.angle = 'B'
LEFT JOIN Astros.Video_Network vn_x ON vn_x.sched_id = p.sched_id AND vn_x.pitch_id = p.pitch_id AND vn_x.angle = 'X'
LEFT JOIN Astros.Video_Network vn_a ON vn_a.sched_id = p.sched_id AND vn_a.pitch_id = p.pitch_id AND vn_a.angle = 'a'
LEFT JOIN Astros.Video_Network vn_v ON vn_v.sched_id = p.sched_id AND vn_v.pitch_id = p.pitch_id AND vn_v.angle = 'v'
LEFT JOIN Astros.Video_Network vn_h ON vn_h.sched_id = p.sched_id AND vn_h.pitch_id = p.pitch_id AND vn_h.angle = 'H'
LEFT JOIN Astros.Video_Network vn_f ON vn_f.sched_id = p.sched_id AND vn_f.pitch_id = p.pitch_id AND vn_f.angle = 'F'
LEFT JOIN Astros.Video_Network vn_7 ON vn_7.sched_id = p.sched_id AND vn_7.pitch_id = p.pitch_id AND vn_7.angle = '7'
LEFT JOIN Astros.Video_Network vn_5 ON vn_5.sched_id = p.sched_id AND vn_5.pitch_id = p.pitch_id AND vn_5.angle = '5'
LEFT JOIN Astros.Video_Network vn_6 ON vn_6.sched_id = p.sched_id AND vn_6.pitch_id = p.pitch_id AND vn_6.angle = '6'
ORDER BY p.side, p.wpa DESC;
