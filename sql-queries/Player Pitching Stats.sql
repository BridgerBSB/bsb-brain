 /** Event **/
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--[noformat]
--[noformat]
--[noformat]
DROP TABLE IF EXISTS #AGG; DROP TABLE IF EXISTS #NTILE;
GO
DECLARE @Param0 varchar(1000) = '176229';
DECLARE @Param1 varchar(1000) = '0';
-- DECLARE @Param2 varchar(1000) = '14', '6', '22', '8', '23';

 SELECT  Schedule.year as Year, case when Schedule.sched_type = 'R' then 'Reg' when Schedule.sched_type in ('S', 'U') then 'Spr' when Schedule.sched_type in ('F', 'D', 'L', 'W', 'C') then 'Post' when Schedule.sched_type in ('P', 'E', 'I', 'A', 'V') then 'Unoff' when Schedule.sched_type = 'B' then 'Bull' else 'Other' end as TypeGroup, case when Schedule.sched_type in ('S', 'U') then 1 when Schedule.sched_type = 'R' then 2 when Schedule.sched_type in ('F', 'D', 'L', 'W', 'C') then 3 when Schedule.sched_type in ('P', 'E', 'I', 'A', 'V') then 4 when Schedule.sched_type = 'B' then 5 else 6 end as TypeGroupOrder, PitchingTeam.org_abbrev as PitcherTeamOrg, datediff(DD, Pitcher.birthdate, datefromparts(Schedule.year,7,1)) / 365.25 as PitcherAge, PitchingTeam.league as PitcherLeague, PitchingTeam.name_short as PitcherTeamName, dbo.GetLevelOrder(Schedule.gc2_level_code) as LevelOrder, dbo.GetLevelString(Schedule.gc2_level_code) as LevelString , sum(cast(CurEvents.pa as int)) as PitcherTBF
, case when sum(case when CurEvents.hit_trajectory_id = 5 then 1 else 0 end) = 0 then null else sum(cast(CurEvents.[hr] as decimal))/sum(case when CurEvents.hit_trajectory_id = 5 then 1 else 0 end) end as HR_FB
, case when sum(case when CurEvents.hit_trajectory_id in (5,6,7,8) then 1 else 0 end) = 0 then null else 1.0 * sum(case when CurEvents.hit_trajectory_id = 6 then 1 else 0 end)/sum(case when CurEvents.hit_trajectory_id in (5,6,7,8) then 1 else 0 end) end as GroundBall_Pct
, ( 13.0*sum(cast(CurEvents.HR as int)) + 3.0*sum(cast(CurEvents.BB as int)+cast(CurEvents.HBP as int)) - 2.0*sum(cast(CurEvents.SO as int)) ) / nullif(sum(cast(CurEvents.outs_after as int) - cast(CurEvents.outs_before as int))/3.0,0) + AVG(Woba.FIPconstant) as FIP
, (3.9 + 31.1 * cast(avg(YtdLeaguePitching.hr) as float)/cast(avg(YtdLeaguePitching.hr) + avg(YtdLeaguePitching.ao) as float)) * coalesce(avg(case when CurEvents.pa = 1 then case when CurEvents.so | CurEvents.bb | CurEvents.hbp = 0 then 1.0 else 0.0 end end) * avg(case when HitsNoBunts.hit_exit_speed is not null then (case when HitsNoBunts.hit_exit_speed >= 0.011 * power(HitsNoBunts.hit_vertical_angle, 2) - 0.91 * HitsNoBunts.hit_vertical_angle + 95.0 then 1.0 else 0.0 end) else null end), 0) + 3.5 * coalesce(avg(case when CurEvents.pa = 1 then case when CurEvents.so | CurEvents.bb | CurEvents.hbp = 0 then 1.0 else 0.0 end end) * avg(case when HitsNoBunts.hit_exit_speed is not null then (case when HitsNoBunts.hit_exit_speed >= 0.011 * power(HitsNoBunts.hit_vertical_angle, 2) - 0.91 * HitsNoBunts.hit_vertical_angle + 95.0 then 0.0 else 1.0 end) else null end), 0) + -3.3 * avg(case when CurEvents.pa = 1 then case when CurEvents.so = 1 then 1.0 else 0.0 end end) + 9.9 * avg(case when CurEvents.pa = 1 then case when CurEvents.bb | CurEvents.hbp = 1 then 1.0 else 0.0 end end) as gcERA
, 100.0*( ( 13.0*sum(cast(CurEvents.HR as int)) + 3.0*sum(cast(CurEvents.BB as int)+cast(CurEvents.HBP as int)) - 2.0*sum(cast(CurEvents.SO as int)) ) / nullif(sum(cast(CurEvents.outs_after as int) - cast(CurEvents.outs_before as int))/3.0,0) + AVG(Woba.FIPconstant) ) / AVG(Woba.lgERA) as FIPminus
, sum(cast(CurEvents.[so] as int)) as PitcherK
, sum(cast(CurEvents.[bb] as int)) as PitcherBB
, sum(cast(CurEvents.[hr] as int)) as PitcherHR
  INTO #AGG 
 FROM Astros.Events_View CurEvents
 left join astros.pitches_view Pitches on CurEvents.sched_id = Pitches.sched_id and CurEvents.event_id = Pitches.cur_event_id
  left join astros.schedule_view Schedule on Pitches.sched_id = Schedule.sched_id
  left join mlbam.schedule MlbamSchedule on Schedule.mlbam_game_pk = MlbamSchedule.game_pk
  left join guts.woba_lwts Woba on MlbamSchedule.year = Woba.year and MlbamSchedule.league = Woba.league
 left join mlbam.YTD_Team_Pitching_Stats YtdLeaguePitching on YtdLeaguePitching.season = (case when year(getdate()) = Schedule.year and month(getdate()) < 5 then Schedule.year-1 else Schedule.year end) and YtdLeaguePitching.level = 'mlb' and YtdLeaguePitching.gm_type = 'r' and YtdLeaguePitching.split_id = 0 and YtdLeaguePitching.team_id = 0 
 left join astros.hits HitsNoBunts on Pitches.sched_id = HitsNoBunts.sched_id and Pitches.pitch_id = HitsNoBunts.pitch_id and Pitches.pitch_result_id in (12,13,14) and (CurEvents.hit_trajectory_id not in (2,3,4) or CurEvents.hit_trajectory_id is null) and not (HitsNoBunts.hit_vertical_angle < -25 and Schedule.level_code in ('hsb', 'sum', 'bbc')) and HitsNoBunts.hit_exit_speed < 125
 left join astros.players Pitcher on Pitches.pitcher_id = Pitcher.groundcontrol_id
 left join mlbam.teams PitchingTeam on CurEvents.fielding_team_id = PitchingTeam.team_id and Schedule.year = PitchingTeam.season
 WHERE Pitches.pitcher_id = @Param0
 AND CurEvents.fielding_team_id <> @Param1
 AND  (Schedule.gc2_level_id NOT  IN /** @Param2 **/ ('14', '6', '22', '8', '23'))
 GROUP BY  Schedule.year, case when Schedule.sched_type = 'R' then 'Reg' when Schedule.sched_type in ('S', 'U') then 'Spr' when Schedule.sched_type in ('F', 'D', 'L', 'W', 'C') then 'Post' when Schedule.sched_type in ('P', 'E', 'I', 'A', 'V') then 'Unoff' when Schedule.sched_type = 'B' then 'Bull' else 'Other' end, case when Schedule.sched_type in ('S', 'U') then 1 when Schedule.sched_type = 'R' then 2 when Schedule.sched_type in ('F', 'D', 'L', 'W', 'C') then 3 when Schedule.sched_type in ('P', 'E', 'I', 'A', 'V') then 4 when Schedule.sched_type = 'B' then 5 else 6 end, PitchingTeam.org_abbrev, datediff(DD, Pitcher.birthdate, datefromparts(Schedule.year,7,1)) / 365.25, PitchingTeam.league, PitchingTeam.name_short, dbo.GetLevelOrder(Schedule.gc2_level_code), dbo.GetLevelString(Schedule.gc2_level_code)
