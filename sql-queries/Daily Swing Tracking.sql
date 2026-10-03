-- NOTE (Apr 26 2026): Astros' canonical bat speed switched to "at contact" (SCV).
-- This GC2 reference query is preserved as-is for diagnostic comparison.
-- See pd-goals/src/percentiles.py for canonical at-contact SQL pattern.

SELECT 
ss.sched_id,
--tp.astros_pitch_id as pitch_id,
--s.year,
--s.level_id,
s.sched_date,
s.level_display as Lvl,
--ap.batter_id,
concat(p.first_name, ' ',p.last_name) as Name,
--ap.bat_side,
CONCAT(ap.balls_before, '-', ap.strikes_before) AS Count, 
ev.inning as Inn, 
--e.inning,
ev.outs_before as Outs,
ev.event_result as Event,
--case when ap.strikes_before in (0,1) then 'Pre2K' when ap.strikes_before in (2) then '2K' end as Count,
--case when ap.pitch_result in ('ball', 'blocked_ball') then 'Ball' when ap.pitch_result in ('called_strike') then 'Called_Strike' when ap.pitch_result in ('foul') then 'Foul' when ap.pitch_result in ('hit_into_play', 'hit_into_play_no_out', 'hit_into_play_score')  then case when ev.event_result_id in (9,21, 41,48) then 'Hit' else 'Out' end when ap.pitch_result in ('swinging_strike', 'swinging_strike_blocked') then 'Whiff' else 'Other' end as pitch_result,
cast(pht.hit_launch_speed as decimal(15,1)) as EV,
cast(pht.hit_launch_angle as decimal(15,1)) as LA, 
cast(pht.hit_launch_direction as decimal(15,1)) as Spray,
case when h.hit_exit_speed * 1.5 - h.hit_vertical_angle >= 116.5 and (h.hit_exit_speed + h.hit_vertical_angle) >= 123.5 and h.hit_exit_speed >= 97.5 and h.hit_vertical_angle > 4.5 and h.hit_vertical_angle < 49.5 then 1 else 0 end as Barrel,
--cast(ap.plate_x as decimal(15,1)) as PlateX,
--cast(ap.plate_z as decimal(15,1)) as PlateZ,
--ap.pitch_type_id,
ap.pitch_type as Pitch, 
--cast(ap.release_speed as decimal(15,1)) as Pitch_Velo,
--ap.swing_zone,
cast(h.hit_initial_contact_point_y as decimal(15,1)) as DOC,
cast(sqrt(power(sc.batvx_con,2) + power(sc.batvy_con,2) + power(sc.batvz_con,2))*0.681818 as decimal(15,1)) as [BatSpd@Con], 

cast(sqrt(power(btm.vx_true_peak,2) + power(btm.vy_true_peak,2) + power(btm.vz_true_peak,2))*0.681818 as decimal(15,1)) as [PeakBatSpd], 
cast(90 - DEGREES(ACOS(sc.batvz_con/sqrt(power(sc.batvx_con,2)+power(sc.batvy_con,2)+power(sc.batvz_con,2)))) as decimal(15,1)) as [AA@Con],
cast((180.0/pi()) * atn2(sc.e1y_con, case when ap.bat_side = 'L' then -1.0 else 1.0 end * sc.e1x_con) as decimal(15,1)) as [HBA@Con], 
cast(pht.hit_launch_spinrate as decimal(15,0)) as Spin_Rt, 
--cast(pht.hit_launch_spinaxis as decimal(15,0)) as Spin_axis,
cast(pht.hit_launch_spinrate * sin(3.141592653589793 *hit_launch_spinaxis / 180) as decimal(15,0)) as SideSpin,
cast(pht.hit_launch_spinrate * sign(abs(pht.hit_launch_direction) - 90) * cos(3.141592653589793 * pht.hit_launch_spinaxis/180) as decimal(15,0)) as [Back/TopSpin],
--cast(pht.hit_launch_spinrate_x as decimal(15,1)) as [Back/TopSpin], 
--cast(pht.hit_launch_spinrate_z as decimal(15,1)) as Sideside,
cast(sc.con_loc_axis * 12 as decimal(15,1)) as con_loc_axis,
cast(sc.con_loc_perp * 12 as decimal(15,1)) as con_loc_perp,
cast(sd.damage_window as decimal(15,3)) as Dmg_Window,
cast(ss.loft as decimal(15,1)) as Loft,
cast(ss.tilt as decimal(15,1)) as Tilt,
--cast(sc.t_con as decimal(15,2)) as t_con,
--ap.did_swing, 
--case when h.hit_exit_speed is not null and (1.6 * power(1.3, cos(-.34) * (h.hit_exit_speed - 98.0) - sin(-.34) * (h.hit_vertical_angle - 27.0) - .02 * power(2 + sin(-.34) * (h.hit_exit_speed - 98.0) + cos(-.34) * (h.hit_vertical_angle - 27.0), 2)) / (7.0 + power(1.3, cos(-.34) * (h.hit_exit_speed - 98.0) - sin(-.34) * (h.hit_vertical_angle - 27.0) - .02 * power(2 + sin(-.34) * (h.hit_exit_speed - 98.0) + cos(-.34) * (h.hit_vertical_angle - 27.0), 2))) > 0.5) then 1 else 0 end as Damage,

