-- GroundControl2 Production Hitter Board - PLATOON Queries
-- Source: GC2 Hitter Board (exported from production)
-- Extracted: Feb 1, 2026
--
-- Structure: Same as gc-hitter-production-queries.sql but with platoon splits
-- Key difference: Pitches.pitcher_throws IN ('L') or ('R') filter added
--
-- Query sections:
--   Players: Same player list query (filters out pitchers, VOL, DEC)
--   Event 0: wRCplus overall (no platoon filter)
--   YtdBase: BatterRAR_Total from Proj.Batting_MLEs (pitcher_throws = '-')
--   Event 1: vs LHP - PA, Walk_Pct, K%, SLG, wOBA, wRCplus
--   Event 2: vs RHP - PA, Walk_Pct, K%, SLG, wOBA, wRCplus
--   Event 3: vs LHP - Batted ball (EV, HardHit, Barrel, Damage, LA)
--   Event 4: vs RHP - Batted ball (EV, HardHit, Barrel, Damage, LA)
--   Pitch 5: vs LHP - Chase, SwDec, SwStr, Swing%, Zswing, Oswing, Whiff (from Pitches_View, ignore_flag=0, pitch_id>0)
--   Event 5: vs LHP - Same pitch metrics (from Events_View join)
--   Pitch 6: vs RHP - Same as Pitch 5
--   Event 6: vs RHP - Same as Event 5
--
-- Key patterns confirmed:
--   Chase% uses called_strike_chance_mlb < 0.01
--   Whiff codes: (10,21,22,23) - no 16
--   ignore_flag = 0 AND pitch_id > 0 on Pitch queries
--   Hits join: pitch_result_id in (12,13,14), hit_trajectory_id not in (2,3,4), hit_exit_speed < 125
--   ProjPitchGrades.swing_decision = separate swing decision grade (from Astros.Projections_Pitches_Grades)
--   swing_decision_abs_grade_2080 = ABS variant of swing decision

 /** Players **/
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
DROP TABLE IF EXISTS #AGG; DROP TABLE IF EXISTS #NTILE;
GO
DECLARE @Param0 varchar(1000) = '2025';
DECLARE @Param1 varchar(1000) = '2025';
-- DECLARE @Param2 varchar(1000) = 'RHR', 'LHR', 'RHS', 'LHS';
-- DECLARE @Param3 varchar(1000) = 'HOU';
-- DECLARE @Param4 varchar(1000) = '1';
-- DECLARE @Param5 varchar(1000) = 'VOL', 'DEC';

 SELECT dbo.GetAge_Decimal(Players.birthdate,getdate()) as CurrentAge
, Players.bats as PlayerBats
, Players.throws as PlayerThrows
, EbisPpMaster.position_lk as PlayerEbisPosition
, case when EbisPpMaster.levelofplay_lk = 'ds' then 'DSL' else dbo.GetLevelString(EbisPpMaster.levelofplay_lk) end as CurrentEbisLevel
, case when EbisPpMaster.mnrosterstatus_lk is null then EbisPpMaster.mjrosterstatus_lk when EbisPpMaster.mjrosterstatus_lk is null then EbisPpMaster.mnrosterstatus_lk else concat(EbisPpMaster.mjrosterstatus_lk, '/', EbisPpMaster.mnrosterstatus_lk) end as CurrentEbisCombinedRosterStatus
, Players.first_name + ' ' + Players.last_name as PlayerName
, Players.groundcontrol_id as PlayerGcId

 FROM Astros.Players Players
 left join mlb_ebis.pp_master EbisPpMaster on Players.ebis_id = EbisPpMaster.player_id and EbisPpMaster.employee_flg = 0
 left join mlb_ebis.pp_playerdata EbisPpPlayerData on Players.ebis_id = EbisPpPlayerData.player_id
 WHERE (select max(season) from mlbam.ytd_player_batting_stats where player_id = Players.mlbam_id and gm_type = 'r' and level in ('mlb','aaa','aax','afa','afx','asx','rok')) >= @Param0
 AND (select max(season) from mlbam.ytd_player_batting_stats where player_id = Players.mlbam_id and gm_type = 'r' and level in ('mlb','aaa','aax','afa','afx','asx','rok')) <= @Param1
 AND case when EbisPpMaster.mnrosterstatus_lk is null then EbisPpMaster.mjrosterstatus_lk when EbisPpMaster.mjrosterstatus_lk is null then EbisPpMaster.mnrosterstatus_lk else concat(EbisPpMaster.mjrosterstatus_lk, '/', EbisPpMaster.mnrosterstatus_lk) end is not null 
 AND  (EbisPpMaster.position_lk NOT  IN /** @Param2 **/ ('RHR', 'LHR', 'RHS', 'LHS')) AND  (EbisPpMaster.ORG_LK IN /** @Param3 **/ ('HOU')) AND  (case when EbisPpMaster.org_lk is not null or EbisPpPlayerData.highestlevelofplay_lk is not null then 1 else 0 end IN /** @Param4 **/ ('1')) AND  (coalesce(nullif(EbisPpMaster.mjrosterstatus_lk, 'OUTRT'), EbisPpMaster.mnrosterstatus_lk, '') NOT  IN /** @Param5 **/ ('VOL', 'DEC'))

 /** 0:Event **/
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
DROP TABLE IF EXISTS #AGG; DROP TABLE IF EXISTS #NTILE;
GO
DECLARE @Param0 varchar(1000) = '2025';
DECLARE @Param1 varchar(1000) = '2025';
-- DECLARE @Param2 varchar(1000) = '13', '1', '2', '3', '4', '5', '20', '24';
-- DECLARE @Param3 varchar(1000) = 'r';
-- DECLARE @Param4 varchar(1000) = '106530', '106564', '106941', '107376', '107881', '110840', '116925', '12043', '1258422', '1263266', '1263291', '1263300', '1263308', '1263311', '1263348', '1263410', '1263427', '1268338', '1284314', '1285841', '1302809', '130666', '136817', '138501', '145359', '15187', '155788', '158168', '166036', '167585', '168757', '169165', '170147', '171629', '174203', '175103', '175966', '176038', '176244', '176301', '176305', '176674', '177606', '17876', '196080', '196356', '196364', '196447', '196986', '197158', '197392', '197463', '197737', '210013', '210926', '211578', '211602', '211942', '212486', '212518', '212527', '212632', '212897', '213722', '216390', '216650', '218498', '218708', '220289', '220492', '234205', '235670', '248234', '251155', '252527', '252859', '254779', '258768', '258844', '259539', '260505', '265930', '266441', '278101', '282599', '282878', '283965', '283966', '284102', '4773', '6380', '67182', '71258', '71625', '73618', '74257', '75825', '75884', '77618', '77907', '78084', '80672', '81631';

 SELECT  Pitches.batter_id as BatterId , sum(cast(CurEvents.pa as int)) as PA
, 100.0 * ( ( (AVG(Woba.woba_BB)*SUM(cast(CurEvents.BB as int)-cast(CurEvents.IBB as int)) + AVG(Woba.woba_HB)*SUM(cast(CurEvents.HBP as int)) + AVG(Woba.woba_1B)*SUM(cast(CurEvents.[1B] as int)) + AVG(Woba.woba_2B)*SUM(cast(CurEvents.[2B] as int)) + AVG(Woba.woba_3B)*SUM(cast(CurEvents.[3B] as int)) + AVG(Woba.woba_HR)*SUM(cast(CurEvents.HR as int))) / NULLIF(SUM(cast(CurEvents.AB as int) + cast(CurEvents.BB as int) - cast(CurEvents.IBB as int) + cast(CurEvents.SF as int) + cast(CurEvents.HBP as int)),0) - AVG(Woba.wOBA) ) / AVG(Woba.wOBA_scale) + AVG(Woba.runs_per_pa) ) / AVG(Woba.runs_per_pa) as wRCplus
  INTO #AGG 
 FROM Astros.Events_View CurEvents
 left join astros.schedule_view Schedule on CurEvents.sched_id = Schedule.sched_id
  left join mlbam.schedule MlbamSchedule on Schedule.mlbam_game_pk = MlbamSchedule.game_pk
  left join guts.woba_lwts Woba on MlbamSchedule.year = Woba.year and MlbamSchedule.league = Woba.league
 left join astros.pitches_view Pitches on CurEvents.sched_id = Pitches.sched_id and CurEvents.event_id = Pitches.cur_event_id
 WHERE Schedule.year >= @Param0
 AND Schedule.year <= @Param1
 AND  (Schedule.gc2_level_id IN /** @Param2 **/ ('13', '1', '2', '3', '4', '5', '20', '24')) AND  (Schedule.sched_type IN /** @Param3 **/ ('r')) AND  (Pitches.batter_id IN /** @Param4 **/ ('106530', '106564', '106941', '107376', '107881', '110840', '116925', '12043', '1258422', '1263266', '1263291', '1263300', '1263308', '1263311', '1263348', '1263410', '1263427', '1268338', '1284314', '1285841', '1302809', '130666', '136817', '138501', '145359', '15187', '155788', '158168', '166036', '167585', '168757', '169165', '170147', '171629', '174203', '175103', '175966', '176038', '176244', '176301', '176305', '176674', '177606', '17876', '196080', '196356', '196364', '196447', '196986', '197158', '197392', '197463', '197737', '210013', '210926', '211578', '211602', '211942', '212486', '212518', '212527', '212632', '212897', '213722', '216390', '216650', '218498', '218708', '220289', '220492', '234205', '235670', '248234', '251155', '252527', '252859', '254779', '258768', '258844', '259539', '260505', '265930', '266441', '278101', '282599', '282878', '283965', '283966', '284102', '4773', '6380', '67182', '71258', '71625', '73618', '74257', '75825', '75884', '77618', '77907', '78084', '80672', '81631'))
 GROUP BY  Pitches.batter_id
-- GO
 OPTION(RECOMPILE) 
  SELECT  Agg.BatterId, Agg.PA, Agg.wRCplus
 FROM 
#AGG AGG 
 WHERE 1=1 

 /** 0:YtdBase **/
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
DROP TABLE IF EXISTS #AGG; DROP TABLE IF EXISTS #NTILE;
GO
DECLARE @Param0 varchar(1000) = '2025';
DECLARE @Param1 varchar(1000) = '2025';
DECLARE @Param2 varchar(1000) = '0';
-- DECLARE @Param3 varchar(1000) = '13', '1', '2', '3', '4', '5', '20', '24';
-- DECLARE @Param4 varchar(1000) = 'r';
-- DECLARE @Param5 varchar(1000) = '106530', '106564', '106941', '107376', '107881', '110840', '116925', '12043', '1258422', '1263266', '1263291', '1263300', '1263308', '1263311', '1263348', '1263410', '1263427', '1268338', '1284314', '1285841', '1302809', '130666', '136817', '138501', '145359', '15187', '155788', '158168', '166036', '167585', '168757', '169165', '170147', '171629', '174203', '175103', '175966', '176038', '176244', '176301', '176305', '176674', '177606', '17876', '196080', '196356', '196364', '196447', '196986', '197158', '197392', '197463', '197737', '210013', '210926', '211578', '211602', '211942', '212486', '212518', '212527', '212632', '212897', '213722', '216390', '216650', '218498', '218708', '220289', '220492', '234205', '235670', '248234', '251155', '252527', '252859', '254779', '258768', '258844', '259539', '260505', '265930', '266441', '278101', '282599', '282878', '283965', '283966', '284102', '4773', '6380', '67182', '71258', '71625', '73618', '74257', '75825', '75884', '77618', '77907', '78084', '80672', '81631';

 SELECT  YtdPlayer.groundcontrol_id as BatterId , sum(YtdPlayerBattingMLETotal.rar) as BatterRAR_Total
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
 left join mlbam.teams YtdTeam on YtdBase.team_id = YtdTeam.team_id and YtdBase.season = YtdTeam.season
 join astros.players YtdPlayer on YtdBase.groundcontrol_id = YtdPlayer.groundcontrol_id
  left join Proj.Batting_MLEs YtdPlayerBattingMLETotal on YtdBase.season = YtdPlayerBattingMLETotal.year and YtdPlayer.groundcontrol_id = YtdPlayerBattingMLETotal.groundcontrol_id and YtdBase.gm_type = 'r' and YtdBase.team_id = YtdPlayerBattingMLETotal.team_id and YtdPlayerBattingMLETotal.pitcher_throws = '-'
 WHERE YtdBase.season >= @Param0
 AND YtdBase.season <= @Param1
 AND YtdBase.team_id <> @Param2
 AND  ((select top 1 level_id from Astros.LK_Levels where level_code = dbo.GetGC2Level(YtdTeam.league_id, YtdBase.level)) IN /** @Param3 **/ ('13', '1', '2', '3', '4', '5', '20', '24')) AND  (YtdBase.gm_type IN /** @Param4 **/ ('r')) AND  (YtdPlayer.groundcontrol_id IN /** @Param5 **/ ('106530', '106564', '106941', '107376', '107881', '110840', '116925', '12043', '1258422', '1263266', '1263291', '1263300', '1263308', '1263311', '1263348', '1263410', '1263427', '1268338', '1284314', '1285841', '1302809', '130666', '136817', '138501', '145359', '15187', '155788', '158168', '166036', '167585', '168757', '169165', '170147', '171629', '174203', '175103', '175966', '176038', '176244', '176301', '176305', '176674', '177606', '17876', '196080', '196356', '196364', '196447', '196986', '197158', '197392', '197463', '197737', '210013', '210926', '211578', '211602', '211942', '212486', '212518', '212527', '212632', '212897', '213722', '216390', '216650', '218498', '218708', '220289', '220492', '234205', '235670', '248234', '251155', '252527', '252859', '254779', '258768', '258844', '259539', '260505', '265930', '266441', '278101', '282599', '282878', '283965', '283966', '284102', '4773', '6380', '67182', '71258', '71625', '73618', '74257', '75825', '75884', '77618', '77907', '78084', '80672', '81631'))
 GROUP BY  YtdPlayer.groundcontrol_id
