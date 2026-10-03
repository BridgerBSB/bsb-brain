-- Hitters

select 
bat.player, 
bat.org, 
bat.level, 
bat.age, 
bat.pa, 
bat.Act_ORP, bat.SA_HS_ORP, bat.MLE_ORP, bat.MLE_OBP, bat.MLE_SLG, bat.MLE_OPS,
bat.pRAR, bat.pORP, 
bat.age_percentile, bat.pRAR_percentile, bat.pORP_percentile, bat.PA_percentile, bat.MLE_OPS_percentile, 
(bat.age_percentile + bat.pRAR_percentile + bat.pORP_percentile + bat.PA_percentile + bat.MLE_OPS_percentile) / 5 as promo_press

from
(
select 
p.first_name + ' ' + p.last_name as Player, 
pp.org_lk as Org,
pp.levelofplay_lk as Level, 
dbo.getage_decimal(p.birthdate, getdate()) as Age,
m.PA,
cast(m.act_orp as decimal(15,1)) as Act_ORP,
cast(m.sa_hs_orp as decimal(15,1)) as SA_HS_ORP, 
cast(m.mle_orp as decimal(15,1)) as MLE_ORP,
cast(m.obp as decimal(15,3)) as MLE_OBP,
cast(m.slg as decimal(15,3)) as MLE_SLG,
cast(m.ops as decimal(15,3)) as MLE_OPS,
cast(b.proj_rar as decimal(15,1)) as pRAR,
cast(b.proj_orp_650 as decimal(15,1)) as pORP,
 
ntile(100) over (partition by pp.levelofplay_lk order by dbo.getage_decimal(p.birthdate,getdate())) as age_percentile, 
ntile(100) over (partition by pp.levelofplay_lk order by b.proj_rar) as pRAR_percentile, 
ntile(100) over (partition by pp.levelofplay_lk order by b.proj_orp_650) as pORP_percentile,
ntile(100) over (partition by pp.levelofplay_lk order by m.pa) as PA_percentile, 
ntile(100) over (partition by pp.levelofplay_lk order by m.ops) as MLE_OPS_percentile

from 
astros.players p 
join MLB_eBis.pp_master pp on p.ebis_id = pp.player_id
join proj.batting b on p.groundcontrol_id = b.groundcontrol_id and b.year = year(getdate()) and b.year_generated = b.year
left join (select bm.groundcontrol_id,
case when t.sport_code = 'mlb' then 'ml' when t.sport_code = 'aaa' then '3a' when t.sport_code = 'aax' then '2a' when t.sport_code = 'afa' then '1a' when t.sport_code = 'afx' then '1f' when t.sport_code = 'rok' then 'r' else null end as sport_code,
sum(bm.pa) as PA, sum(bm.act_orp) as act_orp, sum(bm.spd_adj_hs_orp) as sa_hs_orp, sum(bm.mle_orp) as mle_orp, 
sum((bm.mle_1b + bm.mle_2b + bm.mle_3b + bm.mle_hr + bm.mle_bb) * bm.pa) / nullif(sum(bm.pa),0) as OBP,
sum((bm.mle_1b+bm.mle_2b*2+bm.mle_3b*3+bm.mle_hr*4)*bm.pa)/nullif(sum(bm.pa*(1.0-bm.mle_bb)),0) as SLG, 
sum((bm.mle_1b + bm.mle_2b + bm.mle_3b + bm.mle_hr + bm.mle_bb) * bm.pa) / nullif(sum(bm.pa),0) + sum((bm.mle_1b+bm.mle_2b*2+bm.mle_3b*3+bm.mle_hr*4)*bm.pa)/nullif(sum(bm.pa*(1.0-bm.mle_bb)),0) as OPS

from 
proj.batting_mles bm
join mlbam.teams t on t.season = bm.year and t.team_id = bm.team_id

where 
bm.year >= 2022 
and bm.pitcher_throws = '-'

group by 
bm.groundcontrol_id, 
case when t.sport_code = 'mlb' then 'ml' when t.sport_code = 'aaa' then '3a' when t.sport_code = 'aax' then '2a' when t.sport_code = 'afa' then '1a' when t.sport_code = 'afx' then '1f' when t.sport_code = 'rok' then 'r' else null end
) m on p.groundcontrol_id = m.groundcontrol_id and m.sport_code = pp.levelofplay_lk


where showonroster_flg = 1  
and pp.org_lk is not null

) bat