-- GO
 OPTION(RECOMPILE) 
  SELECT  Agg.Year, Agg.TypeGroup, Agg.TypeGroupOrder, Agg.PitcherTeamOrg, Agg.PitcherAge, Agg.PitcherLeague, Agg.PitcherTeamName, Agg.LevelOrder, Agg.LevelString, Agg.PitcherTBF, Agg.HR_FB, Agg.GroundBall_Pct, Agg.FIP, Agg.gcERA, Agg.FIPminus, Agg.PitcherK, Agg.PitcherBB, Agg.PitcherHR
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
DECLARE @Param0 varchar(1000) = '176229';
DECLARE @Param1 varchar(1000) = '0';
-- DECLARE @Param2 varchar(1000) = '14', '6', '22', '8', '23';

 SELECT  Schedule.year as Year, case when Schedule.sched_type = 'R' then 'Reg' when Schedule.sched_type in ('S', 'U') then 'Spr' when Schedule.sched_type in ('F', 'D', 'L', 'W', 'C') then 'Post' when Schedule.sched_type in ('P', 'E', 'I', 'A', 'V') then 'Unoff' when Schedule.sched_type = 'B' then 'Bull' else 'Other' end as TypeGroup, case when Schedule.sched_type in ('S', 'U') then 1 when Schedule.sched_type = 'R' then 2 when Schedule.sched_type in ('F', 'D', 'L', 'W', 'C') then 3 when Schedule.sched_type in ('P', 'E', 'I', 'A', 'V') then 4 when Schedule.sched_type = 'B' then 5 else 6 end as TypeGroupOrder, PitcherTeam.org_abbrev as PitcherTeamOrg, datediff(DD, GamePitcher.birthdate, datefromparts(Schedule.year,7,1)) / 365.25 as PitcherAge, PitcherTeam.league as PitcherLeague, PitcherTeam.name_short as PitcherTeamName, dbo.GetLevelOrder(Schedule.gc2_level_code) as LevelOrder, dbo.GetLevelString(Schedule.gc2_level_code) as LevelString , sum(case when GameLogPitching.player_id is not null then 1 else 0 end) as PitcherG
