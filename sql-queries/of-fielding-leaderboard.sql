-- OF Fielding Leaderboard Query
-- Source: GC2 OF Leaderboard tool
--
-- Key tables:
--   Astros.Tracking_Defensive_Metrics (play-level tracking data)
--   Astros.Schedule_View (gc2_level_id for level filtering)
--   Astros.Players_Games (pos_id for position filtering)
--   Astros.Defense_Combined_By_Pos (out probabilities)
--
-- Metrics and their aggregation:
--   TopSpeedFielding:    95th percentile (competitive_play=1, top_speed <= 34)
--   AccelerationChestUp: 75th percentile (competitive_play=1)
--   AccelerationChestDown: 75th percentile (competitive_play=1)
--   ReactionTime:        25th percentile (competitive_play=1) — LOWER IS BETTER
--   UsefulReactionTime:  25th percentile (competitive_play=1) — LOWER IS BETTER
--   ReactionRadius:      25th percentile (competitive_play=1) — LOWER IS BETTER
--   ReactionAccuracyRadius: 25th percentile (competitive_play=1) — LOWER IS BETTER
--   ArmStrengthOF:       99th percentile (competitive_throw=1, pos_id IN 7,8,9, arm_strength 60-100)
--   ExchangeOF:          10th percentile (competitive_throw=1, pos_id IN 7,8,9, exchange >= 0.4, arm_strength >= 60) — LOWER IS BETTER
--
-- Position IDs: 7=LF, 8=CF, 9=RF
-- Level: gc2_level_id (13=MLB, etc.)
-- No org filter = league-wide data (all 30 teams)

DECLARE @Season int = 2025;
DECLARE @LevelId varchar(10) = '13';  -- MLB

-- Step 1: Aggregate counts per player
SELECT
    PlayersGames.groundcontrol_id as FielderId,
    SUM(CAST(OutProbs.competitive_play AS int)) AS CompetitivePlays,
    SUM(CAST(DefensiveMetrics.out_made AS int)) AS OutsMade,
    SUM(CASE WHEN DefensiveMetrics.competitive_throw = 1
             AND DefensiveMetrics.pos_id IN (7,8,9)
             AND DefensiveMetrics.arm_strength >= 60
             AND DefensiveMetrics.arm_strength <= 100
        THEN 1 ELSE 0 END) AS ArmStrengthThrowsOF,
    SUM(OutProbs.paa) / NULLIF(SUM(OutProbs.out_prob), 0)
        - AVG(PaaEo.paaeo_offset) AS PlaysAboveAveragePerExpectedOut
INTO #AGG
FROM Astros.Events_View CurEvents
LEFT JOIN Astros.Schedule_View Schedule ON CurEvents.sched_id = Schedule.sched_id
LEFT JOIN Astros.Players_Games PlayersGames ON CurEvents.sched_id = PlayersGames.sched_id AND PlayersGames.pos_id <> 0
LEFT JOIN Astros.Defense_Combined_By_Pos OutProbs ON CurEvents.sched_id = OutProbs.sched_id
    AND CurEvents.event_id = OutProbs.event_id
    AND PlayersGames.pos_id = OutProbs.pos_id
    AND PlayersGames.groundcontrol_id = OutProbs.groundcontrol_id
LEFT JOIN guts.PAA_EO_Position_Calibration PaaEo ON PaaEo.positional = OutProbs.positional
    AND PaaEo.pos_id = OutProbs.pos_id
    AND PaaEo.season = Schedule.year
LEFT JOIN Astros.Tracking_Defensive_Metrics DefensiveMetrics ON CurEvents.sched_id = DefensiveMetrics.sched_id
    AND CurEvents.event_id = DefensiveMetrics.event_id
    AND PlayersGames.pos_id = DefensiveMetrics.pos_id
    AND PlayersGames.groundcontrol_id = DefensiveMetrics.groundcontrol_id
WHERE Schedule.year = @Season
  AND Schedule.gc2_level_id = @LevelId
  AND PlayersGames.pos_id IN (7, 8, 9)  -- OF positions
  AND Schedule.sched_type = 'r'  -- regular season
GROUP BY PlayersGames.groundcontrol_id;

