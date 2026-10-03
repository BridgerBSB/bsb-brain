-- GC2 OF Fielding Detail Query (HOU players, event-level PAAEO join)
-- Source: User-captured from GC2 production tool
--
-- KEY DISCOVERY: `positional` column in Defense_Combined_By_Pos
--   positional = 1 → play was TRACKED (HawkEye tracking data available)
--   positional = 0 → play was NOT TRACKED (no tracking data)
--
-- GC2 computes TWO versions of each metric:
--   1. Overall (all plays, both tracked + untracked)
--   2. Tracked only (positional = 1)
--
-- PAAEO join is at the EVENT level (not post-aggregation):
--   PaaEo.positional = OutProbs.positional
--   PaaEo.pos_id = OutProbs.pos_id
--   PaaEo.season = Schedule.year
--
-- This means different calibration offsets for tracked vs untracked plays.
-- avg(PaaEo.paaeo_offset) naturally weight-averages across both.
--
-- Metrics:
--   ExpectedOuts = SUM(out_prob) * AVG(eo_scalar)
--   PAA = (SUM(paa)/SUM(out_prob) - AVG(paaeo_offset)) * SUM(out_prob) * AVG(eo_scalar)
--   PAA/EO = SUM(paa)/SUM(out_prob) - AVG(paaeo_offset)
--   RAA = PAA * SUM(drv * out_prob) / SUM(out_prob)
--   RAA/EO = PAA/EO * SUM(drv * out_prob) / SUM(out_prob)
--
-- _Tracked variants: same formulas but filtered to positional = 1

/** Players **/
DROP TABLE IF EXISTS #AGG; DROP TABLE IF EXISTS #NTILE;
GO
-- DECLARE @Param0 varchar(1000) = 'HOU';

 SELECT Players.first_name + ' ' + Players.last_name as PlayerName
, Players.groundcontrol_id as PlayerGcId
 FROM Astros.Players Players
 left join mlb_ebis.pp_master EbisPpMaster on Players.ebis_id = EbisPpMaster.player_id and EbisPpMaster.employee_flg = 0
 left join mlb_ebis.pp_playerdata EbisPpPlayerData on Players.ebis_id = EbisPpPlayerData.player_id
 WHERE case when EbisPpMaster.mnrosterstatus_lk is null then EbisPpMaster.mjrosterstatus_lk
            when EbisPpMaster.mjrosterstatus_lk is null then EbisPpMaster.mnrosterstatus_lk
            else concat(EbisPpMaster.mjrosterstatus_lk, '/', EbisPpMaster.mnrosterstatus_lk) end is not null
   AND (EbisPpMaster.ORG_LK IN ('HOU'))
   AND (case when EbisPpMaster.org_lk is not null or EbisPpPlayerData.highestlevelofplay_lk is not null then 1 else 0 end IN ('1'))
   AND (coalesce(nullif(EbisPpMaster.mjrosterstatus_lk, 'OUTRT'), EbisPpMaster.mnrosterstatus_lk, '') NOT IN ('VOL', 'DEC'));

/** Event-level aggregation with PAAEO join **/
DROP TABLE IF EXISTS #AGG; DROP TABLE IF EXISTS #NTILE;
GO
DECLARE @SeasonStart int = 2024;
DECLARE @SeasonEnd int = 2025;

