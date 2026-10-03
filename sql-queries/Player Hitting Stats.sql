 /** Event **/
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--[noformat]
--[noformat]
--[noformat]
DROP TABLE IF EXISTS #AGG; DROP TABLE IF EXISTS #NTILE;
GO
DECLARE @Param0 varchar(1000) = '93850';
DECLARE @Param1 varchar(1000) = '0';
-- DECLARE @Param2 varchar(1000) = '14', '6', '22', '8', '23';

 SELECT  Schedule.year as Year, case when Schedule.sched_type = 'R' then 'Reg' when Schedule.sched_type in ('S', 'U') then 'Spr' when Schedule.sched_type in ('F', 'D', 'L', 'W', 'C') then 'Post' when Schedule.sched_type in ('P', 'E', 'I', 'A', 'V') then 'Unoff' when Schedule.sched_type = 'B' then 'Bull' else 'Other' end as TypeGroup, case when Schedule.sched_type in ('S', 'U') then 1 when Schedule.sched_type = 'R' then 2 when Schedule.sched_type in ('F', 'D', 'L', 'W', 'C') then 3 when Schedule.sched_type in ('P', 'E', 'I', 'A', 'V') then 4 when Schedule.sched_type = 'B' then 5 else 6 end as TypeGroupOrder, BattingTeam.org_abbrev as BatterTeamOrg, datediff(DD, Batter.birthdate, datefromparts(Schedule.year,7,1)) / 365.25 as BatterAge, BattingTeam.league as BatterLeague, BattingTeam.name_short as BatterTeamName, dbo.GetLevelOrder(Schedule.gc2_level_code) as LevelOrder, dbo.GetLevelString(Schedule.gc2_level_code) as LevelString , sum(cast(CurEvents.pa as int)) as BatterPA
, sum(cast(CurEvents.ab as int)) as BatterAB
, sum(cast(CurEvents.[2b] as int)) as Batter2B
, sum(cast(CurEvents.[3b] as int)) as Batter3B
, sum(cast(CurEvents.hr as int)) as BatterHR
, case when (sum(cast(CurEvents.ab as int)))=0 then 0 else (1.0*sum(cast(CurEvents.[1b] as int) + cast(CurEvents.[2b] as int) + cast(CurEvents.[3b] as int) + cast(CurEvents.[hr] as int))) / (sum(cast(CurEvents.ab as int))) end as BatterBA
, (1.0 * (sum(cast(CurEvents.[1b] as int)+cast(CurEvents.[2b] as int)+cast(CurEvents.[3b] as int)+cast(CurEvents.[hr] as int)) + sum(cast(CurEvents.bb as int)) + sum(cast(CurEvents.hbp as int))) / nullif((sum(cast(CurEvents.ab as int)) + sum(cast(CurEvents.bb as int)) + sum(cast(CurEvents.hbp as int)) + sum(isnull(cast(CurEvents.sf as int),0))),0)) as BatterOBP
, (sum(1.0 * cast(CurEvents.[1b] as int) + 2.0 * cast(CurEvents.[2b] as int) + 3.0 * cast(CurEvents.[3b] as int) + 4.0 * cast(CurEvents.[hr] as int)) / nullif(sum(cast(CurEvents.ab as int)),0)) as BatterSLG
, (1.0 * (sum(cast(CurEvents.[1b] as int)+cast(CurEvents.[2b] as int)+cast(CurEvents.[3b] as int)+cast(CurEvents.[hr] as int)) + sum(cast(CurEvents.bb as int)) + sum(cast(CurEvents.hbp as int))) / nullif((sum(cast(CurEvents.ab as int)) + sum(cast(CurEvents.bb as int)) + sum(cast(CurEvents.hbp as int)) + sum(isnull(cast(CurEvents.sf as int),0))),0) + (sum(1.0 * cast(CurEvents.[1b] as int) + 2.0 * cast(CurEvents.[2b] as int) + 3.0 * cast(CurEvents.[3b] as int) + 4.0 * cast(CurEvents.[hr] as int)) / nullif(sum(cast(CurEvents.ab as int)),0))) as BatterOPS
, avg(YtdLeagueBatting.obp) * (0.50 * avg(case when CurEvents.pa = 1 then case when CurEvents.so = 1 then 1.0 else 0.0 end end) + 1.49 * avg(case when CurEvents.pa = 1 then case when (CurEvents.bb | CurEvents.hbp = 0) then 0.0 else 1.0 end end) + 0.11 * avg(case when CurEvents.pa = 1 then case when len(CurEvents.pitches) - len(replace(replace(replace(CurEvents.pitches, 'S', ''), 'W', ''), 'T', '')) = 0 then 1.0 else 0.0 end end) + 0.08 * avg(case when CurEvents.pa = 1 then case when len(CurEvents.pitches) - len(replace(replace(replace(CurEvents.pitches, 'S', ''), 'W', ''), 'T', '')) = 1 then 1.0 else 0.0 end end) + -0.10 * avg(case when CurEvents.pa = 1 then case when len(CurEvents.pitches) - len(replace(replace(replace(CurEvents.pitches, 'S', ''), 'W', ''), 'T', '')) = 2 then 1.0 else 0.0 end end) + -0.10 * avg(case when CurEvents.pa = 1 then case when len(CurEvents.pitches) - len(replace(replace(replace(CurEvents.pitches, 'S', ''), 'W', ''), 'T', '')) = 3 then 1.0 else 0.0 end end) + avg(case when CurEvents.pa = 1 then case when (CurEvents.bb | CurEvents.hbp | CurEvents.so = 0) then 1.0 else 0.0 end end) * (1.70 * isnull(avg(case when CurEvents.pa = 1 then case when HitsNoBunts.hit_exit_speed > 0 then case when HitsNoBunts.hit_exit_speed * 1.5 - HitsNoBunts.hit_vertical_angle >= 117 and HitsNoBunts.hit_exit_speed + HitsNoBunts.hit_vertical_angle >= 124 and HitsNoBunts.hit_exit_speed >= 98 and HitsNoBunts.hit_vertical_angle > 4 and HitsNoBunts.hit_vertical_angle < 50 then 1.0 else 0.0 end else null end end),0.0) + 1.09 * isnull(avg(case when CurEvents.pa = 1 then case when HitsNoBunts.hit_exit_speed > 0 then HitsNoBunts.hit_useful_exit_speed else null end end), 0.0)/100.0)) as gcOBA
, (AVG(Woba.woba_BB)*SUM(cast(CurEvents.BB as int)-cast(CurEvents.IBB as int)) + AVG(Woba.woba_HB)*SUM(cast(CurEvents.HBP as int)) + AVG(Woba.woba_1B)*SUM(cast(CurEvents.[1B] as int)) + AVG(Woba.woba_2B)*SUM(cast(CurEvents.[2B] as int)) + AVG(Woba.woba_3B)*SUM(cast(CurEvents.[3B] as int)) + AVG(Woba.woba_HR)*SUM(cast(CurEvents.HR as int))) / NULLIF(SUM(cast(CurEvents.AB as int) + cast(CurEvents.BB as int) - cast(CurEvents.IBB as int) + cast(CurEvents.SF as int) + cast(CurEvents.HBP as int)),0) as wOBA
, 100.0 * ( ( (AVG(Woba.woba_BB)*SUM(cast(CurEvents.BB as int)-cast(CurEvents.IBB as int)) + AVG(Woba.woba_HB)*SUM(cast(CurEvents.HBP as int)) + AVG(Woba.woba_1B)*SUM(cast(CurEvents.[1B] as int)) + AVG(Woba.woba_2B)*SUM(cast(CurEvents.[2B] as int)) + AVG(Woba.woba_3B)*SUM(cast(CurEvents.[3B] as int)) + AVG(Woba.woba_HR)*SUM(cast(CurEvents.HR as int))) / NULLIF(SUM(cast(CurEvents.AB as int) + cast(CurEvents.BB as int) - cast(CurEvents.IBB as int) + cast(CurEvents.SF as int) + cast(CurEvents.HBP as int)),0) - AVG(Woba.wOBA) ) / AVG(Woba.wOBA_scale) + AVG(Woba.runs_per_pa) ) / AVG(Woba.runs_per_pa) as wRCplus
, sum(isnull(cast(CurEvents.ibb as int),0)) as BatterIBB
, sum(cast(CurEvents.hbp as int)) as BatterHBP
, sum(cast(CurEvents.bb as int)) as BatterBB
, sum(cast(CurEvents.so as int)) as BatterK
, sum(cast(CurEvents.[1b] as int)+cast(CurEvents.[2b] as int)+cast(CurEvents.[3b] as int)+cast(CurEvents.[hr] as int)) as BatterH
  INTO #AGG 
 FROM Astros.Events_View CurEvents
 left join astros.pitches_view Pitches on CurEvents.sched_id = Pitches.sched_id and CurEvents.event_id = Pitches.cur_event_id
  left join astros.schedule_view Schedule on Pitches.sched_id = Schedule.sched_id
  left join mlbam.YTD_Team_Batting_Stats YtdLeagueBatting on YtdLeagueBatting.season = (case when year(getdate()) = Schedule.year and month(getdate()) < 5 then Schedule.year-1 else Schedule.year end) and YtdLeagueBatting.level = 'mlb' and YtdLeagueBatting.gm_type = 'r' and YtdLeagueBatting.split_id = 0 and YtdLeagueBatting.team_id = 0 
 left join mlbam.schedule MlbamSchedule on Schedule.mlbam_game_pk = MlbamSchedule.game_pk
  left join guts.woba_lwts Woba on MlbamSchedule.year = Woba.year and MlbamSchedule.league = Woba.league
 left join astros.hits HitsNoBunts on Pitches.sched_id = HitsNoBunts.sched_id and Pitches.pitch_id = HitsNoBunts.pitch_id and Pitches.pitch_result_id in (12,13,14) and (CurEvents.hit_trajectory_id not in (2,3,4) or CurEvents.hit_trajectory_id is null) and not (HitsNoBunts.hit_vertical_angle < -25 and Schedule.level_code in ('hsb', 'sum', 'bbc')) and HitsNoBunts.hit_exit_speed < 125
 left join astros.players Batter on Pitches.batter_id = Batter.groundcontrol_id
 left join mlbam.teams BattingTeam on CurEvents.batting_team_id = BattingTeam.team_id and Schedule.year = BattingTeam.season
 WHERE Pitches.batter_id = @Param0
 AND CurEvents.batting_team_id <> @Param1
 AND  (Schedule.gc2_level_id NOT  IN /** @Param2 **/ ('14', '6', '22', '8', '23'))
 GROUP BY  Schedule.year, case when Schedule.sched_type = 'R' then 'Reg' when Schedule.sched_type in ('S', 'U') then 'Spr' when Schedule.sched_type in ('F', 'D', 'L', 'W', 'C') then 'Post' when Schedule.sched_type in ('P', 'E', 'I', 'A', 'V') then 'Unoff' when Schedule.sched_type = 'B' then 'Bull' else 'Other' end, case when Schedule.sched_type in ('S', 'U') then 1 when Schedule.sched_type = 'R' then 2 when Schedule.sched_type in ('F', 'D', 'L', 'W', 'C') then 3 when Schedule.sched_type in ('P', 'E', 'I', 'A', 'V') then 4 when Schedule.sched_type = 'B' then 5 else 6 end, BattingTeam.org_abbrev, datediff(DD, Batter.birthdate, datefromparts(Schedule.year,7,1)) / 365.25, BattingTeam.league, BattingTeam.name_short, dbo.GetLevelOrder(Schedule.gc2_level_code), dbo.GetLevelString(Schedule.gc2_level_code)
