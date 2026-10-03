select 
s.sched_date,
case when t.team_id = s.home_team_mlbam_id then 'at ' else 'vs ' end + t.name_abbrev as opponent,
cast(pr.last_name + ', ' + pr.first_name as char(25)) as player_name,
count(1) as tbf,
sum(len(e.pitches) - len(replace(replace(replace(e.pitches, 'S', ''), 'W', ''), 'T', ''))) as whiffs,
sum(case when e.so = 1 then 1 else 0 end) as so,
sum(case when e.bb = 1 then 1 else 0 end) as bb,
sum(case when e.hbp = 1 then 1 else 0 end) as hbp,
sum(case when p.pitch_result_id in (12, 13, 14) then	
		case when h.hit_exit_speed is not null and h.hit_vertical_angle is not null then 
			case when h.hit_exit_speed >= .011 * power(h.hit_vertical_angle, 2) - .91 * h.hit_vertical_angle + 95.0 then 1 else 0 end
		else 
			case when e.hit_trajectory in ('fly_ball', 'line_drive') then 1 else 0 end 
		end
	else 0 end) as pbrl,
sum(case when p.pitch_result_id in (12, 13, 14) then	
		case when h.hit_exit_speed is not null and h.hit_vertical_angle is not null then 
			case when h.hit_exit_speed < .011 * power(h.hit_vertical_angle, 2) - .91 * h.hit_vertical_angle + 95.0 then 1 else 0 end
		else 
			case when e.hit_trajectory not in ('fly_ball', 'line_drive') then 1 else 0 end 
		end
	else 0 end) as nonpbrl,
50.0 +
sum(case when e.so = 1 then 1 else 0 end) * 3.0 +
sum(case when e.bb = 1 then 1 else 0 end) * -4.0 +
sum(case when e.hbp = 1 then 1 else 0 end) * -4.0 +
sum(case when p.pitch_result_id in (12, 13, 14) then	
		case when h.hit_exit_speed is not null and h.hit_vertical_angle is not null then 
			case when h.hit_exit_speed >= .011 * power(h.hit_vertical_angle, 2) - .91 * h.hit_vertical_angle + 95.0 then 1 else 0 end
		else 
			case when e.hit_trajectory in ('fly_ball', 'line_drive') then 1 else 0 end 
		end
	else 0 end) * -1.5 +
sum(case when p.pitch_result_id in (12, 13, 14) then	
		case when h.hit_exit_speed is not null and h.hit_vertical_angle is not null then 
			case when h.hit_exit_speed < .011 * power(h.hit_vertical_angle, 2) - .91 * h.hit_vertical_angle + 95.0 then 1 else 0 end
		else 
			case when e.hit_trajectory not in ('fly_ball', 'line_drive') then 1 else 0 end 
		end
	else 0 end) * .75 as FlyScore,
g.outs, 
coalesce(g.er, 0) as er,
case when g.outs >= 18 and coalesce(g.er, 0) <= 3 then 1 else 0 end as QualityStart,
case when 50.0 +
sum(case when e.so = 1 then 1 else 0 end) * 3.0 +
sum(case when e.bb = 1 then 1 else 0 end) * -4.0 +
sum(case when e.hbp = 1 then 1 else 0 end) * -4.0 +
sum(case when p.pitch_result_id in (12, 13, 14) then	
		case when h.hit_exit_speed is not null and h.hit_vertical_angle is not null then 
			case when h.hit_exit_speed >= .011 * power(h.hit_vertical_angle, 2) - .91 * h.hit_vertical_angle + 95.0 then 1 else 0 end
		else 
			case when e.hit_trajectory in ('fly_ball', 'line_drive') then 1 else 0 end 
		end
	else 0 end) * -1.5 +
sum(case when p.pitch_result_id in (12, 13, 14) then	
		case when h.hit_exit_speed is not null and h.hit_vertical_angle is not null then 
			case when h.hit_exit_speed < .011 * power(h.hit_vertical_angle, 2) - .91 * h.hit_vertical_angle + 95.0 then 1 else 0 end
		else 
			case when e.hit_trajectory not in ('fly_ball', 'line_drive') then 1 else 0 end 
		end
	else 0 end) * .75 >= 60 then 1 else 0 end as FlyingStart,
case when o.winning_team_id = g.team_id then 1 else 0 end as TeamWin
from 
astros.pitches_view p
join astros.schedule_view s on s.sched_id = p.sched_id 
join astros.events_view e on e.sched_id = p.sched_id and e.event_id = p.cur_event_id and e.pa = 1
join astros.players pr on pr.groundcontrol_id = p.pitcher_id
join mlbam.gamelog_pitching g on g.game_pk = s.mlbam_game_pk and g.player_id = pr.mlbam_id and g.is_start = 1
join mlbam.teams t on t.season = s.year and t.team_id = case when s.home_team_mlbam_id = g.team_id then s.away_team_mlbam_id else s.home_team_mlbam_id end
join mlbam.pbp_postgame o on o.game_pk = s.mlbam_game_pk 
left join astros.hits h on h.sched_id = p.sched_id and h.pitch_id = p.pitch_id and p.pitch_result_id in (12, 13, 14) and h.hit_exit_speed > 0
where s.year >= 2025
and s.sched_type in ('f','r','d','l','w')
and s.level_code = 'mlb'
group by
s.year,
s.sched_date,
t.name_abbrev,
t.team_id,
s.home_team_mlbam_id,
pr.groundcontrol_id,
pr.mlbam_id,
pr.last_name,
pr.first_name,
o.winning_team_id,
g.team_id,
g.outs,
g.er
order by FlyScore desc