, sum(GameLogPitching.is_start) as PitcherGS
, sum(GameLogPitching.outs)/3+0.1*(sum(GameLogPitching.outs)%3) as PitcherIP
, sum(GameLogPitching.tbf) as PitcherTBF
, 1.0*sum(GameLogPitching.so)/nullif(sum(GameLogPitching.tbf),0) as PitcherSO_Pct
, 1.0*sum(GameLogPitching.bb)/nullif(sum(GameLogPitching.tbf),0) as PitcherBB_Pct
, 1.0*sum(GameLogPitching.so)/nullif(sum(GameLogPitching.tbf),0) -  1.0*sum(GameLogPitching.bb)/nullif(sum(GameLogPitching.tbf),0) as PitcherSO_BB_Pct
, 1.0*sum(GameLogPitching.hr)/nullif(sum(GameLogPitching.tbf),0) as PitcherHR_Pct
, 27.0*sum(GameLogPitching.so)/nullif(sum(GameLogPitching.outs),0) as PitcherK_Per9
, 27.0*sum(GameLogPitching.bb)/nullif(sum(GameLogPitching.outs),0) as PitcherBB_Per9
, 27.0*sum(GameLogPitching.h)/nullif(sum(GameLogPitching.outs),0) as PitcherH_Per9
, 27.0*sum(GameLogPitching.hr)/nullif(sum(GameLogPitching.outs),0) as PitcherHR_Per9
, 1.0*sum(GameLogPitching.h-GameLogPitching.hr)/nullif(sum(GameLogPitching.ab-GameLogPitching.so-GameLogPitching.hr+GameLogPitching.sf),0) as PitcherBABIP
, 1.0*sum(GameLogPitching.h)/nullif(sum(GameLogPitching.ab),0) as PitcherBA
, 1.0*sum(GameLogPitching.h+GameLogPitching.bb+GameLogPitching.hb)/nullif(sum(GameLogPitching.ab+GameLogPitching.bb+GameLogPitching.hb+GameLogPitching.sf),0) as PitcherOBP
, 1.0*sum(GameLogPitching.h+GameLogPitching.[2b]+GameLogPitching.[3b]*2+GameLogPitching.hr*3)/nullif(sum(GameLogPitching.ab),0) as PitcherSLG
, case when sum(GameLogPitching.outs) = 0 then null else 27.0*sum(GameLogPitching.er)/sum(GameLogPitching.outs) end as PitcherERA
, ( 13.0*sum(cast(GameLogPitching.HR as int)) + 3.0*sum(cast(GameLogPitching.BB as int)+cast(GameLogPitching.HB as int)) - 2.0*sum(cast(GameLogPitching.SO as int)) ) / nullif(sum(GameLogPitching.outs)/3.0,0) + AVG(Woba.FIPconstant) as FIP
, 100.0*sum(cast(isnull(GameLogPitching.er, 0) as int))*9.0 / nullif(sum(GameLogPitching.outs)/3.0,0) / AVG(Woba.lgERA) as ERAminus
, 100.0*( ( 13.0*sum(cast(GameLogPitching.HR as int)) + 3.0*sum(cast(GameLogPitching.BB as int)+cast(GameLogPitching.HB as int)) - 2.0*sum(cast(GameLogPitching.SO as int)) ) / nullif(sum(GameLogPitching.outs)/3.0,0) + AVG(Woba.FIPconstant) ) / AVG(Woba.lgERA) as FIPminus
, sum(case when GameLogPitching.player_id = MlbamPostGame.winning_pitcher_id then 1 else 0 end) as PitcherW
, sum(case when GameLogPitching.player_id = MlbamPostGame.losing_pitcher_id then 1 else 0 end) as PitcherL
, sum(case when GameLogPitching.player_id = MlbamPostGame.saving_pitcher_id then 1 else 0 end) as PitcherSV
, sum(GameLogPitching.so) as PitcherK
, sum(GameLogPitching.bb) as PitcherBB
, sum(GameLogPitching.hr) as PitcherHR
, sum(isnull(GameLogPitching.er,0)) as PitcherER
  INTO #AGG 
 FROM Astros.Schedule_View Schedule
 left join mlbam.gamelog_pitching GameLogPitching on Schedule.mlbam_game_pk = GameLogPitching.game_pk
  left join astros.players GamePitcher on GameLogPitching.player_id = GamePitcher.mlbam_id
 left join mlbam.teams PitcherTeam on GameLogPitching.team_id = PitcherTeam.team_id and Schedule.year = PitcherTeam.season
 left join mlbam.schedule MlbamSchedule on Schedule.mlbam_game_pk = MlbamSchedule.game_pk
  left join guts.woba_lwts Woba on MlbamSchedule.year = Woba.year and MlbamSchedule.league = Woba.league
 left join mlbam.pbp_postgame MlbamPostGame on Schedule.mlbam_game_pk = MlbamPostGame.game_pk
 WHERE GamePitcher.groundcontrol_id = @Param0
 AND GameLogPitching.team_id <> @Param1
 AND  (Schedule.gc2_level_id NOT  IN /** @Param2 **/ ('14', '6', '22', '8', '23'))
 GROUP BY  Schedule.year, case when Schedule.sched_type = 'R' then 'Reg' when Schedule.sched_type in ('S', 'U') then 'Spr' when Schedule.sched_type in ('F', 'D', 'L', 'W', 'C') then 'Post' when Schedule.sched_type in ('P', 'E', 'I', 'A', 'V') then 'Unoff' when Schedule.sched_type = 'B' then 'Bull' else 'Other' end, case when Schedule.sched_type in ('S', 'U') then 1 when Schedule.sched_type = 'R' then 2 when Schedule.sched_type in ('F', 'D', 'L', 'W', 'C') then 3 when Schedule.sched_type in ('P', 'E', 'I', 'A', 'V') then 4 when Schedule.sched_type = 'B' then 5 else 6 end, PitcherTeam.org_abbrev, datediff(DD, GamePitcher.birthdate, datefromparts(Schedule.year,7,1)) / 365.25, PitcherTeam.league, PitcherTeam.name_short, dbo.GetLevelOrder(Schedule.gc2_level_code), dbo.GetLevelString(Schedule.gc2_level_code)
