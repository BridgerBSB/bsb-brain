
select
s.year,
pr.groundcontrol_id,
pr.last_name + ', ' + pr.first_name as player_name,
p0.bat_side,
cast(p.balls_before as char(1)) + '-' + cast(p.strikes_before as char(1)) as thru_count,
count(1) as np,
sum(case when e.pa = 1 then 1 else 0 end) as pa,
sum(case when p0.pitch_result_id in (12, 13, 14) then 1 else 0 end) as bbe,
cast(sum(case when e.so = 1 then 1.0 else 0.0 end)/sum(case when e.pa = 1 then 1.0 else 0.0 end) as decimal(4,3)) as sor,
cast(sum(case when e.bb = 1 then 1.0 else 0.0 end)/sum(case when e.pa = 1 then 1.0 else 0.0 end) as decimal(4,3)) as bbr,
cast(avg(p0.stuffrelvel_grade_2080) as decimal(4,1)) as stuff,
cast(avg(p0.release_speed) as decimal(4,1)) as velo,
cast(avg(g.fb_grade) as decimal(4,1)) as proj,
cast(avg(case when r.did_swing = 1 then 1.0 else 0.0 end) as decimal(4,3)) as swing,
cast(avg(case when p0.swing_zone in ('chase', 'waste') then case when r.did_swing = 1 then 1.0 else 0.0 end end) as decimal(4,3)) as chase,
cast(avg(case when r.did_swing = 1 then case when p0.pitch_result_id not in (22, 23) then 1.0 else 0.0 end end) as decimal(4,3)) as contact,
cast(avg(case when p0.pitch_result_id in (10, 22, 23) then 1.0 else 0.0 end) as decimal(4,3)) as swingstr,
cast(avg(case when p0.pitch_result_id in (6) then 1.0 else 0.0 end) as decimal(4,3)) as callstr,
cast(avg(case when p0.pitch_result_id in (6, 10, 22, 23) then 1.0 else 0.0 end) as decimal(4,3)) as csw,
cast(avg(case when h.hit_exit_speed > 0 then h.hit_exit_speed end) as decimal(4,1)) as ev, 
cast(avg(case when h.hit_exit_speed > 0 then h.hit_useful_exit_speed end) as decimal(4,1)) as uev, 
cast(avg(case when h.hit_exit_speed > 0 then case when h.hit_exit_speed * 1.5 - h.hit_vertical_angle >= 117 and 
	(h.hit_exit_speed + h.hit_vertical_angle) >= 124 and h.hit_exit_speed >= 98 and h.hit_vertical_angle > 4 and h.hit_vertical_angle < 50 then 1.0 else 0.0 end end) as decimal(4,3)) as brl, 
cast(avg(case when h.hit_exit_speed > 0 then case when h.hit_exit_speed >= 95.0 then 1.0 else 0.0 end end) as decimal(4,3)) as hh, 
cast(avg(case when h.hit_exit_speed > 0 then case when h.hit_exit_speed >= 0.011 * power(h.hit_vertical_angle, 2) - 0.91 * h.hit_vertical_angle + 95.0 then 1.0 else 0.0 end end) as decimal(4,3)) as pbrl, 
cast(avg(case when p0.pitch_result_id in (12, 13, 14) then case when e.hit_trajectory = 'ground_ball' then 1.0 else 0.0 end end)  as decimal(4,3)) as gbr,
cast(avg(case when e.ab = 1 then case when e.[1b] | e.[2b] | e.[3b] | e.[hr] = 1 then 1.0 else 0.0 end end) as decimal(4,3)) as ba,
cast(avg(case when e.pa = 1 and e.sh = 0 then case when e.[1b] | e.[2b] | e.[3b] | e.[hr] | e.[bb] = 1 then 1.0 else 0.0 end end) as decimal(4,3)) as obp,
cast(avg(case when e.ab = 1 then case when e.[1b] = 1 then 1.0 when e.[2b] = 1 then 2.0 when e.[3b] = 1 then 3.0 when e.[hr] = 1 then 4.0 else 0.0 end end) as decimal(4,3)) as slg,
cast(avg(case when e.pa = 1 and e.sh = 0 then case 
	when e.[1b] = 1 then w.wOBA_1B 
	when e.[2b] = 1 then w.wOBA_2B 
	when e.[3b] = 1 then w.wOBA_3B 
	when e.[hr] = 1 then w.wOBA_HR 
	when e.[bb] | e.hbp = 1 then w.wOBA_BB else 0.0 end end) as decimal(4,3)) as wOBA,