-- GO
 OPTION(RECOMPILE) 
  SELECT  Agg.BatterId, Agg.BatterRAR_Total
 FROM 
#AGG AGG 
 WHERE 1=1 

 /** 1:Event **/
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
DROP TABLE IF EXISTS #AGG; DROP TABLE IF EXISTS #NTILE;
GO
DECLARE @Param0 varchar(1000) = '2025';
DECLARE @Param1 varchar(1000) = '2025';
-- DECLARE @Param2 varchar(1000) = 'L';
-- DECLARE @Param3 varchar(1000) = '13', '1', '2', '3', '4', '5', '20', '24';
-- DECLARE @Param4 varchar(1000) = 'r';
-- DECLARE @Param5 varchar(1000) = '106530', '106564', '106941', '107376', '107881', '110840', '116925', '12043', '1258422', '1263266', '1263291', '1263300', '1263308', '1263311', '1263348', '1263410', '1263427', '1268338', '1284314', '1285841', '1302809', '130666', '136817', '138501', '145359', '15187', '155788', '158168', '166036', '167585', '168757', '169165', '170147', '171629', '174203', '175103', '175966', '176038', '176244', '176301', '176305', '176674', '177606', '17876', '196080', '196356', '196364', '196447', '196986', '197158', '197392', '197463', '197737', '210013', '210926', '211578', '211602', '211942', '212486', '212518', '212527', '212632', '212897', '213722', '216390', '216650', '218498', '218708', '220289', '220492', '234205', '235670', '248234', '251155', '252527', '252859', '254779', '258768', '258844', '259539', '260505', '265930', '266441', '278101', '282599', '282878', '283965', '283966', '284102', '4773', '6380', '67182', '71258', '71625', '73618', '74257', '75825', '75884', '77618', '77907', '78084', '80672', '81631';

 SELECT  Pitches.batter_id as BatterId , sum(cast(CurEvents.pa as int)) as PA
, case when sum(cast(CurEvents.pa as int)) = 0 then null else sum(cast(CurEvents.bb as decimal))/sum(cast(CurEvents.pa as int)) end as Walk_Pct
, case when sum(cast(CurEvents.pa as int)) = 0 then null else sum(cast(CurEvents.so as decimal))/sum(cast(CurEvents.pa as int)) end as Strikeout_Pct
, case when sum(cast(CurEvents.ab as int)) = 0 then null else sum(cast(CurEvents.[1b] as decimal)+cast(CurEvents.[2b] as decimal)*2+cast(CurEvents.[3b] as decimal)*3+cast(CurEvents.[hr] as decimal)*4)/sum(cast(CurEvents.ab as int)) end as SLG
, (AVG(Woba.woba_BB)*SUM(cast(CurEvents.BB as int)-cast(CurEvents.IBB as int)) + AVG(Woba.woba_HB)*SUM(cast(CurEvents.HBP as int)) + AVG(Woba.woba_1B)*SUM(cast(CurEvents.[1B] as int)) + AVG(Woba.woba_2B)*SUM(cast(CurEvents.[2B] as int)) + AVG(Woba.woba_3B)*SUM(cast(CurEvents.[3B] as int)) + AVG(Woba.woba_HR)*SUM(cast(CurEvents.HR as int))) / NULLIF(SUM(cast(CurEvents.AB as int) + cast(CurEvents.BB as int) - cast(CurEvents.IBB as int) + cast(CurEvents.SF as int) + cast(CurEvents.HBP as int)),0) as wOBA
, 100.0 * ( ( (AVG(Woba.woba_BB)*SUM(cast(CurEvents.BB as int)-cast(CurEvents.IBB as int)) + AVG(Woba.woba_HB)*SUM(cast(CurEvents.HBP as int)) + AVG(Woba.woba_1B)*SUM(cast(CurEvents.[1B] as int)) + AVG(Woba.woba_2B)*SUM(cast(CurEvents.[2B] as int)) + AVG(Woba.woba_3B)*SUM(cast(CurEvents.[3B] as int)) + AVG(Woba.woba_HR)*SUM(cast(CurEvents.HR as int))) / NULLIF(SUM(cast(CurEvents.AB as int) + cast(CurEvents.BB as int) - cast(CurEvents.IBB as int) + cast(CurEvents.SF as int) + cast(CurEvents.HBP as int)),0) - AVG(Woba.wOBA) ) / AVG(Woba.wOBA_scale) + AVG(Woba.runs_per_pa) ) / AVG(Woba.runs_per_pa) as wRCplus
  INTO #AGG 
 FROM Astros.Events_View CurEvents
 left join astros.schedule_view Schedule on CurEvents.sched_id = Schedule.sched_id
  left join mlbam.schedule MlbamSchedule on Schedule.mlbam_game_pk = MlbamSchedule.game_pk
  left join guts.woba_lwts Woba on MlbamSchedule.year = Woba.year and MlbamSchedule.league = Woba.league
 left join astros.pitches_view Pitches on CurEvents.sched_id = Pitches.sched_id and CurEvents.event_id = Pitches.cur_event_id
 WHERE Schedule.year >= @Param0
 AND Schedule.year <= @Param1
 AND  (Pitches.pitcher_throws IN /** @Param2 **/ ('L')) AND  (Schedule.gc2_level_id IN /** @Param3 **/ ('13', '1', '2', '3', '4', '5', '20', '24')) AND  (Schedule.sched_type IN /** @Param4 **/ ('r')) AND  (Pitches.batter_id IN /** @Param5 **/ ('106530', '106564', '106941', '107376', '107881', '110840', '116925', '12043', '1258422', '1263266', '1263291', '1263300', '1263308', '1263311', '1263348', '1263410', '1263427', '1268338', '1284314', '1285841', '1302809', '130666', '136817', '138501', '145359', '15187', '155788', '158168', '166036', '167585', '168757', '169165', '170147', '171629', '174203', '175103', '175966', '176038', '176244', '176301', '176305', '176674', '177606', '17876', '196080', '196356', '196364', '196447', '196986', '197158', '197392', '197463', '197737', '210013', '210926', '211578', '211602', '211942', '212486', '212518', '212527', '212632', '212897', '213722', '216390', '216650', '218498', '218708', '220289', '220492', '234205', '235670', '248234', '251155', '252527', '252859', '254779', '258768', '258844', '259539', '260505', '265930', '266441', '278101', '282599', '282878', '283965', '283966', '284102', '4773', '6380', '67182', '71258', '71625', '73618', '74257', '75825', '75884', '77618', '77907', '78084', '80672', '81631'))
 GROUP BY  Pitches.batter_id
-- GO
 OPTION(RECOMPILE) 
  SELECT  Agg.BatterId, Agg.PA, Agg.Walk_Pct, Agg.Strikeout_Pct, Agg.SLG, Agg.wOBA, Agg.wRCplus
 FROM 
#AGG AGG 
 WHERE 1=1 

 /** 2:Event **/
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
DROP TABLE IF EXISTS #AGG; DROP TABLE IF EXISTS #NTILE;
GO
DECLARE @Param0 varchar(1000) = '2025';
DECLARE @Param1 varchar(1000) = '2025';
-- DECLARE @Param2 varchar(1000) = 'R';
-- DECLARE @Param3 varchar(1000) = '13', '1', '2', '3', '4', '5', '20', '24';
-- DECLARE @Param4 varchar(1000) = 'r';
-- DECLARE @Param5 varchar(1000) = '106530', '106564', '106941', '107376', '107881', '110840', '116925', '12043', '1258422', '1263266', '1263291', '1263300', '1263308', '1263311', '1263348', '1263410', '1263427', '1268338', '1284314', '1285841', '1302809', '130666', '136817', '138501', '145359', '15187', '155788', '158168', '166036', '167585', '168757', '169165', '170147', '171629', '174203', '175103', '175966', '176038', '176244', '176301', '176305', '176674', '177606', '17876', '196080', '196356', '196364', '196447', '196986', '197158', '197392', '197463', '197737', '210013', '210926', '211578', '211602', '211942', '212486', '212518', '212527', '212632', '212897', '213722', '216390', '216650', '218498', '218708', '220289', '220492', '234205', '235670', '248234', '251155', '252527', '252859', '254779', '258768', '258844', '259539', '260505', '265930', '266441', '278101', '282599', '282878', '283965', '283966', '284102', '4773', '6380', '67182', '71258', '71625', '73618', '74257', '75825', '75884', '77618', '77907', '78084', '80672', '81631';

 SELECT  Pitches.batter_id as BatterId , sum(cast(CurEvents.pa as int)) as PA
, case when sum(cast(CurEvents.pa as int)) = 0 then null else sum(cast(CurEvents.bb as decimal))/sum(cast(CurEvents.pa as int)) end as Walk_Pct
, case when sum(cast(CurEvents.pa as int)) = 0 then null else sum(cast(CurEvents.so as decimal))/sum(cast(CurEvents.pa as int)) end as Strikeout_Pct
, case when sum(cast(CurEvents.ab as int)) = 0 then null else sum(cast(CurEvents.[1b] as decimal)+cast(CurEvents.[2b] as decimal)*2+cast(CurEvents.[3b] as decimal)*3+cast(CurEvents.[hr] as decimal)*4)/sum(cast(CurEvents.ab as int)) end as SLG
, (AVG(Woba.woba_BB)*SUM(cast(CurEvents.BB as int)-cast(CurEvents.IBB as int)) + AVG(Woba.woba_HB)*SUM(cast(CurEvents.HBP as int)) + AVG(Woba.woba_1B)*SUM(cast(CurEvents.[1B] as int)) + AVG(Woba.woba_2B)*SUM(cast(CurEvents.[2B] as int)) + AVG(Woba.woba_3B)*SUM(cast(CurEvents.[3B] as int)) + AVG(Woba.woba_HR)*SUM(cast(CurEvents.HR as int))) / NULLIF(SUM(cast(CurEvents.AB as int) + cast(CurEvents.BB as int) - cast(CurEvents.IBB as int) + cast(CurEvents.SF as int) + cast(CurEvents.HBP as int)),0) as wOBA
, 100.0 * ( ( (AVG(Woba.woba_BB)*SUM(cast(CurEvents.BB as int)-cast(CurEvents.IBB as int)) + AVG(Woba.woba_HB)*SUM(cast(CurEvents.HBP as int)) + AVG(Woba.woba_1B)*SUM(cast(CurEvents.[1B] as int)) + AVG(Woba.woba_2B)*SUM(cast(CurEvents.[2B] as int)) + AVG(Woba.woba_3B)*SUM(cast(CurEvents.[3B] as int)) + AVG(Woba.woba_HR)*SUM(cast(CurEvents.HR as int))) / NULLIF(SUM(cast(CurEvents.AB as int) + cast(CurEvents.BB as int) - cast(CurEvents.IBB as int) + cast(CurEvents.SF as int) + cast(CurEvents.HBP as int)),0) - AVG(Woba.wOBA) ) / AVG(Woba.wOBA_scale) + AVG(Woba.runs_per_pa) ) / AVG(Woba.runs_per_pa) as wRCplus
  INTO #AGG 
 FROM Astros.Events_View CurEvents
 left join astros.schedule_view Schedule on CurEvents.sched_id = Schedule.sched_id
  left join mlbam.schedule MlbamSchedule on Schedule.mlbam_game_pk = MlbamSchedule.game_pk
  left join guts.woba_lwts Woba on MlbamSchedule.year = Woba.year and MlbamSchedule.league = Woba.league
 left join astros.pitches_view Pitches on CurEvents.sched_id = Pitches.sched_id and CurEvents.event_id = Pitches.cur_event_id
 WHERE Schedule.year >= @Param0
 AND Schedule.year <= @Param1
 AND  (Pitches.pitcher_throws IN /** @Param2 **/ ('R')) AND  (Schedule.gc2_level_id IN /** @Param3 **/ ('13', '1', '2', '3', '4', '5', '20', '24')) AND  (Schedule.sched_type IN /** @Param4 **/ ('r')) AND  (Pitches.batter_id IN /** @Param5 **/ ('106530', '106564', '106941', '107376', '107881', '110840', '116925', '12043', '1258422', '1263266', '1263291', '1263300', '1263308', '1263311', '1263348', '1263410', '1263427', '1268338', '1284314', '1285841', '1302809', '130666', '136817', '138501', '145359', '15187', '155788', '158168', '166036', '167585', '168757', '169165', '170147', '171629', '174203', '175103', '175966', '176038', '176244', '176301', '176305', '176674', '177606', '17876', '196080', '196356', '196364', '196447', '196986', '197158', '197392', '197463', '197737', '210013', '210926', '211578', '211602', '211942', '212486', '212518', '212527', '212632', '212897', '213722', '216390', '216650', '218498', '218708', '220289', '220492', '234205', '235670', '248234', '251155', '252527', '252859', '254779', '258768', '258844', '259539', '260505', '265930', '266441', '278101', '282599', '282878', '283965', '283966', '284102', '4773', '6380', '67182', '71258', '71625', '73618', '74257', '75825', '75884', '77618', '77907', '78084', '80672', '81631'))
 GROUP BY  Pitches.batter_id