-- GO
 OPTION(RECOMPILE) 
  SELECT  Agg.Year, Agg.TypeGroup, Agg.TypeGroupOrder, Agg.BatterTeamOrg, Agg.BatterAge, Agg.BatterLeague, Agg.BatterTeamName, Agg.LevelOrder, Agg.LevelString, Agg.BatterPA, Agg.BatterAB, Agg.Batter2B, Agg.Batter3B, Agg.BatterHR, Agg.BatterBA, Agg.BatterOBP, Agg.BatterSLG, Agg.BatterOPS, Agg.gcOBA, Agg.wOBA, Agg.wRCplus, Agg.BatterIBB, Agg.BatterHBP, Agg.BatterBB, Agg.BatterK, Agg.BatterH
 FROM 
#AGG AGG 
 WHERE 1=1 
 ORDER BY 
 Year ASC, TypeGroupOrder ASC, LevelOrder DESC

 /** Schedule **/
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--[noformat]
--[noformat]
--[noformat]
DROP TABLE IF EXISTS #AGG; DROP TABLE IF EXISTS #NTILE;
GO
DECLARE @Param0 varchar(1000) = '93850';
DECLARE @Param1 varchar(1000) = '0';
-- DECLARE @Param2 varchar(1000) = '14', '6', '22', '8', '23';

 SELECT  Schedule.year as Year, case when Schedule.sched_type = 'R' then 'Reg' when Schedule.sched_type in ('S', 'U') then 'Spr' when Schedule.sched_type in ('F', 'D', 'L', 'W', 'C') then 'Post' when Schedule.sched_type in ('P', 'E', 'I', 'A', 'V') then 'Unoff' when Schedule.sched_type = 'B' then 'Bull' else 'Other' end as TypeGroup, case when Schedule.sched_type in ('S', 'U') then 1 when Schedule.sched_type = 'R' then 2 when Schedule.sched_type in ('F', 'D', 'L', 'W', 'C') then 3 when Schedule.sched_type in ('P', 'E', 'I', 'A', 'V') then 4 when Schedule.sched_type = 'B' then 5 else 6 end as TypeGroupOrder, BatterTeam.org_abbrev as BatterTeamOrg, datediff(DD, GameBatter.birthdate, datefromparts(Schedule.year,7,1)) / 365.25 as BatterAge, BatterTeam.league as BatterLeague, BatterTeam.name_short as BatterTeamName, dbo.GetLevelOrder(Schedule.gc2_level_code) as LevelOrder, dbo.GetLevelString(Schedule.gc2_level_code) as LevelString , sum(case when GameLogBatting.player_id is not null then 1 else 0 end) as BatterG
