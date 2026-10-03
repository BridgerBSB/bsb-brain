/**
 * gc2_query_pitch_grades.sql
 * 
 * SOURCE: Ground Control 2 internal app query
 * PURPOSE: Pitch grades and projections by bat side, pitch type, year
 * 
 * METRICS INCLUDED:
 * - Pitch Grade Hierarchy: StuffVel, StuffRelVel, All (Loc), Component, Grade
 * - Expected Metrics: PG_Exp_Whiff, PG_Exp_SwStr, PG_Exp_Chase, PG_Exp_CalledStrike
 * - ProjLoc (Grade - StuffRelVel = location contribution)
 * - gcPerformanceGrade
 * - SwingDecision variants
 */

DROP TABLE IF EXISTS #AGG; DROP TABLE IF EXISTS #NTILE;
GO
DECLARE @Param0 varchar(1000) = '110430';  -- pitcher_id
-- DECLARE @Param1 varchar(1000) = '1';     -- is_pro_level_and_winter
-- DECLARE @Param2 varchar(1000) = 'Reg';   -- schedule type

SELECT  
    Pitches.bat_side as BatSide, 
    Pitches.pitch_type as PitchType, 
    dbo.GetPitchTypeOrder(Pitches.pitch_type) as PitchTypeOrder, 
    Schedule.year as GameYear,
    count(1) as GenericCount,
    count(1) as PitchUsage,

    -- Pitch Grade Hierarchy (20-80 scale)
    -- Each level adds more context: StuffVel → StuffRelVel → All → Component → Grade
    avg(PitchGrades.stuffvel_grade_2080) as StuffVel2080_Avg,           -- Movement + Velo + Max Velo
    avg(PitchGrades.stuffrelvel_grade_2080) as StuffRelVel2080_Avg,     -- + Release + Extension
    avg(PitchGrades.stuffvelloc_grade_2080) as StuffVelLoc2080_Avg,     -- StuffVel + Location
    avg(PitchGrades.stuffrelvelloc_grade_2080) as StuffRelVelLoc2080_Avg, -- StuffRelVel + Location (= "All")
    avg(PitchGrades.component_grade_2080) as Component2080_Avg,         -- All + Count
    avg(ProjPitchGrades.fb_grade) as PG_Grade_Avg,                      -- Component + TTO (most predictive)

    -- Location Contribution = Grade - StuffRelVel
    -- Positive = location is helping, Negative = location is hurting
    avg(ProjPitchGrades.fb_grade - PitchGrades.stuffrelvel_grade_2080) as ProjLoc_Avg,

    -- Expected Metrics (from projection model)
    -- PG_Exp_Whiff: Expected whiff rate given swing
    sum(ProjPitchGrades.pg_whiff_swing * ProjPitchGrades.pg_swing) 
        / nullif(sum(ProjPitchGrades.pg_swing),0) as PG_Exp_Whiff_Avg,
    
    -- PG_Exp_SwStr: Expected swinging strike rate
    avg(ProjPitchGrades.pg_whiff_swing * ProjPitchGrades.pg_swing) as PG_Exp_SwStr_Avg,
    
    -- PG_Exp_Chase: Expected chase rate on pitches outside zone (csc < 0.01)
    avg(case when Pitches.called_strike_chance_mlb < 0.01 then ProjPitchGrades.pg_swing else null end) as PG_Exp_Chase_Avg,
    
    -- PG_Exp_CalledStrike: Expected called strike rate
    avg((1-ProjPitchGrades.pg_swing) * Pitches.called_strike_chance_mlb) as PG_Exp_CalledStrike_Avg,

    -- gcPerformanceGrade (Astros custom 20-80 scale)
    50.0 - 1500.0 * avg(
        case 
            when Pitches.pitch_result_id in (10, 22, 23) then 
                case when Pitches.swing_zone in ('heart', 'meatball') then -.1 else -.08 end
            when Pitches.pitch_result_id in (6) then -.02
            when Pitches.pitch_result_id in (4, 5, 11) then .02
            when Pitches.pitch_result_id in (12, 13, 14) then 
                case when Hits.hit_exit_speed >= 0.011 * power(Hits.hit_vertical_angle, 2) 
                                                      - 0.91 * Hits.hit_vertical_angle + 95.0 
                     then .09 else -.02 end
            else 0.0 
        end
    ) as gcPerformanceGrade,

    -- Swing Decision (from hitter's perspective - pitcher sees "against")
    avg(ProjPitchGrades.swing_decision) as SwingDecisionAgainstGrade2080_Avg,
    avg(Pitches.swing_decision_grade_2080) as SwingDecisionAgainstComponentGrade2080_Avg,
    avg(Pitches.swing_decision_abs_grade_2080) as SwingDecisionAgainstABSComponentGrade2080_Avg

INTO #AGG 
FROM Astros.Pitches_View Pitches
LEFT JOIN astros.schedule_view Schedule ON Pitches.sched_id = Schedule.sched_id
LEFT JOIN astros.pitches_grades PitchGrades ON Pitches.sched_id = PitchGrades.sched_id 
    AND Pitches.pitch_id = PitchGrades.pitch_id
LEFT JOIN astros.projections_pitches_grades ProjPitchGrades ON Pitches.sched_id = ProjPitchGrades.sched_id 
    AND Pitches.pitch_id = ProjPitchGrades.pitch_id
LEFT JOIN astros.hits Hits ON Pitches.sched_id = Hits.sched_id 
    AND Pitches.pitch_id = Hits.pitch_id 
    AND Pitches.pitch_result_id in (12,13,14)
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
GROUP BY Pitches.bat_side, Pitches.pitch_type, dbo.GetPitchTypeOrder(Pitches.pitch_type), Schedule.year
OPTION(RECOMPILE);

-- Final output
SELECT Agg.BatSide, Agg.PitchType, Agg.PitchTypeOrder, Agg.GameYear, Agg.GenericCount, Agg.PitchUsage, 
       Agg.StuffVel2080_Avg, Agg.StuffRelVel2080_Avg, Agg.StuffVelLoc2080_Avg, Agg.StuffRelVelLoc2080_Avg,
       Agg.Component2080_Avg, Agg.PG_Grade_Avg, Agg.ProjLoc_Avg,
       Agg.PG_Exp_Whiff_Avg, Agg.PG_Exp_SwStr_Avg, Agg.PG_Exp_Chase_Avg, Agg.PG_Exp_CalledStrike_Avg, 
       Agg.gcPerformanceGrade, Agg.SwingDecisionAgainstGrade2080_Avg, 
       Agg.SwingDecisionAgainstComponentGrade2080_Avg, Agg.SwingDecisionAgainstABSComponentGrade2080_Avg
FROM #AGG AGG 
WHERE 1=1 
ORDER BY BatSide DESC, PitchTypeOrder ASC, GameYear DESC;