-- GO
 OPTION(RECOMPILE) 
  SELECT  Agg.BatterId, Agg.PA, Agg.Walk_Pct, Agg.Strikeout_Pct, Agg.SLG, Agg.wOBA, Agg.wRCplus
 FROM 
#AGG AGG 
 WHERE 1=1 

 /** 3:Event **/
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
DROP TABLE IF EXISTS #AGG; DROP TABLE IF EXISTS #NTILE;
GO
DECLARE @Param0 varchar(1000) = '2025';
DECLARE @Param1 varchar(1000) = '2025';
-- DECLARE @Param2 varchar(1000) = 'L';
-- DECLARE @Param3 varchar(1000) = '13', '1', '2', '3', '4', '5', '20', '24';
-- DECLARE @Param4 varchar(1000) = 'r';
-- DECLARE @Param5 varchar(1000) = '106530', '106564', '106941', '107376', '107881', '110840', '116925', '12043', '1258422', '1263266', '1263291', '1263300', '1263308', '1263311', '1263348', '1263410', '1263427', '1268338', '1284314', '1285841', '1302809', '130666', '136817', '138501', '145359', '15187', '155788', '158168', '166036', '167585', '168757', '169165', '170147', '171629', '174203', '175103', '175966', '176038', '176244', '176301', '176305', '176674', '177606', '17876', '196080', '196356', '196364', '196447', '196986', '197158', '197392', '197463', '197737', '210013', '210926', '211578', '211602', '211942', '212486', '212518', '212527', '212632', '212897', '213722', '216390', '216650', '218498', '218708', '220289', '220492', '234205', '235670', '248234', '251155', '252527', '252859', '254779', '258768', '258844', '259539', '260505', '265930', '266441', '278101', '282599', '282878', '283965', '283966', '284102', '4773', '6380', '67182', '71258', '71625', '73618', '74257', '75825', '75884', '77618', '77907', '78084', '80672', '81631';

 SELECT  Pitches.batter_id as BatterId , avg(HitsNoBunts.hit_exit_speed) as HitExitVelo_Avg
, avg(HitsNoBunts.hit_useful_exit_speed) as HitUsefulExitVelo_Avg
, avg(case when HitsNoBunts.hit_exit_speed is null or Pitches.pitch_result_id not in (12, 13, 14, 18, 19, 20) then null else case when HitsNoBunts.hit_exit_speed >= 95 then 1.0 else 0.0 end end) as HardHit_Pct
, avg(case when HitsNoBunts.hit_exit_speed is null then null else 1.0 * case when cast(HitsNoBunts.hit_exit_speed as decimal(4, 0)) * 1.5 - cast(HitsNoBunts.hit_vertical_angle as decimal(3, 0)) >= 117.0 and cast(HitsNoBunts.hit_exit_speed as decimal(4, 0)) + cast(HitsNoBunts.hit_vertical_angle as decimal(3, 0)) >= 124.0 and cast(HitsNoBunts.hit_exit_speed as decimal(4, 0)) >= 98.0 and cast(HitsNoBunts.hit_vertical_angle as decimal(3, 0)) > 4.0 and cast(HitsNoBunts.hit_vertical_angle as decimal(3, 0)) < 50.0 then 1 else 0 end end) as BarrelRate
, avg(case when HitsNoBunts.hit_exit_speed is not null then 1.6 * power(1.3, cos(-.34) * (HitsNoBunts.hit_exit_speed - 98.0) - sin(-.34) * (HitsNoBunts.hit_vertical_angle - 27.0) - .02 * power(2 + sin(-.34) * (HitsNoBunts.hit_exit_speed - 98.0) + cos(-.34) * (HitsNoBunts.hit_vertical_angle - 27.0), 2)) / (7.0 + power(1.3, cos(-.34) * (HitsNoBunts.hit_exit_speed - 98.0) - sin(-.34) * (HitsNoBunts.hit_vertical_angle - 27.0) - .02 * power(2 + sin(-.34) * (HitsNoBunts.hit_exit_speed - 98.0) + cos(-.34) * (HitsNoBunts.hit_vertical_angle - 27.0), 2))) else null end) as Damage_Pct
, avg(case when HitsNoBunts.hit_vertical_angle is null or Pitches.pitch_result_id not in (12, 13, 14, 18, 19, 20) then null else HitsNoBunts.hit_vertical_angle end) as HitLaunchAngle_Avg
, stdev(case when HitsNoBunts.hit_vertical_angle is null or Pitches.pitch_result_id not in (12, 13, 14, 18, 19, 20) then null else HitsNoBunts.hit_vertical_angle end) as HitLaunchAngle_Sd
, avg(case when HitsNoBunts.hit_vertical_angle is null or Pitches.pitch_result_id not in (12, 13, 14, 18, 19, 20) then null else 1.0 * case when HitsNoBunts.hit_vertical_angle >= 10 and HitsNoBunts.hit_vertical_angle <= 30 and Pitches.pitch_result_id in (12, 13, 14, 18, 19, 20) then 1 else 0 end end) as HitLaunchAngle_1030
  INTO #AGG 
 FROM Astros.Events_View CurEvents
 left join astros.schedule_view Schedule on CurEvents.sched_id = Schedule.sched_id
 left join astros.pitches_view Pitches on CurEvents.sched_id = Pitches.sched_id and CurEvents.event_id = Pitches.cur_event_id
  left join astros.hits HitsNoBunts on Pitches.sched_id = HitsNoBunts.sched_id and Pitches.pitch_id = HitsNoBunts.pitch_id and Pitches.pitch_result_id in (12,13,14) and (CurEvents.hit_trajectory_id not in (2,3,4) or CurEvents.hit_trajectory_id is null) and not (HitsNoBunts.hit_vertical_angle < -25 and Schedule.level_code in ('hsb', 'sum', 'bbc')) and HitsNoBunts.hit_exit_speed < 125
 WHERE Schedule.year >= @Param0
 AND Schedule.year <= @Param1
 AND  (Pitches.pitcher_throws IN /** @Param2 **/ ('L')) AND  (Schedule.gc2_level_id IN /** @Param3 **/ ('13', '1', '2', '3', '4', '5', '20', '24')) AND  (Schedule.sched_type IN /** @Param4 **/ ('r')) AND  (Pitches.batter_id IN /** @Param5 **/ ('106530', '106564', '106941', '107376', '107881', '110840', '116925', '12043', '1258422', '1263266', '1263291', '1263300', '1263308', '1263311', '1263348', '1263410', '1263427', '1268338', '1284314', '1285841', '1302809', '130666', '136817', '138501', '145359', '15187', '155788', '158168', '166036', '167585', '168757', '169165', '170147', '171629', '174203', '175103', '175966', '176038', '176244', '176301', '176305', '176674', '177606', '17876', '196080', '196356', '196364', '196447', '196986', '197158', '197392', '197463', '197737', '210013', '210926', '211578', '211602', '211942', '212486', '212518', '212527', '212632', '212897', '213722', '216390', '216650', '218498', '218708', '220289', '220492', '234205', '235670', '248234', '251155', '252527', '252859', '254779', '258768', '258844', '259539', '260505', '265930', '266441', '278101', '282599', '282878', '283965', '283966', '284102', '4773', '6380', '67182', '71258', '71625', '73618', '74257', '75825', '75884', '77618', '77907', '78084', '80672', '81631'))
 GROUP BY  Pitches.batter_id
-- GO
 OPTION(RECOMPILE) 
  SELECT DISTINCT  Pitches.batter_id as BatterId , percentile_cont(0.99) within group (order by HitsNoBunts.hit_exit_speed) over (partition by  Pitches.batter_id) as HitExitVelo_Max
  INTO #NTILE 
 FROM Astros.Events_View CurEvents
 left join astros.schedule_view Schedule on CurEvents.sched_id = Schedule.sched_id
 left join astros.pitches_view Pitches on CurEvents.sched_id = Pitches.sched_id and CurEvents.event_id = Pitches.cur_event_id
  left join astros.hits HitsNoBunts on Pitches.sched_id = HitsNoBunts.sched_id and Pitches.pitch_id = HitsNoBunts.pitch_id and Pitches.pitch_result_id in (12,13,14) and (CurEvents.hit_trajectory_id not in (2,3,4) or CurEvents.hit_trajectory_id is null) and not (HitsNoBunts.hit_vertical_angle < -25 and Schedule.level_code in ('hsb', 'sum', 'bbc')) and HitsNoBunts.hit_exit_speed < 125
 WHERE Schedule.year >= @Param0
 AND Schedule.year <= @Param1
 AND  (Pitches.pitcher_throws IN /** @Param2 **/ ('L')) AND  (Schedule.gc2_level_id IN /** @Param3 **/ ('13', '1', '2', '3', '4', '5', '20', '24')) AND  (Schedule.sched_type IN /** @Param4 **/ ('r')) AND  (Pitches.batter_id IN /** @Param5 **/ ('106530', '106564', '106941', '107376', '107881', '110840', '116925', '12043', '1258422', '1263266', '1263291', '1263300', '1263308', '1263311', '1263348', '1263410', '1263427', '1268338', '1284314', '1285841', '1302809', '130666', '136817', '138501', '145359', '15187', '155788', '158168', '166036', '167585', '168757', '169165', '170147', '171629', '174203', '175103', '175966', '176038', '176244', '176301', '176305', '176674', '177606', '17876', '196080', '196356', '196364', '196447', '196986', '197158', '197392', '197463', '197737', '210013', '210926', '211578', '211602', '211942', '212486', '212518', '212527', '212632', '212897', '213722', '216390', '216650', '218498', '218708', '220289', '220492', '234205', '235670', '248234', '251155', '252527', '252859', '254779', '258768', '258844', '259539', '260505', '265930', '266441', '278101', '282599', '282878', '283965', '283966', '284102', '4773', '6380', '67182', '71258', '71625', '73618', '74257', '75825', '75884', '77618', '77907', '78084', '80672', '81631'))

 OPTION(RECOMPILE) 
 SELECT  Ntile.BatterId, Ntile.HitExitVelo_Max, Agg.HitExitVelo_Avg, Agg.HitUsefulExitVelo_Avg, Agg.HardHit_Pct, Agg.BarrelRate, Agg.Damage_Pct, Agg.HitLaunchAngle_Avg, Agg.HitLaunchAngle_Sd, Agg.HitLaunchAngle_1030
 FROM 
 #AGG AGG, #NTILE NTILE WHERE  isnull(cast(Agg.BatterId as varchar),'') = isnull(cast( Ntile.BatterId as varchar),'')

 /** 4:Event **/
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
DROP TABLE IF EXISTS #AGG; DROP TABLE IF EXISTS #NTILE;
GO
DECLARE @Param0 varchar(1000) = '2025';
DECLARE @Param1 varchar(1000) = '2025';
-- DECLARE @Param2 varchar(1000) = 'R';
-- DECLARE @Param3 varchar(1000) = '13', '1', '2', '3', '4', '5', '20', '24';
-- DECLARE @Param4 varchar(1000) = 'r';
-- DECLARE @Param5 varchar(1000) = '106530', '106564', '106941', '107376', '107881', '110840', '116925', '12043', '1258422', '1263266', '1263291', '1263300', '1263308', '1263311', '1263348', '1263410', '1263427', '1268338', '1284314', '1285841', '1302809', '130666', '136817', '138501', '145359', '15187', '155788', '158168', '166036', '167585', '168757', '169165', '170147', '171629', '174203', '175103', '175966', '176038', '176244', '176301', '176305', '176674', '177606', '17876', '196080', '196356', '196364', '196447', '196986', '197158', '197392', '197463', '197737', '210013', '210926', '211578', '211602', '211942', '212486', '212518', '212527', '212632', '212897', '213722', '216390', '216650', '218498', '218708', '220289', '220492', '234205', '235670', '248234', '251155', '252527', '252859', '254779', '258768', '258844', '259539', '260505', '265930', '266441', '278101', '282599', '282878', '283965', '283966', '284102', '4773', '6380', '67182', '71258', '71625', '73618', '74257', '75825', '75884', '77618', '77907', '78084', '80672', '81631';

 SELECT  Pitches.batter_id as BatterId , avg(HitsNoBunts.hit_exit_speed) as HitExitVelo_Avg
