declare @proj_year int
declare @rar_year int
declare @value int
-- This is to make changes depending where the season is at and when to consider projections.
-- If it's April 2024, I want to see proj >= 2024 and only consider < 2024 RAR.
-- If it's August 2024, I want too proj > 2024 and only consider <= 2024 RAR.
set @proj_year = 2025 -- Only care about >= 2025 projections
set @rar_year = 2024  -- Only consider RAR from <= 2024
set @value = 1119543

----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- RAR Value for Historical RAR 

drop table if exists #dollar_rar
select *
into #dollar_rar
from
Player_Val.Dollar_Per_WAR 

insert into 
#dollar_rar
(start_year, smoothed_dollar_per_RAR, smoothed_dollar_per_WAR)
values
(2011, 961908, 8922322),
(2012, 961908, 8922322),
(2013, 961908, 8922322),
(2014, 961908, 8922322),
(2025, 1119543, 11006472),
(2026, 1119543, 11006472),
(2027, 1119543, 11006472),
(2028, 1119543, 11006472),
(2029, 1119543, 11006472),
(2030, 1119543, 11006472),
(2031, 1119543, 11006472),
(2032, 1119543, 11006472),
(2033, 1119543, 11006472)

--select * from #dollar_rar order by start_year asc
--------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Historical RAR - Hitters

drop table if exists #rar_h
select 
b.groundcontrol_id,
b.team_id,
b.year,
round(b.rar,1) as rar,
round(b.mle_orp,1) as mle_orp,
round(b.drs,1) as drs,
round(b.war,1) as war,
round(rar*r.smoothed_dollar_per_RAR,2) as dollar_per_rar
into #rar_h
from
proj.Batting_MLEs b
left join #dollar_rar r on r.start_year = b.year
left join astros.players a on a.groundcontrol_id = b.groundcontrol_id
left join MLB_eBis.PP_MASTER pp on pp.PLAYER_ID = a.ebis_id
where
b.pitcher_throws = '-'
and b.team_id between 108 and 158
and b.year <= @rar_year
and b.year >= RULE51STYRELG and b.year <= RULE51STYRELG + 6
and pp.POSITION_LK in ('NULL','1B','2B','3B','BAT','C','CF','DH','IF','LF','OF','PH','RF','SS','UN','UTL')
--and b.groundcontrol_id = 17876
order by
year desc

--select * from proj.Batting_MLEs where groundcontrol_id = 17876 and pitcher_throws = '-' and team_id between 108 and 158
--select * from #rar_h where groundcontrol_id = 71160
---------------------------------------------
-- Historical RAR - Batting Aggregated
---------------------------------------------
drop table if exists #rar_hitters
select 
groundcontrol_id,
sum(rar) as rar,
sum(dollar_per_rar) as sum_dollars_per_rar,
--sum(mle_orp) as mle_orp,
--sum(drs) as drs,
sum(war) as war
into #rar_hitters
from 
#rar_h
group by
groundcontrol_id

--select * from #rar_hitters where groundcontrol_id = 71160

--------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Historical RAR - Pitchers

drop table if exists #rar_p
select
p.groundcontrol_id,
p.team_id,
p.year,
p.tbf,
round(p.mle_prs,1) as prs,
round(p.rar,1) as rar,
round(p.war,1) as war,
round(p.rar*r.smoothed_dollar_per_RAR,2) as dollar_per_rar
into #rar_p
from 
proj.Pitching_MLEs p
left join #dollar_rar r on r.start_year = p.year
left join astros.players a on a.groundcontrol_id = p.groundcontrol_id
left join MLB_eBis.PP_MASTER pp on pp.PLAYER_ID = a.ebis_id
where
p.bat_side = '-'
and p.role = '--'
and p.team_id between 108 and 158
and p.year <= @rar_year
and p.year >= RULE51STYRELG and p.year <= RULE51STYRELG + 6
and pp.POSITION_LK in ('NULL','LHP','LHR','LHS','P','RHP','RHR','RHS','SHS','TWP')
--and p.groundcontrol_id = 32898

