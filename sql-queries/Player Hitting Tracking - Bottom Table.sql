 /** Event **/
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--[noformat]
DROP TABLE IF EXISTS #AGG; DROP TABLE IF EXISTS #NTILE;
GO
DECLARE @Param0 varchar(1000) = '93850';
-- DECLARE @Param1 varchar(1000) = '1';
-- DECLARE @Param2 varchar(1000) = 'Reg';

 SELECT DISTINCT  Schedule.gc2_level_code as GameLevel, dbo.GetLevelOrder(Schedule.gc2_level_code) as LevelOrder, Schedule.year as GameYear , percentile_cont(0.5) within group (order by HitsNoBunts.hit_exit_speed) over (partition by  Schedule.gc2_level_code, dbo.GetLevelOrder(Schedule.gc2_level_code), Schedule.year) as HitExitVelo50th
 
 INTO #HitExitVeloNtile
FROM Astros.Events_View CurEvents
 left join astros.pitches_view Pitches on CurEvents.sched_id = Pitches.sched_id and CurEvents.event_id = Pitches.cur_event_id
  left join astros.schedule_view Schedule on Pitches.sched_id = Schedule.sched_id
  left join mlbam.schedule MlbamSchedule on Schedule.mlbam_game_pk = MlbamSchedule.game_pk
  left join guts.woba_lwts Woba on MlbamSchedule.year = Woba.year and MlbamSchedule.league = Woba.league
 left join guts.hit_specs_ratios HitSpecsRatios on Schedule.year = HitSpecsRatios.season
 left join astros.hits_probabilities HitProbs on Pitches.sched_id = HitProbs.sched_id and Pitches.pitch_id = HitProbs.pitch_id and HitProbs.actual_shift = 1
 left join astros.hits HitsNoBunts on Pitches.sched_id = HitsNoBunts.sched_id and Pitches.pitch_id = HitsNoBunts.pitch_id and Pitches.pitch_result_id in (12,13,14) and (CurEvents.hit_trajectory_id not in (2,3,4) or CurEvents.hit_trajectory_id is null) and not (HitsNoBunts.hit_vertical_angle < -25 and Schedule.level_code in ('hsb', 'sum', 'bbc')) and HitsNoBunts.hit_exit_speed < 125
 left join astros.hits Hits on Pitches.sched_id = Hits.sched_id and Pitches.pitch_id = Hits.pitch_id and Pitches.pitch_result_id in (12,13,14)
 WHERE Pitches.batter_id = @Param0
 AND  (Schedule.is_pro_level_and_winter IN /** @Param1 **/ ('1')) AND  (case when Schedule.sched_type = 'R' then 'Reg' when Schedule.sched_type in ('S', 'U') then 'Spr' when Schedule.sched_type in ('F', 'D', 'L', 'W', 'C') then 'Post' when Schedule.sched_type in ('P', 'E', 'I', 'A', 'V') then 'Unoff' when Schedule.sched_type = 'B' then 'Bull' else 'Other' end IN /** @Param2 **/ ('Reg'))

 SELECT  Schedule.gc2_level_code as GameLevel, dbo.GetLevelOrder(Schedule.gc2_level_code) as LevelOrder, Schedule.year as GameYear , sum(cast(CurEvents.pa as int)) as PA