-- GO
 OPTION(RECOMPILE) 
  SELECT  Agg.Year, Agg.TypeGroup, Agg.TypeGroupOrder, Agg.PitcherTeamOrg, Agg.PitcherAge, Agg.PitcherLeague, Agg.PitcherTeamName, Agg.LevelOrder, Agg.LevelString, Agg.PitcherG, Agg.PitcherGS, Agg.PitcherIP, Agg.PitcherTBF, Agg.PitcherSO_Pct, Agg.PitcherBB_Pct, Agg.PitcherSO_BB_Pct, Agg.PitcherHR_Pct, Agg.PitcherK_Per9, Agg.PitcherBB_Per9, Agg.PitcherH_Per9, Agg.PitcherHR_Per9, Agg.PitcherBABIP, Agg.PitcherBA, Agg.PitcherOBP, Agg.PitcherSLG, Agg.PitcherERA, Agg.FIP, Agg.ERAminus, Agg.FIPminus, Agg.PitcherW, Agg.PitcherL, Agg.PitcherSV, Agg.PitcherK, Agg.PitcherBB, Agg.PitcherHR, Agg.PitcherER
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
DECLARE @Param0 varchar(1000) = '176229';
DECLARE @Param1 varchar(1000) = '0';
-- DECLARE @Param2 varchar(1000) = '14', '6', '22', '8', '23';

 SELECT  YtdBase.season as Year, case when YtdBase.gm_type = 'R' then 'Reg' when YtdBase.gm_type in ('S', 'U') then 'Spr' when YtdBase.gm_type in ('F', 'D', 'L', 'W', 'C') then 'Post' when YtdBase.gm_type in ('P', 'E', 'I', 'A', 'V') then 'Unoff' when YtdBase.gm_type = 'B' then 'Bull' else 'Other' end as TypeGroup, case when YtdBase.gm_type in ('S', 'U') then 1 when YtdBase.gm_type = 'R' then 2 when YtdBase.gm_type in ('F', 'D', 'L', 'W', 'C') then 3 when YtdBase.gm_type in ('P', 'E', 'I', 'A', 'V') then 4 when YtdBase.gm_type = 'B' then 5 else 6 end as TypeGroupOrder, PitcherTeam.org_abbrev as PitcherTeamOrg, datediff(DD, YtdPlayer.birthdate, datefromparts(YtdBase.season,7,1)) / 365.25 as PitcherAge, PitcherTeam.league as PitcherLeague, PitcherTeam.name_short as PitcherTeamName, dbo.GetLevelOrder(dbo.GetGC2Level(YtdTeam.league_id, YtdBase.level)) as LevelOrder, dbo.GetLevelString(dbo.GetGC2Level(YtdTeam.league_id, YtdBase.level)) as LevelString , sum(YtdPlayerPitching.g) as PitcherG
, sum(YtdPlayerPitching.gs) as PitcherGS
, sum(YtdPlayerPitching.outs)/3+0.1*(sum(YtdPlayerPitching.outs)%3) as PitcherIP
, sum(YtdPlayerPitching.tbf) as PitcherTBF
, 1.0*sum(YtdPlayerPitching.so)/nullif(sum(YtdPlayerPitching.tbf),0) as PitcherSO_Pct
, 1.0*sum(YtdPlayerPitching.bb)/nullif(sum(YtdPlayerPitching.tbf),0) as PitcherBB_Pct
, 1.0*sum(YtdPlayerPitching.hr)/nullif(sum(YtdPlayerPitching.tbf),0) as PitcherHR_Pct
, 27.0*sum(YtdPlayerPitching.so)/nullif(sum(YtdPlayerPitching.outs),0) as PitcherK_Per9
, 27.0*sum(YtdPlayerPitching.bb)/nullif(sum(YtdPlayerPitching.outs),0) as PitcherBB_Per9
, 27.0*sum(YtdPlayerPitching.h)/nullif(sum(YtdPlayerPitching.outs),0) as PitcherH_Per9
, 27.0*sum(YtdPlayerPitching.hr)/nullif(sum(YtdPlayerPitching.outs),0) as PitcherHR_Per9
, 1.0*sum(YtdPlayerPitching.h-YtdPlayerPitching.hr)/nullif(sum(YtdPlayerPitching.ab-YtdPlayerPitching.so-YtdPlayerPitching.hr+YtdPlayerPitching.sf),0) as PitcherBABIP
, 1.0*sum(YtdPlayerPitching.h)/nullif(sum(YtdPlayerPitching.ab),0) as PitcherBA
, 1.0*sum(YtdPlayerPitching.h+YtdPlayerPitching.bb+YtdPlayerPitching.hb)/nullif(sum(YtdPlayerPitching.ab+YtdPlayerPitching.bb+YtdPlayerPitching.hb+YtdPlayerPitching.sf),0) as PitcherOBP
, 1.0*sum(YtdPlayerPitching.h+YtdPlayerPitching.[2b]+YtdPlayerPitching.[3b]*2+YtdPlayerPitching.hr*3)/nullif(sum(YtdPlayerPitching.ab),0) as PitcherSLG
, case when sum(YtdPlayerPitching.outs) = 0 then null else 27.0*sum(YtdPlayerPitching.er)/sum(YtdPlayerPitching.outs) end as PitcherERA
, sum(YtdPlayerPitchingMLETotal.mle_prs) as PRS_Total
, sum(YtdPlayerPitchingMLETotal.rar) as PitcherRAR_Total
, sum(YtdPlayerPitchingMLETotal.war) as PitcherWAR_Total
, sum(YtdPlayerPitching.w) as PitcherW
, sum(YtdPlayerPitching.l) as PitcherL
, sum(YtdPlayerPitching.sv) as PitcherSV
, sum(YtdPlayerPitching.so) as PitcherK
, sum(YtdPlayerPitching.bb) as PitcherBB
, sum(YtdPlayerPitching.hr) as PitcherHR
, sum(YtdPlayerPitching.er) as PitcherER
, sum(YtdPlayerPitching.sho) as PitcherSHO
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
  left join Proj.Pitching_MLEs YtdPlayerPitchingMLETotal on YtdBase.season = YtdPlayerPitchingMLETotal.year and YtdPlayer.groundcontrol_id = YtdPlayerPitchingMLETotal.groundcontrol_id and YtdBase.gm_type = 'r' and YtdBase.team_id = YtdPlayerPitchingMLETotal.team_id and YtdPlayerPitchingMLETotal.bat_side = '-' and YtdPlayerPitchingMLETotal.role = '--'
 left join mlbam.ytd_player_pitching_stats YtdPlayerPitching on YtdBase.season = YtdPlayerPitching.season and YtdBase.player_id = YtdPlayerPitching.player_id and YtdBase.gm_type = YtdPlayerPitching.gm_type and YtdBase.team_id = YtdPlayerPitching.team_id and YtdBase.level = YtdPlayerPitching.level and YtdPlayerPitching.split_id = 0
  left join mlbam.teams PitcherTeam on YtdPlayerPitching.team_id = PitcherTeam.team_id and YtdPlayerPitching.season = PitcherTeam.season
 left join mlbam.teams YtdTeam on YtdBase.team_id = YtdTeam.team_id and YtdBase.season = YtdTeam.season
 WHERE YtdPlayer.groundcontrol_id = @Param0
 AND YtdPlayerPitching.team_id <> @Param1
 AND  ((select top 1 level_id from Astros.LK_Levels where level_code = dbo.GetGC2Level(YtdTeam.league_id, YtdBase.level)) NOT  IN /** @Param2 **/ ('14', '6', '22', '8', '23'))
 GROUP BY  YtdBase.season, case when YtdBase.gm_type = 'R' then 'Reg' when YtdBase.gm_type in ('S', 'U') then 'Spr' when YtdBase.gm_type in ('F', 'D', 'L', 'W', 'C') then 'Post' when YtdBase.gm_type in ('P', 'E', 'I', 'A', 'V') then 'Unoff' when YtdBase.gm_type = 'B' then 'Bull' else 'Other' end, case when YtdBase.gm_type in ('S', 'U') then 1 when YtdBase.gm_type = 'R' then 2 when YtdBase.gm_type in ('F', 'D', 'L', 'W', 'C') then 3 when YtdBase.gm_type in ('P', 'E', 'I', 'A', 'V') then 4 when YtdBase.gm_type = 'B' then 5 else 6 end, PitcherTeam.org_abbrev, datediff(DD, YtdPlayer.birthdate, datefromparts(YtdBase.season,7,1)) / 365.25, PitcherTeam.league, PitcherTeam.name_short, dbo.GetLevelOrder(dbo.GetGC2Level(YtdTeam.league_id, YtdBase.level)), dbo.GetLevelString(dbo.GetGC2Level(YtdTeam.league_id, YtdBase.level))
