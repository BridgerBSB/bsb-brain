/**
 * gc2_query_pitcher_tracking.sql
 * 
 * SOURCE: Ground Control 2 internal app query
 * PURPOSE: Pitcher performance tracking by game level, year, pitch type, bat side
 * 
 * METRICS INCLUDED:
 * - Strike%, InZone%, FirstPitch_InZone%, ZeroOrOneStrike_InZone%
 * - Swing%, SwStr%, CSW%
 * - ZSw%, OSw% (weighted), Chase% (binary)
 * - Contact%, ZContact%, OContact%
 * - Whiff%, ZWhiff%
 * - RV metrics (RV_BIP, RV_HitSpecs_BIP, RvGain, RvGainGivenHitSpecs)
 * - gcPerformanceGrade (custom Astros grade)
 * - SwingDecision variants (3 types)
 */

DROP TABLE IF EXISTS #AGG; DROP TABLE IF EXISTS #NTILE;
GO
DECLARE @Param0 varchar(1000) = '145429';  -- pitcher_id
-- DECLARE @Param1 varchar(1000) = '1';     -- is_pro_level_and_winter
-- DECLARE @Param2 varchar(1000) = 'Reg';   -- schedule type

SELECT  
    Schedule.gc2_level_code as GameLevel, 
    dbo.GetLevelOrder(Schedule.gc2_level_code) as LevelOrder, 
    Schedule.year as GameYear, 
    Pitches.pitch_type as PitchType, 
    dbo.GetPitchTypeOrder(Pitches.pitch_type) as PitchTypeOrder, 
    Pitches.bat_side as BatSide,
    count(1) as GenericCount,

    -- Strike Metrics
    avg(case when Pitches.pitch_result_id in (6,7,8,9,10,12,13,14,16,18,19,20,21,22,23,24,25) then 1.0 else 0.0 end) as StrikePercentage,
    avg(Pitches.called_strike_chance_mlb) as InZonePercentage,
    avg(case when Pitches.balls_before = 0 and Pitches.strikes_before = 0 then Pitches.called_strike_chance_mlb else null end) as FirstPitch_InZonePercentage,
    avg(case when Pitches.strikes_before = 0 or Pitches.strikes_before = 1 then Pitches.called_strike_chance_mlb else null end) as ZeroOrOneStrike_InZonePercentage,

    -- Swing Metrics
    avg(case when Pitches.did_swing = 1 then 1.0 else 0.0 end) as SwingPercentage,
    avg(case when Pitches.pitch_result_id in (10,21,22,23) then 1.0 else 0.0 end) as SwingingStrikePercentage,
    avg(case when Pitches.pitch_result_id in (6) then 1.0 else 0.0 end) 
        + avg(case when Pitches.pitch_result_id in (10,21,22,23) then 1.0 else 0.0 end) as CSWPercentage,

    -- Zone-Weighted Swing Rates
    sum(case when Pitches.did_swing = 1 then Pitches.called_strike_chance_mlb else null end)
        / nullif(sum(Pitches.called_strike_chance_mlb),0) as SwingPercentage_InZone,  -- ZSw% (weighted)
    sum(case when Pitches.did_swing = 1 then 1.0 - Pitches.called_strike_chance_mlb else null end)
        / nullif(sum(1.0 - Pitches.called_strike_chance_mlb),0) as SwingPercentage_OutZone,  -- OSw% (weighted)

    -- Contact Metrics
    avg(1.0 * case when Pitches.did_swing = 1 then case when Pitches.pitch_result_id not in (10,21,22,23) then 1 else 0 end else null end) as ContactPercentage,
    sum(case when Pitches.did_swing = 1 and Pitches.pitch_result_id not in (10,21,22,23) then Pitches.called_strike_chance_mlb else null end)
        / nullif(sum(case when Pitches.did_swing = 1 then Pitches.called_strike_chance_mlb else null end),0) as ContactPercentage_InZone,  -- ZContact%
    sum(case when Pitches.did_swing = 1 and Pitches.pitch_result_id not in (10,21,22,23) then 1 - Pitches.called_strike_chance_mlb else null end)
        / nullif(sum(1 - case when Pitches.did_swing = 1 then Pitches.called_strike_chance_mlb else null end),0) as ContactPercentage_OutZone,  -- OContact%

    -- Chase% (binary - csc < 0.01)
    avg(1.0 * case when Pitches.called_strike_chance_mlb < .01 then case when Pitches.did_swing = 1 then 1 else 0 end else null end) as ChasePercentage,

    -- Whiff Metrics
    avg(1.0 * case when Pitches.did_swing = 1 then case when Pitches.pitch_result_id in (10,21,22,23) then 1 else 0 end else null end) as WhiffPercentage,
    sum(case when Pitches.did_swing = 1 then case when Pitches.pitch_result_id in (10,21,22,23) then Pitches.called_strike_chance_mlb else 0 end else null end)
        / nullif(sum(case when Pitches.did_swing = 1 then Pitches.called_strike_chance_mlb else null end),0) as WhiffPercentage_InZone,  -- ZWhiff%

    -- Run Value Metrics
    avg(case when Pitches.pitch_result_id in (12,13,14) then Pitches.rv_gain + Pitches.rv_before else null end) as RV_BIP_Avg,
    avg(case when Pitches.pitch_result_id in (12,13,14) then Pitches.rv_gain_given_hit_specs + Pitches.rv_before else null end) as RV_HitSpecs_BIP_Avg,
    avg(Pitches.rv_gain) as RvGain_Avg,
    avg(Pitches.rv_gain_given_hit_specs) as RvGainGivenHitSpecs_Avg,

    -- gcPerformanceGrade (Astros custom 20-80 scale, 50 = average)
    -- Formula: 50 - (1500 * avg_run_value_per_pitch)
    -- Whiffs: -0.1 (heart/meatball) or -0.08 (other) = good for pitcher
    -- Called Strikes: -0.02 = good for pitcher
    -- Balls/HBP: +0.02 = bad for pitcher
    -- BIP with pBarrel: +0.09 = bad for pitcher
    -- BIP without pBarrel: -0.02 = good for pitcher
    50.0 - 1500.0 * avg(
        case 
            when Pitches.pitch_result_id in (10, 22, 23) then 
                case when Pitches.swing_zone in ('heart', 'meatball') then -.1 else -.08 end
            when Pitches.pitch_result_id in (6) then -.02  -- called strike
            when Pitches.pitch_result_id in (4, 5, 11) then .02  -- ball, HBP
            when Pitches.pitch_result_id in (12, 13, 14) then 
                -- pBarrel check: EV >= parabolic curve
                case when Hits.hit_exit_speed >= 0.011 * power(Hits.hit_vertical_angle, 2) - 0.91 * Hits.hit_vertical_angle + 95.0 
                     then .09 else -.02 end
            else 0.0 
        end
    ) as gcPerformanceGrade,

    -- Swing Decision Variants (from hitter's perspective, pitcher sees "against")
    avg(ProjPitchGrades.swing_decision) as SwingDecisionAgainstGrade2080_Avg,
    avg(Pitches.swing_decision_grade_2080) as SwingDecisionAgainstComponentGrade2080_Avg,
    avg(Pitches.swing_decision_abs_grade_2080) as SwingDecisionAgainstABSComponentGrade2080_Avg

INTO #AGG 
FROM Astros.Pitches_View Pitches
LEFT JOIN astros.schedule_view Schedule ON Pitches.sched_id = Schedule.sched_id
LEFT JOIN astros.hits Hits ON Pitches.sched_id = Hits.sched_id 
    AND Pitches.pitch_id = Hits.pitch_id 
    AND Pitches.pitch_result_id in (12,13,14)
LEFT JOIN astros.projections_pitches_grades ProjPitchGrades ON Pitches.sched_id = ProjPitchGrades.sched_id 
    AND Pitches.pitch_id = ProjPitchGrades.pitch_id
WHERE Pitches.pitcher_id = @Param0
    AND (Schedule.is_pro_level_and_winter IN ('1'))
    AND (case when Schedule.sched_type = 'R' then 'Reg' 
              when Schedule.sched_type in ('S', 'U') then 'Spr' 
              when Schedule.sched_type in ('F', 'D', 'L', 'W', 'C') then 'Post' 
              when Schedule.sched_type in ('P', 'E', 'I', 'A', 'V') then 'Unoff' 
              when Schedule.sched_type = 'B' then 'Bull' 
              else 'Other' end IN ('Reg'))
    AND Pitches.ignore_flag = 0 
    AND Pitches.pitch_id > 0
GROUP BY Schedule.gc2_level_code, dbo.GetLevelOrder(Schedule.gc2_level_code), Schedule.year, 
         Pitches.pitch_type, dbo.GetPitchTypeOrder(Pitches.pitch_type), Pitches.bat_side
OPTION(RECOMPILE);

-- Final output
SELECT Agg.GameLevel, Agg.LevelOrder, Agg.GameYear, Agg.PitchType, Agg.PitchTypeOrder, Agg.BatSide, 
       Agg.GenericCount, Agg.StrikePercentage, Agg.InZonePercentage, Agg.FirstPitch_InZonePercentage, 
       Agg.ZeroOrOneStrike_InZonePercentage, Agg.SwingPercentage, Agg.SwingingStrikePercentage, 
       Agg.CSWPercentage, Agg.SwingPercentage_InZone, Agg.SwingPercentage_OutZone, Agg.ContactPercentage, 
       Agg.ContactPercentage_InZone, Agg.ContactPercentage_OutZone, Agg.ChasePercentage, Agg.WhiffPercentage, 
       Agg.WhiffPercentage_InZone, Agg.RV_BIP_Avg, Agg.RV_HitSpecs_BIP_Avg, Agg.RvGain_Avg, 
       Agg.RvGainGivenHitSpecs_Avg, Agg.gcPerformanceGrade, Agg.SwingDecisionAgainstGrade2080_Avg, 
       Agg.SwingDecisionAgainstComponentGrade2080_Avg, Agg.SwingDecisionAgainstABSComponentGrade2080_Avg
FROM #AGG AGG 
WHERE 1=1 
ORDER BY GameYear DESC, LevelOrder ASC, PitchTypeOrder ASC, BatSide DESC;