, sum(case when Pitches.pitch_result_id in (12,13,14,18,19,20) then 1 else 0 end) as BIP
, sum(case when Pitches.pitch_result_id in (12,13,14) then case when HitProbs.pitch_id is not null then 1.0 else null end else null end)/nullif(sum(case when Pitches.pitch_result_id in (12,13,14) then 1.0 else 0.0 end),0) as BIP_Tracked_Pct
, avg(case when HitsNoBunts.hit_exit_speed is not null then 1.6 * power(1.3, cos(-.34) * (HitsNoBunts.hit_exit_speed - 98.0) - sin(-.34) * (HitsNoBunts.hit_vertical_angle - 27.0) - .02 * power(2 + sin(-.34) * (HitsNoBunts.hit_exit_speed - 98.0) + cos(-.34) * (HitsNoBunts.hit_vertical_angle - 27.0), 2)) / (7.0 + power(1.3, cos(-.34) * (HitsNoBunts.hit_exit_speed - 98.0) - sin(-.34) * (HitsNoBunts.hit_vertical_angle - 27.0) - .02 * power(2 + sin(-.34) * (HitsNoBunts.hit_exit_speed - 98.0) + cos(-.34) * (HitsNoBunts.hit_vertical_angle - 27.0), 2))) else null end) as Damage_Pct
, avg(HitsNoBunts.hit_exit_speed) as HitExitVelo_Avg
, avg(case when HitsNoBunts.hit_exit_speed >= HitExitVeloNtile.HitExitVelo50th then HitsNoBunts.hit_exit_speed else null end) as HitExitVelo_Top50thAvg
, avg(HitsNoBunts.hit_useful_exit_speed) as HitUsefulExitVelo_Avg
, avg(case when HitsNoBunts.hit_exit_speed is null or Pitches.pitch_result_id not in (12, 13, 14, 18, 19, 20) then null else case when HitsNoBunts.hit_exit_speed >= 95 then 1.0 else 0.0 end end) as HardHit_Pct
, avg(case when HitsNoBunts.hit_exit_speed is null then null else 1.0 * case when cast(HitsNoBunts.hit_exit_speed as decimal(4, 0)) * 1.5 - cast(HitsNoBunts.hit_vertical_angle as decimal(3, 0)) >= 117.0 and cast(HitsNoBunts.hit_exit_speed as decimal(4, 0)) + cast(HitsNoBunts.hit_vertical_angle as decimal(3, 0)) >= 124.0 and cast(HitsNoBunts.hit_exit_speed as decimal(4, 0)) >= 98.0 and cast(HitsNoBunts.hit_vertical_angle as decimal(3, 0)) > 4.0 and cast(HitsNoBunts.hit_vertical_angle as decimal(3, 0)) < 50.0 then 1 else 0 end end) as BarrelRate
, avg(1.0 * case when HitsNoBunts.hit_exit_speed is not null then (case when HitsNoBunts.hit_exit_speed >= 0.011 * power(HitsNoBunts.hit_vertical_angle, 2) - 0.91 * HitsNoBunts.hit_vertical_angle + 95.0 then 1 else 0 end) else null end) as pBarrel_Pct
, avg(case when HitsNoBunts.hit_vertical_angle is null or Pitches.pitch_result_id not in (12, 13, 14, 18, 19, 20) then null else HitsNoBunts.hit_vertical_angle end) as HitLaunchAngle_Avg
, stdev(case when HitsNoBunts.hit_vertical_angle is null or Pitches.pitch_result_id not in (12, 13, 14, 18, 19, 20) then null else HitsNoBunts.hit_vertical_angle end) as HitLaunchAngle_Sd
, avg(case when HitsNoBunts.hit_vertical_angle is null or Pitches.pitch_result_id not in (12, 13, 14, 18, 19, 20) then null else 1.0 * case when HitsNoBunts.hit_vertical_angle >= 10 and HitsNoBunts.hit_vertical_angle <= 30 and Pitches.pitch_result_id in (12, 13, 14, 18, 19, 20) then 1 else 0 end end) as HitLaunchAngle_1030
, avg(HitsNoBunts.hit_bearing) as HitSprayAngle_Avg
, avg(Hits.hit_initial_contact_point_y) as HitInitialContactPointY_Avg
, avg(1.0 * case when Hits.hit_bearing is not null and CurEvents.hit_trajectory_id = 6 then case when case when Hits.hit_bearing is null then null when (case when Pitches.bat_side = 'L' then -1.0 else 1.0 end) * Hits.hit_bearing <= -15.0 then 'Pull' when (case when Pitches.bat_side = 'L' then -1.0 else 1.0 end) * Hits.hit_bearing >= 15.0 then 'Oppo' else 'Str' end = 'Pull' then 1 else 0 end end) as HitPull_Pct
, avg(1.0 * case when Hits.hit_bearing is not null and CurEvents.hit_trajectory_id = 6 then case when case when Hits.hit_bearing is null then null when (case when Pitches.bat_side = 'L' then -1.0 else 1.0 end) * Hits.hit_bearing <= -15.0 then 'Pull' when (case when Pitches.bat_side = 'L' then -1.0 else 1.0 end) * Hits.hit_bearing >= 15.0 then 'Oppo' else 'Str' end = 'Str' then 1 else 0 end end) as HitStraightAway_Pct
, avg(1.0 * case when Hits.hit_bearing is not null and CurEvents.hit_trajectory_id = 6 then case when case when Hits.hit_bearing is null then null when (case when Pitches.bat_side = 'L' then -1.0 else 1.0 end) * Hits.hit_bearing <= -15.0 then 'Pull' when (case when Pitches.bat_side = 'L' then -1.0 else 1.0 end) * Hits.hit_bearing >= 15.0 then 'Oppo' else 'Str' end = 'Oppo' then 1 else 0 end end) as HitOppo_Pct
, case when sum(case when CurEvents.hit_trajectory_id in (5,6,7,8) then 1 else 0 end) = 0 then null else 1.0 * sum(case when CurEvents.hit_trajectory_id = 6 then 1 else 0 end)/sum(case when CurEvents.hit_trajectory_id in (5,6,7,8) then 1 else 0 end) end as GroundBall_Pct
, case when sum(case when CurEvents.hit_trajectory_id in (5,6,7,8) then 1 else 0 end) = 0 then null else 1.0 * sum(case when CurEvents.hit_trajectory_id = 7 then 1 else 0 end)/sum(case when CurEvents.hit_trajectory_id in (5,6,7,8) then 1 else 0 end) end as LineDrive_Pct
, case when sum(case when CurEvents.hit_trajectory_id in (5,6,7,8) then 1 else 0 end) = 0 then null else 1.0 * sum(case when CurEvents.hit_trajectory_id = 5 then 1 else 0 end)/sum(case when CurEvents.hit_trajectory_id in (5,6,7,8) then 1 else 0 end) end as FlyBall_Pct
, case when sum(case when CurEvents.hit_trajectory_id in (5,6,7,8) then 1 else 0 end) = 0 then null else 1.0 * sum(case when CurEvents.hit_trajectory_id = 8 then 1 else 0 end)/sum(case when CurEvents.hit_trajectory_id in (5,6,7,8) then 1 else 0 end) end as PopUp_Pct
, avg(case when Pitches.pitch_result_id in (12,13,14) and CurEvents.hr <> 1 then case when CurEvents.[1b] = 1 or CurEvents.[2b] = 1 or CurEvents.[3b] = 1 then 1.0 else 0.0 end end) as BABIP
, case when sum(cast(CurEvents.ab as int)) = 0 then null else sum(cast(CurEvents.[1b] as decimal)+cast(CurEvents.[2b] as decimal)+cast(CurEvents.[3b] as decimal)+cast(CurEvents.[hr] as decimal))/sum(cast(CurEvents.ab as int)) end as AVG
, case when sum(cast(CurEvents.ab as int)+cast(CurEvents.bb as int)+cast(CurEvents.hbp as int)+coalesce(cast(CurEvents.sf as int), 0)) = 0 then null else sum(cast(CurEvents.[1b] as decimal)+cast(CurEvents.[2b] as decimal)+cast(CurEvents.[3b] as decimal)+cast(CurEvents.[hr] as decimal)+cast(CurEvents.bb as decimal)+cast(CurEvents.hbp as decimal))/sum(cast(CurEvents.ab as int)+cast(CurEvents.bb as int)+cast(CurEvents.hbp as int)+coalesce(cast(CurEvents.sf as int), 0)) end as OBP
, case when sum(cast(CurEvents.ab as int)) = 0 then null else sum(cast(CurEvents.[1b] as decimal)+cast(CurEvents.[2b] as decimal)*2+cast(CurEvents.[3b] as decimal)*3+cast(CurEvents.[hr] as decimal)*4)/sum(cast(CurEvents.ab as int)) end as SLG
, (AVG(Woba.woba_BB)*SUM(cast(CurEvents.BB as int)-cast(CurEvents.IBB as int)) + AVG(Woba.woba_HB)*SUM(cast(CurEvents.HBP as int)) + AVG(Woba.woba_1B)*SUM(cast(CurEvents.[1B] as int)) + AVG(Woba.woba_2B)*SUM(cast(CurEvents.[2B] as int)) + AVG(Woba.woba_3B)*SUM(cast(CurEvents.[3B] as int)) + AVG(Woba.woba_HR)*SUM(cast(CurEvents.HR as int))) / NULLIF(SUM(cast(CurEvents.AB as int) + cast(CurEvents.BB as int) - cast(CurEvents.IBB as int) + cast(CurEvents.SF as int) + cast(CurEvents.HBP as int)),0) as wOBA
, sum(case when Pitches.pitch_result_id in (12, 13, 14) then isnull((1.0 - power(HitProbs.prob_hr, HitSpecsRatios.exp_hr)) * (power(HitProbs.prob_inf_1b + HitProbs.prob_of_1b, HitSpecsRatios.exp_1b) + power(HitProbs.prob_2b, HitSpecsRatios.exp_2b) + power(HitProbs.prob_3b, HitSpecsRatios.exp_3b)) / (power(HitProbs.prob_inf_1b + HitProbs.prob_of_1b, HitSpecsRatios.exp_1b) + power(HitProbs.prob_2b, HitSpecsRatios.exp_2b) + power(HitProbs.prob_3b, HitSpecsRatios.exp_3b) + power(HitProbs.prob_inf_out + HitProbs.prob_of_out + HitProbs.prob_inf_error + HitProbs.prob_of_error, HitSpecsRatios.exp_fo)) , cast(CurEvents.[1b] as float) + cast(CurEvents.[2b] as float) + cast(CurEvents.[3b] as float)) else null end) / nullif(sum(case when Pitches.pitch_result_id in (12,13,14) then isnull(1.0 - (power(HitProbs.prob_hr, HitSpecsRatios.exp_hr)), 1.0 - cast(CurEvents.hr as float)) else null end), 0) as xBABIP
, avg(case when CurEvents.ab = 1 or CurEvents.sf = 1 then isnull((1.0 - power(HitProbs.prob_hr, HitSpecsRatios.exp_hr)) * (power(HitProbs.prob_inf_1b + HitProbs.prob_of_1b, HitSpecsRatios.exp_1b) + power(HitProbs.prob_2b, HitSpecsRatios.exp_2b) + power(HitProbs.prob_3b, HitSpecsRatios.exp_3b)) / (power(HitProbs.prob_inf_1b + HitProbs.prob_of_1b, HitSpecsRatios.exp_1b) + power(HitProbs.prob_2b, HitSpecsRatios.exp_2b) + power(HitProbs.prob_3b, HitSpecsRatios.exp_3b) + power(HitProbs.prob_inf_out + HitProbs.prob_of_out + HitProbs.prob_inf_error + HitProbs.prob_of_error, HitSpecsRatios.exp_fo)) + (power(HitProbs.prob_hr, HitSpecsRatios.exp_hr)) , cast(CurEvents.[1b] as float) + cast(CurEvents.[2b] as float) + cast(CurEvents.[3b] as float) + cast(CurEvents.hr as float)) else null end) as xAVG
, sum(case when CurEvents.bb = 1 or CurEvents.hbp = 1 then 1.0 when CurEvents.ab = 1 or CurEvents.sf = 1 then isnull((1.0 - power(HitProbs.prob_hr, HitSpecsRatios.exp_hr)) * (power(HitProbs.prob_inf_1b + HitProbs.prob_of_1b, HitSpecsRatios.exp_1b) + power(HitProbs.prob_2b, HitSpecsRatios.exp_2b) + power(HitProbs.prob_3b, HitSpecsRatios.exp_3b)) / (power(HitProbs.prob_inf_1b + HitProbs.prob_of_1b, HitSpecsRatios.exp_1b) + power(HitProbs.prob_2b, HitSpecsRatios.exp_2b) + power(HitProbs.prob_3b, HitSpecsRatios.exp_3b) + power(HitProbs.prob_inf_out + HitProbs.prob_of_out + HitProbs.prob_inf_error + HitProbs.prob_of_error, HitSpecsRatios.exp_fo)) + (power(HitProbs.prob_hr, HitSpecsRatios.exp_hr)) , cast(CurEvents.[1b] as float) + cast(CurEvents.[2b] as float) + cast(CurEvents.[3b] as float) + cast(CurEvents.[hr] as float)) else null end) / nullif(sum(cast(CurEvents.ab as int) + cast(CurEvents.bb as int) + cast(CurEvents.hbp as int) + coalesce(cast(CurEvents.sf as int), 0)), 0) as xOBP
, avg(case when CurEvents.ab = 1 or CurEvents.sf = 1 then isnull((1.0 - power(HitProbs.prob_hr, HitSpecsRatios.exp_hr)) * (power(HitProbs.prob_inf_1b + HitProbs.prob_of_1b, HitSpecsRatios.exp_1b) + power(HitProbs.prob_2b, HitSpecsRatios.exp_2b) * 2 + power(HitProbs.prob_3b, HitSpecsRatios.exp_3b) * 3) / (power(HitProbs.prob_inf_1b + HitProbs.prob_of_1b, HitSpecsRatios.exp_1b) + power(HitProbs.prob_2b, HitSpecsRatios.exp_2b) + power(HitProbs.prob_3b, HitSpecsRatios.exp_3b) + power(HitProbs.prob_inf_out + HitProbs.prob_of_out + HitProbs.prob_inf_error + HitProbs.prob_of_error, HitSpecsRatios.exp_fo)) + (power(HitProbs.prob_hr, HitSpecsRatios.exp_hr) * 4) , cast(CurEvents.[1b] as float) + cast(CurEvents.[2b] as float) * 2 + cast(CurEvents.[3b] as float) * 3 + cast(CurEvents.hr as float) * 4) else null end) as xSLG
, sum(case when CurEvents.bb = 1 or CurEvents.hbp = 1 then 1.0 * Woba.woba_bb when CurEvents.ab = 1 or CurEvents.sf = 1 then isnull((1.0 - power(HitProbs.prob_hr, HitSpecsRatios.exp_hr)) * (power(HitProbs.prob_inf_1b + HitProbs.prob_of_1b, HitSpecsRatios.exp_1b) * Woba.woba_1b + power(HitProbs.prob_2b, HitSpecsRatios.exp_2b) * Woba.woba_2b + power(HitProbs.prob_3b, HitSpecsRatios.exp_3b) * Woba.woba_3b) / (power(HitProbs.prob_inf_1b + HitProbs.prob_of_1b, HitSpecsRatios.exp_1b) + power(HitProbs.prob_2b, HitSpecsRatios.exp_2b) + power(HitProbs.prob_3b, HitSpecsRatios.exp_3b) + power(HitProbs.prob_inf_out + HitProbs.prob_of_out + HitProbs.prob_inf_error + HitProbs.prob_of_error, HitSpecsRatios.exp_fo)) + (power(HitProbs.prob_hr, HitSpecsRatios.exp_hr) * Woba.woba_hr) , cast(CurEvents.[1b] as float) * Woba.woba_1b + cast(CurEvents.[2b] as float) * Woba.woba_2b + cast(CurEvents.[3b] as float) * Woba.woba_3b + cast(CurEvents.[hr] as float) * Woba.woba_hr) else null end) / nullif(sum(cast(CurEvents.ab as int) + cast(CurEvents.bb as int) + cast(CurEvents.hbp as int) + coalesce(cast(CurEvents.sf as int), 0)), 0) as xwOBA
  INTO #AGG 
 FROM Astros.Events_View CurEvents
 left join astros.pitches_view Pitches on CurEvents.sched_id = Pitches.sched_id and CurEvents.event_id = Pitches.cur_event_id
  left join astros.schedule_view Schedule on Pitches.sched_id = Schedule.sched_id
  left join mlbam.schedule MlbamSchedule on Schedule.mlbam_game_pk = MlbamSchedule.game_pk
  left join guts.woba_lwts Woba on MlbamSchedule.year = Woba.year and MlbamSchedule.league = Woba.league
 left join guts.hit_specs_ratios HitSpecsRatios on Schedule.year = HitSpecsRatios.season
 left join astros.hits_probabilities HitProbs on Pitches.sched_id = HitProbs.sched_id and Pitches.pitch_id = HitProbs.pitch_id and HitProbs.actual_shift = 1
 left join astros.hits HitsNoBunts on Pitches.sched_id = HitsNoBunts.sched_id and Pitches.pitch_id = HitsNoBunts.pitch_id and Pitches.pitch_result_id in (12,13,14) and (CurEvents.hit_trajectory_id not in (2,3,4) or CurEvents.hit_trajectory_id is null) and not (HitsNoBunts.hit_vertical_angle < -25 and Schedule.level_code in ('hsb', 'sum', 'bbc')) and HitsNoBunts.hit_exit_speed < 125
 left join astros.hits Hits on Pitches.sched_id = Hits.sched_id and Pitches.pitch_id = Hits.pitch_id and Pitches.pitch_result_id in (12,13,14)
 LEFT JOIN #HitExitVeloNtile AS HitExitVeloNtile ON 
