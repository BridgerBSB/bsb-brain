SELECT
    s.year,
    s.level_code AS level,
    pr.last_name + ', ' + pr.first_name AS player_name,
    SUM(CASE WHEN e.pa = 1 THEN 1 ELSE 0 END) AS tbf,
    p.bat_side,

    -- Rates / outcomes (percent: 0..100)
    CAST(AVG(CASE WHEN p.balls_before = 0 AND p.strikes_before = 1 THEN CASE WHEN ab.so = 1 THEN 100.0 ELSE 0.0 END END) AS DECIMAL(4,0)) AS so_01,
    CAST(AVG(CASE WHEN p.balls_before = 1 AND p.strikes_before = 0 THEN CASE WHEN ab.so = 1 THEN 100.0 ELSE 0.0 END END) AS DECIMAL(4,0)) AS so_10,
    CAST(AVG(CASE WHEN e.pa = 1 THEN CASE WHEN e.so = 1 THEN 100.0 ELSE 0.0 END END) AS DECIMAL(4,0)) AS sor,

    -- 1st pitch in-zone rate
    CAST(AVG(
        CASE WHEN p.ab_pitch_number = 1 AND p.strikes_before = 0 AND p.balls_before = 0
             THEN (CASE WHEN p.called_strike_chance_mlb <= 1.0
                        THEN 100.0 * p.called_strike_chance_mlb
                        ELSE p.called_strike_chance_mlb
                   END)
        END
    ) AS DECIMAL(5,2)) AS inZ_1p,

    CAST(AVG(CASE WHEN p.balls_before = 0 AND p.strikes_before = 1 THEN CASE WHEN ab.bb = 1 THEN 100.0 ELSE 0.0 END END) AS DECIMAL(4,0)) AS bb_01,
    CAST(AVG(CASE WHEN p.balls_before = 1 AND p.strikes_before = 0 THEN CASE WHEN ab.bb = 1 THEN 100.0 ELSE 0.0 END END) AS DECIMAL(4,0)) AS bb_10,

    -- 3-2 in-zone rate
    CAST(AVG(
        CASE WHEN p.balls_before = 3 AND p.strikes_before = 2
             THEN (CASE WHEN p.called_strike_chance_mlb <= 1.0
                        THEN 100.0 * p.called_strike_chance_mlb
                        ELSE p.called_strike_chance_mlb
                   END)
        END
    ) AS DECIMAL(5,2)) AS inZ_32,

    CAST(AVG(CASE WHEN e.bb = 1 THEN CASE WHEN p.strikes_before = 2 THEN 100.0 ELSE 0.0 END END) AS DECIMAL(4,0)) AS prop_bb_32,
    CAST(AVG(CASE WHEN e.pa = 1 THEN CASE WHEN e.bb = 1 THEN 100.0 ELSE 0.0 END END) AS DECIMAL(4,0)) AS bbr,

    -- Slugging in count states + overall
    CAST(AVG(CASE WHEN p.balls_before = 0 AND p.strikes_before = 1 AND ab.ab = 1
                  THEN CASE WHEN ab.[1b] = 1 THEN 1.0 WHEN ab.[2b] = 1 THEN 2.0
                            WHEN ab.[3b] = 1 THEN 3.0 WHEN ab.hr = 1 THEN 4.0 ELSE 0.0 END
             END) AS DECIMAL(5,3)) AS slg_01,

    CAST(AVG(CASE WHEN p.balls_before = 1 AND p.strikes_before = 0 AND ab.ab = 1
                  THEN CASE WHEN ab.[1b] = 1 THEN 1.0 WHEN ab.[2b] = 1 THEN 2.0
                            WHEN ab.[3b] = 1 THEN 3.0 WHEN ab.hr = 1 THEN 4.0 ELSE 0.0 END
             END) AS DECIMAL(5,3)) AS slg_10,

    CAST(AVG(CASE WHEN e.ab = 1
                  THEN CASE WHEN e.[1b] = 1 THEN 1.0 WHEN e.[2b] = 1 THEN 2.0
                            WHEN e.[3b] = 1 THEN 3.0 WHEN e.hr = 1 THEN 4.0 ELSE 0.0 END
             END) AS DECIMAL(5,3)) AS slg,

    CAST(AVG(CASE WHEN (COALESCE(e.pa, 0) = 0 OR e.so = 1) AND p.ab_pitch_number = 3
                  THEN CASE WHEN p.strikes_after >= 2 THEN 100.0 ELSE 0.0 END
             END) AS DECIMAL(4,0)) AS R2K,

    CAST(AVG(CASE WHEN p.strikes_before = 2 AND p.balls_before < 3
                  THEN CASE WHEN COALESCE(e.so, 0) = 1 THEN 100.0 ELSE 0.0 END
             END) AS DECIMAL(4,0)) AS kill_rate,

    CAST(AVG(CASE WHEN r.did_swing = 1
                  THEN CASE WHEN p.pitch_result_id IN (22, 23, 10) THEN 100.0 ELSE 0.0 END
             END) AS DECIMAL(4,0)) AS whiff,

    CAST(AVG(CASE WHEN r.did_swing = 1 AND p.strikes_before = 2 AND p.balls_before < 3
                  THEN CASE WHEN p.pitch_result_id IN (22, 23, 10) THEN 100.0 ELSE 0.0 END
             END) AS DECIMAL(4,0)) AS whiff_2k,

    CAST(AVG(CASE WHEN p.swing_zone IN ('chase', 'waste') AND p.strikes_before < 2
                  THEN CASE WHEN r.did_swing = 1 THEN 100.0 ELSE 0.0 END
             END) AS DECIMAL(4,0)) AS chase_pre2k,

    CAST(AVG(CASE WHEN p.swing_zone IN ('chase', 'waste') AND p.strikes_before = 2
                  THEN CASE WHEN r.did_swing = 1 THEN 100.0 ELSE 0.0 END
             END) AS DECIMAL(4,0)) AS chase_2k,

    CAST(AVG(CASE WHEN p.strikes_before = 2 AND p.balls_before <> 3
                  THEN gg.fb_grade
             END) AS DECIMAL(15,1)) AS proj_2k,

    -- >>> NEW COLUMN: early win (counts: 0-0, 1-0, 0-1, 1-1) <<<
    CAST(
        (
            100.0 *
            SUM(
                CASE
                    WHEN ab.ab = 1
                         AND (
                              (p.balls_before = 0 AND p.strikes_before = 0) OR
                              (p.balls_before = 1 AND p.strikes_before = 0) OR
                              (p.balls_before = 0 AND p.strikes_before = 1) OR
                              (p.balls_before = 1 AND p.strikes_before = 1)
                         )
                         AND TRY_CONVERT(float, gg. pg_weak_contact_bip) < 95.0
                    THEN 1 ELSE 0
                END
            )
        ) / NULLIF(
            SUM(CASE WHEN ab.ab = 1 THEN 1 ELSE 0 END), 0
        )
    AS DECIMAL(5,2)) AS [early_win]

