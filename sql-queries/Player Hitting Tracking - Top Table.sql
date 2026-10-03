-- NOTE (Apr 26 2026): Astros' canonical bat speed switched to "at contact" (SCV).
-- This GC2 reference query is preserved as-is for diagnostic comparison.
-- See pd-goals/src/percentiles.py for canonical at-contact SQL pattern.

 /** Pitch **/
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--[noformat]
DROP TABLE IF EXISTS #AGG; DROP TABLE IF EXISTS #NTILE;
GO
DECLARE @Param0 varchar(1000) = '93850';
-- DECLARE @Param1 varchar(1000) = '1';
-- DECLARE @Param2 varchar(1000) = 'Reg';

 SELECT  Schedule.gc2_level_code as GameLevel, dbo.GetLevelOrder(Schedule.gc2_level_code) as LevelOrder, Schedule.year as GameYear , count(1) as GenericCount
, avg(case when Pitches.did_swing = 1 then 1.0 else 0.0 end) as SwingPercentage
, avg(case when Pitches.pitch_result_id in (10,21,22,23) then 1.0 else 0.0 end) as SwingingStrikePercentage
, sum(case when Pitches.did_swing = 1 then Pitches.called_strike_chance_mlb else null end)/nullif(sum(Pitches.called_strike_chance_mlb),0) as SwingPercentage_InZone
, sum(case when Pitches.did_swing = 1 then 1.0 - Pitches.called_strike_chance_mlb else null end)/nullif(sum(1.0 - Pitches.called_strike_chance_mlb),0) as SwingPercentage_OutZone
, avg(1.0 * case when Pitches.did_swing = 1 then case when Pitches.pitch_result_id not in (10,21,22,23) then 1 else 0 end else null end) as ContactPercentage
, avg(Pitches.called_strike_chance_mlb) as InZonePercentage
, sum(case when Pitches.did_swing = 1 and Pitches.pitch_result_id not in (10,21,22,23) then Pitches.called_strike_chance_mlb else null end)/nullif(sum(case when Pitches.did_swing = 1 then Pitches.called_strike_chance_mlb else null end),0) as ContactPercentage_InZone
, sum(case when Pitches.did_swing = 1 and Pitches.pitch_result_id not in (10,21,22,23) then 1 - Pitches.called_strike_chance_mlb else null end)/nullif(sum(1 - case when Pitches.did_swing = 1 then Pitches.called_strike_chance_mlb else null end),0) as ContactPercentage_OutZone
, avg(1.0 * case when Pitches.called_strike_chance_mlb < .01 then case when Pitches.did_swing = 1 then 1 else 0 end else null end) as ChasePercentage
, avg(1.0 * case when Pitches.did_swing = 1 then case when Pitches.pitch_result_id in (10,21,22,23) then 1 else 0 end else null end) as WhiffPercentage
, sum(case when Pitches.did_swing = 1 then case when Pitches.pitch_result_id in (10,21,22,23) then Pitches.called_strike_chance_mlb else 0 end else null end)/nullif(sum(case when Pitches.did_swing = 1 then Pitches.called_strike_chance_mlb else null end),0) as WhiffPercentage_InZone
, avg(case when Pitches.pitch_result_id in (12,13,14) then Pitches.rv_gain + Pitches.rv_before else null end) as RV_BIP_Avg
, avg(case when Pitches.pitch_result_id in (12,13,14) then Pitches.rv_gain_given_hit_specs + Pitches.rv_before else null end) as RV_HitSpecs_BIP_Avg
, avg(Pitches.rv_gain) as RvGain_Avg
, avg(Pitches.rv_gain_given_hit_specs) as RvGainGivenHitSpecs_Avg
, avg(ProjPitchGrades.swing_decision) as SwingDecisionAgainstGrade2080_Avg
, avg(Pitches.swing_decision_grade_2080) as SwingDecisionAgainstComponentGrade2080_Avg
, avg(Pitches.swing_decision_abs_grade_2080) as SwingDecisionAgainstABSComponentGrade2080_Avg
, avg(PitchGrades.stuffrelvel_grade_2080) as StuffRelVel2080_Avg
, avg(ProjPitchGrades.fb_grade) as PG_Grade_Avg
, count(BatTrackingMetrics.v_peak) as BatTrackingNumSwings
, avg(ASIN(BatTrackingMetrics.vz_true_peak / nullif(BatTrackingMetrics.v_true_peak, 0)) * (180 / PI())) as BatTrackingPeakAttackAngle_Avg
, avg(case when BatTrackingMetrics.v_true_peak * .682 < 100 then BatTrackingMetrics.v_true_peak * .682 end) as BatTrackingPeakBatSpeed_Avg
, avg(BatTrackingMetrics.adj_aa_pitcher_face) as BatTrackingLocAdjOpenFaceAttackAngle_Avg
, avg(BatTrackingMetrics.adj_vba_pitcher_face) as BatTrackingLocAdjOpenFaceVerticalBatAngle_Avg
, avg(case when  case when Pitches.pitch_result_id in (12,13,14,18,19,20) then 1 else 0 end = 1 and SwingContactValues.con_loc_axis between -2.5 and 2.5 then SwingContactValues.con_loc_axis * 12 else null end ) as ContactLocationAxisAvg
, avg(case when case when Pitches.pitch_result_id in (12,13,14,18,19,20) then 1 else 0 end = 1 and SwingContactValues.con_loc_perp between -2 and 2 then SwingContactValues.con_loc_perp * 12 else null end ) as ContactLocationPerpendicularAvg
, avg(case when case when Pitches.pitch_result_id in (12,13,14,18,19,20) then 1 else 0 end = 1 and case when Pitches.bat_side = 'R' then ((SwingContactValues.ballx_con - SwingContactValues.batx_con) * (SwingContactValues.e1y_con * SwingContactValues.batvz_con - SwingContactValues.e1z_con * SwingContactValues.batvy_con) - (SwingContactValues.bally_con - SwingContactValues.baty_con) * (SwingContactValues.e1x_con * SwingContactValues.batvz_con - SwingContactValues.e1z_con * SwingContactValues.batvx_con) +  (SwingContactValues.ballz_con - SwingContactValues.batz_con) * (SwingContactValues.e1x_con * SwingContactValues.batvy_con - SwingContactValues.e1y_con * SwingContactValues.batvx_con)) / sqrt(power(SwingContactValues.batvx_con, 2) + power(SwingContactValues.batvy_con, 2) + power(SwingContactValues.batvz_con, 2)) when Pitches.bat_side = 'L' then ((SwingContactValues.ballx_con - SwingContactValues.batx_con) * (-1 * SwingContactValues.e1y_con * SwingContactValues.batvz_con - -1 * SwingContactValues.e1z_con * SwingContactValues.batvy_con) - (SwingContactValues.bally_con - SwingContactValues.baty_con) * (-1 * SwingContactValues.e1x_con * SwingContactValues.batvz_con - -1 * SwingContactValues.e1z_con * SwingContactValues.batvx_con) +  (SwingContactValues.ballz_con - SwingContactValues.batz_con) * (-1 * SwingContactValues.e1x_con * SwingContactValues.batvy_con - -1 * SwingContactValues.e1y_con * SwingContactValues.batvx_con)) / sqrt(power(SwingContactValues.batvx_con, 2) + power(SwingContactValues.batvy_con, 2) + power(SwingContactValues.batvz_con, 2)) else null end between -2 and 2 then (case when Pitches.bat_side = 'R' then ((SwingContactValues.ballx_con - SwingContactValues.batx_con) * (SwingContactValues.e1y_con * SwingContactValues.batvz_con - SwingContactValues.e1z_con * SwingContactValues.batvy_con) - (SwingContactValues.bally_con - SwingContactValues.baty_con) * (SwingContactValues.e1x_con * SwingContactValues.batvz_con - SwingContactValues.e1z_con * SwingContactValues.batvx_con) +  (SwingContactValues.ballz_con - SwingContactValues.batz_con) * (SwingContactValues.e1x_con * SwingContactValues.batvy_con - SwingContactValues.e1y_con * SwingContactValues.batvx_con)) / sqrt(power(SwingContactValues.batvx_con, 2) + power(SwingContactValues.batvy_con, 2) + power(SwingContactValues.batvz_con, 2)) when Pitches.bat_side = 'L' then ((SwingContactValues.ballx_con - SwingContactValues.batx_con) * (-1 * SwingContactValues.e1y_con * SwingContactValues.batvz_con - -1 * SwingContactValues.e1z_con * SwingContactValues.batvy_con) - (SwingContactValues.bally_con - SwingContactValues.baty_con) * (-1 * SwingContactValues.e1x_con * SwingContactValues.batvz_con - -1 * SwingContactValues.e1z_con * SwingContactValues.batvx_con) +  (SwingContactValues.ballz_con - SwingContactValues.batz_con) * (-1 * SwingContactValues.e1x_con * SwingContactValues.batvy_con - -1 * SwingContactValues.e1y_con * SwingContactValues.batvx_con)) / sqrt(power(SwingContactValues.batvx_con, 2) + power(SwingContactValues.batvy_con, 2) + power(SwingContactValues.batvz_con, 2)) else null end) * 12 else null end) as ContactLocationPerpendicularBatAvg
, avg(case when case when Pitches.pitch_result_id in (12,13,14,18,19,20) then 1 else 0 end = 1 and case when Pitches.bat_side = 'R' then degrees(atn2(SwingContactValues.e1y_con, SwingContactValues.e1x_con)) else degrees(atn2(SwingContactValues.e1y_con, -SwingContactValues.e1x_con)) end between -90 and 80 then case when Pitches.bat_side = 'R' then degrees(atn2(SwingContactValues.e1y_con, SwingContactValues.e1x_con)) else degrees(atn2(SwingContactValues.e1y_con, -SwingContactValues.e1x_con)) end else null end) as HorzBatAngleAtContactAvg
, avg(case when case when Pitches.pitch_result_id in (12,13,14,18,19,20) then 1 else 0 end = 1 and 90 - degrees(acos(SwingContactValues.e1z_con)) between -70 and 10 then 90 - degrees(acos(SwingContactValues.e1z_con)) else null end) as VertBatAngleAtContactAvg
, avg(case when case when Pitches.pitch_result_id in (12,13,14,18,19,20) then 1 else 0 end = 1 and sqrt(power(SwingContactValues.batvx_con, 2) + power(SwingContactValues.batvy_con, 2) + power(SwingContactValues.batvz_con, 2)) * 0.681818 between 0 and 100 then sqrt(power(SwingContactValues.batvx_con, 2) + power(SwingContactValues.batvy_con, 2) + power(SwingContactValues.batvz_con, 2)) * 0.681818 else null end) as BatSpeedAtContactAvg
, avg(case when case when Pitches.pitch_result_id in (12,13,14,18,19,20) then 1 else 0 end = 1 and 90 - degrees(acos(SwingContactValues.batvz_con/sqrt(power(SwingContactValues.batvx_con,2)+power(SwingContactValues.batvy_con,2)+power(SwingContactValues.batvz_con,2)))) between -50 and 50 then 90 - degrees(acos(SwingContactValues.batvz_con/sqrt(power(SwingContactValues.batvx_con,2)+power(SwingContactValues.batvy_con,2)+power(SwingContactValues.batvz_con,2)))) else null end) as AttackAngleAtContactAvg
, avg(case when SwingDamageWindows.damage_window between 0.0 and 0.05 then SwingDamageWindows.damage_window * 1000 else null end) as SwingDamageWindowAvg
, avg(case when cast(1 as decimal) / SwingShapes.Km30 between 1.0 and 5.0 then cast(1 as decimal) / SwingShapes.Km30 else null end) as SwingRadiusMinus30degAvg
, avg(case when cast(1 as decimal) / SwingShapes.Km15 between 1.0 and 4.0 then cast(1 as decimal) / SwingShapes.Km15 else null end) as SwingRadiusMinus15degAvg
, avg(case when cast(1 as decimal) / SwingShapes.K0 between 1.0 and 4.0 then cast(1 as decimal) / SwingShapes.K0 else null end) as SwingRadius0degAvg
, avg(case when cast(1 as decimal) / SwingShapes.K15 between 2.0 and 4.0 then cast(1 as decimal) / SwingShapes.K15 else null end) as SwingRadius15degAvg
, avg(case when cast(1 as decimal) / SwingShapes.K30 between 2.0 and 5.0 then cast(1 as decimal) / SwingShapes.K30 else null end) as SwingRadius30degAvg
, avg(case when cast(1 as decimal) / SwingShapes.K45 between 3.0 and 7.0 then cast(1 as decimal) / SwingShapes.K45 else null end) as SwingRadius45degAvg
, avg(case when SwingShapes.loft between -20.0 and 27.5 then SwingShapes.loft else null end) as SwingShapesLoftAvg
, avg(case when SwingShapes.tilt between 0.0 and 65 then SwingShapes.tilt else null end) as SwingShapesTiltAvg
  INTO #AGG 
 FROM Astros.Pitches_View Pitches
 left join astros.schedule_view Schedule on Pitches.sched_id = Schedule.sched_id
 left join astros.projections_pitches_grades ProjPitchGrades on Pitches.sched_id = ProjPitchGrades.sched_id and Pitches.pitch_id = ProjPitchGrades.pitch_id
 left join astros.pitches_grades PitchGrades on Pitches.sched_id = PitchGrades.sched_id and Pitches.pitch_id = PitchGrades.pitch_id
 left join astros.bat_tracking_metrics BatTrackingMetrics on Pitches.sched_id = BatTrackingMetrics.sched_id and Pitches.pitch_id = BatTrackingMetrics.pitch_id and time_pitcher_face between .2 and .6 and yaw_pitcher_face between -5 and 5 and time_peak between .2 and .6 and yaw_peak between -30 and 30 and roll_pitcher_face between -60 and 0 and roll_peak between -60 and 0 and v_peak between 70 and 155 and ASIN(vz_pitcher_face / nullif(v_pitcher_face, 0)) * (180 / PI()) between -30 and 40 and ASIN(vz_peak / nullif(v_peak, 0)) * (180 / PI()) between -30 and 40
 left join groundcontroltracking.tracking.plays TrackingPlays on Pitches.sched_id = TrackingPlays.sched_id and Pitches.pitch_id = TrackingPlays.astros_pitch_id
  left join groundcontroltracking.tracking.swing_contact_values as SwingContactValues on SwingContactValues.sched_id = TrackingPlays.sched_id and SwingContactValues.tracking_play_id = TrackingPlays.tracking_play_id
 left join groundcontroltracking.tracking.swing_damage_windows as SwingDamageWindows on SwingDamageWindows.sched_id = TrackingPlays.sched_id and SwingDamageWindows.tracking_play_id = TrackingPlays.tracking_play_id
 left join groundcontroltracking.tracking.swing_shapes as SwingShapes on SwingShapes.sched_id = TrackingPlays.sched_id and SwingShapes.tracking_play_id = TrackingPlays.tracking_play_id
 WHERE Pitches.batter_id = @Param0
 AND  (Schedule.is_pro_level_and_winter IN /** @Param1 **/ ('1')) AND  (case when Schedule.sched_type = 'R' then 'Reg' when Schedule.sched_type in ('S', 'U') then 'Spr' when Schedule.sched_type in ('F', 'D', 'L', 'W', 'C') then 'Post' when Schedule.sched_type in ('P', 'E', 'I', 'A', 'V') then 'Unoff' when Schedule.sched_type = 'B' then 'Bull' else 'Other' end IN /** @Param2 **/ ('Reg'))
 AND Pitches.ignore_flag = 0 AND Pitches.pitch_id > 0
 GROUP BY  Schedule.gc2_level_code, dbo.GetLevelOrder(Schedule.gc2_level_code), Schedule.year