HitExitVeloNtile.GameLevel = Schedule.gc2_level_code
 AND HitExitVeloNtile.LevelOrder = dbo.GetLevelOrder(Schedule.gc2_level_code)
 AND HitExitVeloNtile.GameYear = Schedule.year
 WHERE Pitches.batter_id = @Param0
 AND  (Schedule.is_pro_level_and_winter IN /** @Param1 **/ ('1')) AND  (case when Schedule.sched_type = 'R' then 'Reg' when Schedule.sched_type in ('S', 'U') then 'Spr' when Schedule.sched_type in ('F', 'D', 'L', 'W', 'C') then 'Post' when Schedule.sched_type in ('P', 'E', 'I', 'A', 'V') then 'Unoff' when Schedule.sched_type = 'B' then 'Bull' else 'Other' end IN /** @Param2 **/ ('Reg'))
 GROUP BY  Schedule.gc2_level_code, dbo.GetLevelOrder(Schedule.gc2_level_code), Schedule.year
-- GO
 OPTION(RECOMPILE) 
  SELECT DISTINCT  Schedule.gc2_level_code as GameLevel, dbo.GetLevelOrder(Schedule.gc2_level_code) as LevelOrder, Schedule.year as GameYear , percentile_cont(0.99) within group (order by HitsNoBunts.hit_exit_speed) over (partition by  Schedule.gc2_level_code, dbo.GetLevelOrder(Schedule.gc2_level_code), Schedule.year) as HitExitVelo_Max
  INTO #NTILE 
 FROM Astros.Events_View CurEvents
 left join astros.pitches_view Pitches on CurEvents.sched_id = Pitches.sched_id and CurEvents.event_id = Pitches.cur_event_id
  left join astros.schedule_view Schedule on Pitches.sched_id = Schedule.sched_id
  left join mlbam.schedule MlbamSchedule on Schedule.mlbam_game_pk = MlbamSchedule.game_pk
  left join guts.woba_lwts Woba on MlbamSchedule.year = Woba.year and MlbamSchedule.league = Woba.league
 left join guts.hit_specs_ratios HitSpecsRatios on Schedule.year = HitSpecsRatios.season
 left join astros.hits_probabilities HitProbs on Pitches.sched_id = HitProbs.sched_id and Pitches.pitch_id = HitProbs.pitch_id and HitProbs.actual_shift = 1
 left join astros.hits HitsNoBunts on Pitches.sched_id = HitsNoBunts.sched_id and Pitches.pitch_id = HitsNoBunts.pitch_id and Pitches.pitch_result_id in (12,13,14) and (CurEvents.hit_trajectory_id not in (2,3,4) or CurEvents.hit_trajectory_id is null) and not (HitsNoBunts.hit_vertical_angle < -25 and Schedule.level_code in ('hsb', 'sum', 'bbc')) and HitsNoBunts.hit_exit_speed < 125
 left join astros.hits Hits on Pitches.sched_id = Hits.sched_id and Pitches.pitch_id = Hits.pitch_id and Pitches.pitch_result_id in (12,13,14)
 WHERE Pitches.batter_id = @Param0
 AND  (Schedule.is_pro_level_and_winter IN /** @Param1 **/ ('1')) AND  (case when Schedule.sched_type = 'R' then 'Reg' when Schedule.sched_type in ('S', 'U') then 'Spr' when Schedule.sched_type in ('F', 'D', 'L', 'W', 'C') then 'Post' when Schedule.sched_type in ('P', 'E', 'I', 'A', 'V') then 'Unoff' when Schedule.sched_type = 'B' then 'Bull' else 'Other' end IN /** @Param2 **/ ('Reg'))

 OPTION(RECOMPILE) 
 SELECT  Agg.GameLevel, Agg.LevelOrder, Agg.GameYear, Agg.PA, Agg.BIP, Agg.BIP_Tracked_Pct, Agg.Damage_Pct, Agg.HitExitVelo_Avg, Agg.HitExitVelo_Top50thAvg, Ntile.HitExitVelo_Max, Agg.HitUsefulExitVelo_Avg, Agg.HardHit_Pct, Agg.BarrelRate, Agg.pBarrel_Pct, Agg.HitLaunchAngle_Avg, Agg.HitLaunchAngle_Sd, Agg.HitLaunchAngle_1030, Agg.HitSprayAngle_Avg, Agg.HitInitialContactPointY_Avg, Agg.HitPull_Pct, Agg.HitStraightAway_Pct, Agg.HitOppo_Pct, Agg.GroundBall_Pct, Agg.LineDrive_Pct, Agg.FlyBall_Pct, Agg.PopUp_Pct, Agg.BABIP, Agg.AVG, Agg.OBP, Agg.SLG, Agg.wOBA, Agg.xBABIP, Agg.xAVG, Agg.xOBP, Agg.xSLG, Agg.xwOBA
 FROM 
 #AGG AGG, #NTILE NTILE WHERE  isnull(cast(Agg.GameLevel as varchar),'') = isnull(cast( Ntile.GameLevel as varchar),'') AND isnull(cast(Agg.LevelOrder as varchar),'') = isnull(cast( Ntile.LevelOrder as varchar),'') AND isnull(cast(Agg.GameYear as varchar),'') = isnull(cast( Ntile.GameYear as varchar),'')
 ORDER BY 
 GameYear DESC, LevelOrder ASC