-- GO
 OPTION(RECOMPILE) 
  SELECT  Agg.Year, Agg.TypeGroup, Agg.TypeGroupOrder, Agg.PitcherTeamOrg, Agg.PitcherAge, Agg.PitcherLeague, Agg.PitcherTeamName, Agg.LevelOrder, Agg.LevelString, Agg.PitcherG, Agg.PitcherGS, Agg.PitcherIP, Agg.PitcherTBF, Agg.PitcherSO_Pct, Agg.PitcherBB_Pct, Agg.PitcherHR_Pct, Agg.PitcherK_Per9, Agg.PitcherBB_Per9, Agg.PitcherH_Per9, Agg.PitcherHR_Per9, Agg.PitcherBABIP, Agg.PitcherBA, Agg.PitcherOBP, Agg.PitcherSLG, Agg.PitcherERA, Agg.PRS_Total, Agg.PitcherRAR_Total, Agg.PitcherWAR_Total, Agg.PitcherW, Agg.PitcherL, Agg.PitcherSV, Agg.PitcherK, Agg.PitcherBB, Agg.PitcherHR, Agg.PitcherER, Agg.PitcherSHO
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
DECLARE @Param0 varchar(1000) = '176229';
DECLARE @Param1 varchar(1000) = '0';
-- DECLARE @Param2 varchar(1000) = 'Reg';
-- DECLARE @Param3 varchar(1000) = '14', '6', '22', '8', '23';

 SELECT  dbo.GetLevelOrder(Schedule.gc2_level_code) as LevelOrder, dbo.GetLevelString(Schedule.gc2_level_code) as LevelString , sum(cast(CurEvents.pa as int)) as PitcherTBF