--cast(ss.Km30 as decimal(15,3)) as Km30,
--cast(ss.Km15 as decimal(15,3)) Km15,
--cast(ss.K0 as decimal(15,3)) as K0,
--cast(ss.K15 as decimal(15,3)) as K15,
--cast(ss.K30 as decimal(15,3)) K30,
--cast(ss.K45 as decimal(15,3)) as K45
--case when ap.pitch_type in ('ff', 'ft') then 'Fastballs' when ap.pitch_type in ('FC', 'SL', 'CU', 'KC') then 'Spin' when ap.pitch_type in ('CH', 'FS') then 'OffSpeed' end as Pitch_Group
vn.video_url as vid,
av.video_url as RHH_HSV_vid,
avt.video_url as LHH_HSV_vid

FROM Astros.Pitches_View ap 
left JOIN Astros.Schedule_View s ON ap.sched_id = s.sched_id
left join astros.events e on ap.sched_id = e.sched_id and e.event_id = ap.ab_event_id
left join astros.Events_View ev on ap.sched_id = ev.sched_id and ev.event_id = ap.cur_event_id
  JOIN GroundControlTracking.tracking.plays tp ON s.sched_id = tp.sched_id and ap.pitch_id = tp.astros_pitch_id
  join GroundControlTracking.tracking.swing_shapes ss on ss.sched_id = s.sched_id and ss.tracking_play_id = tp.tracking_play_id and ss.loft>-30 and ss.loft<30 and ss.tilt>0 and ss.tilt<60 
left JOIN GroundControlTracking.tracking.Swing_Contact_Values sc ON ss.sched_id = sc.sched_id AND ss.tracking_play_id = sc.tracking_play_id
left JOIN Groundcontroltracking.tracking.swing_damage_windows sd ON ss.sched_id = sd.sched_id AND ss.tracking_play_id = sd.tracking_play_id and sd.damage_window < 0.025
LEFT JOIN GroundControlTracking.Tracking.pitch_hit_trajectories pht ON tp.sched_id = pht.sched_id AND tp.tracking_play_id = pht.tracking_play_id
LEFT JOIN astros.bat_tracking_metrics btm ON ap.sched_id = btm.sched_id AND ap.pitch_id = btm.pitch_id and sqrt(power(btm.vx_true_peak,2) + power(btm.vy_true_peak,2) + power(btm.vz_true_peak,2))*0.681818 < 90
LEFT join Astros.players p ON p.groundcontrol_id = ap.batter_id
left join astros.hits h on h.sched_id = ap.sched_id and h.pitch_id = ap.pitch_id
left join mlbam.rosters r on p.mlbam_id = r.player_id and r.status_code in ('A')
left join MLBAM.Teams t on r.team_id = t.team_id and t.season = s.year 
left join astros.video_network vn on vn.sched_id = ap. sched_id and vn.pitch_id = ap.pitch_id and vn.angle = 'a'
left join astros.video_network av on av.sched_id = ap. sched_id and av.pitch_id = ap.pitch_id and av.angle = 's'
left join astros.video_network avt on avt.sched_id = ap. sched_id and avt.pitch_id = ap.pitch_id and avt.angle = 't'


WHERE --
--datediff(day, s.sched_date, getdate()) = 1

--and s.level_id in (13)
--s.year >= 2024
  s.sched_date between '01-29-2025' and '11-02-2025'
--   s.sched_id in( 1283542,
--1283543,
--1283544,
--1283535,
--1283536,
--1283537,
--1283531,
--1283538,
--1283539,
--1283540,
--1283532,
--1283533,
--1283534)
--and s.sched_type = 'r'
--and s.level_code not in ('mlb')
--and ap.pitch_type in ('ff')
and s.level_code in ('bbc') --, 'afx', 'aax')
--and ap.pitch_type is not null
--and t.org_abbrev = 'hou' 
--and ap.pitch_result in ('hit_into_play', 'hit_into_play_no_out', 'hit_into_play_score') 
--and p.last_name = 'walker'-- and p.first_name = 'tate'
--and (sc.con_loc_axis * 12) >= 4.0 and (sc.con_loc_axis * 12) <= 8.0 --or (90 - DEGREES(ACOS(sc.batvz_con/sqrt(power(sc.batvx_con,2)+power(sc.batvy_con,2)+power(sc.batvz_con,2)))) >= 10))
--and pht.hit_launch_angle >= -10 and pht.hit_launch_angle <= 45 
--and pht.hit_launch_speed >= 105 and pht.hit_launch_speed <= 108 
--and pht.hit_launch_angle > 20 and pht.hit_launch_angle < 28
--and h.hit_initial_contact_point_y >2 and h.hit_initial_contact_point_y < 2.5
--and ap.batter_id in (1257254)
and last_name like 'Frey%'
and first_name like 'Ethan%'

order by
--con_loc_perp desc;
PeakBatSpd desc;
--name asc;
--level_display asc, inn asc, outs asc;
 --BatSpd@Con desc;
 --sched_date desc;

 