, avg(HitsNoBunts.hit_useful_exit_speed) as HitUsefulExitVelo_Avg
, avg(case when HitsNoBunts.hit_exit_speed is null or Pitches.pitch_result_id not in (12, 13, 14, 18, 19, 20) then null else case when HitsNoBunts.hit_exit_speed >= 95 then 1.0 else 0.0 end end) as HardHit_Pct
, avg(case when HitsNoBunts.hit_exit_speed is null then null else 1.0 * case when cast(HitsNoBunts.hit_exit_speed as decimal(4, 0)) * 1.5 - cast(HitsNoBunts.hit_vertical_angle as decimal(3, 0)) >= 117.0 and cast(HitsNoBunts.hit_exit_speed as decimal(4, 0)) + cast(HitsNoBunts.hit_vertical_angle as decimal(3, 0)) >= 124.0 and cast(HitsNoBunts.hit_exit_speed as decimal(4, 0)) >= 98.0 and cast(HitsNoBunts.hit_vertical_angle as decimal(3, 0)) > 4.0 and cast(HitsNoBunts.hit_vertical_angle as decimal(3, 0)) < 50.0 then 1 else 0 end end) as BarrelRate
, avg(case when HitsNoBunts.hit_exit_speed is not null then 1.6 * power(1.3, cos(-.34) * (HitsNoBunts.hit_exit_speed - 98.0) - sin(-.34) * (HitsNoBunts.hit_vertical_angle - 27.0) - .02 * power(2 + sin(-.34) * (HitsNoBunts.hit_exit_speed - 98.0) + cos(-.34) * (HitsNoBunts.hit_vertical_angle - 27.0), 2)) / (7.0 + power(1.3, cos(-.34) * (HitsNoBunts.hit_exit_speed - 98.0) - sin(-.34) * (HitsNoBunts.hit_vertical_angle - 27.0) - .02 * power(2 + sin(-.34) * (HitsNoBunts.hit_exit_speed - 98.0) + cos(-.34) * (HitsNoBunts.hit_vertical_angle - 27.0), 2))) else null end) as Damage_Pct
, avg(case when HitsNoBunts.hit_vertical_angle is null or Pitches.pitch_result_id not in (12, 13, 14, 18, 19, 20) then null else HitsNoBunts.hit_vertical_angle end) as HitLaunchAngle_Avg
, stdev(case when HitsNoBunts.hit_vertical_angle is null or Pitches.pitch_result_id not in (12, 13, 14, 18, 19, 20) then null else HitsNoBunts.hit_vertical_angle end) as HitLaunchAngle_Sd
, avg(case when HitsNoBunts.hit_vertical_angle is null or Pitches.pitch_result_id not in (12, 13, 14, 18, 19, 20) then null else 1.0 * case when HitsNoBunts.hit_vertical_angle >= 10 and HitsNoBunts.hit_vertical_angle <= 30 and Pitches.pitch_result_id in (12, 13, 14, 18, 19, 20) then 1 else 0 end end) as HitLaunchAngle_1030
  INTO #AGG 
 FROM Astros.Events_View CurEvents
 left join astros.schedule_view Schedule on CurEvents.sched_id = Schedule.sched_id
 left join astros.pitches_view Pitches on CurEvents.sched_id = Pitches.sched_id and CurEvents.event_id = Pitches.cur_event_id
  left join astros.hits HitsNoBunts on Pitches.sched_id = HitsNoBunts.sched_id and Pitches.pitch_id = HitsNoBunts.pitch_id and Pitches.pitch_result_id in (12,13,14) and (CurEvents.hit_trajectory_id not in (2,3,4) or CurEvents.hit_trajectory_id is null) and not (HitsNoBunts.hit_vertical_angle < -25 and Schedule.level_code in ('hsb', 'sum', 'bbc')) and HitsNoBunts.hit_exit_speed < 125
 WHERE Schedule.year >= @Param0
 AND Schedule.year <= @Param1
 AND  (Pitches.pitcher_throws IN /** @Param2 **/ ('R')) AND  (Schedule.gc2_level_id IN /** @Param3 **/ ('13', '1', '2', '3', '4', '5', '20', '24')) AND  (Schedule.sched_type IN /** @Param4 **/ ('r')) AND  (Pitches.batter_id IN /** @Param5 **/ ('106530', '106564', '106941', '107376', '107881', '110840', '116925', '12043', '1258422', '1263266', '1263291', '1263300', '1263308', '1263311', '1263348', '1263410', '1263427', '1268338', '1284314', '1285841', '1302809', '130666', '136817', '138501', '145359', '15187', '155788', '158168', '166036', '167585', '168757', '169165', '170147', '171629', '174203', '175103', '175966', '176038', '176244', '176301', '176305', '176674', '177606', '17876', '196080', '196356', '196364', '196447', '196986', '197158', '197392', '197463', '197737', '210013', '210926', '211578', '211602', '211942', '212486', '212518', '212527', '212632', '212897', '213722', '216390', '216650', '218498', '218708', '220289', '220492', '234205', '235670', '248234', '251155', '252527', '252859', '254779', '258768', '258844', '259539', '260505', '265930', '266441', '278101', '282599', '282878', '283965', '283966', '284102', '4773', '6380', '67182', '71258', '71625', '73618', '74257', '75825', '75884', '77618', '77907', '78084', '80672', '81631'))
 GROUP BY  Pitches.batter_id
-- GO
 OPTION(RECOMPILE) 
  SELECT DISTINCT  Pitches.batter_id as BatterId , percentile_cont(0.99) within group (order by HitsNoBunts.hit_exit_speed) over (partition by  Pitches.batter_id) as HitExitVelo_Max
  INTO #NTILE 
 FROM Astros.Events_View CurEvents
 left join astros.schedule_view Schedule on CurEvents.sched_id = Schedule.sched_id
 left join astros.pitches_view Pitches on CurEvents.sched_id = Pitches.sched_id and CurEvents.event_id = Pitches.cur_event_id
  left join astros.hits HitsNoBunts on Pitches.sched_id = HitsNoBunts.sched_id and Pitches.pitch_id = HitsNoBunts.pitch_id and Pitches.pitch_result_id in (12,13,14) and (CurEvents.hit_trajectory_id not in (2,3,4) or CurEvents.hit_trajectory_id is null) and not (HitsNoBunts.hit_vertical_angle < -25 and Schedule.level_code in ('hsb', 'sum', 'bbc')) and HitsNoBunts.hit_exit_speed < 125
 WHERE Schedule.year >= @Param0
 AND Schedule.year <= @Param1
 AND  (Pitches.pitcher_throws IN /** @Param2 **/ ('R')) AND  (Schedule.gc2_level_id IN /** @Param3 **/ ('13', '1', '2', '3', '4', '5', '20', '24')) AND  (Schedule.sched_type IN /** @Param4 **/ ('r')) AND  (Pitches.batter_id IN /** @Param5 **/ ('106530', '106564', '106941', '107376', '107881', '110840', '116925', '12043', '1258422', '1263266', '1263291', '1263300', '1263308', '1263311', '1263348', '1263410', '1263427', '1268338', '1284314', '1285841', '1302809', '130666', '136817', '138501', '145359', '15187', '155788', '158168', '166036', '167585', '168757', '169165', '170147', '171629', '174203', '175103', '175966', '176038', '176244', '176301', '176305', '176674', '177606', '17876', '196080', '196356', '196364', '196447', '196986', '197158', '197392', '197463', '197737', '210013', '210926', '211578', '211602', '211942', '212486', '212518', '212527', '212632', '212897', '213722', '216390', '216650', '218498', '218708', '220289', '220492', '234205', '235670', '248234', '251155', '252527', '252859', '254779', '258768', '258844', '259539', '260505', '265930', '266441', '278101', '282599', '282878', '283965', '283966', '284102', '4773', '6380', '67182', '71258', '71625', '73618', '74257', '75825', '75884', '77618', '77907', '78084', '80672', '81631'))

 OPTION(RECOMPILE) 
 SELECT  Ntile.BatterId, Ntile.HitExitVelo_Max, Agg.HitExitVelo_Avg, Agg.HitUsefulExitVelo_Avg, Agg.HardHit_Pct, Agg.BarrelRate, Agg.Damage_Pct, Agg.HitLaunchAngle_Avg, Agg.HitLaunchAngle_Sd, Agg.HitLaunchAngle_1030
 FROM 
 #AGG AGG, #NTILE NTILE WHERE  isnull(cast(Agg.BatterId as varchar),'') = isnull(cast( Ntile.BatterId as varchar),'')

 /** 5:Pitch **/
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
DROP TABLE IF EXISTS #AGG; DROP TABLE IF EXISTS #NTILE;
GO
DECLARE @Param0 varchar(1000) = '2025';
DECLARE @Param1 varchar(1000) = '2025';
-- DECLARE @Param2 varchar(1000) = 'L';
-- DECLARE @Param3 varchar(1000) = '13', '1', '2', '3', '4', '5', '20', '24';
-- DECLARE @Param4 varchar(1000) = 'r';
-- DECLARE @Param5 varchar(1000) = '106530', '106564', '106941', '107376', '107881', '110840', '116925', '12043', '1258422', '1263266', '1263291', '1263300', '1263308', '1263311', '1263348', '1263410', '1263427', '1268338', '1284314', '1285841', '1302809', '130666', '136817', '138501', '145359', '15187', '155788', '158168', '166036', '167585', '168757', '169165', '170147', '171629', '174203', '175103', '175966', '176038', '176244', '176301', '176305', '176674', '177606', '17876', '196080', '196356', '196364', '196447', '196986', '197158', '197392', '197463', '197737', '210013', '210926', '211578', '211602', '211942', '212486', '212518', '212527', '212632', '212897', '213722', '216390', '216650', '218498', '218708', '220289', '220492', '234205', '235670', '248234', '251155', '252527', '252859', '254779', '258768', '258844', '259539', '260505', '265930', '266441', '278101', '282599', '282878', '283965', '283966', '284102', '4773', '6380', '67182', '71258', '71625', '73618', '74257', '75825', '75884', '77618', '77907', '78084', '80672', '81631';

 SELECT  Pitches.batter_id as BatterId , avg(1.0 * case when Pitches.called_strike_chance_mlb < .01 then case when Pitches.did_swing = 1 then 1 else 0 end else null end) as ChasePercentage
, avg(Pitches.swing_decision_grade_2080) as SwingDecisionAgainstComponentGrade2080_Avg
, avg(ProjPitchGrades.swing_decision) as SwingDecisionAgainstGrade2080_Avg
, avg(Pitches.swing_decision_abs_grade_2080) as SwingDecisionAgainstABSComponentGrade2080_Avg
, avg(case when Pitches.pitch_result_id in (10,21,22,23) then 1.0 else 0.0 end) as SwingingStrikePercentage
, avg(case when Pitches.did_swing = 1 then 1.0 else 0.0 end) as SwingPercentage
, sum(case when Pitches.did_swing = 1 then Pitches.called_strike_chance_mlb else null end)/nullif(sum(Pitches.called_strike_chance_mlb),0) as SwingPercentage_InZone
, sum(case when Pitches.did_swing = 1 then 1.0 - Pitches.called_strike_chance_mlb else null end)/nullif(sum(1.0 - Pitches.called_strike_chance_mlb),0) as SwingPercentage_OutZone
, avg(1.0 * case when Pitches.did_swing = 1 then case when Pitches.pitch_result_id in (10,21,22,23) then 1 else 0 end else null end) as WhiffPercentage
, sum(case when Pitches.did_swing = 1 then case when Pitches.pitch_result_id in (10,21,22,23) then Pitches.called_strike_chance_mlb else 0 end else null end)/nullif(sum(case when Pitches.did_swing = 1 then Pitches.called_strike_chance_mlb else null end),0) as WhiffPercentage_InZone
  INTO #AGG 
 FROM Astros.Pitches_View Pitches
 left join astros.schedule_view Schedule on Pitches.sched_id = Schedule.sched_id
 left join astros.projections_pitches_grades ProjPitchGrades on Pitches.sched_id = ProjPitchGrades.sched_id and Pitches.pitch_id = ProjPitchGrades.pitch_id
 WHERE Schedule.year >= @Param0
 AND Schedule.year <= @Param1
 AND  (Pitches.pitcher_throws IN /** @Param2 **/ ('L')) AND  (Schedule.gc2_level_id IN /** @Param3 **/ ('13', '1', '2', '3', '4', '5', '20', '24')) AND  (Schedule.sched_type IN /** @Param4 **/ ('r')) AND  (Pitches.batter_id IN /** @Param5 **/ ('106530', '106564', '106941', '107376', '107881', '110840', '116925', '12043', '1258422', '1263266', '1263291', '1263300', '1263308', '1263311', '1263348', '1263410', '1263427', '1268338', '1284314', '1285841', '1302809', '130666', '136817', '138501', '145359', '15187', '155788', '158168', '166036', '167585', '168757', '169165', '170147', '171629', '174203', '175103', '175966', '176038', '176244', '176301', '176305', '176674', '177606', '17876', '196080', '196356', '196364', '196447', '196986', '197158', '197392', '197463', '197737', '210013', '210926', '211578', '211602', '211942', '212486', '212518', '212527', '212632', '212897', '213722', '216390', '216650', '218498', '218708', '220289', '220492', '234205', '235670', '248234', '251155', '252527', '252859', '254779', '258768', '258844', '259539', '260505', '265930', '266441', '278101', '282599', '282878', '283965', '283966', '284102', '4773', '6380', '67182', '71258', '71625', '73618', '74257', '75825', '75884', '77618', '77907', '78084', '80672', '81631'))
 AND Pitches.ignore_flag = 0 AND Pitches.pitch_id > 0
 GROUP BY  Pitches.batter_id
-- GO
 OPTION(RECOMPILE) 
  SELECT  Agg.BatterId, Agg.ChasePercentage, Agg.SwingDecisionAgainstComponentGrade2080_Avg, Agg.SwingDecisionAgainstGrade2080_Avg, Agg.SwingDecisionAgainstABSComponentGrade2080_Avg, Agg.SwingingStrikePercentage, Agg.SwingPercentage, Agg.SwingPercentage_InZone, Agg.SwingPercentage_OutZone, Agg.WhiffPercentage, Agg.WhiffPercentage_InZone
 FROM 