cast(avg(case when e.pa = 1 and e.sh = 0 and e.so | e.bb | e.hbp = 0 then case 
	when e.[1b] = 1 then w.wOBA_1B 
	when e.[2b] = 1 then w.wOBA_2B 
	when e.[3b] = 1 then w.wOBA_3B 
	when e.[hr] = 1 then w.wOBA_HR 
	when e.[bb] | e.hbp = 1 then w.wOBA_BB else 0.0 end end) as decimal(4,3)) as wOBAcon,
cast(avg(case when p0.called_strike_chance > .5 and e.pa = 1 and e.sh = 0 and e.so | e.bb | e.hbp = 0 then case 
	when e.[1b] = 1 then w.wOBA_1B 
	when e.[2b] = 1 then w.wOBA_2B 
	when e.[3b] = 1 then w.wOBA_3B 
	when e.[hr] = 1 then w.wOBA_HR 
	when e.[bb] | e.hbp = 1 then w.wOBA_BB else 0.0 end end) as decimal(4,3)) as inZ_wOBAcon,
cast(50.0 - 1500.0 * avg(case 
	when p0.pitch_result_id in (10, 22, 23) then -.08
	when p0.pitch_result_id in (6) then -.03
	when p0.pitch_result_id in (4, 5) then .03
	when p0.pitch_result_id in (11) then .10
	when p0.pitch_result_id in (12, 13, 14) then 
		case when h.hit_exit_speed >= 0.011 * power(h.hit_vertical_angle, 2) - 0.91 * h.hit_vertical_angle + 95.0 then .08 else -.03 end
	else 0.0 end) as decimal(4,1)) as gcpg,
cast(avg(case when e.pa = 1 then case 
	 when e.so = 1 then -3.3
	 when e.bb | e.hbp = 1 then 9.9
	 when h.hit_exit_speed >= .011 * power(h.hit_vertical_angle, 2) - .91 * h.hit_vertical_angle + 95.0 then (3.9 + 31.1 * cast(y.hr as float)/cast(y.hr + y.ao as float)) 
	 else 3.5 end end) as decimal(6,3)) as gcera
from
astros.pitches_view p0
join groundcontroltracking.tracking.plays pl on pl.sched_id = p0.sched_id and pl.astros_pitch_id = p0.pitch_id
join groundcontroltracking.tracking.pitch_hit_trajectories pht on pht.sched_id = pl.sched_id and pht.tracking_play_id = pl.tracking_play_id
join astros.Projections_Pitches_Grades g on g.sched_id = p0.sched_id and g.pitch_id = p0.pitch_id
left join astros.hits h on h.sched_id = p0.sched_id and h.pitch_id = p0.pitch_id and p0.pitch_result_id in (12, 13, 14) and h.hit_exit_speed > 0
left join astros.Hits_Probabilities hp on hp.sched_id = h.sched_id and hp.pitch_id = h.pitch_id and hp.actual_shift = 1
left join astros.events_view e on e.sched_id = p0.sched_id and e.event_id = p0.cur_event_id and e.pa = 1
left join astros.events_view eab on eab.sched_id = p0.sched_id and eab.event_id = p0.ab_event_id
join astros.pitches_view p on p.sched_id = p0.sched_id and p0.ab_event_id = p.ab_event_id and p.balls_before + p.strikes_before = 1
join astros.Schedule_View s on s.sched_id = p0.sched_id
join astros.lk_pitch_results r on r.pitch_result_id = p0.pitch_result_id
join guts.woba_lwts w on w.year = s.year and w.league = 'al'
join astros.players pr on pr.groundcontrol_id = p0.pitcher_id 
join mlbam.ytd_team_pitching_stats y on y.season = s.year and y.level = 'mlb' and y.split_id = 0 and y.team_id = 0 and y.gm_type = 'r'
where
s.year >= 2025
and s.sched_type in ('r')
and pr.groundcontrol_id = 77028
group by
s.year, 
pr.groundcontrol_id,
pr.first_name,
pr.last_name,
p0.pitcher_throws,
p0.bat_side,
p.balls_before,
p.strikes_before
order by bat_side, thru_count