, sum(GameLogBatting.pa) as BatterPA
, sum(GameLogBatting.ab) as BatterAB
, sum(GameLogBatting.h-GameLogBatting.[2b]-GameLogBatting.[3b]-GameLogBatting.hr) as Batter1B
, sum(GameLogBatting.[2b]) as Batter2B
, sum(GameLogBatting.[3b]) as Batter3B
, sum(GameLogBatting.hr) as BatterHR
, sum(GameLogBatting.sb) as BatterSB
, sum(GameLogBatting.cs) as BatterCS
, 1.0*sum(GameLogBatting.sb)/nullif(sum(GameLogBatting.sb+GameLogBatting.cs),0) as BatterSB_Pct
, 1.0*sum(GameLogBatting.bb)/nullif(sum(GameLogBatting.pa),0) as BatterBB_Pct
, 1.0*sum(GameLogBatting.so)/nullif(sum(GameLogBatting.pa),0) as BatterK_Pct
, 1.0*sum(GameLogBatting.h-GameLogBatting.hr)/nullif(sum(GameLogBatting.ab-GameLogBatting.so-GameLogBatting.hr+GameLogBatting.sf),0) as BatterBABIP
, case when sum(GameLogBatting.ab) = 0 then null else 1.0*sum(GameLogBatting.h)/sum(GameLogBatting.ab) end as BatterBA
, 1.0*sum(GameLogBatting.h+GameLogBatting.bb+GameLogBatting.hbp)/nullif(sum(GameLogBatting.ab+GameLogBatting.bb+GameLogBatting.hbp+GameLogBatting.sf),0) as BatterOBP
, 1.0*sum(GameLogBatting.h+GameLogBatting.[2b]+GameLogBatting.[3b]*2+GameLogBatting.hr*3)/nullif(sum(GameLogBatting.ab),0) as BatterSLG
, 1.0*sum(GameLogBatting.h+GameLogBatting.bb+GameLogBatting.hbp)/nullif(sum(GameLogBatting.ab+GameLogBatting.bb+GameLogBatting.hbp+GameLogBatting.sf),0) + 1.0*sum(GameLogBatting.h+GameLogBatting.[2b]+GameLogBatting.[3b]*2+GameLogBatting.hr*3)/nullif(sum(GameLogBatting.ab),0) as BatterOPS
, sum(GameLogBatting.ibb) as BatterIBB
, sum(GameLogBatting.hbp) as BatterHBP
, sum(GameLogBatting.bb) as BatterBB
, sum(GameLogBatting.so) as BatterK
, sum(GameLogBatting.r) as BatterR
, sum(GameLogBatting.h) as BatterH
  INTO #AGG 
 FROM Astros.Schedule_View Schedule
 left join mlbam.gamelog_batting GameLogBatting on Schedule.mlbam_game_pk = GameLogBatting.game_pk
  left join astros.players GameBatter on GameLogBatting.player_id = GameBatter.mlbam_id
 left join mlbam.teams BatterTeam on GameLogBatting.team_id = BatterTeam.team_id and Schedule.year = BatterTeam.season
 WHERE GameBatter.groundcontrol_id = @Param0
 AND GameLogBatting.team_id <> @Param1
 AND  (Schedule.gc2_level_id NOT  IN /** @Param2 **/ ('14', '6', '22', '8', '23'))
 GROUP BY  Schedule.year, case when Schedule.sched_type = 'R' then 'Reg' when Schedule.sched_type in ('S', 'U') then 'Spr' when Schedule.sched_type in ('F', 'D', 'L', 'W', 'C') then 'Post' when Schedule.sched_type in ('P', 'E', 'I', 'A', 'V') then 'Unoff' when Schedule.sched_type = 'B' then 'Bull' else 'Other' end, case when Schedule.sched_type in ('S', 'U') then 1 when Schedule.sched_type = 'R' then 2 when Schedule.sched_type in ('F', 'D', 'L', 'W', 'C') then 3 when Schedule.sched_type in ('P', 'E', 'I', 'A', 'V') then 4 when Schedule.sched_type = 'B' then 5 else 6 end, BatterTeam.org_abbrev, datediff(DD, GameBatter.birthdate, datefromparts(Schedule.year,7,1)) / 365.25, BatterTeam.league, BatterTeam.name_short, dbo.GetLevelOrder(Schedule.gc2_level_code), dbo.GetLevelString(Schedule.gc2_level_code)
-- GO
 OPTION(RECOMPILE) 
  SELECT  Agg.Year, Agg.TypeGroup, Agg.TypeGroupOrder, Agg.BatterTeamOrg, Agg.BatterAge, Agg.BatterLeague, Agg.BatterTeamName, Agg.LevelOrder, Agg.LevelString, Agg.BatterG, Agg.BatterPA, Agg.BatterAB, Agg.Batter1B, Agg.Batter2B, Agg.Batter3B, Agg.BatterHR, Agg.BatterSB, Agg.BatterCS, Agg.BatterSB_Pct, Agg.BatterBB_Pct, Agg.BatterK_Pct, Agg.BatterBABIP, Agg.BatterBA, Agg.BatterOBP, Agg.BatterSLG, Agg.BatterOPS, Agg.BatterIBB, Agg.BatterHBP, Agg.BatterBB, Agg.BatterK, Agg.BatterR, Agg.BatterH
 FROM 
#AGG AGG 
 WHERE 1=1 
 ORDER BY 
 Year ASC, TypeGroupOrder ASC, LevelOrder DESC

 /** YtdBase **/
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--[noformat]
--[noformat]
--[noformat]
DROP TABLE IF EXISTS #AGG; DROP TABLE IF EXISTS #NTILE;
GO
DECLARE @Param0 varchar(1000) = '93850';
DECLARE @Param1 varchar(1000) = '0';
-- DECLARE @Param2 varchar(1000) = '14', '6', '22', '8', '23';

 SELECT  YtdBase.season as Year, case when YtdBase.gm_type = 'R' then 'Reg' when YtdBase.gm_type in ('S', 'U') then 'Spr' when YtdBase.gm_type in ('F', 'D', 'L', 'W', 'C') then 'Post' when YtdBase.gm_type in ('P', 'E', 'I', 'A', 'V') then 'Unoff' when YtdBase.gm_type = 'B' then 'Bull' else 'Other' end as TypeGroup, case when YtdBase.gm_type in ('S', 'U') then 1 when YtdBase.gm_type = 'R' then 2 when YtdBase.gm_type in ('F', 'D', 'L', 'W', 'C') then 3 when YtdBase.gm_type in ('P', 'E', 'I', 'A', 'V') then 4 when YtdBase.gm_type = 'B' then 5 else 6 end as TypeGroupOrder, BatterTeam.org_abbrev as BatterTeamOrg, datediff(DD, YtdPlayer.birthdate, datefromparts(YtdBase.season,7,1)) / 365.25 as BatterAge, BatterTeam.league as BatterLeague, BatterTeam.name_short as BatterTeamName, dbo.GetLevelOrder(dbo.GetGC2Level(YtdTeam.league_id, YtdBase.level)) as LevelOrder, dbo.GetLevelString(dbo.GetGC2Level(YtdTeam.league_id, YtdBase.level)) as LevelString , sum(YtdPlayerBatting.g) as BatterG
