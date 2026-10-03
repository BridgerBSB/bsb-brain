select
s.year,
pr.groundcontrol_id,
pr.last_name + ', ' + pr.first_name as player_name,
sum(case when e.pa = 1 then 1 else 0 end) as pa,
sum(case when p.pitch_result_id in (12, 13, 14) then 1 else 0 end) as bbe,
cast(sum(case when ah.hit_exit_speed is not null then case when ah.hit_exit_speed * 1.5 - ah.hit_vertical_angle >= 117 and (ah.hit_exit_speed + ah.hit_vertical_angle) >= 124 and ah.hit_exit_speed >= 98 and ah.hit_vertical_angle > 4 and ah.hit_vertical_angle < 50 then 1 else 0 end end)/sum(case when e.ab | e.sf = 1 then 1.0 else 0.0 end) as decimal(4,3)) as brl_per_ab,
cast(avg(case when e.pa = 1 then case when e.bb  = 1 then 1.0 else 0.0 end end) as decimal(4,3)) as bbr,
sum(case when e.hr = 1 then 1 else 0 end) as hr,
sum(case when ah.hit_exit_speed is not null then case when ah.hit_exit_speed * 1.5 - ah.hit_vertical_angle >= 117 and (ah.hit_exit_speed + ah.hit_vertical_angle) >= 124 and ah.hit_exit_speed >= 98 and ah.hit_vertical_angle > 4 and ah.hit_vertical_angle < 50 then 1 else 0 end end) as brls,
cast(avg(case when ah.hit_exit_speed is not null then case when ah.hit_exit_speed * 1.5 - ah.hit_vertical_angle >= 117 and (ah.hit_exit_speed + ah.hit_vertical_angle) >= 124 and ah.hit_exit_speed >= 98 and ah.hit_vertical_angle > 4 and ah.hit_vertical_angle < 50 then 1.0 else 0.0 end end) as decimal(4,3)) as brl_per_bbe,
cast(avg(case when r.did_swing = 1 then case when p.pitch_result_id in (10, 22, 23) then 1.0 else 0.0 end end) as decimal(4,3)) as whiff,
cast(sum(case when ah.hit_exit_speed is not null then case when ah.hit_exit_speed * 1.5 - ah.hit_vertical_angle >= 117 and (ah.hit_exit_speed + ah.hit_vertical_angle) >= 124 and ah.hit_exit_speed >= 98 and ah.hit_vertical_angle > 4 and ah.hit_vertical_angle < 50 then 1.0 else 0.0 end end)
/ sum(case when r.did_swing = 1 then case when p.pitch_result_id in (10, 22, 23) then 1.0 else 0.0 end end) as decimal(4,3)) as brl_per_whiff,
cast(avg(case when ah.hit_exit_speed is not null then case when ah.hit_exit_speed * 1.5 - ah.hit_vertical_angle >= 117 and (ah.hit_exit_speed + ah.hit_vertical_angle) >= 124 and ah.hit_exit_speed >= 98 and ah.hit_vertical_angle > 4 and ah.hit_vertical_angle < 50 then 1.0 else 0.0 end end)
/ avg(case when r.did_swing = 1 then case when p.pitch_result_id in (10, 22, 23) then 1.0 else 0.0 end end) as decimal(4,3)) brl_whiff_ratio,
cast(sum(case when e.hr = 1 then 1.0 else 0.0 end)/nullif(sum(case when ah.hit_exit_speed is not null then case when ah.hit_exit_speed * 1.5 - ah.hit_vertical_angle >= 117 and (ah.hit_exit_speed + ah.hit_vertical_angle) >= 124 and ah.hit_exit_speed >= 98 and ah.hit_vertical_angle > 4 and ah.hit_vertical_angle < 50 then 1.0 else 0.0 end end), 0) as decimal(4,3)) as hr_per_brl,
cast(sum(case when e.hr = 1 and ah.hit_exit_speed * 1.5 - ah.hit_vertical_angle >= 117 and (ah.hit_exit_speed + ah.hit_vertical_angle) >= 124 and ah.hit_exit_speed >= 98 and ah.hit_vertical_angle > 4 and ah.hit_vertical_angle < 50 then 1.0 else 0.0 end)/nullif(sum(case when ah.hit_exit_speed is not null then case when ah.hit_exit_speed * 1.5 - ah.hit_vertical_angle >= 117 and (ah.hit_exit_speed + ah.hit_vertical_angle) >= 124 and ah.hit_exit_speed >= 98 and ah.hit_vertical_angle > 4 and ah.hit_vertical_angle < 50 then 1.0 else 0.0 end end), 0) as decimal(4,3)) as hr_on_brl
from
astros.pitches_view p
join astros.lk_pitch_results r on r.pitch_result_id = p.pitch_result_id
left join astros.projections_pitches_grades g on g.sched_id = p.sched_id and g.pitch_id = p.pitch_id 
join astros.schedule_view s on s.sched_id = p.sched_id
left join astros.events_view e on e.sched_id = p.sched_id and e.event_id = p.cur_event_id and e.pa = 1
left join astros.hits ah on ah.sched_id = p.sched_id and ah.pitch_id = p.pitch_id and p.pitch_result_id in (12, 13, 14) and e.hit_trajectory_id not in (2, 3, 4)
join astros.players pr on pr.groundcontrol_id = p.batter_id
join mlbam.players mr on mr.player_id = pr.mlbam_id 
left join mlbam.rosters ro on ro.player_id = mr.player_id and ro.sport_code = 'mlb'
where
s.year = 2025
and s.sched_type = 'r'
and s.level_code in ('mlb')
group by
s.year,
pr.groundcontrol_id,
pr.last_name,
pr.first_name
having 
sum(case when e.pa = 1 then 1 else 0 end) >= 200
order by brl_per_ab desc