, case when sum(case when CurEvents.hit_trajectory_id = 5 then 1 else 0 end) = 0 then null else sum(cast(CurEvents.[hr] as decimal))/sum(case when CurEvents.hit_trajectory_id = 5 then 1 else 0 end) end as HR_FB
, case when sum(case when CurEvents.hit_trajectory_id in (5,6,7,8) then 1 else 0 end) = 0 then null else 1.0 * sum(case when CurEvents.hit_trajectory_id = 6 then 1 else 0 end)/sum(case when CurEvents.hit_trajectory_id in (5,6,7,8) then 1 else 0 end) end as GroundBall_Pct
, ( 13.0*sum(cast(CurEvents.HR as int)) + 3.0*sum(cast(CurEvents.BB as int)+cast(CurEvents.HBP as int)) - 2.0*sum(cast(CurEvents.SO as int)) ) / nullif(sum(cast(CurEvents.outs_after as int) - cast(CurEvents.outs_before as int))/3.0,0) + AVG(Woba.FIPconstant) as FIP
, (3.9 + 31.1 * cast(avg(YtdLeaguePitching.hr) as float)/cast(avg(YtdLeaguePitching.hr) + avg(YtdLeaguePitching.ao) as float)) * coalesce(avg(case when CurEvents.pa = 1 then case when CurEvents.so | CurEvents.bb | CurEvents.hbp = 0 then 1.0 else 0.0 end end) * avg(case when HitsNoBunts.hit_exit_speed is not null then (case when HitsNoBunts.hit_exit_speed >= 0.011 * power(HitsNoBunts.hit_vertical_angle, 2) - 0.91 * HitsNoBunts.hit_vertical_angle + 95.0 then 1.0 else 0.0 end) else null end), 0) + 3.5 * coalesce(avg(case when CurEvents.pa = 1 then case when CurEvents.so | CurEvents.bb | CurEvents.hbp = 0 then 1.0 else 0.0 end end) * avg(case when HitsNoBunts.hit_exit_speed is not null then (case when HitsNoBunts.hit_exit_speed >= 0.011 * power(HitsNoBunts.hit_vertical_angle, 2) - 0.91 * HitsNoBunts.hit_vertical_angle + 95.0 then 0.0 else 1.0 end) else null end), 0) + -3.3 * avg(case when CurEvents.pa = 1 then case when CurEvents.so = 1 then 1.0 else 0.0 end end) + 9.9 * avg(case when CurEvents.pa = 1 then case when CurEvents.bb | CurEvents.hbp = 1 then 1.0 else 0.0 end end) as gcERA
, 100.0*( ( 13.0*sum(cast(CurEvents.HR as int)) + 3.0*sum(cast(CurEvents.BB as int)+cast(CurEvents.HBP as int)) - 2.0*sum(cast(CurEvents.SO as int)) ) / nullif(sum(cast(CurEvents.outs_after as int) - cast(CurEvents.outs_before as int))/3.0,0) + AVG(Woba.FIPconstant) ) / AVG(Woba.lgERA) as FIPminus
, sum(cast(CurEvents.[so] as int)) as PitcherK
, sum(cast(CurEvents.[bb] as int)) as PitcherBB
, sum(cast(CurEvents.[hr] as int)) as PitcherHR
  INTO #AGG 
 FROM Astros.Events_View CurEvents
 left join astros.pitches_view Pitches on CurEvents.sched_id = Pitches.sched_id and CurEvents.event_id = Pitches.cur_event_id
  left join astros.schedule_view Schedule on Pitches.sched_id = Schedule.sched_id
  left join mlbam.schedule MlbamSchedule on Schedule.mlbam_game_pk = MlbamSchedule.game_pk
  left join guts.woba_lwts Woba on MlbamSchedule.year = Woba.year and MlbamSchedule.league = Woba.league
 left join mlbam.YTD_Team_Pitching_Stats YtdLeaguePitching on YtdLeaguePitching.season = (case when year(getdate()) = Schedule.year and month(getdate()) < 5 then Schedule.year-1 else Schedule.year end) and YtdLeaguePitching.level = 'mlb' and YtdLeaguePitching.gm_type = 'r' and YtdLeaguePitching.split_id = 0 and YtdLeaguePitching.team_id = 0 
 left join astros.hits HitsNoBunts on Pitches.sched_id = HitsNoBunts.sched_id and Pitches.pitch_id = HitsNoBunts.pitch_id and Pitches.pitch_result_id in (12,13,14) and (CurEvents.hit_trajectory_id not in (2,3,4) or CurEvents.hit_trajectory_id is null) and not (HitsNoBunts.hit_vertical_angle < -25 and Schedule.level_code in ('hsb', 'sum', 'bbc')) and HitsNoBunts.hit_exit_speed < 125
 WHERE Pitches.pitcher_id = @Param0
 AND CurEvents.fielding_team_id <> @Param1
 AND  (case when Schedule.sched_type = 'R' then 'Reg' when Schedule.sched_type in ('S', 'U') then 'Spr' when Schedule.sched_type in ('F', 'D', 'L', 'W', 'C') then 'Post' when Schedule.sched_type in ('P', 'E', 'I', 'A', 'V') then 'Unoff' when Schedule.sched_type = 'B' then 'Bull' else 'Other' end IN /** @Param2 **/ ('Reg')) AND  (Schedule.gc2_level_id NOT  IN /** @Param3 **/ ('14', '6', '22', '8', '23'))
 GROUP BY  dbo.GetLevelOrder(Schedule.gc2_level_code), dbo.GetLevelString(Schedule.gc2_level_code)
-- GO
 OPTION(RECOMPILE) 
  SELECT  Agg.LevelOrder, Agg.LevelString, Agg.PitcherTBF, Agg.HR_FB, Agg.GroundBall_Pct, Agg.FIP, Agg.gcERA, Agg.FIPminus, Agg.PitcherK, Agg.PitcherBB, Agg.PitcherHR
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
DECLARE @Param0 varchar(1000) = '176229';
DECLARE @Param1 varchar(1000) = '0';
-- DECLARE @Param2 varchar(1000) = 'Reg';
-- DECLARE @Param3 varchar(1000) = '14', '6', '22', '8', '23';

 SELECT  dbo.GetLevelOrder(Schedule.gc2_level_code) as LevelOrder, dbo.GetLevelString(Schedule.gc2_level_code) as LevelString , sum(case when GameLogPitching.player_id is not null then 1 else 0 end) as PitcherG
