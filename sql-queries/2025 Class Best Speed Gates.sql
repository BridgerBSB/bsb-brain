select distinct
sg_best.groundcontrol_id,
a.first_name + ' ' + a.last_name as 'name',
b.primary_position as 'pos',
m.schteamname as 'school',
sg_best.measurement_date,
sg_best.split_1,
sg_best.split_2,
sg_best.total
from (
select distinct
m.groundcontrol_id,
m.measurement_date,
m.trial,
s1.split_1,
s2.split_2,
st.total,
row_number() over (
partition by
m.groundcontrol_id
order by
st.total
) as best
from
sportsmed.metrics m
left join sportsmed.lk_metric_types t on t.metric_type_id = m.metric_type_id
left join sportsmed.lk_metric_sources s on s.metric_source_id = t.metric_source_id
left join (
select
m.groundcontrol_id,
m.measurement_date,
m.trial,
t.metric_name,
m.metric_value as split_1
from
sportsmed.metrics m
left join sportsmed.lk_metric_types t on t.metric_type_id = m.metric_type_id
left join sportsmed.lk_metric_sources s on s.metric_source_id = t.metric_source_id
where
s.metric_source_name = 'sprints'
and t.metric_name = 'split 1'
) s1 on s1.groundcontrol_id = m.groundcontrol_id and s1.measurement_date = m.measurement_date and s1.trial = m.trial
left join (
select
m.groundcontrol_id,
m.measurement_date,
m.trial,
t.metric_name,
m.metric_value as split_2
from
sportsmed.metrics m
left join sportsmed.lk_metric_types t on t.metric_type_id = m.metric_type_id
left join sportsmed.lk_metric_sources s on s.metric_source_id = t.metric_source_id
where
s.metric_source_name = 'sprints'
and t.metric_name = 'split 2'
) s2 on s2.groundcontrol_id = m.groundcontrol_id and s2.measurement_date = m.measurement_date and s2.trial = m.trial
left join (
select
m.groundcontrol_id,
m.measurement_date,
m.trial,
t.metric_name,
m.metric_value as total
from
sportsmed.metrics m
left join sportsmed.lk_metric_types t on t.metric_type_id = m.metric_type_id
left join sportsmed.lk_metric_sources s on s.metric_source_id = t.metric_source_id
where
s.metric_source_name = 'sprints'
and t.metric_name = 'total'
) st on st.groundcontrol_id = m.groundcontrol_id and st.measurement_date = m.measurement_date and st.trial = m.trial
where
s.metric_source_name = 'sprints'
and s1.split_1 is not null
and s2.split_2 is not null
and st.total is not null
and st.total >= 3.0
and st.total <= 6.0
) sg_best
left join astros.players a on a.groundcontrol_id = sg_best.groundcontrol_id
left join scout.bios b on b.groundcontrol_id = a.groundcontrol_id
left join mlb_ebis.gbl_schteam m on m.schteam_id = b.school_id
where
sg_best.best = 1
and b.draft_elig_year = 2025
order by
sg_best.total