SELECT
    PlayersGames.groundcontrol_id AS FielderId,
    COUNT(DISTINCT PlayersGames.sched_id) AS FielderG,
    COUNT(DISTINCT CASE WHEN AstrosLineup.lineup IS NOT NULL THEN AstrosLineup.sched_id ELSE NULL END) AS FielderGS,

    -- ===== OVERALL metrics (all plays) =====
    SUM(OutProbs.out_prob) * AVG(PaaEo.eo_scalar) AS ExpectedOuts,

    (SUM(OutProbs.paa) / NULLIF(SUM(OutProbs.out_prob), 0) - AVG(PaaEo.paaeo_offset))
        * SUM(OutProbs.out_prob) * AVG(PaaEo.eo_scalar)
    AS PlaysAboveAverage,

    SUM(OutProbs.paa) / NULLIF(SUM(OutProbs.out_prob), 0) - AVG(PaaEo.paaeo_offset)
    AS PlaysAboveAveragePerExpectedOut,

    (SUM(OutProbs.paa) / NULLIF(SUM(OutProbs.out_prob), 0) - AVG(PaaEo.paaeo_offset))
        * SUM(OutProbs.out_prob) * AVG(PaaEo.eo_scalar)
        * SUM(OutProbs.drv * OutProbs.out_prob) / SUM(OutProbs.out_prob)
    AS RunsAboveAverage,

    (SUM(OutProbs.paa) / NULLIF(SUM(OutProbs.out_prob), 0) - AVG(PaaEo.paaeo_offset))
        * SUM(OutProbs.drv * OutProbs.out_prob) / SUM(OutProbs.out_prob)
    AS RunsAboveAveragePerExpectedOut,

    -- ===== TRACKED metrics (positional = 1 only) =====
    SUM(CASE WHEN OutProbs.positional = 1 THEN OutProbs.out_prob ELSE NULL END)
        * AVG(CASE WHEN OutProbs.positional = 1 THEN PaaEo.eo_scalar ELSE NULL END)
    AS EOTracked,

    (SUM(CASE WHEN OutProbs.positional = 1 THEN OutProbs.paa ELSE NULL END)
        / NULLIF(SUM(CASE WHEN OutProbs.positional = 1 THEN OutProbs.out_prob ELSE NULL END), 0)
        - AVG(CASE WHEN OutProbs.positional = 1 THEN PaaEo.paaeo_offset ELSE NULL END))
        * SUM(CASE WHEN OutProbs.positional = 1 THEN OutProbs.out_prob ELSE NULL END)
        * AVG(CASE WHEN OutProbs.positional = 1 THEN PaaEo.eo_scalar ELSE NULL END)
    AS PlaysAboveAverage_Tracked,

    SUM(CASE WHEN OutProbs.positional = 1 THEN OutProbs.paa ELSE NULL END)
        / NULLIF(SUM(CASE WHEN OutProbs.positional = 1 THEN OutProbs.out_prob ELSE NULL END), 0)
        - AVG(CASE WHEN OutProbs.positional = 1 THEN PaaEo.paaeo_offset ELSE NULL END)
    AS PlaysAboveAveragePerExpectedOut_Tracked,

    (SUM(CASE WHEN OutProbs.positional = 1 THEN OutProbs.paa ELSE NULL END)
        / NULLIF(SUM(CASE WHEN OutProbs.positional = 1 THEN OutProbs.out_prob ELSE NULL END), 0)
        - AVG(CASE WHEN OutProbs.positional = 1 THEN PaaEo.paaeo_offset ELSE NULL END))
        * SUM(CASE WHEN OutProbs.positional = 1 THEN OutProbs.out_prob ELSE NULL END)
        * AVG(CASE WHEN OutProbs.positional = 1 THEN PaaEo.eo_scalar ELSE NULL END)
        * SUM(CASE WHEN OutProbs.positional = 1 THEN OutProbs.drv * OutProbs.out_prob ELSE NULL END)
        / SUM(CASE WHEN OutProbs.positional = 1 THEN OutProbs.out_prob ELSE NULL END)
    AS RunsAboveAverage_Tracked,

    (SUM(CASE WHEN OutProbs.positional = 1 THEN OutProbs.paa ELSE NULL END)
        / NULLIF(SUM(CASE WHEN OutProbs.positional = 1 THEN OutProbs.out_prob ELSE NULL END), 0)
        - AVG(CASE WHEN OutProbs.positional = 1 THEN PaaEo.paaeo_offset ELSE NULL END))
        * SUM(CASE WHEN OutProbs.positional = 1 THEN OutProbs.drv * OutProbs.out_prob ELSE NULL END)
        / SUM(CASE WHEN OutProbs.positional = 1 THEN OutProbs.out_prob ELSE NULL END)
    AS RunsAboveAveragePerExpectedOut_Tracked,

    SUM(CAST(OutProbs.positional AS int)) AS PlaysTracked

INTO #AGG
FROM Astros.Events_View CurEvents
LEFT JOIN Astros.Schedule_View Schedule ON CurEvents.sched_id = Schedule.sched_id
LEFT JOIN Astros.Players_Games PlayersGames ON CurEvents.sched_id = PlayersGames.sched_id AND PlayersGames.pos_id <> 0
LEFT JOIN Astros.Schedule_View FielderSchedule ON PlayersGames.sched_id = FielderSchedule.sched_id
LEFT JOIN MLBAM.Teams FielderTeam ON PlayersGames.team_id = FielderTeam.team_id AND FielderSchedule.year = FielderTeam.season
LEFT JOIN Astros.Lineup_View AstrosLineup ON PlayersGames.sched_id = AstrosLineup.sched_id
    AND PlayersGames.groundcontrol_id = AstrosLineup.groundcontrol_id
    AND AstrosLineup.pos = dbo.GetPositionString(PlayersGames.pos_id)
LEFT JOIN Astros.Defense_Combined_By_Pos OutProbs ON CurEvents.sched_id = OutProbs.sched_id
    AND CurEvents.event_id = OutProbs.event_id
    AND PlayersGames.pos_id = OutProbs.pos_id
    AND PlayersGames.groundcontrol_id = OutProbs.groundcontrol_id
LEFT JOIN guts.PAA_EO_Position_Calibration PaaEo ON PaaEo.positional = OutProbs.positional
    AND PaaEo.pos_id = OutProbs.pos_id
    AND PaaEo.season = Schedule.year
WHERE Schedule.year >= @SeasonStart
  AND Schedule.year <= @SeasonEnd
  AND Schedule.gc2_level_id IN ('13', '1', '2', '3')
  AND FielderTeam.org_abbrev IN ('HOU')
  AND Schedule.sched_type IN ('r')
GROUP BY PlayersGames.groundcontrol_id
OPTION(RECOMPILE);

SELECT * FROM #AGG;
DROP TABLE IF EXISTS #AGG;
