 /** Pitch **/
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--[noformat]
DROP TABLE IF EXISTS #AGG; DROP TABLE IF EXISTS #NTILE;
GO
DECLARE @Param0 varchar(1000) = '176229';
-- DECLARE @Param1 varchar(1000) = '1';
-- DECLARE @Param2 varchar(1000) = 'Reg';

 SELECT  Pitches.pitch_type as PitchType, dbo.GetPitchTypeOrder(Pitches.pitch_type) as PitchTypeOrder, Schedule.year as GameYear , count(1) as GenericCount
, count(1) as PitchUsage
, avg(Pitches.release_speed) as Velo_Avg
, avg(sqrt(power(Pitches.horzbreak,2) + power(Pitches.inducedvertbreak,2))) as BreakMagnitude_Avg
, cast(dateadd(minute, case when atn2(avg(-Pitches.horzbreak), avg(Pitches.inducedvertbreak))/(2.0 * pi()) < 1.0/12.0 then 12.0 * 60.0 else 0.0 end + 12.0 * 60.0 * atn2(avg(-Pitches.horzbreak), avg(Pitches.inducedvertbreak))/(2.0 * pi()), 0) as time) as ClockShape
, avg(Pitches.extension) as Extension_Avg
, avg(Pitches.horzbreak) as HorzBreak_Avg
, avg(Pitches.release_x) as ReleaseX_Avg
, avg(Pitches.release_z) as ReleaseZ_Avg
, avg(Pitches.spin_rate) as SpinRate_Avg
, avg(Pitches.inducedvertbreak) as VertBreak_Avg
, avg(Pitches.ax0) as AccX_Avg
, avg(Pitches.az0 + 32.17) as AccZ_Corrected_Avg
, (180.0/pi()) * atn2(avg(Pitches.vx0), -avg(Pitches.vy0)) as HorzRelAngle_Avg
, (180.0/pi()) * atn2(avg(Pitches.vz0), -avg(Pitches.vy0)) as VertRelAngle_Avg
, avg(Pitches.horz_appr_angle) as HorzApprAngle_Avg
, avg(Pitches.vert_appr_angle) as VertApprAngle_Avg
, avg(Pitches.Mnx) as HorzBreak_SSW_Avg
, avg(Pitches.Mnz) as VertBreak_SSW_Avg
, avg(Pitches.spin_eff) as SpinEfficiency_Avg
, avg(TrackingHitTraj.pitch_trajectory_poly_x_2 * 0.682) as PitchReleaseVeloX_Avg
, avg( TrackingHitTraj.pitch_trajectory_poly_y_2 * 0.682) as PitchReleaseVeloY_Avg
, avg(TrackingHitTraj.pitch_trajectory_poly_z_2 * 0.682) as PitchReleaseVeloZ_Avg
  INTO #AGG 
 FROM Astros.Pitches_View Pitches
 left join astros.schedule_view Schedule on Pitches.sched_id = Schedule.sched_id
 left join astros.pitches_attributes PitchAttributes on Pitches.sched_id = PitchAttributes.sched_id and Pitches.pitch_id = PitchAttributes.pitch_id
 left join groundcontroltracking.tracking.plays TrackingPlays on Pitches.sched_id = TrackingPlays.sched_id and Pitches.pitch_id = TrackingPlays.astros_pitch_id
  left join groundcontroltracking.tracking.pitch_hit_trajectories TrackingHitTraj on TrackingPlays.tracking_play_id = TrackingHitTraj.tracking_play_id and TrackingHitTraj.sched_id = TrackingPlays.sched_id
 WHERE Pitches.pitcher_id = @Param0
 AND  (Schedule.is_pro_level_and_winter IN /** @Param1 **/ ('1')) AND  (case when Schedule.sched_type = 'R' then 'Reg' when Schedule.sched_type in ('S', 'U') then 'Spr' when Schedule.sched_type in ('F', 'D', 'L', 'W', 'C') then 'Post' when Schedule.sched_type in ('P', 'E', 'I', 'A', 'V') then 'Unoff' when Schedule.sched_type = 'B' then 'Bull' else 'Other' end IN /** @Param2 **/ ('Reg'))
 AND Pitches.ignore_flag = 0 AND Pitches.pitch_id > 0
 GROUP BY  Pitches.pitch_type, dbo.GetPitchTypeOrder(Pitches.pitch_type), Schedule.year
-- GO
 OPTION(RECOMPILE) 
  SELECT DISTINCT  Pitches.pitch_type as PitchType, dbo.GetPitchTypeOrder(Pitches.pitch_type) as PitchTypeOrder, Schedule.year as GameYear , percentile_cont(0.99) within group (order by Pitches.release_speed) over (partition by  Pitches.pitch_type, dbo.GetPitchTypeOrder(Pitches.pitch_type), Schedule.year) as Velo_Max