--select * from #rar_p where groundcontrol_id = 71160

---------------------------------------------
-- Historical RAR - Pitching Aggregated
---------------------------------------------

drop table if exists #rar_pitchers
select 
groundcontrol_id,
--sum(tbf) as tbf,
--sum(prs) as prs,
sum(rar) as rar,
sum(dollar_per_rar) as sum_dollars_per_rar,
sum(war) as war
into #rar_pitchers
from 
#rar_p
group by
groundcontrol_id

--select * from #rar_pitchers where groundcontrol_id = 71160

--------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Historial RAR - Combined Pitchers and Hitters

drop table if exists #rar
select * into #rar from #rar_hitters
union
select * from #rar_pitchers

--select * from #rar where groundcontrol_id = 71267 order by rar desc


--------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Asset Value - Proj RAR - Historical RAR Queries

--select * from #av order by asset_value desc
--select * from #proj_rar order by proj_rar desc
--select * from #rar order by rar desc

--------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Intl Players - Asset Value - Proj RAR - Historical RAR Queries

drop table if exists #master
select
a.groundcontrol_id,
a.first_name + ' ' + a.last_name as player,
cast(i.birth_date as date) as birth_date,
cast(datediff(dayofyear, i.birth_date, getdate())/365.25 as decimal(3,1)) as age,
i.school_name,
i.school_type,
i.school_state,
i.school_level,
i.signed,
i.draft_year,
i.draft_round,
i.pick_in_round,
i.overall_pick,
case
when i.draft_org = 'NY' then 'NYM'
else i.draft_org end as signing_org,
i.signing_bonus,
left(round(i.age_at_draft,2),4) as draft_age,
i.position,
--case when i.top_level = 'MLB' then 1 else 0 end as mlb_product,
rar.rar as real_rar,
case
when rar.rar <= 0.0 then 0.0
when rar.rar is null then 0.0
else rar.rar end as accrued_rar,
rar.sum_dollars_per_rar,
@value as rar_value,
left(cast(rar.rar as int) / nullif(i.signing_bonus,0),10) as rar_per_signing_bonus
into #master
from
mlb_ebis.R4_Draft_Query i
join astros.players a on a.ebis_id = i.PLAYER_ID

left join #rar rar on rar.groundcontrol_id = a.groundcontrol_id
where 

a.groundcontrol_id not in (82125)
--and a.groundcontrol_id in (71160)

select  m.draft_year, m.draft_round, m.pick_in_round,  m.overall_pick,
 m.groundcontrol_id, m.player, m.position, pp.POSITION_LK as pro_pos, m.school_name, m.school_type, m.school_state, m.school_level, 
m.signing_org, m.signing_bonus, m.draft_age, m.signed,
m.age,
debut.debut_team, debut.debut_year, m.accrued_rar
from #master m
left join (select 
groundcontrol_id,
 avg(athleticism_grade) as avg_ath_grade
from scout.Reports_Full_Hitting_View
where report_year >= 2012 and report_market_id = 1 
group by groundcontrol_id) r on m.groundcontrol_id = r.groundcontrol_id
left join (select Player_id, groundcontrol_id, FIRSTMJLGACQUISITIONORG_LK as debut_team, year(FIRSTMJLGACQUISITION_DTE) as debut_year 
from mlb_ebis.pp_playerdata s
left join astros.players p on p.ebis_id = s.PLAYER_ID) debut on debut.groundcontrol_id = m.groundcontrol_id
left join mlb_ebis.pp_master pp on pp.PLAYER_ID = debut.PLAYER_ID
where
draft_year >= 2012

order by accrued_rar desc;



--select * from MLB_eBis.R4_Draft_Query where groundcontrol_id = 72603