FROM astros.pitches_view p
JOIN astros.lk_pitch_results r
  ON r.pitch_result_id = p.pitch_result_id
JOIN astros.schedule_view s
  ON s.sched_id = p.sched_id
LEFT JOIN astros.Projections_Pitches_Grades gg
  ON p.pitch_id = gg.pitch_id
 AND p.sched_id = gg.sched_id
LEFT JOIN astros.events_view e
  ON e.sched_id = p.sched_id
 AND e.event_id = p.cur_event_id
 AND e.pa = 1
LEFT JOIN astros.events_view ab
  ON ab.sched_id = p.sched_id
 AND ab.event_id = p.ab_event_id
 AND ab.pa = 1
JOIN astros.players pr
  ON pr.groundcontrol_id = p.pitcher_id
LEFT JOIN mlbam.rosters ro
  ON ro.player_id = pr.mlbam_id
WHERE
    s.year = '2025'
and s.sched_type = 'r'
and p.bat_side = 'l'
and s.level_code IN ('mlb', 'aaa', 'aax', 'afa', 'afx')
and pr.first_name = 'hudson'
and pr.last_name = 'leach'

GROUP BY
    s.year,
    s.level_code,
    p.bat_side,
    pr.first_name,
    pr.last_name
HAVING
    SUM(CASE WHEN e.pa = 1 THEN 1 ELSE 0 END) > 0
ORDER BY
    s.level_code,
    so_10 DESC;