, percentile_cont(0.01) within group (order by Pitches.release_speed) over (partition by  Pitches.pitch_type, dbo.GetPitchTypeOrder(Pitches.pitch_type), Schedule.year) as Velo_Min
, percentile_cont(0.50) within group (order by Pitches.spin_rate) over (partition by  Pitches.pitch_type, dbo.GetPitchTypeOrder(Pitches.pitch_type), Schedule.year) as SpinRate_Median
, percentile_cont(0.50) within group (order by PitchAttributes.m_theta_xz) over (partition by  Pitches.pitch_type, dbo.GetPitchTypeOrder(Pitches.pitch_type), Schedule.year) as LastTouchPointXZ_Median
, percentile_cont(0.50) within group (order by PitchAttributes.m_theta_yz) over (partition by  Pitches.pitch_type, dbo.GetPitchTypeOrder(Pitches.pitch_type), Schedule.year) as LastTouchPointYZ_Median
, percentile_cont(0.50) within group (order by TrackingHitTraj.pitch_release_spinrate_x) over (partition by  Pitches.pitch_type, dbo.GetPitchTypeOrder(Pitches.pitch_type), Schedule.year) as PitchReleaseSpinX_Med
, percentile_cont(0.50) within group (order by TrackingHitTraj.pitch_release_spinrate_y) over (partition by  Pitches.pitch_type, dbo.GetPitchTypeOrder(Pitches.pitch_type), Schedule.year) as PitchReleaseSpinY_Med
, percentile_cont(0.50) within group (order by TrackingHitTraj.pitch_release_spinrate_z) over (partition by  Pitches.pitch_type, dbo.GetPitchTypeOrder(Pitches.pitch_type), Schedule.year) as PitchReleaseSpinZ_Med
  INTO #NTILE 
 FROM Astros.Pitches_View Pitches
 left join astros.schedule_view Schedule on Pitches.sched_id = Schedule.sched_id
 left join astros.pitches_attributes PitchAttributes on Pitches.sched_id = PitchAttributes.sched_id and Pitches.pitch_id = PitchAttributes.pitch_id
 left join groundcontroltracking.tracking.plays TrackingPlays on Pitches.sched_id = TrackingPlays.sched_id and Pitches.pitch_id = TrackingPlays.astros_pitch_id
  left join groundcontroltracking.tracking.pitch_hit_trajectories TrackingHitTraj on TrackingPlays.tracking_play_id = TrackingHitTraj.tracking_play_id and TrackingHitTraj.sched_id = TrackingPlays.sched_id
 WHERE Pitches.pitcher_id = @Param0
 AND  (Schedule.is_pro_level_and_winter IN /** @Param1 **/ ('1')) AND  (case when Schedule.sched_type = 'R' then 'Reg' when Schedule.sched_type in ('S', 'U') then 'Spr' when Schedule.sched_type in ('F', 'D', 'L', 'W', 'C') then 'Post' when Schedule.sched_type in ('P', 'E', 'I', 'A', 'V') then 'Unoff' when Schedule.sched_type = 'B' then 'Bull' else 'Other' end IN /** @Param2 **/ ('Reg'))
 AND Pitches.ignore_flag = 0 AND Pitches.pitch_id > 0

 OPTION(RECOMPILE) 
 SELECT  Agg.PitchType, Agg.PitchTypeOrder, Agg.GameYear, Agg.GenericCount, Agg.PitchUsage, Agg.Velo_Avg, Ntile.Velo_Max, Ntile.Velo_Min, Agg.BreakMagnitude_Avg, Agg.ClockShape, Agg.Extension_Avg, Agg.HorzBreak_Avg, Agg.ReleaseX_Avg, Agg.ReleaseZ_Avg, Agg.SpinRate_Avg, Ntile.SpinRate_Median, Agg.VertBreak_Avg, Agg.AccX_Avg, Agg.AccZ_Corrected_Avg, Agg.HorzRelAngle_Avg, Agg.VertRelAngle_Avg, Agg.HorzApprAngle_Avg, Agg.VertApprAngle_Avg, Agg.HorzBreak_SSW_Avg, Agg.VertBreak_SSW_Avg, Agg.SpinEfficiency_Avg, Ntile.LastTouchPointXZ_Median, Ntile.LastTouchPointYZ_Median, Ntile.PitchReleaseSpinX_Med, Ntile.PitchReleaseSpinY_Med, Ntile.PitchReleaseSpinZ_Med, Agg.PitchReleaseVeloX_Avg, Agg.PitchReleaseVeloY_Avg, Agg.PitchReleaseVeloZ_Avg
 FROM 
 #AGG AGG, #NTILE NTILE WHERE  isnull(cast(Agg.PitchType as varchar),'') = isnull(cast( Ntile.PitchType as varchar),'') AND isnull(cast(Agg.PitchTypeOrder as varchar),'') = isnull(cast( Ntile.PitchTypeOrder as varchar),'') AND isnull(cast(Agg.GameYear as varchar),'') = isnull(cast( Ntile.GameYear as varchar),'')
 ORDER BY 
 PitchTypeOrder ASC, GameYear DESC