#AGG AGG 
 WHERE 1=1 

 /** 5:Event **/
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
DROP TABLE IF EXISTS #AGG; DROP TABLE IF EXISTS #NTILE;
GO
DECLARE @Param0 varchar(1000) = '2025';
DECLARE @Param1 varchar(1000) = '2025';
-- DECLARE @Param2 varchar(1000) = 'L';
-- DECLARE @Param3 varchar(1000) = '13', '1', '2', '3', '4', '5', '20', '24';
-- DECLARE @Param4 varchar(1000) = 'r';
-- DECLARE @Param5 varchar(1000) = '106530', '106564', '106941', '107376', '107881', '110840', '116925', '12043', '1258422', '1263266', '1263291', '1263300', '1263308', '1263311', '1263348', '1263410', '1263427', '1268338', '1284314', '1285841', '1302809', '130666', '136817', '138501', '145359', '15187', '155788', '158168', '166036', '167585', '168757', '169165', '170147', '171629', '174203', '175103', '175966', '176038', '176244', '176301', '176305', '176674', '177606', '17876', '196080', '196356', '196364', '196447', '196986', '197158', '197392', '197463', '197737', '210013', '210926', '211578', '211602', '211942', '212486', '212518', '212527', '212632', '212897', '213722', '216390', '216650', '218498', '218708', '220289', '220492', '234205', '235670', '248234', '251155', '252527', '252859', '254779', '258768', '258844', '259539', '260505', '265930', '266441', '278101', '282599', '282878', '283965', '283966', '284102', '4773', '6380', '67182', '71258', '71625', '73618', '74257', '75825', '75884', '77618', '77907', '78084', '80672', '81631';

 SELECT  Pitches.batter_id as BatterId , avg(1.0 * case when Pitches.called_strike_chance_mlb < .01 then case when Pitches.did_swing = 1 then 1 else 0 end else null end) as ChasePercentage
, avg(Pitches.swing_decision_grade_2080) as SwingDecisionAgainstComponentGrade2080_Avg
, avg(Pitches.swing_decision_abs_grade_2080) as SwingDecisionAgainstABSComponentGrade2080_Avg
, avg(case when Pitches.pitch_result_id in (10,21,22,23) then 1.0 else 0.0 end) as SwingingStrikePercentage
, avg(case when Pitches.did_swing = 1 then 1.0 else 0.0 end) as SwingPercentage
, avg(1.0 * case when Pitches.did_swing = 1 then case when Pitches.pitch_result_id in (10,21,22,23) then 1 else 0 end else null end) as WhiffPercentage
, sum(case when Pitches.did_swing = 1 then case when Pitches.pitch_result_id in (10,21,22,23) then Pitches.called_strike_chance_mlb else 0 end else null end)/nullif(sum(case when Pitches.did_swing = 1 then Pitches.called_strike_chance_mlb else null end),0) as WhiffPercentage_InZone
  INTO #AGG 
 FROM Astros.Events_View CurEvents
 left join astros.schedule_view Schedule on CurEvents.sched_id = Schedule.sched_id
 left join astros.pitches_view Pitches on CurEvents.sched_id = Pitches.sched_id and CurEvents.event_id = Pitches.cur_event_id
 WHERE Schedule.year >= @Param0
 AND Schedule.year <= @Param1
 AND  (Pitches.pitcher_throws IN /** @Param2 **/ ('L')) AND  (Schedule.gc2_level_id IN /** @Param3 **/ ('13', '1', '2', '3', '4', '5', '20', '24')) AND  (Schedule.sched_type IN /** @Param4 **/ ('r')) AND  (Pitches.batter_id IN /** @Param5 **/ ('106530', '106564', '106941', '107376', '107881', '110840', '116925', '12043', '1258422', '1263266', '1263291', '1263300', '1263308', '1263311', '1263348', '1263410', '1263427', '1268338', '1284314', '1285841', '1302809', '130666', '136817', '138501', '145359', '15187', '155788', '158168', '166036', '167585', '168757', '169165', '170147', '171629', '174203', '175103', '175966', '176038', '176244', '176301', '176305', '176674', '177606', '17876', '196080', '196356', '196364', '196447', '196986', '197158', '197392', '197463', '197737', '210013', '210926', '211578', '211602', '211942', '212486', '212518', '212527', '212632', '212897', '213722', '216390', '216650', '218498', '218708', '220289', '220492', '234205', '235670', '248234', '251155', '252527', '252859', '254779', '258768', '258844', '259539', '260505', '265930', '266441', '278101', '282599', '282878', '283965', '283966', '284102', '4773', '6380', '67182', '71258', '71625', '73618', '74257', '75825', '75884', '77618', '77907', '78084', '80672', '81631'))
 GROUP BY  Pitches.batter_id
-- GO
 OPTION(RECOMPILE) 
  SELECT  Agg.BatterId, Agg.ChasePercentage, Agg.SwingDecisionAgainstComponentGrade2080_Avg, Agg.SwingDecisionAgainstABSComponentGrade2080_Avg, Agg.SwingingStrikePercentage, Agg.SwingPercentage, Agg.WhiffPercentage, Agg.WhiffPercentage_InZone
 FROM 
#AGG AGG 
 WHERE 1=1 

 /** 6:Pitch **/
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
DROP TABLE IF EXISTS #AGG; DROP TABLE IF EXISTS #NTILE;
GO
DECLARE @Param0 varchar(1000) = '2025';
DECLARE @Param1 varchar(1000) = '2025';
-- DECLARE @Param2 varchar(1000) = 'R';
-- DECLARE @Param3 varchar(1000) = '13', '1', '2', '3', '4', '5', '20', '24';
-- DECLARE @Param4 varchar(1000) = 'r';
-- DECLARE @Param5 varchar(1000) = '106530', '106564', '106941', '107376', '107881', '110840', '116925', '12043', '1258422', '1263266', '1263291', '1263300', '1263308', '1263311', '1263348', '1263410', '1263427', '1268338', '1284314', '1285841', '1302809', '130666', '136817', '138501', '145359', '15187', '155788', '158168', '166036', '167585', '168757', '169165', '170147', '171629', '174203', '175103', '175966', '176038', '176244', '176301', '176305', '176674', '177606', '17876', '196080', '196356', '196364', '196447', '196986', '197158', '197392', '197463', '197737', '210013', '210926', '211578', '211602', '211942', '212486', '212518', '212527', '212632', '212897', '213722', '216390', '216650', '218498', '218708', '220289', '220492', '234205', '235670', '248234', '251155', '252527', '252859', '254779', '258768', '258844', '259539', '260505', '265930', '266441', '278101', '282599', '282878', '283965', '283966', '284102', '4773', '6380', '67182', '71258', '71625', '73618', '74257', '75825', '75884', '77618', '77907', '78084', '80672', '81631';

 SELECT  Pitches.batter_id as BatterId , avg(1.0 * case when Pitches.called_strike_chance_mlb < .01 then case when Pitches.did_swing = 1 then 1 else 0 end else null end) as ChasePercentage
, avg(Pitches.swing_decision_grade_2080) as SwingDecisionAgainstComponentGrade2080_Avg
, avg(ProjPitchGrades.swing_decision) as SwingDecisionAgainstGrade2080_Avg
, avg(Pitches.swing_decision_abs_grade_2080) as SwingDecisionAgainstABSComponentGrade2080_Avg
, avg(case when Pitches.pitch_result_id in (10,21,22,23) then 1.0 else 0.0 end) as SwingingStrikePercentage
, avg(case when Pitches.did_swing = 1 then 1.0 else 0.0 end) as SwingPercentage
, sum(case when Pitches.did_swing = 1 then Pitches.called_strike_chance_mlb else null end)/nullif(sum(Pitches.called_strike_chance_mlb),0) as SwingPercentage_InZone
, sum(case when Pitches.did_swing = 1 then 1.0 - Pitches.called_strike_chance_mlb else null end)/nullif(sum(1.0 - Pitches.called_strike_chance_mlb),0) as SwingPercentage_OutZone
, avg(1.0 * case when Pitches.did_swing = 1 then case when Pitches.pitch_result_id in (10,21,22,23) then 1 else 0 end else null end) as WhiffPercentage
, sum(case when Pitches.did_swing = 1 then case when Pitches.pitch_result_id in (10,21,22,23) then Pitches.called_strike_chance_mlb else 0 end else null end)/nullif(sum(case when Pitches.did_swing = 1 then Pitches.called_strike_chance_mlb else null end),0) as WhiffPercentage_InZone
  INTO #AGG 
 FROM Astros.Pitches_View Pitches
 left join astros.schedule_view Schedule on Pitches.sched_id = Schedule.sched_id
 left join astros.projections_pitches_grades ProjPitchGrades on Pitches.sched_id = ProjPitchGrades.sched_id and Pitches.pitch_id = ProjPitchGrades.pitch_id
 WHERE Schedule.year >= @Param0
 AND Schedule.year <= @Param1
 AND  (Pitches.pitcher_throws IN /** @Param2 **/ ('R')) AND  (Schedule.gc2_level_id IN /** @Param3 **/ ('13', '1', '2', '3', '4', '5', '20', '24')) AND  (Schedule.sched_type IN /** @Param4 **/ ('r')) AND  (Pitches.batter_id IN /** @Param5 **/ ('106530', '106564', '106941', '107376', '107881', '110840', '116925', '12043', '1258422', '1263266', '1263291', '1263300', '1263308', '1263311', '1263348', '1263410', '1263427', '1268338', '1284314', '1285841', '1302809', '130666', '136817', '138501', '145359', '15187', '155788', '158168', '166036', '167585', '168757', '169165', '170147', '171629', '174203', '175103', '175966', '176038', '176244', '176301', '176305', '176674', '177606', '17876', '196080', '196356', '196364', '196447', '196986', '197158', '197392', '197463', '197737', '210013', '210926', '211578', '211602', '211942', '212486', '212518', '212527', '212632', '212897', '213722', '216390', '216650', '218498', '218708', '220289', '220492', '234205', '235670', '248234', '251155', '252527', '252859', '254779', '258768', '258844', '259539', '260505', '265930', '266441', '278101', '282599', '282878', '283965', '283966', '284102', '4773', '6380', '67182', '71258', '71625', '73618', '74257', '75825', '75884', '77618', '77907', '78084', '80672', '81631'))
 AND Pitches.ignore_flag = 0 AND Pitches.pitch_id > 0
 GROUP BY  Pitches.batter_id
-- GO
 OPTION(RECOMPILE) 
  SELECT  Agg.BatterId, Agg.ChasePercentage, Agg.SwingDecisionAgainstComponentGrade2080_Avg, Agg.SwingDecisionAgainstGrade2080_Avg, Agg.SwingDecisionAgainstABSComponentGrade2080_Avg, Agg.SwingingStrikePercentage, Agg.SwingPercentage, Agg.SwingPercentage_InZone, Agg.SwingPercentage_OutZone, Agg.WhiffPercentage, Agg.WhiffPercentage_InZone
 FROM 
#AGG AGG 
 WHERE 1=1 

 /** 6:Event **/
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
DROP TABLE IF EXISTS #AGG; DROP TABLE IF EXISTS #NTILE;
GO
DECLARE @Param0 varchar(1000) = '2025';
DECLARE @Param1 varchar(1000) = '2025';
-- DECLARE @Param2 varchar(1000) = 'R';
-- DECLARE @Param3 varchar(1000) = '13', '1', '2', '3', '4', '5', '20', '24';
-- DECLARE @Param4 varchar(1000) = 'r';
-- DECLARE @Param5 varchar(1000) = '106530', '106564', '106941', '107376', '107881', '110840', '116925', '12043', '1258422', '1263266', '1263291', '1263300', '1263308', '1263311', '1263348', '1263410', '1263427', '1268338', '1284314', '1285841', '1302809', '130666', '136817', '138501', '145359', '15187', '155788', '158168', '166036', '167585', '168757', '169165', '170147', '171629', '174203', '175103', '175966', '176038', '176244', '176301', '176305', '176674', '177606', '17876', '196080', '196356', '196364', '196447', '196986', '197158', '197392', '197463', '197737', '210013', '210926', '211578', '211602', '211942', '212486', '212518', '212527', '212632', '212897', '213722', '216390', '216650', '218498', '218708', '220289', '220492', '234205', '235670', '248234', '251155', '252527', '252859', '254779', '258768', '258844', '259539', '260505', '265930', '266441', '278101', '282599', '282878', '283965', '283966', '284102', '4773', '6380', '67182', '71258', '71625', '73618', '74257', '75825', '75884', '77618', '77907', '78084', '80672', '81631';

 SELECT  Pitches.batter_id as BatterId , avg(1.0 * case when Pitches.called_strike_chance_mlb < .01 then case when Pitches.did_swing = 1 then 1 else 0 end else null end) as ChasePercentage
