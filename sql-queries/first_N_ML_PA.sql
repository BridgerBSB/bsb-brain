set nocount on;

declare @pa int = 493

drop table if exists #pa_nums
select 
s.sched_id,
e.event_id,
count(1) over (partition by p.batter_id order by s.sched_date, m.game_nbr, e.event_id) as batter_pa
into #pa_nums
from
astros.pitches_view p
join astros.schedule_view s on s.sched_id = p.sched_id and s.sched_type = 'r' and s.level_code = 'mlb'
join mlbam.schedule m on m.game_pk = s.mlbam_game_pk
join astros.events_view e on e.sched_id = p.sched_id and e.event_id = p.cur_event_id and e.pa = 1

select 
min(s.year) as year,
pr.groundcontrol_id,
pr.last_name + ', ' + pr.first_name as player_name,
max(datediff(day, pr.birthdate, s.sched_date)/365.25) as age,
pr.bats,
sum(case when e.pa = 1 then 1 else 0 end) as pa,
sum(case when e.ab = 1 then 1 else 0 end) as ab,
avg(case when p.swing_zone in ('chase', 'waste') then case when r.did_swing = 1 then 1.0 else 0.0 end end) as chase_sw,
avg(case when r.did_swing = 1 then case when p.pitch_result_id in (10, 22, 23) then 0.0 else 1.0 end end) as cntct,
avg(case when e.pa = 1 then case when e.so = 1 then 1.0 else 0.0 end end) as sor,
avg(case when e.pa = 1 then case when e.bb = 1 then 1.0 else 0.0 end end) as bbr,
avg(case when e.pa = 1 then case when e.bb | e.hbp | e.so = 1 then 0.0 else 1.0 end end) as bber,
avg(case when e.ab = 1 then case when e.[1b] | e.[2b] | e.[3b] | e.[hr] = 1 then 1.0 else 0.0 end end) as ba,
avg(case when e.sh = 0 then case when e.bb | e.hbp | e.[1b] | e.[2b] | e.[3b] | e.[hr] = 1 then 1.0 else 0.0 end end) as obp,
avg(case when e.ab = 1 then case when e.[1b] = 1 then 1.0 when e.[2b] = 1 then 2.0 when e.[3b] = 1 then 3.0 when e.[hr] = 1 then 4.0 else 0.0 end end) as slg,
avg(case when e.pa = 1 and e.bb | e.hbp = 0 then 
	case when hp.pitch_id is null then 
	case when e.[1b] = 1 then 1.0
		 when e.[2b] = 1 then 1.0
		 when e.[3b] = 1 then 1.0
		 when e.[hr] = 1 then 1.0
		 else 0.0
		 end else
	 (power(hp.prob_inf_1b + hp.prob_of_1b, hr.exp_1b)  * 1.0 +
	 power(hp.prob_2b, hr.exp_2b) * 1.0 +
	 power(hp.prob_3b, hr.exp_3b) * 1.0 +
	 power(hp.prob_hr, hr.exp_hr) * 1.0) /
	 (power(hp.prob_inf_1b + hp.prob_of_1b, hr.exp_1b) + 
	  power(hp.prob_2b, hr.exp_2b) +
	  power(hp.prob_3b, hr.exp_3b) +
	  power(hp.prob_hr, hr.exp_hr) +
	  power(hp.prob_inf_out + hp.prob_inf_error + hp.prob_of_out + hp.prob_of_error, hr.exp_fo))
	 end end) as xba,