, sum(YtdPlayerBatting.pa) as BatterPA
, sum(YtdPlayerBatting.ab) as BatterAB
, sum(YtdPlayerBatting.h-YtdPlayerBatting.[2b]-YtdPlayerBatting.[3b]-YtdPlayerBatting.hr) as Batter1B
, sum(YtdPlayerBatting.[2b]) as Batter2B
, sum(YtdPlayerBatting.[3b]) as Batter3B
, sum(YtdPlayerBatting.hr) as BatterHR
, sum(YtdPlayerBatting.sb) as BatterSB
, sum(YtdPlayerBatting.cs) as BatterCS
, 1.0*sum(YtdPlayerBatting.sb)/nullif(sum(YtdPlayerBatting.sb+YtdPlayerBatting.cs),0) as BatterSB_Pct
, 1.0*sum(YtdPlayerBatting.bb)/nullif(sum(YtdPlayerBatting.pa),0) as BatterBB_Pct
, 1.0*sum(YtdPlayerBatting.so)/nullif(sum(YtdPlayerBatting.pa),0) as BatterK_Pct
, 1.0*sum(YtdPlayerBatting.h-YtdPlayerBatting.hr)/nullif(sum(YtdPlayerBatting.ab-YtdPlayerBatting.so-YtdPlayerBatting.hr+YtdPlayerBatting.sf),0) as BatterBABIP
, 1.0*sum(YtdPlayerBatting.h)/nullif(sum(YtdPlayerBatting.ab),0) as BatterBA
, 1.0*sum(YtdPlayerBatting.h+YtdPlayerBatting.bb+YtdPlayerBatting.hbp)/nullif(sum(YtdPlayerBatting.ab+YtdPlayerBatting.bb+YtdPlayerBatting.hbp+YtdPlayerBatting.sf),0) as BatterOBP
, 1.0*sum(YtdPlayerBatting.h+YtdPlayerBatting.[2b]+YtdPlayerBatting.[3b]*2+YtdPlayerBatting.hr*3)/nullif(sum(YtdPlayerBatting.ab),0) as BatterSLG
, 1.0*sum(YtdPlayerBatting.h+YtdPlayerBatting.bb+YtdPlayerBatting.hbp)/nullif(sum(YtdPlayerBatting.ab+YtdPlayerBatting.bb+YtdPlayerBatting.hbp+YtdPlayerBatting.sf),0) + 1.0*sum(YtdPlayerBatting.h+YtdPlayerBatting.[2b]+YtdPlayerBatting.[3b]*2+YtdPlayerBatting.hr*3)/nullif(sum(YtdPlayerBatting.ab),0) as BatterOPS
, sum(YtdPlayerBattingMLETotal.mle_orp) as ORPBatting_Total
, sum(YtdPlayerBattingMLETotal.drs+YtdPlayerBattingMLETotal.repl) as DRS_Total
, sum(YtdPlayerBattingRAR.orp_run) as ORPRunning
, sum(YtdPlayerBattingMLETotal.rar) as BatterRAR_Total
, sum(YtdPlayerBattingMLETotal.war) as BatterWAR_Total
, sum(YtdPlayerBatting.ibb) as BatterIBB
, sum(YtdPlayerBatting.hbp) as BatterHBP
, sum(YtdPlayerBatting.bb) as BatterBB
, sum(YtdPlayerBatting.so) as BatterK
, sum(YtdPlayerBatting.r) as BatterR
, sum(YtdPlayerBatting.h) as BatterH
  INTO #AGG 
 FROM (select groundcontrol_id, season, level, gm_type, team_id, player_id,
                         null as college_player_id, null as college_team_id
                       from mlbam.ytd_player_batting_stats x
                       join astros.players y on x.player_id = y.mlbam_id
                       where split_id = 0
                       union
                       select groundcontrol_id, season, level, gm_type, team_id, player_id, null, null
                       from mlbam.ytd_player_pitching_stats x
                       join astros.players y on x.player_id = y.mlbam_id
                       where split_id = 0
                       union
                       select groundcontrol_id, season, case when is_summer = 1 then 'sum' else 'bbc' end, 'R',
                         null, null, player_id, team_id
                       from College.YTD_Player_Pitching_Stats x
                       join astros.players y on x.player_id = y.college_splits_id
                       where split_id = 0
                       union
                       select groundcontrol_id, season, case when is_summer = 1 then 'sum' else 'bbc' end, 'R',
                         null, null, player_id, team_id
                       from College.YTD_Player_Batting_Stats x
                       join astros.players y on x.player_id = y.college_splits_id
                       where split_id = 0) YtdBase
 join astros.players YtdPlayer on YtdBase.groundcontrol_id = YtdPlayer.groundcontrol_id
  left join Proj.Batting_MLEs YtdPlayerBattingMLETotal on YtdBase.season = YtdPlayerBattingMLETotal.year and YtdPlayer.groundcontrol_id = YtdPlayerBattingMLETotal.groundcontrol_id and YtdBase.gm_type = 'r' and YtdBase.team_id = YtdPlayerBattingMLETotal.team_id and YtdPlayerBattingMLETotal.pitcher_throws = '-'
 left join mlbam.ytd_player_batting_stats YtdPlayerBatting on YtdBase.season = YtdPlayerBatting.season and YtdBase.player_id = YtdPlayerBatting.player_id and YtdBase.gm_type = YtdPlayerBatting.gm_type and YtdBase.team_id = YtdPlayerBatting.team_id and YtdBase.level = YtdPlayerBatting.level and YtdPlayerBatting.split_id = 0
  left join mlbam.teams BatterTeam on YtdPlayerBatting.team_id = BatterTeam.team_id and YtdPlayerBatting.season = BatterTeam.season
 left join mlbam.teams YtdTeam on YtdBase.team_id = YtdTeam.team_id and YtdBase.season = YtdTeam.season
 left join mlbam.YTD_Player_Batting_RAR_Produced YtdPlayerBattingRAR on YtdBase.season = YtdPlayerBattingRAR.season and YtdBase.player_id = YtdPlayerBattingRAR.player_id and YtdBase.gm_type = 'R' and YtdBase.team_id = YtdPlayerBattingRAR.team_id and YtdBase.level = YtdPlayerBattingRAR.level
 WHERE YtdPlayer.groundcontrol_id = @Param0
 AND YtdPlayerBatting.team_id <> @Param1
 AND  ((select top 1 level_id from Astros.LK_Levels where level_code = dbo.GetGC2Level(YtdTeam.league_id, YtdBase.level)) NOT  IN /** @Param2 **/ ('14', '6', '22', '8', '23'))
 GROUP BY  YtdBase.season, case when YtdBase.gm_type = 'R' then 'Reg' when YtdBase.gm_type in ('S', 'U') then 'Spr' when YtdBase.gm_type in ('F', 'D', 'L', 'W', 'C') then 'Post' when YtdBase.gm_type in ('P', 'E', 'I', 'A', 'V') then 'Unoff' when YtdBase.gm_type = 'B' then 'Bull' else 'Other' end, case when YtdBase.gm_type in ('S', 'U') then 1 when YtdBase.gm_type = 'R' then 2 when YtdBase.gm_type in ('F', 'D', 'L', 'W', 'C') then 3 when YtdBase.gm_type in ('P', 'E', 'I', 'A', 'V') then 4 when YtdBase.gm_type = 'B' then 5 else 6 end, BatterTeam.org_abbrev, datediff(DD, YtdPlayer.birthdate, datefromparts(YtdBase.season,7,1)) / 365.25, BatterTeam.league, BatterTeam.name_short, dbo.GetLevelOrder(dbo.GetGC2Level(YtdTeam.league_id, YtdBase.level)), dbo.GetLevelString(dbo.GetGC2Level(YtdTeam.league_id, YtdBase.level))