, avg(Pitches.swing_decision_grade_2080) as SwingDecisionAgainstComponentGrade2080_Avg
, avg(Pitches.swing_decision_abs_grade_2080) as SwingDecisionAgainstABSComponentGrade2080_Avg
, avg(case when Pitches.pitch_result_id in (10,21,22,23) then 1.0 else 0.0 end) as SwingingStrikePercentage
, avg(case when Pitches.did_swing = 1 then 1.0 else 0.0 end) as SwingPercentage
, avg(1.0 * case when Pitches.did_swing = 1 then case when Pitches.pitch_result_id in (10,21,22,23) then 1 else 0 end else null end) as WhiffPercentage
, sum(case when Pitches.did_swing = 1 then case when Pitches.pitch_result_id in (10,21,22,23) then Pitches.called_strike_chance_mlb else 0 end else null end)/nullif(sum(case when Pitches.did_swing = 1 then Pitches.called_strike_chance_mlb else null end),0) as WhiffPercentage_InZone
  INTO #AGG 
 FROM Astros.Events_View CurEvents
 left join astros.schedule_view Schedule on CurEvents.sched_id = Schedule.sched_id
 left join astros.pitches_view Pitches on CurEvents.sched_id = Pitches.sched_id and CurEvents.event_id = Pitches.cur_event_id
 WHERE Schedule.year >= @Param0
 AND Schedule.year <= @Param1
 AND  (Pitches.pitcher_throws IN /** @Param2 **/ ('R')) AND  (Schedule.gc2_level_id IN /** @Param3 **/ ('13', '1', '2', '3', '4', '5', '20', '24')) AND  (Schedule.sched_type IN /** @Param4 **/ ('r')) AND  (Pitches.batter_id IN /** @Param5 **/ ('106530', '106564', '106941', '107376', '107881', '110840', '116925', '12043', '1258422', '1263266', '1263291', '1263300', '1263308', '1263311', '1263348', '1263410', '1263427', '1268338', '1284314', '1285841', '1302809', '130666', '136817', '138501', '145359', '15187', '155788', '158168', '166036', '167585', '168757', '169165', '170147', '171629', '174203', '175103', '175966', '176038', '176244', '176301', '176305', '176674', '177606', '17876', '196080', '196356', '196364', '196447', '196986', '197158', '197392', '197463', '197737', '210013', '210926', '211578', '211602', '211942', '212486', '212518', '212527', '212632', '212897', '213722', '216390', '216650', '218498', '218708', '220289', '220492', '234205', '235670', '248234', '251155', '252527', '252859', '254779', '258768', '258844', '259539', '260505', '265930', '266441', '278101', '282599', '282878', '283965', '283966', '284102', '4773', '6380', '67182', '71258', '71625', '73618', '74257', '75825', '75884', '77618', '77907', '78084', '80672', '81631'))
 GROUP BY  Pitches.batter_id
-- GO
 OPTION(RECOMPILE) 
  SELECT  Agg.BatterId, Agg.ChasePercentage, Agg.SwingDecisionAgainstComponentGrade2080_Avg, Agg.SwingDecisionAgainstABSComponentGrade2080_Avg, Agg.SwingingStrikePercentage, Agg.SwingPercentage, Agg.WhiffPercentage, Agg.WhiffPercentage_InZone
 FROM 
#AGG AGG 
 WHERE 1=1 

 /** 7:Pitch **/
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
DROP TABLE IF EXISTS #AGG; DROP TABLE IF EXISTS #NTILE;
GO
DECLARE @Param0 varchar(1000) = '2025';
DECLARE @Param1 varchar(1000) = '2025';
-- DECLARE @Param2 varchar(1000) = 'L';
-- DECLARE @Param3 varchar(1000) = '13', '1', '2', '3', '4', '5', '20', '24';
-- DECLARE @Param4 varchar(1000) = 'r';
-- DECLARE @Param5 varchar(1000) = '106530', '106564', '106941', '107376', '107881', '110840', '116925', '12043', '1258422', '1263266', '1263291', '1263300', '1263308', '1263311', '1263348', '1263410', '1263427', '1268338', '1284314', '1285841', '1302809', '130666', '136817', '138501', '145359', '15187', '155788', '158168', '166036', '167585', '168757', '169165', '170147', '171629', '174203', '175103', '175966', '176038', '176244', '176301', '176305', '176674', '177606', '17876', '196080', '196356', '196364', '196447', '196986', '197158', '197392', '197463', '197737', '210013', '210926', '211578', '211602', '211942', '212486', '212518', '212527', '212632', '212897', '213722', '216390', '216650', '218498', '218708', '220289', '220492', '234205', '235670', '248234', '251155', '252527', '252859', '254779', '258768', '258844', '259539', '260505', '265930', '266441', '278101', '282599', '282878', '283965', '283966', '284102', '4773', '6380', '67182', '71258', '71625', '73618', '74257', '75825', '75884', '77618', '77907', '78084', '80672', '81631';

 SELECT  Pitches.batter_id as BatterId , avg(1.0 * case when Pitches.did_swing = 1 then case when Pitches.pitch_result_id not in (10,21,22,23) then 1 else 0 end else null end) as ContactPercentage
, sum(case when Pitches.did_swing = 1 and Pitches.pitch_result_id not in (10,21,22,23) then Pitches.called_strike_chance_mlb else null end)/nullif(sum(case when Pitches.did_swing = 1 then Pitches.called_strike_chance_mlb else null end),0) as ContactPercentage_InZone
, sum(case when Pitches.did_swing = 1 and Pitches.pitch_result_id not in (10,21,22,23) then 1 - Pitches.called_strike_chance_mlb else null end)/nullif(sum(1 - case when Pitches.did_swing = 1 then Pitches.called_strike_chance_mlb else null end),0) as ContactPercentage_OutZone
  INTO #AGG 
 FROM Astros.Pitches_View Pitches
 left join astros.schedule_view Schedule on Pitches.sched_id = Schedule.sched_id
 WHERE Schedule.year >= @Param0
 AND Schedule.year <= @Param1
 AND  (Pitches.pitcher_throws IN /** @Param2 **/ ('L')) AND  (Schedule.gc2_level_id IN /** @Param3 **/ ('13', '1', '2', '3', '4', '5', '20', '24')) AND  (Schedule.sched_type IN /** @Param4 **/ ('r')) AND  (Pitches.batter_id IN /** @Param5 **/ ('106530', '106564', '106941', '107376', '107881', '110840', '116925', '12043', '1258422', '1263266', '1263291', '1263300', '1263308', '1263311', '1263348', '1263410', '1263427', '1268338', '1284314', '1285841', '1302809', '130666', '136817', '138501', '145359', '15187', '155788', '158168', '166036', '167585', '168757', '169165', '170147', '171629', '174203', '175103', '175966', '176038', '176244', '176301', '176305', '176674', '177606', '17876', '196080', '196356', '196364', '196447', '196986', '197158', '197392', '197463', '197737', '210013', '210926', '211578', '211602', '211942', '212486', '212518', '212527', '212632', '212897', '213722', '216390', '216650', '218498', '218708', '220289', '220492', '234205', '235670', '248234', '251155', '252527', '252859', '254779', '258768', '258844', '259539', '260505', '265930', '266441', '278101', '282599', '282878', '283965', '283966', '284102', '4773', '6380', '67182', '71258', '71625', '73618', '74257', '75825', '75884', '77618', '77907', '78084', '80672', '81631'))
 AND Pitches.ignore_flag = 0 AND Pitches.pitch_id > 0
 GROUP BY  Pitches.batter_id
-- GO
 OPTION(RECOMPILE) 
  SELECT  Agg.BatterId, Agg.ContactPercentage, Agg.ContactPercentage_InZone, Agg.ContactPercentage_OutZone
 FROM 
#AGG AGG 
 WHERE 1=1 

 /** 7:Event **/
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
DROP TABLE IF EXISTS #AGG; DROP TABLE IF EXISTS #NTILE;
GO
DECLARE @Param0 varchar(1000) = '2025';
DECLARE @Param1 varchar(1000) = '2025';
-- DECLARE @Param2 varchar(1000) = 'L';
-- DECLARE @Param3 varchar(1000) = '13', '1', '2', '3', '4', '5', '20', '24';
-- DECLARE @Param4 varchar(1000) = 'r';
-- DECLARE @Param5 varchar(1000) = '106530', '106564', '106941', '107376', '107881', '110840', '116925', '12043', '1258422', '1263266', '1263291', '1263300', '1263308', '1263311', '1263348', '1263410', '1263427', '1268338', '1284314', '1285841', '1302809', '130666', '136817', '138501', '145359', '15187', '155788', '158168', '166036', '167585', '168757', '169165', '170147', '171629', '174203', '175103', '175966', '176038', '176244', '176301', '176305', '176674', '177606', '17876', '196080', '196356', '196364', '196447', '196986', '197158', '197392', '197463', '197737', '210013', '210926', '211578', '211602', '211942', '212486', '212518', '212527', '212632', '212897', '213722', '216390', '216650', '218498', '218708', '220289', '220492', '234205', '235670', '248234', '251155', '252527', '252859', '254779', '258768', '258844', '259539', '260505', '265930', '266441', '278101', '282599', '282878', '283965', '283966', '284102', '4773', '6380', '67182', '71258', '71625', '73618', '74257', '75825', '75884', '77618', '77907', '78084', '80672', '81631';

 SELECT  Pitches.batter_id as BatterId , avg(1.0 * case when Pitches.did_swing = 1 then case when Pitches.pitch_result_id not in (10,21,22,23) then 1 else 0 end else null end) as ContactPercentage
, sum(case when Pitches.did_swing = 1 and Pitches.pitch_result_id not in (10,21,22,23) then Pitches.called_strike_chance_mlb else null end)/nullif(sum(case when Pitches.did_swing = 1 then Pitches.called_strike_chance_mlb else null end),0) as ContactPercentage_InZone
, sum(case when Pitches.did_swing = 1 and Pitches.pitch_result_id not in (10,21,22,23) then 1 - Pitches.called_strike_chance_mlb else null end)/nullif(sum(1 - case when Pitches.did_swing = 1 then Pitches.called_strike_chance_mlb else null end),0) as ContactPercentage_OutZone
  INTO #AGG 
 FROM Astros.Events_View CurEvents
 left join astros.schedule_view Schedule on CurEvents.sched_id = Schedule.sched_id
 left join astros.pitches_view Pitches on CurEvents.sched_id = Pitches.sched_id and CurEvents.event_id = Pitches.cur_event_id
 WHERE Schedule.year >= @Param0
 AND Schedule.year <= @Param1
 AND  (Pitches.pitcher_throws IN /** @Param2 **/ ('L')) AND  (Schedule.gc2_level_id IN /** @Param3 **/ ('13', '1', '2', '3', '4', '5', '20', '24')) AND  (Schedule.sched_type IN /** @Param4 **/ ('r')) AND  (Pitches.batter_id IN /** @Param5 **/ ('106530', '106564', '106941', '107376', '107881', '110840', '116925', '12043', '1258422', '1263266', '1263291', '1263300', '1263308', '1263311', '1263348', '1263410', '1263427', '1268338', '1284314', '1285841', '1302809', '130666', '136817', '138501', '145359', '15187', '155788', '158168', '166036', '167585', '168757', '169165', '170147', '171629', '174203', '175103', '175966', '176038', '176244', '176301', '176305', '176674', '177606', '17876', '196080', '196356', '196364', '196447', '196986', '197158', '197392', '197463', '197737', '210013', '210926', '211578', '211602', '211942', '212486', '212518', '212527', '212632', '212897', '213722', '216390', '216650', '218498', '218708', '220289', '220492', '234205', '235670', '248234', '251155', '252527', '252859', '254779', '258768', '258844', '259539', '260505', '265930', '266441', '278101', '282599', '282878', '283965', '283966', '284102', '4773', '6380', '67182', '71258', '71625', '73618', '74257', '75825', '75884', '77618', '77907', '78084', '80672', '81631'))
 GROUP BY  Pitches.batter_id
-- GO
 OPTION(RECOMPILE) 
  SELECT  Agg.BatterId, Agg.ContactPercentage, Agg.ContactPercentage_InZone, Agg.ContactPercentage_OutZone
 FROM 
#AGG AGG 
 WHERE 1=1 

 /** 8:Pitch **/
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
DROP TABLE IF EXISTS #AGG; DROP TABLE IF EXISTS #NTILE;
GO
DECLARE @Param0 varchar(1000) = '2025';
DECLARE @Param1 varchar(1000) = '2025';
-- DECLARE @Param2 varchar(1000) = 'R';
-- DECLARE @Param3 varchar(1000) = '13', '1', '2', '3', '4', '5', '20', '24';
-- DECLARE @Param4 varchar(1000) = 'r';
-- DECLARE @Param5 varchar(1000) = '106530', '106564', '106941', '107376', '107881', '110840', '116925', '12043', '1258422', '1263266', '1263291', '1263300', '1263308', '1263311', '1263348', '1263410', '1263427', '1268338', '1284314', '1285841', '1302809', '130666', '136817', '138501', '145359', '15187', '155788', '158168', '166036', '167585', '168757', '169165', '170147', '171629', '174203', '175103', '175966', '176038', '176244', '176301', '176305', '176674', '177606', '17876', '196080', '196356', '196364', '196447', '196986', '197158', '197392', '197463', '197737', '210013', '210926', '211578', '211602', '211942', '212486', '212518', '212527', '212632', '212897', '213722', '216390', '216650', '218498', '218708', '220289', '220492', '234205', '235670', '248234', '251155', '252527', '252859', '254779', '258768', '258844', '259539', '260505', '265930', '266441', '278101', '282599', '282878', '283965', '283966', '284102', '4773', '6380', '67182', '71258', '71625', '73618', '74257', '75825', '75884', '77618', '77907', '78084', '80672', '81631';

 SELECT  Pitches.batter_id as BatterId , avg(1.0 * case when Pitches.did_swing = 1 then case when Pitches.pitch_result_id not in (10,21,22,23) then 1 else 0 end else null end) as ContactPercentage