avg(case when e.pa = 1 and e.bb | e.hbp = 0 then 
	case when hp.pitch_id is null then 
	case when e.[1b] = 1 then 1.0
		 when e.[2b] = 1 then 2.0
		 when e.[3b] = 1 then 3.0
		 when e.[hr] = 1 then 4.0
		 else 0.0
		 end else
	 (power(hp.prob_inf_1b + hp.prob_of_1b, hr.exp_1b)  * 1.0 +
	 power(hp.prob_2b, hr.exp_2b) * 2.0 +
	 power(hp.prob_3b, hr.exp_3b) * 3.0 +
	 power(hp.prob_hr, hr.exp_hr) * 4.0) /
	 (power(hp.prob_inf_1b + hp.prob_of_1b, hr.exp_1b) + 
	  power(hp.prob_2b, hr.exp_2b) +
	  power(hp.prob_3b, hr.exp_3b) +
	  power(hp.prob_hr, hr.exp_hr) +
	  power(hp.prob_inf_out + hp.prob_inf_error + hp.prob_of_out + hp.prob_of_error, hr.exp_fo))
	 end end) as xslg,

sum(p.rv_gain)/sum(case when e.pa = 1 then 1 else 0 end) as orp,
sum(p.rv_gain_given_hit_specs)/sum(case when e.pa = 1 then 1 else 0 end) as orp_hs,
avg(case when e.pa = 1 then 
	case when e.[1b] = 1 then w.woba_1b 
		 when e.[2b] = 1 then w.woba_2b
		 when e.[3b] = 1 then w.woba_3b
		 when e.[hr] = 1 then w.woba_hr
		 when e.bb | e.hbp = 1 then w.woba_bb
		 else 0.0
		 end end) as woba,
avg(case when e.pa = 1 then 
	case when hp.pitch_id is null then 
	case when e.[1b] = 1 then w.woba_1b 
		 when e.[2b] = 1 then w.woba_2b
		 when e.[3b] = 1 then w.woba_3b
		 when e.[hr] = 1 then w.woba_hr
		 when e.bb | e.hbp = 1 then w.woba_bb
		 else 0.0
		 end else
	 (power(hp.prob_inf_1b + hp.prob_of_1b, hr.exp_1b)  * w.woba_1b +
	 power(hp.prob_2b, hr.exp_2b) * w.woba_2b +
	 power(hp.prob_3b, hr.exp_3b) * w.woba_3b +
	 power(hp.prob_hr, hr.exp_hr) * w.woba_hr) /
	 (power(hp.prob_inf_1b + hp.prob_of_1b, hr.exp_1b) + 
	  power(hp.prob_2b, hr.exp_2b) +
	  power(hp.prob_3b, hr.exp_3b) +
	  power(hp.prob_hr, hr.exp_hr) +
	  power(hp.prob_inf_out + hp.prob_inf_error + hp.prob_of_out + hp.prob_of_error, hr.exp_fo))
	 end end) as xwoba,
avg(case when e.ab = 1 and e.so = 0 and e.hr = 0 then case when e.[1b] | e.[2b] | e.[3b] = 1 then 1.0 else 0.0 end end) as babip,
avg(case when e.hr | e.so = 1 then case when e.hr = 1 then 1.0 else 0.0 end end) as baboop,
sum(power(hp.prob_inf_1b + hp.prob_of_1b, hr.exp_1b) + 
	  power(hp.prob_2b, hr.exp_2b) +
	  power(hp.prob_3b, hr.exp_3b))/sum(
	  power(hp.prob_inf_1b + hp.prob_of_1b, hr.exp_1b) + 
	  power(hp.prob_2b, hr.exp_2b) +
	  power(hp.prob_3b, hr.exp_3b) +
	  power(hp.prob_inf_out + hp.prob_inf_error + hp.prob_of_out + hp.prob_of_error, hr.exp_fo)) as xbabip,
sum(power(hp.prob_hr, hr.exp_hr))/sum(
	  coalesce(power(hp.prob_hr, hr.exp_hr), 0) + case when e.so = 1 then 1.0 else 0.0 end) as xbaboop,
