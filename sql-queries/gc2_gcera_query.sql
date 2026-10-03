-- gcERA Formula — from GC2 Production (Pitcher Event View)
-- =========================================================
-- Extracted Feb 15, 2026 for percentile implementation.
--
-- gcERA is a per-game metric computed at the pitch level (weighted by
-- pitches per PA). The formula uses PA outcomes (SO, BB, HBP, BIP)
-- and pBarrel status, scaled by a league-wide HR rate.
--
-- Formula:
--   gcERA = (3.9 + 31.1 * lg_HR_rate) * BIP_rate * pBarrel_rate
--         + 3.5 * BIP_rate * (1 - pBarrel_rate)
--         + (-3.3) * SO_rate
--         + 9.9 * BB_HBP_rate
--
-- GC2 Event query: FROM Events_View LEFT JOIN Pitches ON cur_event_id
-- → one row per PA → rates are PA-weighted (count/BF), NOT pitch-weighted.
--
-- HR rate source: mlbam.ytd_team_pitching_stats
--   - level='mlb', gm_type='r', split_id=0, team_id=0
--   - If current year before May, uses prior year
--
-- HitsNoBunts filters:
--   - pitch_result_id IN (12,13,14) — BIP only
--   - hit_trajectory_id NOT IN (2,3,4) — exclude bunts
--   - NOT (hit_vertical_angle < -25 AND level IN hsb/sum/bbc) — exclude extreme LA at low levels
--   - hit_exit_speed < 125 — EV cap
--
-- pBarrel formula: EV >= 0.011 * LA^2 - 0.91 * LA + 95.0

-- === GC2 gcERA expression (Event-level query, GROUP BY pitcher_id + sched_id) ===
-- Inline in the SELECT:

(3.9 + 31.1 * cast(avg(YtdLeaguePitching.hr) as float)
              / cast(avg(YtdLeaguePitching.hr) + avg(YtdLeaguePitching.ao) as float))
  * coalesce(
      avg(case when CurEvents.pa = 1
               then case when CurEvents.so | CurEvents.bb | CurEvents.hbp = 0
                         then 1.0 else 0.0 end end)
      * avg(case when HitsNoBunts.hit_exit_speed is not null
                 then (case when HitsNoBunts.hit_exit_speed
                                >= 0.011 * power(HitsNoBunts.hit_vertical_angle, 2)
                                   - 0.91 * HitsNoBunts.hit_vertical_angle + 95.0
                            then 1.0 else 0.0 end)
                 else null end)
    , 0)
+ 3.5
  * coalesce(
      avg(case when CurEvents.pa = 1
               then case when CurEvents.so | CurEvents.bb | CurEvents.hbp = 0
                         then 1.0 else 0.0 end end)
      * avg(case when HitsNoBunts.hit_exit_speed is not null
                 then (case when HitsNoBunts.hit_exit_speed
                                >= 0.011 * power(HitsNoBunts.hit_vertical_angle, 2)
                                   - 0.91 * HitsNoBunts.hit_vertical_angle + 95.0
                            then 0.0 else 1.0 end)
                 else null end)
    , 0)
+ (-3.3)
  * avg(case when CurEvents.pa = 1
             then case when CurEvents.so = 1 then 1.0 else 0.0 end end)
+ 9.9
  * avg(case when CurEvents.pa = 1
             then case when CurEvents.bb | CurEvents.hbp = 1 then 1.0 else 0.0 end end)
AS gcERA

-- === Key joins for gcERA (from the Event query) ===
-- FROM Astros.Events_View CurEvents
-- LEFT JOIN astros.pitches_view Pitches
--     ON CurEvents.sched_id = Pitches.sched_id
--     AND CurEvents.event_id = Pitches.cur_event_id
-- LEFT JOIN astros.hits HitsNoBunts
--     ON Pitches.sched_id = HitsNoBunts.sched_id
--     AND Pitches.pitch_id = HitsNoBunts.pitch_id
--     AND Pitches.pitch_result_id IN (12,13,14)
--     AND (CurEvents.hit_trajectory_id NOT IN (2,3,4) OR CurEvents.hit_trajectory_id IS NULL)
--     AND NOT (HitsNoBunts.hit_vertical_angle < -25 AND Schedule.level_code IN ('hsb','sum','bbc'))
--     AND HitsNoBunts.hit_exit_speed < 125
-- LEFT JOIN mlbam.YTD_Team_Pitching_Stats YtdLeaguePitching
--     ON YtdLeaguePitching.season = (CASE WHEN YEAR(GETDATE()) = Schedule.year
--                                          AND MONTH(GETDATE()) < 5
--                                         THEN Schedule.year-1 ELSE Schedule.year END)
--     AND YtdLeaguePitching.level = 'mlb'
--     AND YtdLeaguePitching.gm_type = 'r'
--     AND YtdLeaguePitching.split_id = 0
--     AND YtdLeaguePitching.team_id = 0