, sum(GameLogPitching.is_start) as PitcherGS
, sum(GameLogPitching.outs)/3+0.1*(sum(GameLogPitching.outs)%3) as PitcherIP
, sum(GameLogPitching.tbf) as PitcherTBF
, 1.0*sum(GameLogPitching.so)/nullif(sum(GameLogPitching.tbf),0) as PitcherSO_Pct
, 1.0*sum(GameLogPitching.bb)/nullif(sum(GameLogPitching.tbf),0) as PitcherBB_Pct
, 1.0*sum(GameLogPitching.so)/nullif(sum(GameLogPitching.tbf),0) -  1.0*sum(GameLogPitching.bb)/nullif(sum(GameLogPitching.tbf),0) as PitcherSO_BB_Pct
, 1.0*sum(GameLogPitching.hr)/nullif(sum(GameLogPitching.tbf),0) as PitcherHR_Pct
, 27.0*sum(GameLogPitching.so)/nullif(sum(GameLogPitching.outs),0) as PitcherK_Per9
, 27.0*sum(GameLogPitching.bb)/nullif(sum(GameLogPitching.outs),0) as PitcherBB_Per9
, 27.0*sum(GameLogPitching.h)/nullif(sum(GameLogPitching.outs),0) as PitcherH_Per9
, 27.0*sum(GameLogPitching.hr)/nullif(sum(GameLogPitching.outs),0) as PitcherHR_Per9
, 1.0*sum(GameLogPitching.h-GameLogPitching.hr)/nullif(sum(GameLogPitching.ab-GameLogPitching.so-GameLogPitching.hr+GameLogPitching.sf),0) as PitcherBABIP
, 1.0*sum(GameLogPitching.h)/nullif(sum(GameLogPitching.ab),0) as PitcherBA
, 1.0*sum(GameLogPitching.h+GameLogPitching.bb+GameLogPitching.hb)/nullif(sum(GameLogPitching.ab+GameLogPitching.bb+GameLogPitching.hb+GameLogPitching.sf),0) as PitcherOBP
, 1.0*sum(GameLogPitching.h+GameLogPitching.[2b]+GameLogPitching.[3b]*2+GameLogPitching.hr*3)/nullif(sum(GameLogPitching.ab),0) as PitcherSLG
, case when sum(GameLogPitching.outs) = 0 then null else 27.0*sum(GameLogPitching.er)/sum(GameLogPitching.outs) end as PitcherERA
, ( 13.0*sum(cast(GameLogPitching.HR as int)) + 3.0*sum(cast(GameLogPitching.BB as int)+cast(GameLogPitching.HB as int)) - 2.0*sum(cast(GameLogPitching.SO as int)) ) / nullif(sum(GameLogPitching.outs)/3.0,0) + AVG(Woba.FIPconstant) as FIP
, 100.0*sum(cast(isnull(GameLogPitching.er, 0) as int))*9.0 / nullif(sum(GameLogPitching.outs)/3.0,0) / AVG(Woba.lgERA) as ERAminus
, 100.0*( ( 13.0*sum(cast(GameLogPitching.HR as int)) + 3.0*sum(cast(GameLogPitching.BB as int)+cast(GameLogPitching.HB as int)) - 2.0*sum(cast(GameLogPitching.SO as int)) ) / nullif(sum(GameLogPitching.outs)/3.0,0) + AVG(Woba.FIPconstant) ) / AVG(Woba.lgERA) as FIPminus
, sum(case when GameLogPitching.player_id = MlbamPostGame.winning_pitcher_id then 1 else 0 end) as PitcherW
, sum(case when GameLogPitching.player_id = MlbamPostGame.losing_pitcher_id then 1 else 0 end) as PitcherL
, sum(case when GameLogPitching.player_id = MlbamPostGame.saving_pitcher_id then 1 else 0 end) as PitcherSV
, sum(GameLogPitching.so) as PitcherK
, sum(GameLogPitching.bb) as PitcherBB
, sum(GameLogPitching.hr) as PitcherHR
, sum(isnull(GameLogPitching.er,0)) as PitcherER
  INTO #AGG 
 FROM Astros.Schedule_View Schedule
 left join mlbam.gamelog_pitching GameLogPitching on Schedule.mlbam_game_pk = GameLogPitching.game_pk
  left join astros.players GamePitcher on GameLogPitching.player_id = GamePitcher.mlbam_id
 left join mlbam.schedule MlbamSchedule on Schedule.mlbam_game_pk = MlbamSchedule.game_pk
  left join guts.woba_lwts Woba on MlbamSchedule.year = Woba.year and MlbamSchedule.league = Woba.league
 left join mlbam.pbp_postgame MlbamPostGame on Schedule.mlbam_game_pk = MlbamPostGame.game_pk
 WHERE GamePitcher.groundcontrol_id = @Param0
 AND GameLogPitching.team_id <> @Param1
 AND  (case when Schedule.sched_type = 'R' then 'Reg' when Schedule.sched_type in ('S', 'U') then 'Spr' when Schedule.sched_type in ('F', 'D', 'L', 'W', 'C') then 'Post' when Schedule.sched_type in ('P', 'E', 'I', 'A', 'V') then 'Unoff' when Schedule.sched_type = 'B' then 'Bull' else 'Other' end IN /** @Param2 **/ ('Reg')) AND  (Schedule.gc2_level_id NOT  IN /** @Param3 **/ ('14', '6', '22', '8', '23'))
 GROUP BY  dbo.GetLevelOrder(Schedule.gc2_level_code), dbo.GetLevelString(Schedule.gc2_level_code)
-- GO
 OPTION(RECOMPILE) 
  SELECT  Agg.LevelOrder, Agg.LevelString, Agg.PitcherG, Agg.PitcherGS, Agg.PitcherIP, Agg.PitcherTBF, Agg.PitcherSO_Pct, Agg.PitcherBB_Pct, Agg.PitcherSO_BB_Pct, Agg.PitcherHR_Pct, Agg.PitcherK_Per9, Agg.PitcherBB_Per9, Agg.PitcherH_Per9, Agg.PitcherHR_Per9, Agg.PitcherBABIP, Agg.PitcherBA, Agg.PitcherOBP, Agg.PitcherSLG, Agg.PitcherERA, Agg.FIP, Agg.ERAminus, Agg.FIPminus, Agg.PitcherW, Agg.PitcherL, Agg.PitcherSV, Agg.PitcherK, Agg.PitcherBB, Agg.PitcherHR, Agg.PitcherER
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
DECLARE @Param0 varchar(1000) = '176229';
DECLARE @Param1 varchar(1000) = '0';
-- DECLARE @Param2 varchar(1000) = 'Reg';
-- DECLARE @Param3 varchar(1000) = '14', '6', '22', '8', '23';

 SELECT  dbo.GetLevelOrder(dbo.GetGC2Level(YtdTeam.league_id, YtdBase.level)) as LevelOrder, dbo.GetLevelString(dbo.GetGC2Level(YtdTeam.league_id, YtdBase.level)) as LevelString , sum(YtdPlayerPitching.g) as PitcherG