avg(case when h.hit_exit_speed is not null then h.hit_exit_speed end) as ev,
avg(case when h.hit_exit_speed is not null then case when h.hit_exit_speed > 88.0 then h.hit_exit_speed - 88.0 else 0 end end) as escv,
avg(case when h.hit_exit_speed is not null then h.hit_useful_exit_speed end) as uev,
avg(case when h.hit_exit_speed is not null then case when h.hit_useful_exit_speed > 88.0 then h.hit_useful_exit_speed - 88.0 else 0 end end) as uescv,
avg(case when h.hit_exit_speed is not null then case when h.hit_exit_speed >= 95.0 then 1.0 else 0.0 end end) as hh,
avg(case when h.hit_exit_speed is not null then case when h.hit_useful_exit_speed >= 95.0 then 1.0 else 0.0 end end) as uhh,
avg(case when h.hit_exit_speed is not null then case when h.hit_exit_speed * 1.5 - h.hit_vertical_angle >= 117 and (h.hit_exit_speed + h.hit_vertical_angle) >= 124 and h.hit_exit_speed >= 98 and h.hit_vertical_angle > 4 and h.hit_vertical_angle < 50 then 1.0 else 0.0 end end) as brl,
avg(case when h.hit_exit_speed is not null then 1.6 *
power(1.3, cos(-.34) * (h.hit_exit_speed - 98.0) - sin(-.34) * (h.hit_vertical_angle - 27.0) -
  .02 * power(2 + sin(-.34) * (h.hit_exit_speed - 98.0) + cos(-.34) * (h.hit_vertical_angle - 27.0), 2)) / (7.0 + power(1.3, cos(-.34) * (h.hit_exit_speed - 98.0) - sin(-.34) * (h.hit_vertical_angle - 27.0) -
  .02 * power(2 + sin(-.34) * (h.hit_exit_speed - 98.0) + cos(-.34) * (h.hit_vertical_angle - 27.0), 2))) else null end) as dmg,
avg(b.obp) *
(0.50 * avg(case when e.pa = 1 then case when e.so = 1 then 1.0 else 0.0 end end) +
 1.49 * avg(case when e.pa = 1 then case when e.bb | e.hbp = 0 then 0.0 else 1.0 end end) +
 0.11 * avg(case when e.pa = 1 then case when len(e.pitches) - len(replace(replace(replace(e.pitches, 'S', ''), 'W', ''), 'T', '')) = 0 then 1.0 else 0.0 end end) +
 0.08 * avg(case when e.pa = 1 then case when len(e.pitches) - len(replace(replace(replace(e.pitches, 'S', ''), 'W', ''), 'T', '')) = 1 then 1.0 else 0.0 end end) +
-0.10 * avg(case when e.pa = 1 then case when len(e.pitches) - len(replace(replace(replace(e.pitches, 'S', ''), 'W', ''), 'T', '')) = 2 then 1.0 else 0.0 end end) +
-0.10 * avg(case when e.pa = 1 then case when len(e.pitches) - len(replace(replace(replace(e.pitches, 'S', ''), 'W', ''), 'T', '')) = 3 then 1.0 else 0.0 end end) +
 avg(case when e.pa = 1 then case when e.bb | e.hbp | e.so = 0 then 1.0 else 0.0 end end) *
 (1.70 * avg(case when h.hit_exit_speed > 0 then 
                  case when
	              h.hit_exit_speed * 1.5 - h.hit_vertical_angle >= 117 and
	              h.hit_exit_speed + h.hit_vertical_angle >= 124 and
	              h.hit_exit_speed >= 98 and
	              h.hit_vertical_angle > 4 and
	              h.hit_vertical_angle < 50
	              then 1.0 else 0.0 end 
				  else null end) +
  1.09 * avg(case when h.hit_exit_speed > 0 then h.hit_useful_exit_speed else null end)/100.0)) as gcoba,
 .300 *