--where
--level = '1a'
--org = 'hou' 

order by --Org asc, 
case when Level = 'ML' then 1 when level = '3a' then 2 when level = '2a' then 3 when level = '1a' then 4 when level = '1f' then 5 when level = 'r' then 6 end asc, 
promo_press desc;



-- MLB Hitters 

select bm.groundcontrol_id, p.first_name + ' ' + p.last_name as player,
case when t.sport_code = 'mlb' then 'ml' when t.sport_code = 'aaa' then '3a' when t.sport_code = 'aax' then '2a' when t.sport_code = 'afa' then '1a' when t.sport_code = 'afx' then '1f' when t.sport_code = 'asx' then 'A-' when t.sport_code = 'rok' then 'r' else null end as sport_code,
sum(bm.pa) as PA, cast(sum(bm.act_orp) as decimal(15,1)) as act_orp, cast(sum(bm.spd_adj_hs_orp) as decimal(15,1)) as sa_hs_orp, cast(sum(bm.mle_orp) as decimal(15,1)) as mle_orp, 
cast(sum((bm.mle_1b + bm.mle_2b + bm.mle_3b + bm.mle_hr + bm.mle_bb) * bm.pa) / nullif(sum(bm.pa),0) as decimal(15,3)) as MLE_OBP,
cast(sum((bm.mle_1b+bm.mle_2b*2+bm.mle_3b*3+bm.mle_hr*4)*bm.pa)/nullif(sum(bm.pa*(1.0-bm.mle_bb)),0) as decimal(15,3)) as MLE_SLG, 
cast(sum((bm.mle_1b + bm.mle_2b + bm.mle_3b + bm.mle_hr + bm.mle_bb) * bm.pa) / nullif(sum(bm.pa),0) + sum((bm.mle_1b+bm.mle_2b*2+bm.mle_3b*3+bm.mle_hr*4)*bm.pa)/nullif(sum(bm.pa*(1.0-bm.mle_bb)),0) as decimal(15,3)) as MLE_OPS

from 
proj.batting_mles bm
join astros.players p on bm.groundcontrol_id = p.groundcontrol_id 
join mlbam.teams t on t.season = bm.year and t.team_id = bm.team_id 
join mlbam.rosters r on p.mlbam_id = r.player_id

where 
bm.year >= 2008
and bm.pitcher_throws = '-' 
and r.sport_code = 'mlb' and r.status_code = 'a' and r.primary_position != '1' 

group by 
bm.groundcontrol_id, p.first_name + ' ' + p.last_name,
case when t.sport_code = 'mlb' then 'ml' when t.sport_code = 'aaa' then '3a' when t.sport_code = 'aax' then '2a' when t.sport_code = 'afa' then '1a' when t.sport_code = 'afx' then '1f' when t.sport_code = 'asx' then 'A-' when t.sport_code = 'rok' then 'r' else null end 

order by 
groundcontrol_id asc; 

-- Pitchers

select 
pit.player, 
pit.org, 
pit.level,
pit.role,
pit.age, 
pit.TBF, 
pit.Act_PRS, pit.HS_PRS, pit.MLE_PRS, pit.[MLE_FIP-],
pit.pRAR, pit.pPRS, 
pit.age_percentile, pit.pRAR_percentile, pit.pPRS_percentile, pit.TBF_percentile, pit.MLE_FIPm_percentile, 
(pit.age_percentile + pit.pRAR_percentile + pit.pPRS_percentile + pit.TBF_percentile + pit.MLE_FIPm_percentile) / 5 as promo_press