-- GO
 OPTION(RECOMPILE) 
  SELECT  Agg.Year, Agg.TypeGroup, Agg.TypeGroupOrder, Agg.BatterTeamOrg, Agg.BatterAge, Agg.BatterLeague, Agg.BatterTeamName, Agg.LevelOrder, Agg.LevelString, Agg.BatterG, Agg.BatterPA, Agg.BatterAB, Agg.Batter1B, Agg.Batter2B, Agg.Batter3B, Agg.BatterHR, Agg.BatterSB, Agg.BatterCS, Agg.BatterSB_Pct, Agg.BatterBB_Pct, Agg.BatterK_Pct, Agg.BatterBABIP, Agg.BatterBA, Agg.BatterOBP, Agg.BatterSLG, Agg.BatterOPS, Agg.ORPBatting_Total, Agg.DRS_Total, Agg.ORPRunning, Agg.BatterRAR_Total, Agg.BatterWAR_Total, Agg.BatterIBB, Agg.BatterHBP, Agg.BatterBB, Agg.BatterK, Agg.BatterR, Agg.BatterH
 FROM 
#AGG AGG 
 WHERE 1=1 
 ORDER BY 
 Year ASC, TypeGroupOrder ASC, LevelOrder DESC

 /** Event 2 **/
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--[noformat]
--[noformat]
--[noformat]
DROP TABLE IF EXISTS #AGG; DROP TABLE IF EXISTS #NTILE;
GO
DECLARE @Param0 varchar(1000) = '93850';
DECLARE @Param1 varchar(1000) = '0';
-- DECLARE @Param2 varchar(1000) = 'Reg';
-- DECLARE @Param3 varchar(1000) = '14', '6', '22', '8', '23';

 SELECT  dbo.GetLevelOrder(Schedule.gc2_level_code) as LevelOrder, dbo.GetLevelString(Schedule.gc2_level_code) as LevelString , sum(cast(CurEvents.pa as int)) as BatterPA