(0.50 * avg(case when e.pa = 1 then case when e.so = 1 then 1.0 else 0.0 end end) +
 1.49 * avg(case when e.pa = 1 then case when e.bb | e.hbp = 0 then 0.0 else 1.0 end end) +
 0.11 * avg(case when e.pa = 1 then case when len(e.pitches) - len(replace(replace(replace(e.pitches, 'S', ''), 'W', ''), 'T', '')) = 0 then 1.0 else 0.0 end end) +
 0.08 * avg(case when e.pa = 1 then case when len(e.pitches) - len(replace(replace(replace(e.pitches, 'S', ''), 'W', ''), 'T', '')) = 1 then 1.0 else 0.0 end end) +
-0.10 * avg(case when e.pa = 1 then case when len(e.pitches) - len(replace(replace(replace(e.pitches, 'S', ''), 'W', ''), 'T', '')) = 2 then 1.0 else 0.0 end end) +
-0.10 * avg(case when e.pa = 1 then case when len(e.pitches) - len(replace(replace(replace(e.pitches, 'S', ''), 'W', ''), 'T', '')) = 3 then 1.0 else 0.0 end end) +
 avg(case when e.pa = 1 then case when e.bb | e.hbp | e.so = 0 then 1.0 else 0.0 end end) *
 (1.70 * avg(case when h.hit_exit_speed > 0 then 
                  case when
	              h.hit_exit_speed * 1.5 - h.hit_vertical_angle >= 117 and
	              h.hit_exit_speed + h.hit_vertical_angle >= 124 and
	              h.hit_exit_speed >= 98 and
	              h.hit_vertical_angle > 4 and
	              h.hit_vertical_angle < 50
	              then 1.0 else 0.0 end 
				  else null end) +
avg(case when h.hit_exit_speed is not null then 1.6 *
power(1.3, cos(-.34) * (h.hit_exit_speed - 98.0) - sin(-.34) * (h.hit_vertical_angle - 27.0) -
  .02 * power(2 + sin(-.34) * (h.hit_exit_speed - 98.0) + cos(-.34) * (h.hit_vertical_angle - 27.0), 2)) / (7.0 + power(1.3, cos(-.34) * (h.hit_exit_speed - 98.0) - sin(-.34) * (h.hit_vertical_angle - 27.0) -
  .02 * power(2 + sin(-.34) * (h.hit_exit_speed - 98.0) + cos(-.34) * (h.hit_vertical_angle - 27.0), 2))) else null end) + 			  
  1.09 * avg(case when h.hit_exit_speed > 0 then h.hit_useful_exit_speed else null end)/100.0)) as gcoba2
from 
astros.pitches_view p
join astros.schedule_view s on s.sched_id = p.sched_id and s.year >= 2015 and s.sched_type = 'r' and s.level_code = 'mlb'
join guts.hit_specs_ratios hr on hr.season = s.year  
left join astros.events_view e on e.sched_id = p.sched_id and e.event_id = p.cur_event_id and e.pa = 1
join astros.players pr on pr.groundcontrol_id = p.batter_id
left join astros.hits h on h.sched_id = p.sched_id and h.pitch_id = p.pitch_id and p.pitch_result_id in (12, 13, 14) and h.hit_exit_speed > 0
join guts.woba_lwts w on w.league = 'al' and w.year = s.year
left join astros.hits_probabilities hp on hp.sched_id = p.sched_id and hp.pitch_id = p.pitch_id and hp.actual_shift = 1 
join mlbam.ytd_team_batting_stats b on b.season = s.year and b.gm_type = 'r' and b.team_id = 0 and b.split_id = 0 and b.level = 'mlb'
left join astros.projections_pitches_grades pg on pg.sched_id = p.sched_id and pg.pitch_id = p.pitch_id
join astros.lk_pitch_results r on r.pitch_result_id = p.pitch_result_id
join #pa_nums n on n.sched_id = e.sched_id and n.event_id = e.event_id and n.batter_pa <= @pa
group by
pr.groundcontrol_id,
pr.last_name,
pr.first_name,
pr.bats
having sum(case when e.pa = 1 then 1 else 0 end) >= @pa
order by gcoba2 desc