, sum(case when Pitches.did_swing = 1 and Pitches.pitch_result_id not in (10,21,22,23) then Pitches.called_strike_chance_mlb else null end)/nullif(sum(case when Pitches.did_swing = 1 then Pitches.called_strike_chance_mlb else null end),0) as ContactPercentage_InZone
, sum(case when Pitches.did_swing = 1 and Pitches.pitch_result_id not in (10,21,22,23) then 1 - Pitches.called_strike_chance_mlb else null end)/nullif(sum(1 - case when Pitches.did_swing = 1 then Pitches.called_strike_chance_mlb else null end),0) as ContactPercentage_OutZone
  INTO #AGG 
 FROM Astros.Pitches_View Pitches
 left join astros.schedule_view Schedule on Pitches.sched_id = Schedule.sched_id
 WHERE Schedule.year >= @Param0
 AND Schedule.year <= @Param1
 AND  (Pitches.pitcher_throws IN /** @Param2 **/ ('R')) AND  (Schedule.gc2_level_id IN /** @Param3 **/ ('13', '1', '2', '3', '4', '5', '20', '24')) AND  (Schedule.sched_type IN /** @Param4 **/ ('r')) AND  (Pitches.batter_id IN /** @Param5 **/ ('106530', '106564', '106941', '107376', '107881', '110840', '116925', '12043', '1258422', '1263266', '1263291', '1263300', '1263308', '1263311', '1263348', '1263410', '1263427', '1268338', '1284314', '1285841', '1302809', '130666', '136817', '138501', '145359', '15187', '155788', '158168', '166036', '167585', '168757', '169165', '170147', '171629', '174203', '175103', '175966', '176038', '176244', '176301', '176305', '176674', '177606', '17876', '196080', '196356', '196364', '196447', '196986', '197158', '197392', '197463', '197737', '210013', '210926', '211578', '211602', '211942', '212486', '212518', '212527', '212632', '212897', '213722', '216390', '216650', '218498', '218708', '220289', '220492', '234205', '235670', '248234', '251155', '252527', '252859', '254779', '258768', '258844', '259539', '260505', '265930', '266441', '278101', '282599', '282878', '283965', '283966', '284102', '4773', '6380', '67182', '71258', '71625', '73618', '74257', '75825', '75884', '77618', '77907', '78084', '80672', '81631'))
 AND Pitches.ignore_flag = 0 AND Pitches.pitch_id > 0
 GROUP BY  Pitches.batter_id
-- GO
 OPTION(RECOMPILE) 
  SELECT  Agg.BatterId, Agg.ContactPercentage, Agg.ContactPercentage_InZone, Agg.ContactPercentage_OutZone
 FROM 
#AGG AGG 
 WHERE 1=1 

 /** 8:Event **/
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
DROP TABLE IF EXISTS #AGG; DROP TABLE IF EXISTS #NTILE;
GO
DECLARE @Param0 varchar(1000) = '2025';
DECLARE @Param1 varchar(1000) = '2025';
-- DECLARE @Param2 varchar(1000) = 'R';
-- DECLARE @Param3 varchar(1000) = '13', '1', '2', '3', '4', '5', '20', '24';
-- DECLARE @Param4 varchar(1000) = 'r';
-- DECLARE @Param5 varchar(1000) = '106530', '106564', '106941', '107376', '107881', '110840', '116925', '12043', '1258422', '1263266', '1263291', '1263300', '1263308', '1263311', '1263348', '1263410', '1263427', '1268338', '1284314', '1285841', '1302809', '130666', '136817', '138501', '145359', '15187', '155788', '158168', '166036', '167585', '168757', '169165', '170147', '171629', '174203', '175103', '175966', '176038', '176244', '176301', '176305', '176674', '177606', '17876', '196080', '196356', '196364', '196447', '196986', '197158', '197392', '197463', '197737', '210013', '210926', '211578', '211602', '211942', '212486', '212518', '212527', '212632', '212897', '213722', '216390', '216650', '218498', '218708', '220289', '220492', '234205', '235670', '248234', '251155', '252527', '252859', '254779', '258768', '258844', '259539', '260505', '265930', '266441', '278101', '282599', '282878', '283965', '283966', '284102', '4773', '6380', '67182', '71258', '71625', '73618', '74257', '75825', '75884', '77618', '77907', '78084', '80672', '81631';

 SELECT  Pitches.batter_id as BatterId , avg(1.0 * case when Pitches.did_swing = 1 then case when Pitches.pitch_result_id not in (10,21,22,23) then 1 else 0 end else null end) as ContactPercentage
, sum(case when Pitches.did_swing = 1 and Pitches.pitch_result_id not in (10,21,22,23) then Pitches.called_strike_chance_mlb else null end)/nullif(sum(case when Pitches.did_swing = 1 then Pitches.called_strike_chance_mlb else null end),0) as ContactPercentage_InZone
, sum(case when Pitches.did_swing = 1 and Pitches.pitch_result_id not in (10,21,22,23) then 1 - Pitches.called_strike_chance_mlb else null end)/nullif(sum(1 - case when Pitches.did_swing = 1 then Pitches.called_strike_chance_mlb else null end),0) as ContactPercentage_OutZone
  INTO #AGG 
 FROM Astros.Events_View CurEvents
 left join astros.schedule_view Schedule on CurEvents.sched_id = Schedule.sched_id
 left join astros.pitches_view Pitches on CurEvents.sched_id = Pitches.sched_id and CurEvents.event_id = Pitches.cur_event_id
 WHERE Schedule.year >= @Param0
 AND Schedule.year <= @Param1
 AND  (Pitches.pitcher_throws IN /** @Param2 **/ ('R')) AND  (Schedule.gc2_level_id IN /** @Param3 **/ ('13', '1', '2', '3', '4', '5', '20', '24')) AND  (Schedule.sched_type IN /** @Param4 **/ ('r')) AND  (Pitches.batter_id IN /** @Param5 **/ ('106530', '106564', '106941', '107376', '107881', '110840', '116925', '12043', '1258422', '1263266', '1263291', '1263300', '1263308', '1263311', '1263348', '1263410', '1263427', '1268338', '1284314', '1285841', '1302809', '130666', '136817', '138501', '145359', '15187', '155788', '158168', '166036', '167585', '168757', '169165', '170147', '171629', '174203', '175103', '175966', '176038', '176244', '176301', '176305', '176674', '177606', '17876', '196080', '196356', '196364', '196447', '196986', '197158', '197392', '197463', '197737', '210013', '210926', '211578', '211602', '211942', '212486', '212518', '212527', '212632', '212897', '213722', '216390', '216650', '218498', '218708', '220289', '220492', '234205', '235670', '248234', '251155', '252527', '252859', '254779', '258768', '258844', '259539', '260505', '265930', '266441', '278101', '282599', '282878', '283965', '283966', '284102', '4773', '6380', '67182', '71258', '71625', '73618', '74257', '75825', '75884', '77618', '77907', '78084', '80672', '81631'))
 GROUP BY  Pitches.batter_id
-- GO
 OPTION(RECOMPILE) 
  SELECT  Agg.BatterId, Agg.ContactPercentage, Agg.ContactPercentage_InZone, Agg.ContactPercentage_OutZone
 FROM 
#AGG AGG 
 WHERE 1=1 

 /** 9:Event **/
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
DROP TABLE IF EXISTS #AGG; DROP TABLE IF EXISTS #NTILE;
GO
DECLARE @Param0 varchar(1000) = '2025';
DECLARE @Param1 varchar(1000) = '2025';
-- DECLARE @Param2 varchar(1000) = 'L';
-- DECLARE @Param3 varchar(1000) = '13', '1', '2', '3', '4', '5', '20', '24';
-- DECLARE @Param4 varchar(1000) = 'r';
-- DECLARE @Param5 varchar(1000) = '106530', '106564', '106941', '107376', '107881', '110840', '116925', '12043', '1258422', '1263266', '1263291', '1263300', '1263308', '1263311', '1263348', '1263410', '1263427', '1268338', '1284314', '1285841', '1302809', '130666', '136817', '138501', '145359', '15187', '155788', '158168', '166036', '167585', '168757', '169165', '170147', '171629', '174203', '175103', '175966', '176038', '176244', '176301', '176305', '176674', '177606', '17876', '196080', '196356', '196364', '196447', '196986', '197158', '197392', '197463', '197737', '210013', '210926', '211578', '211602', '211942', '212486', '212518', '212527', '212632', '212897', '213722', '216390', '216650', '218498', '218708', '220289', '220492', '234205', '235670', '248234', '251155', '252527', '252859', '254779', '258768', '258844', '259539', '260505', '265930', '266441', '278101', '282599', '282878', '283965', '283966', '284102', '4773', '6380', '67182', '71258', '71625', '73618', '74257', '75825', '75884', '77618', '77907', '78084', '80672', '81631';

 SELECT  Pitches.batter_id as BatterId , sum(case when Pitches.pitch_result_id in (12, 13, 14) then isnull((1.0 - power(HitProbs.prob_hr, HitSpecsRatios.exp_hr)) * (power(HitProbs.prob_inf_1b + HitProbs.prob_of_1b, HitSpecsRatios.exp_1b) + power(HitProbs.prob_2b, HitSpecsRatios.exp_2b) + power(HitProbs.prob_3b, HitSpecsRatios.exp_3b)) / (power(HitProbs.prob_inf_1b + HitProbs.prob_of_1b, HitSpecsRatios.exp_1b) + power(HitProbs.prob_2b, HitSpecsRatios.exp_2b) + power(HitProbs.prob_3b, HitSpecsRatios.exp_3b) + power(HitProbs.prob_inf_out + HitProbs.prob_of_out + HitProbs.prob_inf_error + HitProbs.prob_of_error, HitSpecsRatios.exp_fo)) , cast(CurEvents.[1b] as float) + cast(CurEvents.[2b] as float) + cast(CurEvents.[3b] as float)) else null end) / nullif(sum(case when Pitches.pitch_result_id in (12,13,14) then isnull(1.0 - (power(HitProbs.prob_hr, HitSpecsRatios.exp_hr)), 1.0 - cast(CurEvents.hr as float)) else null end), 0) as xBABIP
, sum(case when CurEvents.bb = 1 or CurEvents.hbp = 1 then 1.0 when CurEvents.ab = 1 or CurEvents.sf = 1 then isnull((1.0 - power(HitProbs.prob_hr, HitSpecsRatios.exp_hr)) * (power(HitProbs.prob_inf_1b + HitProbs.prob_of_1b, HitSpecsRatios.exp_1b) + power(HitProbs.prob_2b, HitSpecsRatios.exp_2b) + power(HitProbs.prob_3b, HitSpecsRatios.exp_3b)) / (power(HitProbs.prob_inf_1b + HitProbs.prob_of_1b, HitSpecsRatios.exp_1b) + power(HitProbs.prob_2b, HitSpecsRatios.exp_2b) + power(HitProbs.prob_3b, HitSpecsRatios.exp_3b) + power(HitProbs.prob_inf_out + HitProbs.prob_of_out + HitProbs.prob_inf_error + HitProbs.prob_of_error, HitSpecsRatios.exp_fo)) + (power(HitProbs.prob_hr, HitSpecsRatios.exp_hr)) , cast(CurEvents.[1b] as float) + cast(CurEvents.[2b] as float) + cast(CurEvents.[3b] as float) + cast(CurEvents.[hr] as float)) else null end) / nullif(sum(cast(CurEvents.ab as int) + cast(CurEvents.bb as int) + cast(CurEvents.hbp as int) + coalesce(cast(CurEvents.sf as int), 0)), 0) as xOBP
, avg(case when CurEvents.ab = 1 or CurEvents.sf = 1 then isnull((1.0 - power(HitProbs.prob_hr, HitSpecsRatios.exp_hr)) * (power(HitProbs.prob_inf_1b + HitProbs.prob_of_1b, HitSpecsRatios.exp_1b) + power(HitProbs.prob_2b, HitSpecsRatios.exp_2b) * 2 + power(HitProbs.prob_3b, HitSpecsRatios.exp_3b) * 3) / (power(HitProbs.prob_inf_1b + HitProbs.prob_of_1b, HitSpecsRatios.exp_1b) + power(HitProbs.prob_2b, HitSpecsRatios.exp_2b) + power(HitProbs.prob_3b, HitSpecsRatios.exp_3b) + power(HitProbs.prob_inf_out + HitProbs.prob_of_out + HitProbs.prob_inf_error + HitProbs.prob_of_error, HitSpecsRatios.exp_fo)) + (power(HitProbs.prob_hr, HitSpecsRatios.exp_hr) * 4) , cast(CurEvents.[1b] as float) + cast(CurEvents.[2b] as float) * 2 + cast(CurEvents.[3b] as float) * 3 + cast(CurEvents.hr as float) * 4) else null end) as xSLG
, sum(case when CurEvents.bb = 1 or CurEvents.hbp = 1 then 1.0 * Woba.woba_bb when CurEvents.ab = 1 or CurEvents.sf = 1 then isnull((1.0 - power(HitProbs.prob_hr, HitSpecsRatios.exp_hr)) * (power(HitProbs.prob_inf_1b + HitProbs.prob_of_1b, HitSpecsRatios.exp_1b) * Woba.woba_1b + power(HitProbs.prob_2b, HitSpecsRatios.exp_2b) * Woba.woba_2b + power(HitProbs.prob_3b, HitSpecsRatios.exp_3b) * Woba.woba_3b) / (power(HitProbs.prob_inf_1b + HitProbs.prob_of_1b, HitSpecsRatios.exp_1b) + power(HitProbs.prob_2b, HitSpecsRatios.exp_2b) + power(HitProbs.prob_3b, HitSpecsRatios.exp_3b) + power(HitProbs.prob_inf_out + HitProbs.prob_of_out + HitProbs.prob_inf_error + HitProbs.prob_of_error, HitSpecsRatios.exp_fo)) + (power(HitProbs.prob_hr, HitSpecsRatios.exp_hr) * Woba.woba_hr) , cast(CurEvents.[1b] as float) * Woba.woba_1b + cast(CurEvents.[2b] as float) * Woba.woba_2b + cast(CurEvents.[3b] as float) * Woba.woba_3b + cast(CurEvents.[hr] as float) * Woba.woba_hr) else null end) / nullif(sum(cast(CurEvents.ab as int) + cast(CurEvents.bb as int) + cast(CurEvents.hbp as int) + coalesce(cast(CurEvents.sf as int), 0)), 0) as xwOBA
  INTO #AGG 
 FROM Astros.Events_View CurEvents
 left join astros.schedule_view Schedule on CurEvents.sched_id = Schedule.sched_id
  left join guts.hit_specs_ratios HitSpecsRatios on Schedule.year = HitSpecsRatios.season
 left join mlbam.schedule MlbamSchedule on Schedule.mlbam_game_pk = MlbamSchedule.game_pk
  left join guts.woba_lwts Woba on MlbamSchedule.year = Woba.year and MlbamSchedule.league = Woba.league
 left join astros.pitches_view Pitches on CurEvents.sched_id = Pitches.sched_id and CurEvents.event_id = Pitches.cur_event_id
  left join astros.hits_probabilities HitProbs on Pitches.sched_id = HitProbs.sched_id and Pitches.pitch_id = HitProbs.pitch_id and HitProbs.actual_shift = 1
 WHERE Schedule.year >= @Param0
 AND Schedule.year <= @Param1
 AND  (Pitches.pitcher_throws IN /** @Param2 **/ ('L')) AND  (Schedule.gc2_level_id IN /** @Param3 **/ ('13', '1', '2', '3', '4', '5', '20', '24')) AND  (Schedule.sched_type IN /** @Param4 **/ ('r')) AND  (Pitches.batter_id IN /** @Param5 **/ ('106530', '106564', '106941', '107376', '107881', '110840', '116925', '12043', '1258422', '1263266', '1263291', '1263300', '1263308', '1263311', '1263348', '1263410', '1263427', '1268338', '1284314', '1285841', '1302809', '130666', '136817', '138501', '145359', '15187', '155788', '158168', '166036', '167585', '168757', '169165', '170147', '171629', '174203', '175103', '175966', '176038', '176244', '176301', '176305', '176674', '177606', '17876', '196080', '196356', '196364', '196447', '196986', '197158', '197392', '197463', '197737', '210013', '210926', '211578', '211602', '211942', '212486', '212518', '212527', '212632', '212897', '213722', '216390', '216650', '218498', '218708', '220289', '220492', '234205', '235670', '248234', '251155', '252527', '252859', '254779', '258768', '258844', '259539', '260505', '265930', '266441', '278101', '282599', '282878', '283965', '283966', '284102', '4773', '6380', '67182', '71258', '71625', '73618', '74257', '75825', '75884', '77618', '77907', '78084', '80672', '81631'))
 GROUP BY  Pitches.batter_id