, sum(cast(CurEvents.ab as int)) as BatterAB
, sum(cast(CurEvents.[2b] as int)) as Batter2B
, sum(cast(CurEvents.[3b] as int)) as Batter3B
, sum(cast(CurEvents.hr as int)) as BatterHR
, case when (sum(cast(CurEvents.ab as int)))=0 then 0 else (1.0*sum(cast(CurEvents.[1b] as int) + cast(CurEvents.[2b] as int) + cast(CurEvents.[3b] as int) + cast(CurEvents.[hr] as int))) / (sum(cast(CurEvents.ab as int))) end as BatterBA
, (1.0 * (sum(cast(CurEvents.[1b] as int)+cast(CurEvents.[2b] as int)+cast(CurEvents.[3b] as int)+cast(CurEvents.[hr] as int)) + sum(cast(CurEvents.bb as int)) + sum(cast(CurEvents.hbp as int))) / nullif((sum(cast(CurEvents.ab as int)) + sum(cast(CurEvents.bb as int)) + sum(cast(CurEvents.hbp as int)) + sum(isnull(cast(CurEvents.sf as int),0))),0)) as BatterOBP
, (sum(1.0 * cast(CurEvents.[1b] as int) + 2.0 * cast(CurEvents.[2b] as int) + 3.0 * cast(CurEvents.[3b] as int) + 4.0 * cast(CurEvents.[hr] as int)) / nullif(sum(cast(CurEvents.ab as int)),0)) as BatterSLG
, (1.0 * (sum(cast(CurEvents.[1b] as int)+cast(CurEvents.[2b] as int)+cast(CurEvents.[3b] as int)+cast(CurEvents.[hr] as int)) + sum(cast(CurEvents.bb as int)) + sum(cast(CurEvents.hbp as int))) / nullif((sum(cast(CurEvents.ab as int)) + sum(cast(CurEvents.bb as int)) + sum(cast(CurEvents.hbp as int)) + sum(isnull(cast(CurEvents.sf as int),0))),0) + (sum(1.0 * cast(CurEvents.[1b] as int) + 2.0 * cast(CurEvents.[2b] as int) + 3.0 * cast(CurEvents.[3b] as int) + 4.0 * cast(CurEvents.[hr] as int)) / nullif(sum(cast(CurEvents.ab as int)),0))) as BatterOPS
, avg(YtdLeagueBatting.obp) * (0.50 * avg(case when CurEvents.pa = 1 then case when CurEvents.so = 1 then 1.0 else 0.0 end end) + 1.49 * avg(case when CurEvents.pa = 1 then case when (CurEvents.bb | CurEvents.hbp = 0) then 0.0 else 1.0 end end) + 0.11 * avg(case when CurEvents.pa = 1 then case when len(CurEvents.pitches) - len(replace(replace(replace(CurEvents.pitches, 'S', ''), 'W', ''), 'T', '')) = 0 then 1.0 else 0.0 end end) + 0.08 * avg(case when CurEvents.pa = 1 then case when len(CurEvents.pitches) - len(replace(replace(replace(CurEvents.pitches, 'S', ''), 'W', ''), 'T', '')) = 1 then 1.0 else 0.0 end end) + -0.10 * avg(case when CurEvents.pa = 1 then case when len(CurEvents.pitches) - len(replace(replace(replace(CurEvents.pitches, 'S', ''), 'W', ''), 'T', '')) = 2 then 1.0 else 0.0 end end) + -0.10 * avg(case when CurEvents.pa = 1 then case when len(CurEvents.pitches) - len(replace(replace(replace(CurEvents.pitches, 'S', ''), 'W', ''), 'T', '')) = 3 then 1.0 else 0.0 end end) + avg(case when CurEvents.pa = 1 then case when (CurEvents.bb | CurEvents.hbp | CurEvents.so = 0) then 1.0 else 0.0 end end) * (1.70 * isnull(avg(case when CurEvents.pa = 1 then case when HitsNoBunts.hit_exit_speed > 0 then case when HitsNoBunts.hit_exit_speed * 1.5 - HitsNoBunts.hit_vertical_angle >= 117 and HitsNoBunts.hit_exit_speed + HitsNoBunts.hit_vertical_angle >= 124 and HitsNoBunts.hit_exit_speed >= 98 and HitsNoBunts.hit_vertical_angle > 4 and HitsNoBunts.hit_vertical_angle < 50 then 1.0 else 0.0 end else null end end),0.0) + 1.09 * isnull(avg(case when CurEvents.pa = 1 then case when HitsNoBunts.hit_exit_speed > 0 then HitsNoBunts.hit_useful_exit_speed else null end end), 0.0)/100.0)) as gcOBA
, (AVG(Woba.woba_BB)*SUM(cast(CurEvents.BB as int)-cast(CurEvents.IBB as int)) + AVG(Woba.woba_HB)*SUM(cast(CurEvents.HBP as int)) + AVG(Woba.woba_1B)*SUM(cast(CurEvents.[1B] as int)) + AVG(Woba.woba_2B)*SUM(cast(CurEvents.[2B] as int)) + AVG(Woba.woba_3B)*SUM(cast(CurEvents.[3B] as int)) + AVG(Woba.woba_HR)*SUM(cast(CurEvents.HR as int))) / NULLIF(SUM(cast(CurEvents.AB as int) + cast(CurEvents.BB as int) - cast(CurEvents.IBB as int) + cast(CurEvents.SF as int) + cast(CurEvents.HBP as int)),0) as wOBA
, 100.0 * ( ( (AVG(Woba.woba_BB)*SUM(cast(CurEvents.BB as int)-cast(CurEvents.IBB as int)) + AVG(Woba.woba_HB)*SUM(cast(CurEvents.HBP as int)) + AVG(Woba.woba_1B)*SUM(cast(CurEvents.[1B] as int)) + AVG(Woba.woba_2B)*SUM(cast(CurEvents.[2B] as int)) + AVG(Woba.woba_3B)*SUM(cast(CurEvents.[3B] as int)) + AVG(Woba.woba_HR)*SUM(cast(CurEvents.HR as int))) / NULLIF(SUM(cast(CurEvents.AB as int) + cast(CurEvents.BB as int) - cast(CurEvents.IBB as int) + cast(CurEvents.SF as int) + cast(CurEvents.HBP as int)),0) - AVG(Woba.wOBA) ) / AVG(Woba.wOBA_scale) + AVG(Woba.runs_per_pa) ) / AVG(Woba.runs_per_pa) as wRCplus
, sum(isnull(cast(CurEvents.ibb as int),0)) as BatterIBB
, sum(cast(CurEvents.hbp as int)) as BatterHBP
, sum(cast(CurEvents.bb as int)) as BatterBB
, sum(cast(CurEvents.so as int)) as BatterK
, sum(cast(CurEvents.[1b] as int)+cast(CurEvents.[2b] as int)+cast(CurEvents.[3b] as int)+cast(CurEvents.[hr] as int)) as BatterH
  INTO #AGG 
 FROM Astros.Events_View CurEvents
 left join astros.pitches_view Pitches on CurEvents.sched_id = Pitches.sched_id and CurEvents.event_id = Pitches.cur_event_id
  left join astros.schedule_view Schedule on Pitches.sched_id = Schedule.sched_id
  left join mlbam.YTD_Team_Batting_Stats YtdLeagueBatting on YtdLeagueBatting.season = (case when year(getdate()) = Schedule.year and month(getdate()) < 5 then Schedule.year-1 else Schedule.year end) and YtdLeagueBatting.level = 'mlb' and YtdLeagueBatting.gm_type = 'r' and YtdLeagueBatting.split_id = 0 and YtdLeagueBatting.team_id = 0 
 left join mlbam.schedule MlbamSchedule on Schedule.mlbam_game_pk = MlbamSchedule.game_pk
  left join guts.woba_lwts Woba on MlbamSchedule.year = Woba.year and MlbamSchedule.league = Woba.league
 left join astros.hits HitsNoBunts on Pitches.sched_id = HitsNoBunts.sched_id and Pitches.pitch_id = HitsNoBunts.pitch_id and Pitches.pitch_result_id in (12,13,14) and (CurEvents.hit_trajectory_id not in (2,3,4) or CurEvents.hit_trajectory_id is null) and not (HitsNoBunts.hit_vertical_angle < -25 and Schedule.level_code in ('hsb', 'sum', 'bbc')) and HitsNoBunts.hit_exit_speed < 125
 WHERE Pitches.batter_id = @Param0
 AND CurEvents.batting_team_id <> @Param1
 AND  (case when Schedule.sched_type = 'R' then 'Reg' when Schedule.sched_type in ('S', 'U') then 'Spr' when Schedule.sched_type in ('F', 'D', 'L', 'W', 'C') then 'Post' when Schedule.sched_type in ('P', 'E', 'I', 'A', 'V') then 'Unoff' when Schedule.sched_type = 'B' then 'Bull' else 'Other' end IN /** @Param2 **/ ('Reg')) AND  (Schedule.gc2_level_id NOT  IN /** @Param3 **/ ('14', '6', '22', '8', '23'))
 GROUP BY  dbo.GetLevelOrder(Schedule.gc2_level_code), dbo.GetLevelString(Schedule.gc2_level_code)
-- GO
 OPTION(RECOMPILE) 
  SELECT  Agg.LevelOrder, Agg.LevelString, Agg.BatterPA, Agg.BatterAB, Agg.Batter2B, Agg.Batter3B, Agg.BatterHR, Agg.BatterBA, Agg.BatterOBP, Agg.BatterSLG, Agg.BatterOPS, Agg.gcOBA, Agg.wOBA, Agg.wRCplus, Agg.BatterIBB, Agg.BatterHBP, Agg.BatterBB, Agg.BatterK, Agg.BatterH
 FROM 
#AGG AGG 
 WHERE 1=1 
 ORDER BY 
 LevelOrder ASC

 /** Schedule 2 **/
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--[noformat]
--[noformat]
--[noformat]
DROP TABLE IF EXISTS #AGG; DROP TABLE IF EXISTS #NTILE;
GO
DECLARE @Param0 varchar(1000) = '93850';
DECLARE @Param1 varchar(1000) = '0';
-- DECLARE @Param2 varchar(1000) = 'Reg';
-- DECLARE @Param3 varchar(1000) = '14', '6', '22', '8', '23';

 SELECT  dbo.GetLevelOrder(Schedule.gc2_level_code) as LevelOrder, dbo.GetLevelString(Schedule.gc2_level_code) as LevelString , sum(case when GameLogBatting.player_id is not null then 1 else 0 end) as BatterG