from
(
select 
p.first_name + ' ' + p.last_name as Player, 
pp.org_lk as Org,
pp.levelofplay_lk as Level, 
pit.role, 
dbo.getage_decimal(p.birthdate, getdate()) as Age,
m.TBF,
cast(m.act_prs as decimal(15,1)) as Act_PRS,
cast(m.hs_prs as decimal(15,1)) as HS_PRS, 
cast(m.mle_prs as decimal(15,1)) as MLE_PRS,
cast(m.obp as decimal(15,3)) as MLE_OBP,
cast(m.slg as decimal(15,3)) as MLE_SLG,
cast(m.ops as decimal(15,3)) as MLE_OPS,
cast(m.FIPm as decimal(15,1)) as [MLE_FIP-], 
cast(pit.proj_rar as decimal(15,1)) as pRAR,
cast(pit.proj_prs as decimal(15,1)) as pPRS,
 

ntile(100) over (partition by pp.levelofplay_lk, pit.role order by dbo.getage_decimal(p.birthdate,getdate())) as age_percentile, 
ntile(100) over (partition by pp.levelofplay_lk, pit.role order by pit.proj_rar) as pRAR_percentile, 
ntile(100) over (partition by pp.levelofplay_lk, pit.role order by pit.proj_prs) as pPRS_percentile,
ntile(100) over (partition by pp.levelofplay_lk, pit.role order by m.tbf) as TBF_percentile, 
ntile(100) over (partition by pp.levelofplay_lk, pit.role order by m.FIPm desc) as MLE_FIPm_percentile


from 
astros.players p 
join MLB_eBis.pp_master pp on p.ebis_id = pp.player_id
join proj.pitching pit on p.groundcontrol_id = pit.groundcontrol_id and pit.year = year(getdate()) and pit.year_generated = pit.year and pit.prop_role >= 0.5
left join (select pm.groundcontrol_id,
case when t.sport_code = 'mlb' then 'ml' when t.sport_code = 'aaa' then '3a' when t.sport_code = 'aax' then '2a' when t.sport_code = 'afa' then '1a' when t.sport_code = 'afx' then '1f' when t.sport_code = 'rok' then 'r' else null end as sport_code,
sum(pm.tbf) as TBF, sum(pm.act_prs) as act_prs, sum(pm.hs_prs) as hs_prs, sum(pm.mle_prs) as mle_prs, 
sum((pm.mle_1b + pm.mle_2b + pm.mle_3b + pm.mle_hr + pm.mle_bb) * pm.tbf) / nullif(sum(pm.tbf),0) as OBP,
sum((pm.mle_1b+pm.mle_2b*2+pm.mle_3b*3+pm.mle_hr*4)*pm.tbf)/nullif(sum(pm.tbf*(1.0-pm.mle_bb)),0) as SLG, 
sum((pm.mle_1b + pm.mle_2b + pm.mle_3b + pm.mle_hr + pm.mle_bb) * pm.tbf) / nullif(sum(pm.tbf),0) + sum((pm.mle_1b+pm.mle_2b*2+pm.mle_3b*3+pm.mle_hr*4)*pm.tbf)/nullif(sum(pm.tbf*(1.0-pm.mle_bb)),0) as OPS, 
100.0*( ( 13.0*sum(pm.mle_hr*pm.tbf)/nullif(sum(pm.tbf),0) + 3.0*sum(pm.mle_bb*pm.tbf)/nullif(sum(pm.tbf),0) - 2.0*sum(pm.mle_so*pm.tbf)/nullif(sum(pm.tbf),0) ) / nullif(sum((pm.mle_fo+pm.mle_so)*pm.tbf)/nullif(sum(pm.tbf),0)/3.0,0) + AVG(MLEWoba.FIPconstant) ) / AVG(MLEWoba.lgERA) as FIPm


from 
proj.pitching_mles pm
join mlbam.teams t on t.season = pm.year and t.team_id = pm.team_id 
left join Guts.Woba_LWTS MleWoba on pm.year = MleWoba.year and MleWoba.league = 'AL'

where 
pm.year >= 2022 
and pm.bat_side = '-' 
and pm.role = '--'

group by 
pm.groundcontrol_id, 
case when t.sport_code = 'mlb' then 'ml' when t.sport_code = 'aaa' then '3a' when t.sport_code = 'aax' then '2a' when t.sport_code = 'afa' then '1a' when t.sport_code = 'afx' then '1f' when t.sport_code = 'rok' then 'r' else null end
) m on p.groundcontrol_id = m.groundcontrol_id and m.sport_code = pp.levelofplay_lk


where showonroster_flg = 1  
and pp.org_lk is not null

) pit