-- GO
 OPTION(RECOMPILE) 
  SELECT  Agg.GameLevel, Agg.LevelOrder, Agg.GameYear, Agg.GenericCount, Agg.SwingPercentage, Agg.SwingingStrikePercentage, Agg.SwingPercentage_InZone, Agg.SwingPercentage_OutZone, Agg.ContactPercentage, Agg.InZonePercentage, Agg.ContactPercentage_InZone, Agg.ContactPercentage_OutZone, Agg.ChasePercentage, Agg.WhiffPercentage, Agg.WhiffPercentage_InZone, Agg.RV_BIP_Avg, Agg.RV_HitSpecs_BIP_Avg, Agg.RvGain_Avg, Agg.RvGainGivenHitSpecs_Avg, Agg.SwingDecisionAgainstGrade2080_Avg, Agg.SwingDecisionAgainstComponentGrade2080_Avg, Agg.SwingDecisionAgainstABSComponentGrade2080_Avg, Agg.StuffRelVel2080_Avg, Agg.PG_Grade_Avg, Agg.BatTrackingNumSwings, Agg.BatTrackingPeakAttackAngle_Avg, Agg.BatTrackingPeakBatSpeed_Avg, Agg.BatTrackingLocAdjOpenFaceAttackAngle_Avg, Agg.BatTrackingLocAdjOpenFaceVerticalBatAngle_Avg, Agg.ContactLocationAxisAvg, Agg.ContactLocationPerpendicularAvg, Agg.ContactLocationPerpendicularBatAvg, Agg.HorzBatAngleAtContactAvg, Agg.VertBatAngleAtContactAvg, Agg.BatSpeedAtContactAvg, Agg.AttackAngleAtContactAvg, Agg.SwingDamageWindowAvg, Agg.SwingRadiusMinus30degAvg, Agg.SwingRadiusMinus15degAvg, Agg.SwingRadius0degAvg, Agg.SwingRadius15degAvg, Agg.SwingRadius30degAvg, Agg.SwingRadius45degAvg, Agg.SwingShapesLoftAvg, Agg.SwingShapesTiltAvg
 FROM 
#AGG AGG 
 WHERE 1=1 
 ORDER BY 
 GameYear DESC, LevelOrder ASC