, sum(GameLogBatting.pa) as BatterPA
, sum(GameLogBatting.ab) as BatterAB
, sum(GameLogBatting.h-GameLogBatting.[2b]-GameLogBatting.[3b]-GameLogBatting.hr) as Batter1B
, sum(GameLogBatting.[2b]) as Batter2B
, sum(GameLogBatting.[3b]) as Batter3B
, sum(GameLogBatting.hr) as BatterHR
, sum(GameLogBatting.sb) as BatterSB
, sum(GameLogBatting.cs) as BatterCS
, 1.0*sum(GameLogBatting.sb)/nullif(sum(GameLogBatting.sb+GameLogBatting.cs),0) as BatterSB_Pct
, 1.0*sum(GameLogBatting.bb)/nullif(sum(GameLogBatting.pa),0) as BatterBB_Pct
, 1.0*sum(GameLogBatting.so)/nullif(sum(GameLogBatting.pa),0) as BatterK_Pct
, 1.0*sum(GameLogBatting.h-GameLogBatting.hr)/nullif(sum(GameLogBatting.ab-GameLogBatting.so-GameLogBatting.hr+GameLogBatting.sf),0) as BatterBABIP
, case when sum(GameLogBatting.ab) = 0 then null else 1.0*sum(GameLogBatting.h)/sum(GameLogBatting.ab) end as BatterBA
, 1.0*sum(GameLogBatting.h+GameLogBatting.bb+GameLogBatting.hbp)/nullif(sum(GameLogBatting.ab+GameLogBatting.bb+GameLogBatting.hbp+GameLogBatting.sf),0) as BatterOBP
, 1.0*sum(GameLogBatting.h+GameLogBatting.[2b]+GameLogBatting.[3b]*2+GameLogBatting.hr*3)/nullif(sum(GameLogBatting.ab),0) as BatterSLG
, 1.0*sum(GameLogBatting.h+GameLogBatting.bb+GameLogBatting.hbp)/nullif(sum(GameLogBatting.ab+GameLogBatting.bb+GameLogBatting.hbp+GameLogBatting.sf),0) + 1.0*sum(GameLogBatting.h+GameLogBatting.[2b]+GameLogBatting.[3b]*2+GameLogBatting.hr*3)/nullif(sum(GameLogBatting.ab),0) as BatterOPS
, sum(GameLogBatting.ibb) as BatterIBB
, sum(GameLogBatting.hbp) as BatterHBP
, sum(GameLogBatting.bb) as BatterBB
, sum(GameLogBatting.so) as BatterK
, sum(GameLogBatting.r) as BatterR
, sum(GameLogBatting.h) as BatterH
  INTO #AGG 
 FROM Astros.Schedule_View Schedule
 left join mlbam.gamelog_batting GameLogBatting on Schedule.mlbam_game_pk = GameLogBatting.game_pk
  left join astros.players GameBatter on GameLogBatting.player_id = GameBatter.mlbam_id
 WHERE GameBatter.groundcontrol_id = @Param0
 AND GameLogBatting.team_id <> @Param1
 AND  (case when Schedule.sched_type = 'R' then 'Reg' when Schedule.sched_type in ('S', 'U') then 'Spr' when Schedule.sched_type in ('F', 'D', 'L', 'W', 'C') then 'Post' when Schedule.sched_type in ('P', 'E', 'I', 'A', 'V') then 'Unoff' when Schedule.sched_type = 'B' then 'Bull' else 'Other' end IN /** @Param2 **/ ('Reg')) AND  (Schedule.gc2_level_id NOT  IN /** @Param3 **/ ('14', '6', '22', '8', '23'))
 GROUP BY  dbo.GetLevelOrder(Schedule.gc2_level_code), dbo.GetLevelString(Schedule.gc2_level_code)
-- GO
 OPTION(RECOMPILE) 
  SELECT  Agg.LevelOrder, Agg.LevelString, Agg.BatterG, Agg.BatterPA, Agg.BatterAB, Agg.Batter1B, Agg.Batter2B, Agg.Batter3B, Agg.BatterHR, Agg.BatterSB, Agg.BatterCS, Agg.BatterSB_Pct, Agg.BatterBB_Pct, Agg.BatterK_Pct, Agg.BatterBABIP, Agg.BatterBA, Agg.BatterOBP, Agg.BatterSLG, Agg.BatterOPS, Agg.BatterIBB, Agg.BatterHBP, Agg.BatterBB, Agg.BatterK, Agg.BatterR, Agg.BatterH
 FROM 
#AGG AGG 
 WHERE 1=1 
 ORDER BY 
 LevelOrder ASC

 /** YtdBase 2 **/
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--[noformat]
--[noformat]
--[noformat]
DROP TABLE IF EXISTS #AGG; DROP TABLE IF EXISTS #NTILE;
GO
DECLARE @Param0 varchar(1000) = '93850';
DECLARE @Param1 varchar(1000) = '0';
-- DECLARE @Param2 varchar(1000) = 'Reg';
-- DECLARE @Param3 varchar(1000) = '14', '6', '22', '8', '23';

 SELECT  dbo.GetLevelOrder(dbo.GetGC2Level(YtdTeam.league_id, YtdBase.level)) as LevelOrder, dbo.GetLevelString(dbo.GetGC2Level(YtdTeam.league_id, YtdBase.level)) as LevelString , sum(YtdPlayerBatting.g) as BatterG
