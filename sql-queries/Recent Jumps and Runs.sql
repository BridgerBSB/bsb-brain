declare @year int = 2025

select
a.groundcontrol_id,
a.first_name + ' ' + a.last_name as 'name',
b.area_scout,
fp.test_date,
fp.concentric_impulse,
fp.concentric_mean_power_bm,
fp.vertical_velocity_at_takeoff,
fp.concentric_impulse_100ms,
sg.measurement_date,
sg.split_1,
sg.split_2,
sg.total
from
astros.players a
left join scout.bios b on b.groundcontrol_id = a.groundcontrol_id
-- FORCEPLATES -----------------------------------------------------------------------------------------------------------------------------------------------------
left join (
select distinct
fp_rec.groundcontrol_id,
fp_rec.test_date,
fp_rec.concentric_impulse,
fp_rec.concentric_mean_power_bm,
fp_rec.vertical_velocity_at_takeoff,
fp_rec.concentric_impulse_100ms
from (
select
groundcontrol_id,
test_date,
concentric_impulse,
concentric_mean_power_bm,
vertical_velocity_at_takeoff,
concentric_impulse_100ms,
row_number() over (
partition by
groundcontrol_id
order by
test_date desc
) as recent
from
sportsmed.forcedeck_metrics
where
test_type = 'cmj'
) fp_rec
where
fp_rec.recent = 1
) fp on fp.groundcontrol_id = a.groundcontrol_id
-- SPEED GATES -----------------------------------------------------------------------------------------------------------------------------------------------------
left join (
select distinct
sg_best.groundcontrol_id,
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
m.metric_value as 'split_1'
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
m.metric_value as 'split_2'
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
m.metric_value as 'total'
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
where
sg_best.best = 1
) sg on sg.groundcontrol_id = a.groundcontrol_id

where
b.draft_elig_year >= @year
and fp.test_date is not null
and a.groundcontrol_id = 1250402
--and sg.measurement_date is not null

order by
fp.test_date desc, a.first_name + ' ' + a.last_name
--sg.measurement_date desc