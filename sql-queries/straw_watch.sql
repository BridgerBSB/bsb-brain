select
s.year,
case 
	when month(s.sched_date) <= 4 then 'March/April'
	when month(s.sched_date) = 5 then 'May'
	when month(s.sched_date) = 6 then 'June'
	when month(s.sched_date) = 7 then 'July'
	when month(s.sched_date) = 8 then 'August'
	when month(s.sched_date) >= 9 then 'Sept/Oct'
end as month,
pr.groundcontrol_id,
pr.last_name + ', ' + pr.first_name as player_name,
sum(b.pa) as pa,
cast(sum(cast(b.h as float))/sum(cast(b.ab as float)) as decimal(5,3)) as ba,
cast(sum(cast(b.h + b.bb + b.hbp as float))/sum(cast(b.ab + b.bb + b.hbp + b.sf as float)) as decimal(5,3)) as obp,
cast(sum(cast(b.tb as float))/sum(cast(b.ab as float)) as decimal(5,3)) as slg,
cast(sum(cast(b.h + b.bb + b.hbp as float))/sum(cast(b.ab + b.bb + b.hbp + b.sf as float)) + sum(cast(b.tb as float))/sum(cast(b.ab as float)) as decimal(6,4)) as ops,
cast(sum(cast(b.tb - b.h as float))/sum(cast(b.ab as float)) as decimal(5,3)) as iso,
cast(sum(cast(b.so as float))/sum(cast(b.pa as float)) as decimal(5,3)) as sor
from
mlbam.gamelog_batting b
join astros.players pr on pr.mlbam_id = b.player_id
join astros.schedule_view s on s.mlbam_game_pk = b.game_pk
where 
s.sched_type = 'r'
and s.level_code = 'mlb'
and b.pa > 0
group by 
s.year,
case 
	when month(s.sched_date) <= 4 then 'March/April'
	when month(s.sched_date) = 5 then 'May'
	when month(s.sched_date) = 6 then 'June'
	when month(s.sched_date) = 7 then 'July'
	when month(s.sched_date) = 8 then 'August'
	when month(s.sched_date) >= 9 then 'Sept/Oct'
end,
pr.groundcontrol_id,
pr.last_name, 
pr.first_name
having sum(b.pa) >= 75
order by ops