, sum(YtdPlayerPitching.gs) as PitcherGS
, sum(YtdPlayerPitching.outs)/3+0.1*(sum(YtdPlayerPitching.outs)%3) as PitcherIP
, sum(YtdPlayerPitching.tbf) as PitcherTBF
, 1.0*sum(YtdPlayerPitching.so)/nullif(sum(YtdPlayerPitching.tbf),0) as PitcherSO_Pct
, 1.0*sum(YtdPlayerPitching.bb)/nullif(sum(YtdPlayerPitching.tbf),0) as PitcherBB_Pct
, 1.0*sum(YtdPlayerPitching.hr)/nullif(sum(YtdPlayerPitching.tbf),0) as PitcherHR_Pct
, 27.0*sum(YtdPlayerPitching.so)/nullif(sum(YtdPlayerPitching.outs),0) as PitcherK_Per9
, 27.0*sum(YtdPlayerPitching.bb)/nullif(sum(YtdPlayerPitching.outs),0) as PitcherBB_Per9
, 27.0*sum(YtdPlayerPitching.h)/nullif(sum(YtdPlayerPitching.outs),0) as PitcherH_Per9
, 27.0*sum(YtdPlayerPitching.hr)/nullif(sum(YtdPlayerPitching.outs),0) as PitcherHR_Per9
, 1.0*sum(YtdPlayerPitching.h-YtdPlayerPitching.hr)/nullif(sum(YtdPlayerPitching.ab-YtdPlayerPitching.so-YtdPlayerPitching.hr+YtdPlayerPitching.sf),0) as PitcherBABIP
, 1.0*sum(YtdPlayerPitching.h)/nullif(sum(YtdPlayerPitching.ab),0) as PitcherBA
, 1.0*sum(YtdPlayerPitching.h+YtdPlayerPitching.bb+YtdPlayerPitching.hb)/nullif(sum(YtdPlayerPitching.ab+YtdPlayerPitching.bb+YtdPlayerPitching.hb+YtdPlayerPitching.sf),0) as PitcherOBP
, 1.0*sum(YtdPlayerPitching.h+YtdPlayerPitching.[2b]+YtdPlayerPitching.[3b]*2+YtdPlayerPitching.hr*3)/nullif(sum(YtdPlayerPitching.ab),0) as PitcherSLG
, case when sum(YtdPlayerPitching.outs) = 0 then null else 27.0*sum(YtdPlayerPitching.er)/sum(YtdPlayerPitching.outs) end as PitcherERA
, sum(YtdPlayerPitchingMLETotal.mle_prs) as PRS_Total
, sum(YtdPlayerPitchingMLETotal.rar) as PitcherRAR_Total
, sum(YtdPlayerPitchingMLETotal.war) as PitcherWAR_Total
, sum(YtdPlayerPitching.w) as PitcherW
, sum(YtdPlayerPitching.l) as PitcherL
, sum(YtdPlayerPitching.sv) as PitcherSV
, sum(YtdPlayerPitching.so) as PitcherK
, sum(YtdPlayerPitching.bb) as PitcherBB
, sum(YtdPlayerPitching.hr) as PitcherHR
, sum(YtdPlayerPitching.er) as PitcherER
, sum(YtdPlayerPitching.sho) as PitcherSHO
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
  left join Proj.Pitching_MLEs YtdPlayerPitchingMLETotal on YtdBase.season = YtdPlayerPitchingMLETotal.year and YtdPlayer.groundcontrol_id = YtdPlayerPitchingMLETotal.groundcontrol_id and YtdBase.gm_type = 'r' and YtdBase.team_id = YtdPlayerPitchingMLETotal.team_id and YtdPlayerPitchingMLETotal.bat_side = '-' and YtdPlayerPitchingMLETotal.role = '--'
 left join mlbam.ytd_player_pitching_stats YtdPlayerPitching on YtdBase.season = YtdPlayerPitching.season and YtdBase.player_id = YtdPlayerPitching.player_id and YtdBase.gm_type = YtdPlayerPitching.gm_type and YtdBase.team_id = YtdPlayerPitching.team_id and YtdBase.level = YtdPlayerPitching.level and YtdPlayerPitching.split_id = 0
 left join mlbam.teams YtdTeam on YtdBase.team_id = YtdTeam.team_id and YtdBase.season = YtdTeam.season
 WHERE YtdPlayer.groundcontrol_id = @Param0
 AND YtdPlayerPitching.team_id <> @Param1
 AND  (case when YtdBase.gm_type = 'R' then 'Reg' when YtdBase.gm_type in ('S', 'U') then 'Spr' when YtdBase.gm_type in ('F', 'D', 'L', 'W', 'C') then 'Post' when YtdBase.gm_type in ('P', 'E', 'I', 'A', 'V') then 'Unoff' when YtdBase.gm_type = 'B' then 'Bull' else 'Other' end IN /** @Param2 **/ ('Reg')) AND  ((select top 1 level_id from Astros.LK_Levels where level_code = dbo.GetGC2Level(YtdTeam.league_id, YtdBase.level)) NOT  IN /** @Param3 **/ ('14', '6', '22', '8', '23'))
 GROUP BY  dbo.GetLevelOrder(dbo.GetGC2Level(YtdTeam.league_id, YtdBase.level)), dbo.GetLevelString(dbo.GetGC2Level(YtdTeam.league_id, YtdBase.level))
-- GO
 OPTION(RECOMPILE) 
  SELECT  Agg.LevelOrder, Agg.LevelString, Agg.PitcherG, Agg.PitcherGS, Agg.PitcherIP, Agg.PitcherTBF, Agg.PitcherSO_Pct, Agg.PitcherBB_Pct, Agg.PitcherHR_Pct, Agg.PitcherK_Per9, Agg.PitcherBB_Per9, Agg.PitcherH_Per9, Agg.PitcherHR_Per9, Agg.PitcherBABIP, Agg.PitcherBA, Agg.PitcherOBP, Agg.PitcherSLG, Agg.PitcherERA, Agg.PRS_Total, Agg.PitcherRAR_Total, Agg.PitcherWAR_Total, Agg.PitcherW, Agg.PitcherL, Agg.PitcherSV, Agg.PitcherK, Agg.PitcherBB, Agg.PitcherHR, Agg.PitcherER, Agg.PitcherSHO
 FROM 
#AGG AGG 
 WHERE 1=1 
 ORDER BY 
 LevelOrder ASC