, sum(YtdPlayerBatting.pa) as BatterPA
, sum(YtdPlayerBatting.ab) as BatterAB
, sum(YtdPlayerBatting.h-YtdPlayerBatting.[2b]-YtdPlayerBatting.[3b]-YtdPlayerBatting.hr) as Batter1B
, sum(YtdPlayerBatting.[2b]) as Batter2B
, sum(YtdPlayerBatting.[3b]) as Batter3B
, sum(YtdPlayerBatting.hr) as BatterHR
, sum(YtdPlayerBatting.sb) as BatterSB
, sum(YtdPlayerBatting.cs) as BatterCS
, 1.0*sum(YtdPlayerBatting.sb)/nullif(sum(YtdPlayerBatting.sb+YtdPlayerBatting.cs),0) as BatterSB_Pct
, 1.0*sum(YtdPlayerBatting.bb)/nullif(sum(YtdPlayerBatting.pa),0) as BatterBB_Pct
, 1.0*sum(YtdPlayerBatting.so)/nullif(sum(YtdPlayerBatting.pa),0) as BatterK_Pct
, 1.0*sum(YtdPlayerBatting.h-YtdPlayerBatting.hr)/nullif(sum(YtdPlayerBatting.ab-YtdPlayerBatting.so-YtdPlayerBatting.hr+YtdPlayerBatting.sf),0) as BatterBABIP
, 1.0*sum(YtdPlayerBatting.h)/nullif(sum(YtdPlayerBatting.ab),0) as BatterBA
, 1.0*sum(YtdPlayerBatting.h+YtdPlayerBatting.bb+YtdPlayerBatting.hbp)/nullif(sum(YtdPlayerBatting.ab+YtdPlayerBatting.bb+YtdPlayerBatting.hbp+YtdPlayerBatting.sf),0) as BatterOBP
, 1.0*sum(YtdPlayerBatting.h+YtdPlayerBatting.[2b]+YtdPlayerBatting.[3b]*2+YtdPlayerBatting.hr*3)/nullif(sum(YtdPlayerBatting.ab),0) as BatterSLG
, 1.0*sum(YtdPlayerBatting.h+YtdPlayerBatting.bb+YtdPlayerBatting.hbp)/nullif(sum(YtdPlayerBatting.ab+YtdPlayerBatting.bb+YtdPlayerBatting.hbp+YtdPlayerBatting.sf),0) + 1.0*sum(YtdPlayerBatting.h+YtdPlayerBatting.[2b]+YtdPlayerBatting.[3b]*2+YtdPlayerBatting.hr*3)/nullif(sum(YtdPlayerBatting.ab),0) as BatterOPS
, sum(YtdPlayerBattingMLETotal.mle_orp) as ORPBatting_Total
, sum(YtdPlayerBattingMLETotal.drs+YtdPlayerBattingMLETotal.repl) as DRS_Total
, sum(YtdPlayerBattingRAR.orp_run) as ORPRunning
, sum(YtdPlayerBattingMLETotal.rar) as BatterRAR_Total
, sum(YtdPlayerBattingMLETotal.war) as BatterWAR_Total
, sum(YtdPlayerBatting.ibb) as BatterIBB
, sum(YtdPlayerBatting.hbp) as BatterHBP
, sum(YtdPlayerBatting.bb) as BatterBB
, sum(YtdPlayerBatting.so) as BatterK
, sum(YtdPlayerBatting.r) as BatterR
, sum(YtdPlayerBatting.h) as BatterH
  INTO #AGG 
 FROM (select groundcontrol_id, season, level, gm_type, team_id, player_id,
                         null as college_player_id, null as college_team_id
                       from mlbam.ytd_player_batting_stats x
                       join astros.players y on x.player_id = y.mlbam_id
                       where split_id = 0
                       union
                       select groundcontrol_id, season, level, gm_type, team_id, player_id, null, null
                       from mlbam.ytd_player_pitching_stats x
                       join astros.players y on x.player_id = y.mlbam_id
                       where split_id = 0
                       union
                       select groundcontrol_id, season, case when is_summer = 1 then 'sum' else 'bbc' end, 'R',
                         null, null, player_id, team_id
                       from College.YTD_Player_Pitching_Stats x
                       join astros.players y on x.player_id = y.college_splits_id
                       where split_id = 0
                       union
                       select groundcontrol_id, season, case when is_summer = 1 then 'sum' else 'bbc' end, 'R',
                         null, null, player_id, team_id
                       from College.YTD_Player_Batting_Stats x
                       join astros.players y on x.player_id = y.college_splits_id
                       where split_id = 0) YtdBase
 join astros.players YtdPlayer on YtdBase.groundcontrol_id = YtdPlayer.groundcontrol_id
  left join Proj.Batting_MLEs YtdPlayerBattingMLETotal on YtdBase.season = YtdPlayerBattingMLETotal.year and YtdPlayer.groundcontrol_id = YtdPlayerBattingMLETotal.groundcontrol_id and YtdBase.gm_type = 'r' and YtdBase.team_id = YtdPlayerBattingMLETotal.team_id and YtdPlayerBattingMLETotal.pitcher_throws = '-'
 left join mlbam.ytd_player_batting_stats YtdPlayerBatting on YtdBase.season = YtdPlayerBatting.season and YtdBase.player_id = YtdPlayerBatting.player_id and YtdBase.gm_type = YtdPlayerBatting.gm_type and YtdBase.team_id = YtdPlayerBatting.team_id and YtdBase.level = YtdPlayerBatting.level and YtdPlayerBatting.split_id = 0
 left join mlbam.teams YtdTeam on YtdBase.team_id = YtdTeam.team_id and YtdBase.season = YtdTeam.season
 left join mlbam.YTD_Player_Batting_RAR_Produced YtdPlayerBattingRAR on YtdBase.season = YtdPlayerBattingRAR.season and YtdBase.player_id = YtdPlayerBattingRAR.player_id and YtdBase.gm_type = 'R' and YtdBase.team_id = YtdPlayerBattingRAR.team_id and YtdBase.level = YtdPlayerBattingRAR.level
 WHERE YtdPlayer.groundcontrol_id = @Param0
 AND YtdPlayerBatting.team_id <> @Param1
 AND  (case when YtdBase.gm_type = 'R' then 'Reg' when YtdBase.gm_type in ('S', 'U') then 'Spr' when YtdBase.gm_type in ('F', 'D', 'L', 'W', 'C') then 'Post' when YtdBase.gm_type in ('P', 'E', 'I', 'A', 'V') then 'Unoff' when YtdBase.gm_type = 'B' then 'Bull' else 'Other' end IN /** @Param2 **/ ('Reg')) AND  ((select top 1 level_id from Astros.LK_Levels where level_code = dbo.GetGC2Level(YtdTeam.league_id, YtdBase.level)) NOT  IN /** @Param3 **/ ('14', '6', '22', '8', '23'))
 GROUP BY  dbo.GetLevelOrder(dbo.GetGC2Level(YtdTeam.league_id, YtdBase.level)), dbo.GetLevelString(dbo.GetGC2Level(YtdTeam.league_id, YtdBase.level))
-- GO
 OPTION(RECOMPILE) 
  SELECT  Agg.LevelOrder, Agg.LevelString, Agg.BatterG, Agg.BatterPA, Agg.BatterAB, Agg.Batter1B, Agg.Batter2B, Agg.Batter3B, Agg.BatterHR, Agg.BatterSB, Agg.BatterCS, Agg.BatterSB_Pct, Agg.BatterBB_Pct, Agg.BatterK_Pct, Agg.BatterBABIP, Agg.BatterBA, Agg.BatterOBP, Agg.BatterSLG, Agg.BatterOPS, Agg.ORPBatting_Total, Agg.DRS_Total, Agg.ORPRunning, Agg.BatterRAR_Total, Agg.BatterWAR_Total, Agg.BatterIBB, Agg.BatterHBP, Agg.BatterBB, Agg.BatterK, Agg.BatterR, Agg.BatterH
 FROM 
#AGG AGG 
 WHERE 1=1 
 ORDER BY 
 LevelOrder ASC