where
--level = '1f' 
--and role = 'sp'
org = 'ari' 

order by --Org asc, 
case when Level = 'ML' then 1 when level = '3a' then 2 when level = '2a' then 3 when level = '1a' then 4 when level = '1f' then 5 when level = 'r' then 6 end asc, 
promo_press desc; 


-- MLB Pitchers 

select pm.groundcontrol_id, p.first_name + ' ' + p.last_name as player,
case when t.sport_code = 'mlb' then 'ml' when t.sport_code = 'aaa' then '3a' when t.sport_code = 'aax' then '2a' when t.sport_code = 'afa' then '1a' when t.sport_code = 'afx' then '1f' when t.sport_code = 'asx' then 'A-' when t.sport_code = 'rok' then 'r' else null end as sport_code,
sum(pm.tbf) as TBF, cast(sum(pm.act_prs) as decimal(15,1)) as act_prs, cast(sum(pm.hs_prs) as decimal(15,1)) as hs_prs, cast(sum(pm.mle_prs) as decimal(15,1)) as mle_prs, 
sum((pm.mle_1b + pm.mle_2b + pm.mle_3b + pm.mle_hr + pm.mle_bb) * pm.tbf) / nullif(sum(pm.tbf),0) as OBP,
sum((pm.mle_1b+pm.mle_2b*2+pm.mle_3b*3+pm.mle_hr*4)*pm.tbf)/nullif(sum(pm.tbf*(1.0-pm.mle_bb)),0) as SLG, 
sum((pm.mle_1b + pm.mle_2b + pm.mle_3b + pm.mle_hr + pm.mle_bb) * pm.tbf) / nullif(sum(pm.tbf),0) + sum((pm.mle_1b+pm.mle_2b*2+pm.mle_3b*3+pm.mle_hr*4)*pm.tbf)/nullif(sum(pm.tbf*(1.0-pm.mle_bb)),0) as OPS, 
100.0*( ( 13.0*sum(pm.mle_hr*pm.tbf)/nullif(sum(pm.tbf),0) + 3.0*sum(pm.mle_bb*pm.tbf)/nullif(sum(pm.tbf),0) - 2.0*sum(pm.mle_so*pm.tbf)/nullif(sum(pm.tbf),0) ) / nullif(sum((pm.mle_fo+pm.mle_so)*pm.tbf)/nullif(sum(pm.tbf),0)/3.0,0) + AVG(MLEWoba.FIPconstant) ) / AVG(MLEWoba.lgERA) as FIPm

from 
proj.pitching_mles pm
join astros.players p on pm.groundcontrol_id = p.groundcontrol_id 
join mlbam.teams t on t.season = pm.year and t.team_id = pm.team_id 
join mlbam.rosters r on p.mlbam_id = r.player_id
left join Guts.Woba_LWTS MleWoba on pm.year = MleWoba.year and MleWoba.league = 'AL'


where 
pm.year >= 2008
and pm.bat_side = '-' 
and pm.role = '--'
and r.sport_code = 'mlb' and r.status_code = 'a' and r.primary_position = '1' 

group by 
pm.groundcontrol_id, p.first_name + ' ' + p.last_name,
case when t.sport_code = 'mlb' then 'ml' when t.sport_code = 'aaa' then '3a' when t.sport_code = 'aax' then '2a' when t.sport_code = 'afa' then '1a' when t.sport_code = 'afx' then '1f' when t.sport_code = 'asx' then 'A-' when t.sport_code = 'rok' then 'r' else null end 

order by 
groundcontrol_id asc; 