-- Step 2: Compute player-level metric values using percentile_cont
SELECT DISTINCT
    PlayersGames.groundcontrol_id AS FielderId,

    -- Speed (95th percentile, higher is better)
    PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY
        CASE WHEN DefensiveMetrics.competitive_play = 1 AND DefensiveMetrics.top_speed <= 34
        THEN DefensiveMetrics.top_speed ELSE NULL END
    ) OVER (PARTITION BY PlayersGames.groundcontrol_id) AS TopSpeedFielding,

    -- Acceleration (75th percentile, higher is better)
    PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY
        CASE WHEN DefensiveMetrics.competitive_play = 1
        THEN DefensiveMetrics.acceleration_chest_up ELSE NULL END
    ) OVER (PARTITION BY PlayersGames.groundcontrol_id) AS AccelerationChestUp,

    PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY
        CASE WHEN DefensiveMetrics.competitive_play = 1
        THEN DefensiveMetrics.acceleration_chest_down ELSE NULL END
    ) OVER (PARTITION BY PlayersGames.groundcontrol_id) AS AccelerationChestDown,

    -- Reaction (25th percentile, lower is better)
    PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY
        CASE WHEN DefensiveMetrics.competitive_play = 1
        THEN DefensiveMetrics.reaction_4mph ELSE NULL END
    ) OVER (PARTITION BY PlayersGames.groundcontrol_id) AS ReactionTime,

    PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY
        CASE WHEN DefensiveMetrics.competitive_play = 1
        THEN DefensiveMetrics.useful_reaction_4mph ELSE NULL END
    ) OVER (PARTITION BY PlayersGames.groundcontrol_id) AS UsefulReactionTime,

    PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY
        CASE WHEN DefensiveMetrics.competitive_play = 1
        THEN DefensiveMetrics.reaction_radius ELSE NULL END
    ) OVER (PARTITION BY PlayersGames.groundcontrol_id) AS ReactionRadius,

    PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY
        CASE WHEN DefensiveMetrics.competitive_play = 1
        THEN DefensiveMetrics.reaction_accuracy_radius ELSE NULL END
    ) OVER (PARTITION BY PlayersGames.groundcontrol_id) AS ReactionAccuracyRadius,

    -- Arm (99th percentile for strength, higher is better)
    PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY
        CASE WHEN DefensiveMetrics.competitive_throw = 1
             AND DefensiveMetrics.pos_id IN (7,8,9)
             AND DefensiveMetrics.arm_strength >= 60
             AND DefensiveMetrics.arm_strength <= 100
        THEN DefensiveMetrics.arm_strength ELSE NULL END
    ) OVER (PARTITION BY PlayersGames.groundcontrol_id) AS ArmStrengthOF,

    -- Exchange (10th percentile, lower is better)
    PERCENTILE_CONT(0.10) WITHIN GROUP (ORDER BY
        CASE WHEN DefensiveMetrics.competitive_throw = 1
             AND DefensiveMetrics.pos_id IN (7,8,9)
             AND DefensiveMetrics.exchange >= 0.4
             AND DefensiveMetrics.arm_strength >= 60
        THEN DefensiveMetrics.exchange ELSE NULL END
    ) OVER (PARTITION BY PlayersGames.groundcontrol_id) AS ExchangeOF

INTO #NTILE
FROM Astros.Events_View CurEvents
LEFT JOIN Astros.Schedule_View Schedule ON CurEvents.sched_id = Schedule.sched_id
LEFT JOIN Astros.Players_Games PlayersGames ON CurEvents.sched_id = PlayersGames.sched_id AND PlayersGames.pos_id <> 0
LEFT JOIN Astros.Defense_Combined_By_Pos OutProbs ON CurEvents.sched_id = OutProbs.sched_id
    AND CurEvents.event_id = OutProbs.event_id
    AND PlayersGames.pos_id = OutProbs.pos_id
    AND PlayersGames.groundcontrol_id = OutProbs.groundcontrol_id
LEFT JOIN guts.PAA_EO_Position_Calibration PaaEo ON PaaEo.positional = OutProbs.positional
    AND PaaEo.pos_id = OutProbs.pos_id
    AND PaaEo.season = Schedule.year
LEFT JOIN Astros.Tracking_Defensive_Metrics DefensiveMetrics ON CurEvents.sched_id = DefensiveMetrics.sched_id
    AND CurEvents.event_id = DefensiveMetrics.event_id
    AND PlayersGames.pos_id = DefensiveMetrics.pos_id
    AND PlayersGames.groundcontrol_id = DefensiveMetrics.groundcontrol_id
WHERE Schedule.year = @Season
  AND Schedule.gc2_level_id = @LevelId
  AND PlayersGames.pos_id IN (7, 8, 9)
  AND Schedule.sched_type = 'r';

-- Final result: join aggregates with percentile values
SELECT
    Agg.FielderId,
    Agg.CompetitivePlays,
    Agg.OutsMade,
    Ntile.TopSpeedFielding,
    Ntile.AccelerationChestUp,
    Ntile.AccelerationChestDown,
    Ntile.ReactionTime,
    Ntile.UsefulReactionTime,
    Ntile.ReactionRadius,
    Ntile.ReactionAccuracyRadius,
    Agg.ArmStrengthThrowsOF,
    Ntile.ArmStrengthOF,
    Ntile.ExchangeOF,
    Agg.PlaysAboveAveragePerExpectedOut
FROM #AGG Agg
JOIN #NTILE Ntile ON Agg.FielderId = Ntile.FielderId;

-- Cleanup
DROP TABLE IF EXISTS #AGG;
DROP TABLE IF EXISTS #NTILE;