-- GO
 OPTION(RECOMPILE) 
  SELECT  Agg.BatterId, Agg.xBABIP, Agg.xOBP, Agg.xSLG, Agg.xwOBA
 FROM 
#AGG AGG 
 WHERE 1=1 

 /** 10:Event **/
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
--[noformat]
DROP TABLE IF EXISTS #AGG; DROP TABLE IF EXISTS #NTILE;
GO
DECLARE @Param0 varchar(1000) = '2025';
DECLARE @Param1 varchar(1000) = '2025';
-- DECLARE @Param2 varchar(1000) = 'R';
-- DECLARE @Param3 varchar(1000) = '13', '1', '2', '3', '4', '5', '20', '24';
-- DECLARE @Param4 varchar(1000) = 'r';
-- DECLARE @Param5 varchar(1000) = '106530', '106564', '106941', '107376', '107881', '110840', '116925', '12043', '1258422', '1263266', '1263291', '1263300', '1263308', '1263311', '1263348', '1263410', '1263427', '1268338', '1284314', '1285841', '1302809', '130666', '136817', '138501', '145359', '15187', '155788', '158168', '166036', '167585', '168757', '169165', '170147', '171629', '174203', '175103', '175966', '176038', '176244', '176301', '176305', '176674', '177606', '17876', '196080', '196356', '196364', '196447', '196986', '197158', '197392', '197463', '197737', '210013', '210926', '211578', '211602', '211942', '212486', '212518', '212527', '212632', '212897', '213722', '216390', '216650', '218498', '218708', '220289', '220492', '234205', '235670', '248234', '251155', '252527', '252859', '254779', '258768', '258844', '259539', '260505', '265930', '266441', '278101', '282599', '282878', '283965', '283966', '284102', '4773', '6380', '67182', '71258', '71625', '73618', '74257', '75825', '75884', '77618', '77907', '78084', '80672', '81631';

 SELECT  Pitches.batter_id as BatterId , sum(case when Pitches.pitch_result_id in (12, 13, 14) then isnull((1.0 - power(HitProbs.prob_hr, HitSpecsRatios.exp_hr)) * (power(HitProbs.prob_inf_1b + HitProbs.prob_of_1b, HitSpecsRatios.exp_1b) + power(HitProbs.prob_2b, HitSpecsRatios.exp_2b) + power(HitProbs.prob_3b, HitSpecsRatios.exp_3b)) / (power(HitProbs.prob_inf_1b + HitProbs.prob_of_1b, HitSpecsRatios.exp_1b) + power(HitProbs.prob_2b, HitSpecsRatios.exp_2b) + power(HitProbs.prob_3b, HitSpecsRatios.exp_3b) + power(HitProbs.prob_inf_out + HitProbs.prob_of_out + HitProbs.prob_inf_error + HitProbs.prob_of_error, HitSpecsRatios.exp_fo)) , cast(CurEvents.[1b] as float) + cast(CurEvents.[2b] as float) + cast(CurEvents.[3b] as float)) else null end) / nullif(sum(case when Pitches.pitch_result_id in (12,13,14) then isnull(1.0 - (power(HitProbs.prob_hr, HitSpecsRatios.exp_hr)), 1.0 - cast(CurEvents.hr as float)) else null end), 0) as xBABIP
, sum(case when CurEvents.bb = 1 or CurEvents.hbp = 1 then 1.0 when CurEvents.ab = 1 or CurEvents.sf = 1 then isnull((1.0 - power(HitProbs.prob_hr, HitSpecsRatios.exp_hr)) * (power(HitProbs.prob_inf_1b + HitProbs.prob_of_1b, HitSpecsRatios.exp_1b) + power(HitProbs.prob_2b, HitSpecsRatios.exp_2b) + power(HitProbs.prob_3b, HitSpecsRatios.exp_3b)) / (power(HitProbs.prob_inf_1b + HitProbs.prob_of_1b, HitSpecsRatios.exp_1b) + power(HitProbs.prob_2b, HitSpecsRatios.exp_2b) + power(HitProbs.prob_3b, HitSpecsRatios.exp_3b) + power(HitProbs.prob_inf_out + HitProbs.prob_of_out + HitProbs.prob_inf_error + HitProbs.prob_of_error, HitSpecsRatios.exp_fo)) + (power(HitProbs.prob_hr, HitSpecsRatios.exp_hr)) , cast(CurEvents.[1b] as float) + cast(CurEvents.[2b] as float) + cast(CurEvents.[3b] as float) + cast(CurEvents.[hr] as float)) else null end) / nullif(sum(cast(CurEvents.ab as int) + cast(CurEvents.bb as int) + cast(CurEvents.hbp as int) + coalesce(cast(CurEvents.sf as int), 0)), 0) as xOBP
, avg(case when CurEvents.ab = 1 or CurEvents.sf = 1 then isnull((1.0 - power(HitProbs.prob_hr, HitSpecsRatios.exp_hr)) * (power(HitProbs.prob_inf_1b + HitProbs.prob_of_1b, HitSpecsRatios.exp_1b) + power(HitProbs.prob_2b, HitSpecsRatios.exp_2b) * 2 + power(HitProbs.prob_3b, HitSpecsRatios.exp_3b) * 3) / (power(HitProbs.prob_inf_1b + HitProbs.prob_of_1b, HitSpecsRatios.exp_1b) + power(HitProbs.prob_2b, HitSpecsRatios.exp_2b) + power(HitProbs.prob_3b, HitSpecsRatios.exp_3b) + power(HitProbs.prob_inf_out + HitProbs.prob_of_out + HitProbs.prob_inf_error + HitProbs.prob_of_error, HitSpecsRatios.exp_fo)) + (power(HitProbs.prob_hr, HitSpecsRatios.exp_hr) * 4) , cast(CurEvents.[1b] as float) + cast(CurEvents.[2b] as float) * 2 + cast(CurEvents.[3b] as float) * 3 + cast(CurEvents.hr as float) * 4) else null end) as xSLG
, sum(case when CurEvents.bb = 1 or CurEvents.hbp = 1 then 1.0 * Woba.woba_bb when CurEvents.ab = 1 or CurEvents.sf = 1 then isnull((1.0 - power(HitProbs.prob_hr, HitSpecsRatios.exp_hr)) * (power(HitProbs.prob_inf_1b + HitProbs.prob_of_1b, HitSpecsRatios.exp_1b) * Woba.woba_1b + power(HitProbs.prob_2b, HitSpecsRatios.exp_2b) * Woba.woba_2b + power(HitProbs.prob_3b, HitSpecsRatios.exp_3b) * Woba.woba_3b) / (power(HitProbs.prob_inf_1b + HitProbs.prob_of_1b, HitSpecsRatios.exp_1b) + power(HitProbs.prob_2b, HitSpecsRatios.exp_2b) + power(HitProbs.prob_3b, HitSpecsRatios.exp_3b) + power(HitProbs.prob_inf_out + HitProbs.prob_of_out + HitProbs.prob_inf_error + HitProbs.prob_of_error, HitSpecsRatios.exp_fo)) + (power(HitProbs.prob_hr, HitSpecsRatios.exp_hr) * Woba.woba_hr) , cast(CurEvents.[1b] as float) * Woba.woba_1b + cast(CurEvents.[2b] as float) * Woba.woba_2b + cast(CurEvents.[3b] as float) * Woba.woba_3b + cast(CurEvents.[hr] as float) * Woba.woba_hr) else null end) / nullif(sum(cast(CurEvents.ab as int) + cast(CurEvents.bb as int) + cast(CurEvents.hbp as int) + coalesce(cast(CurEvents.sf as int), 0)), 0) as xwOBA
  INTO #AGG 
 FROM Astros.Events_View CurEvents
 left join astros.schedule_view Schedule on CurEvents.sched_id = Schedule.sched_id
  left join guts.hit_specs_ratios HitSpecsRatios on Schedule.year = HitSpecsRatios.season
 left join mlbam.schedule MlbamSchedule on Schedule.mlbam_game_pk = MlbamSchedule.game_pk
  left join guts.woba_lwts Woba on MlbamSchedule.year = Woba.year and MlbamSchedule.league = Woba.league
 left join astros.pitches_view Pitches on CurEvents.sched_id = Pitches.sched_id and CurEvents.event_id = Pitches.cur_event_id
  left join astros.hits_probabilities HitProbs on Pitches.sched_id = HitProbs.sched_id and Pitches.pitch_id = HitProbs.pitch_id and HitProbs.actual_shift = 1
 WHERE Schedule.year >= @Param0
 AND Schedule.year <= @Param1
 AND  (Pitches.pitcher_throws IN /** @Param2 **/ ('R')) AND  (Schedule.gc2_level_id IN /** @Param3 **/ ('13', '1', '2', '3', '4', '5', '20', '24')) AND  (Schedule.sched_type IN /** @Param4 **/ ('r')) AND  (Pitches.batter_id IN /** @Param5 **/ ('106530', '106564', '106941', '107376', '107881', '110840', '116925', '12043', '1258422', '1263266', '1263291', '1263300', '1263308', '1263311', '1263348', '1263410', '1263427', '1268338', '1284314', '1285841', '1302809', '130666', '136817', '138501', '145359', '15187', '155788', '158168', '166036', '167585', '168757', '169165', '170147', '171629', '174203', '175103', '175966', '176038', '176244', '176301', '176305', '176674', '177606', '17876', '196080', '196356', '196364', '196447', '196986', '197158', '197392', '197463', '197737', '210013', '210926', '211578', '211602', '211942', '212486', '212518', '212527', '212632', '212897', '213722', '216390', '216650', '218498', '218708', '220289', '220492', '234205', '235670', '248234', '251155', '252527', '252859', '254779', '258768', '258844', '259539', '260505', '265930', '266441', '278101', '282599', '282878', '283965', '283966', '284102', '4773', '6380', '67182', '71258', '71625', '73618', '74257', '75825', '75884', '77618', '77907', '78084', '80672', '81631'))
 GROUP BY  Pitches.batter_id
-- GO
 OPTION(RECOMPILE) 
  SELECT  Agg.BatterId, Agg.xBABIP, Agg.xOBP, Agg.xSLG, Agg.xwOBA
 FROM 
#AGG AGG 
 WHERE 1=1 

