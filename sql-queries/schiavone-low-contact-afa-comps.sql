-- ====================================================================
-- Schiavone low-contact AFA comps — refreshed May 15 2026 for Sam Niedorf
-- ====================================================================
-- Driver: Jason Schiavone (groundcontrol_id 218498) currently at AFA
-- with low contact rate.
--
-- Question: of hitters who put up sub-60% Ctct% at A+ (AFA) from
-- 2016-2026 with at least 50 PA, which ones ever reached MLB?
--
-- Pool filters:
--   level_code = 'afa'  (A+ / High-A only — AFX = Low-A excluded)
--   sched_type = 'R'    (regular season only)
--   year BETWEEN 2016 AND 2026
--   pv.pitch_id > 0     (exclude junk pitches)
--   AFA pa >= 50 across the window
--   AFA Ctct% < 60   (Schiavone himself bypasses this gate — see ORDER BY + WHERE)
--
-- "Reached MLB" = took at least one MLB regular-season pitch in
-- Pitches_View. Loose floor — includes cup-of-coffee callups. Tighten
-- with `mlb_pitches_seen >= N` if needed.
--
-- Metrics shown per batter, AT EACH LEVEL (afa + mlb where applicable):
--   - Ctct%      (canonical Barrelsville form, hitter_kpi_data.py:753-756)
--   - Dmg%       (sigmoid damage formula, EV-misread-cleaned, LA-NULL-safe)
--   - gcOBA      (multi-component composite, MLB OBP scaling per production
--                 hitter_kpi_data.py:1339-1350 + postgame_data.py:2001)
--
-- Changes from prior version (May 15 2026):
--   1. league_obp is now DYNAMIC — pulls MLB OBP from mlbam.YTD_Team_Batting_Stats
--      (current season, falls back to prior season per GC2 rule). Was hardcoded 0.317.
--   2. EV misread filter ADDED via canonical EV_MISREAD_CTE pattern (database.py:268).
--      Per-batter P95 EV cap on BIPs with EV>=100 AND LA<-35. Eliminates the ~0.1% pitch
--      bias from Hawkeye misreads on weak choppers / popups.
--   3. LA-NULL leak FIXED — Dmg% BIP filter now requires hit_vertical_angle IS NOT NULL.
--      Was using ISNULL(LA, 0) which leaked NULL-LA BIPs into the avg at ~0.001 each.
--      Barrel filter unchanged — already safe because its `> 4` test excludes NULL-coerced-to-0.
-- ====================================================================

-- Dynamic MLB OBP — production scaling factor for gcOBA across all levels.
-- Tries current season first, falls back to prior season if not populated yet.
DECLARE @league_obp DECIMAL(4,3) = (
    SELECT TOP 1 obp
    FROM mlbam.YTD_Team_Batting_Stats
    WHERE season IN (2026, 2025)
      AND level = 'mlb'
      AND gm_type = 'r'
      AND split_id = 0
      AND team_id = 0
      AND obp IS NOT NULL
    ORDER BY season DESC
);

WITH
-- ---- Per-batter P95 EV (EV misread filter) — canonical EV_MISREAD_CTE
-- Multi-year window matches comp pool. Apply via LEFT JOIN below + the
-- exclusion clause inside damage / barrel / avg_useful_ev CASE WHENs:
--   AND NOT (h.hit_exit_speed >= 100 AND h.hit_vertical_angle < -35
--            AND h.hit_exit_speed > ISNULL(bp95.p95_ev, 105))
batter_ev_p95 AS (
    SELECT sub.batter_id, sub.p95_ev
    FROM (
        SELECT DISTINCT pv2.batter_id,
               PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY h2.hit_exit_speed)
                   OVER (PARTITION BY pv2.batter_id) AS p95_ev,
               COUNT(*) OVER (PARTITION BY pv2.batter_id) AS n_bip
        FROM Astros.Pitches_View pv2
        JOIN Astros.Schedule_View sv2 ON pv2.sched_id = sv2.sched_id
        JOIN Astros.Hits h2 ON h2.sched_id = pv2.sched_id AND h2.pitch_id = pv2.pitch_id
        WHERE pv2.pitch_result_id IN (12, 13, 14)
          AND h2.hit_exit_speed > 0 AND h2.hit_exit_speed < 125
          AND pv2.pitch_id > 0
          AND sv2.sched_type IN ('R', 'S', 'E')
          AND sv2.year BETWEEN 2016 AND 2026
          AND (sv2.level_code IN ('mlb','aaa','aax','afa','afx')
               OR sv2.gc2_level_code IN ('rok','dsl'))
    ) sub
    WHERE sub.n_bip >= 20
),

-- ---- AFA pitch-level stats (barrel, n_bip_tracked, avg_useful_ev, dmg_raw mean)
afa_pitch AS (
    SELECT
        pv.batter_id,
        SUM(CASE WHEN pv.pitch_result_id IN (12,13,14)
                      AND h.hit_exit_speed > 0 AND h.hit_exit_speed < 125
                      AND NOT (h.hit_exit_speed >= 100
                               AND h.hit_vertical_angle < -35
                               AND h.hit_exit_speed > ISNULL(bp95.p95_ev, 105))
                      AND (ev2.hit_trajectory_id NOT IN (2,3,4) OR ev2.hit_trajectory_id IS NULL)
                      AND h.hit_exit_speed * 1.5 - ISNULL(h.hit_vertical_angle, 0) >= 117
                      AND h.hit_exit_speed + ISNULL(h.hit_vertical_angle, 0) >= 124
                      AND h.hit_exit_speed >= 98
                      AND ISNULL(h.hit_vertical_angle, 0) > 4
                      AND ISNULL(h.hit_vertical_angle, 0) < 50
                 THEN 1 ELSE 0 END) AS n_barrel,
        SUM(CASE WHEN pv.pitch_result_id IN (12,13,14)
                      AND h.hit_exit_speed > 0 AND h.hit_exit_speed < 125
                      AND NOT (h.hit_exit_speed >= 100
                               AND h.hit_vertical_angle < -35
                               AND h.hit_exit_speed > ISNULL(bp95.p95_ev, 105))
                      AND (ev2.hit_trajectory_id NOT IN (2,3,4) OR ev2.hit_trajectory_id IS NULL)
                 THEN 1 ELSE 0 END) AS n_bip_tracked,
        AVG(CASE WHEN pv.pitch_result_id IN (12,13,14)
                      AND h.hit_exit_speed > 0 AND h.hit_exit_speed < 125
                      AND NOT (h.hit_exit_speed >= 100
                               AND h.hit_vertical_angle < -35
                               AND h.hit_exit_speed > ISNULL(bp95.p95_ev, 105))
                      AND (ev2.hit_trajectory_id NOT IN (2,3,4) OR ev2.hit_trajectory_id IS NULL)
                 THEN h.hit_useful_exit_speed END) AS avg_useful_ev,
        AVG(CASE WHEN pv.pitch_result_id IN (12,13,14)
                      AND h.hit_exit_speed > 0 AND h.hit_exit_speed < 125
                      AND NOT (h.hit_exit_speed >= 100
                               AND h.hit_vertical_angle < -35
                               AND h.hit_exit_speed > ISNULL(bp95.p95_ev, 105))
                      AND (ev2.hit_trajectory_id NOT IN (2,3,4) OR ev2.hit_trajectory_id IS NULL)
                      AND h.hit_vertical_angle IS NOT NULL          -- LA-NULL fix
                 THEN
                    1.6 * POWER(1.3,
                        COS(-0.34) * (h.hit_exit_speed - 98.0)
                        - SIN(-0.34) * (h.hit_vertical_angle - 27.0)
                        - 0.02 * POWER(
                            2 + SIN(-0.34) * (h.hit_exit_speed - 98.0)
                            + COS(-0.34) * (h.hit_vertical_angle - 27.0), 2)
                    ) / (7.0 + POWER(1.3,
                        COS(-0.34) * (h.hit_exit_speed - 98.0)
                        - SIN(-0.34) * (h.hit_vertical_angle - 27.0)
                        - 0.02 * POWER(
                            2 + SIN(-0.34) * (h.hit_exit_speed - 98.0)
                            + COS(-0.34) * (h.hit_vertical_angle - 27.0), 2)
                    ))
                 END) AS dmg_raw_mean
    FROM Astros.Pitches_View pv
    JOIN Astros.Schedule_View sv ON pv.sched_id = sv.sched_id
    LEFT JOIN Astros.Hits h ON pv.sched_id = h.sched_id AND pv.pitch_id = h.pitch_id
    LEFT JOIN Astros.Events_View ev2
        ON pv.sched_id = ev2.sched_id AND pv.ab_event_id = ev2.event_id
    LEFT JOIN batter_ev_p95 bp95 ON bp95.batter_id = pv.batter_id
    WHERE sv.level_code = 'afa'
      AND sv.sched_type = 'R'
      AND sv.year BETWEEN 2016 AND 2026
      AND pv.pitch_id > 0
    GROUP BY pv.batter_id
),

-- ---- AFA per-PA stats (pa, so, bb, ibb, hbp) on PA-ending pitch
afa_pa AS (
    SELECT
        pv.batter_id,
        SUM(CAST(ev.pa AS int)) + SUM(CAST(ISNULL(ev.ibb, 0) AS int)) AS pa,
        SUM(CAST(ev.so  AS int))                                       AS so,
        SUM(CAST(ev.bb  AS int))                                       AS bb,
        SUM(CAST(ISNULL(ev.ibb, 0) AS int))                            AS ibb,
        SUM(CAST(ISNULL(ev.hbp, 0) AS int))                            AS hbp
    FROM Astros.Pitches_View pv
    JOIN Astros.Schedule_View sv ON pv.sched_id = sv.sched_id
    JOIN Astros.Events_View ev
        ON pv.sched_id = ev.sched_id AND pv.cur_event_id = ev.event_id
    WHERE sv.level_code = 'afa'
      AND sv.sched_type = 'R'
      AND sv.year BETWEEN 2016 AND 2026
      AND pv.pitch_id > 0
    GROUP BY pv.batter_id
),

-- ---- AFA swing distribution (whiffs-per-PA buckets, used by gcOBA)
-- swing_count = whiffs in PA (pitch_result_id IN (10,22,23) per
-- canonical _SWING_DIST_QUERY in hitter_kpi_data.py:961)
afa_pa_swings AS (
    SELECT pv.batter_id, pv.sched_id, pv.ab_event_id,
           SUM(CASE WHEN pv.pitch_result_id IN (10,22,23) THEN 1 ELSE 0 END) AS swing_count
    FROM Astros.Pitches_View pv
    JOIN Astros.Schedule_View sv ON pv.sched_id = sv.sched_id
    JOIN Astros.Events_View ev
        ON pv.sched_id = ev.sched_id AND pv.ab_event_id = ev.event_id
    WHERE sv.level_code = 'afa'
      AND sv.sched_type = 'R'
      AND sv.year BETWEEN 2016 AND 2026
      AND pv.pitch_id > 0
      AND (CAST(ev.pa AS int) = 1 OR CAST(ISNULL(ev.ibb, 0) AS int) = 1)
    GROUP BY pv.batter_id, pv.sched_id, pv.ab_event_id
),
afa_swing_dist AS (
    SELECT batter_id,
           1.0 * SUM(CASE WHEN swing_count = 0 THEN 1 ELSE 0 END) / COUNT(*) AS zero_sw,
           1.0 * SUM(CASE WHEN swing_count = 1 THEN 1 ELSE 0 END) / COUNT(*) AS one_sw,
           1.0 * SUM(CASE WHEN swing_count = 2 THEN 1 ELSE 0 END) / COUNT(*) AS two_sw,
           1.0 * SUM(CASE WHEN swing_count >= 3 THEN 1 ELSE 0 END) / COUNT(*) AS three_plus_sw
    FROM afa_pa_swings
    GROUP BY batter_id
),

-- ---- AFA Ctct% pieces (contacts, swings)
afa_swings AS (
    SELECT
        pv.batter_id,
        SUM(CASE WHEN (pv.did_swing = 1
                       OR (pv.ignore_flag = 1 AND pv.did_swing IS NULL
                           AND pv.pitch_result_id IN (7,8,9,10,12,13,14,16,18,19,20,21,22,23,25)))
                  AND pv.pitch_result_id NOT IN (10,16,21,22,23,25)
                 THEN 1 ELSE 0 END) AS contacts,
        SUM(CASE WHEN (pv.did_swing = 1
                       OR (pv.ignore_flag = 1 AND pv.did_swing IS NULL
                           AND pv.pitch_result_id IN (7,8,9,10,12,13,14,16,18,19,20,21,22,23,25)))
                 THEN 1 ELSE 0 END) AS swings,
        MIN(sv.year) AS first_afa_year,
        MAX(sv.year) AS last_afa_year
    FROM Astros.Pitches_View pv
    JOIN Astros.Schedule_View sv ON pv.sched_id = sv.sched_id
    WHERE sv.level_code = 'afa'
      AND sv.sched_type = 'R'
      AND sv.year BETWEEN 2016 AND 2026
      AND pv.pitch_id > 0
    GROUP BY pv.batter_id
),

-- ---- MLB pitch-level stats (same shape as afa_pitch, level='mlb', any year)
mlb_pitch AS (
    SELECT
        pv.batter_id,
        SUM(CASE WHEN pv.pitch_result_id IN (12,13,14)
                      AND h.hit_exit_speed > 0 AND h.hit_exit_speed < 125
                      AND NOT (h.hit_exit_speed >= 100
                               AND h.hit_vertical_angle < -35
                               AND h.hit_exit_speed > ISNULL(bp95.p95_ev, 105))
                      AND (ev2.hit_trajectory_id NOT IN (2,3,4) OR ev2.hit_trajectory_id IS NULL)
                      AND h.hit_exit_speed * 1.5 - ISNULL(h.hit_vertical_angle, 0) >= 117
                      AND h.hit_exit_speed + ISNULL(h.hit_vertical_angle, 0) >= 124
                      AND h.hit_exit_speed >= 98
                      AND ISNULL(h.hit_vertical_angle, 0) > 4
                      AND ISNULL(h.hit_vertical_angle, 0) < 50
                 THEN 1 ELSE 0 END) AS n_barrel,
        SUM(CASE WHEN pv.pitch_result_id IN (12,13,14)
                      AND h.hit_exit_speed > 0 AND h.hit_exit_speed < 125
                      AND NOT (h.hit_exit_speed >= 100
                               AND h.hit_vertical_angle < -35
                               AND h.hit_exit_speed > ISNULL(bp95.p95_ev, 105))
                      AND (ev2.hit_trajectory_id NOT IN (2,3,4) OR ev2.hit_trajectory_id IS NULL)
                 THEN 1 ELSE 0 END) AS n_bip_tracked,
        AVG(CASE WHEN pv.pitch_result_id IN (12,13,14)
                      AND h.hit_exit_speed > 0 AND h.hit_exit_speed < 125
                      AND NOT (h.hit_exit_speed >= 100
                               AND h.hit_vertical_angle < -35
                               AND h.hit_exit_speed > ISNULL(bp95.p95_ev, 105))
                      AND (ev2.hit_trajectory_id NOT IN (2,3,4) OR ev2.hit_trajectory_id IS NULL)
                 THEN h.hit_useful_exit_speed END) AS avg_useful_ev,
        AVG(CASE WHEN pv.pitch_result_id IN (12,13,14)
                      AND h.hit_exit_speed > 0 AND h.hit_exit_speed < 125
                      AND NOT (h.hit_exit_speed >= 100
                               AND h.hit_vertical_angle < -35
                               AND h.hit_exit_speed > ISNULL(bp95.p95_ev, 105))
                      AND (ev2.hit_trajectory_id NOT IN (2,3,4) OR ev2.hit_trajectory_id IS NULL)
                      AND h.hit_vertical_angle IS NOT NULL          -- LA-NULL fix
                 THEN
                    1.6 * POWER(1.3,
                        COS(-0.34) * (h.hit_exit_speed - 98.0)
                        - SIN(-0.34) * (h.hit_vertical_angle - 27.0)
                        - 0.02 * POWER(
                            2 + SIN(-0.34) * (h.hit_exit_speed - 98.0)
                            + COS(-0.34) * (h.hit_vertical_angle - 27.0), 2)
                    ) / (7.0 + POWER(1.3,
                        COS(-0.34) * (h.hit_exit_speed - 98.0)
                        - SIN(-0.34) * (h.hit_vertical_angle - 27.0)
                        - 0.02 * POWER(
                            2 + SIN(-0.34) * (h.hit_exit_speed - 98.0)
                            + COS(-0.34) * (h.hit_vertical_angle - 27.0), 2)
                    ))
                 END) AS dmg_raw_mean
    FROM Astros.Pitches_View pv
    JOIN Astros.Schedule_View sv ON pv.sched_id = sv.sched_id
    LEFT JOIN Astros.Hits h ON pv.sched_id = h.sched_id AND pv.pitch_id = h.pitch_id
    LEFT JOIN Astros.Events_View ev2
        ON pv.sched_id = ev2.sched_id AND pv.ab_event_id = ev2.event_id
    LEFT JOIN batter_ev_p95 bp95 ON bp95.batter_id = pv.batter_id
    WHERE sv.level_code = 'mlb'
      AND sv.sched_type = 'R'
      AND pv.pitch_id > 0
    GROUP BY pv.batter_id
),
mlb_pa AS (
    SELECT
        pv.batter_id,
        MIN(sv.year)                                                   AS first_mlb_year,
        SUM(CAST(ev.pa AS int)) + SUM(CAST(ISNULL(ev.ibb, 0) AS int)) AS pa,
        SUM(CAST(ev.so  AS int))                                       AS so,
        SUM(CAST(ev.bb  AS int))                                       AS bb,
        SUM(CAST(ISNULL(ev.ibb, 0) AS int))                            AS ibb,
        SUM(CAST(ISNULL(ev.hbp, 0) AS int))                            AS hbp,
        COUNT(*)                                                        AS mlb_pitches_seen
    FROM Astros.Pitches_View pv
    JOIN Astros.Schedule_View sv ON pv.sched_id = sv.sched_id
    JOIN Astros.Events_View ev
        ON pv.sched_id = ev.sched_id AND pv.cur_event_id = ev.event_id
    WHERE sv.level_code = 'mlb'
      AND sv.sched_type = 'R'
      AND pv.pitch_id > 0
    GROUP BY pv.batter_id
),
mlb_pa_swings AS (
    SELECT pv.batter_id, pv.sched_id, pv.ab_event_id,
           SUM(CASE WHEN pv.pitch_result_id IN (10,22,23) THEN 1 ELSE 0 END) AS swing_count
    FROM Astros.Pitches_View pv
    JOIN Astros.Schedule_View sv ON pv.sched_id = sv.sched_id
    JOIN Astros.Events_View ev
        ON pv.sched_id = ev.sched_id AND pv.ab_event_id = ev.event_id
    WHERE sv.level_code = 'mlb'
      AND sv.sched_type = 'R'
      AND pv.pitch_id > 0
      AND (CAST(ev.pa AS int) = 1 OR CAST(ISNULL(ev.ibb, 0) AS int) = 1)
    GROUP BY pv.batter_id, pv.sched_id, pv.ab_event_id
),
mlb_swing_dist AS (
    SELECT batter_id,
           1.0 * SUM(CASE WHEN swing_count = 0 THEN 1 ELSE 0 END) / COUNT(*) AS zero_sw,
           1.0 * SUM(CASE WHEN swing_count = 1 THEN 1 ELSE 0 END) / COUNT(*) AS one_sw,
           1.0 * SUM(CASE WHEN swing_count = 2 THEN 1 ELSE 0 END) / COUNT(*) AS two_sw,
           1.0 * SUM(CASE WHEN swing_count >= 3 THEN 1 ELSE 0 END) / COUNT(*) AS three_plus_sw
    FROM mlb_pa_swings
    GROUP BY batter_id
)

SELECT
    s.batter_id,
    CONCAT(p.first_name, ' ', p.last_name)              AS player_name,
    p.bats,
    s.first_afa_year,
    s.last_afa_year,
    apa.pa                                              AS afa_pa,
    s.swings                                            AS afa_swings,

    -- AFA Ctct%
    CAST(100.0 * s.contacts / NULLIF(s.swings, 0)
         AS DECIMAL(5,2))                               AS afa_ctct_pct,

    -- AFA Damage% (mean of per-pitch sigmoid, only tracked non-bunt BIPs, EV-misread-cleaned, LA-NULL-safe)
    CAST(100.0 * ap.dmg_raw_mean AS DECIMAL(5,2))       AS afa_dmg_pct,

    -- AFA gcOBA — multi-component composite, MLB OBP scaling per production
    CAST(@league_obp * (
              0.50 * (CAST(apa.so AS float) / NULLIF(apa.pa, 0))
            + 1.49 * (CAST(apa.bb + apa.hbp AS float) / NULLIF(apa.pa, 0))
            + 0.11 * ISNULL(asd.zero_sw, 0.25)
            + 0.08 * ISNULL(asd.one_sw,  0.25)
            + (-0.10) * ISNULL(asd.two_sw,        0.25)
            + (-0.10) * ISNULL(asd.three_plus_sw, 0.25)
            + (CASE WHEN apa.pa > 0
                    THEN CAST(apa.pa - apa.so - apa.bb - apa.hbp AS float) / apa.pa
                    ELSE 0 END) * (
                  1.70 * (CAST(ap.n_barrel AS float) / NULLIF(ap.n_bip_tracked, 0))
                + 1.09 * (ISNULL(ap.avg_useful_ev, 0) / 100.0)
              )
         ) AS DECIMAL(5,3))                              AS afa_gcoba,

    -- MLB columns (NULL when batter never reached MLB)
    CASE WHEN mpa.batter_id IS NOT NULL THEN 'Yes'
         ELSE 'No' END                                   AS reached_mlb,
    mpa.first_mlb_year,
    mpa.pa                                               AS mlb_pa,
    mpa.mlb_pitches_seen,

    -- MLB Damage% (EV-misread-cleaned, LA-NULL-safe)
    CAST(100.0 * mp.dmg_raw_mean AS DECIMAL(5,2))        AS mlb_dmg_pct,

    -- MLB gcOBA — same MLB OBP scaling
    CAST(@league_obp * (
              0.50 * (CAST(mpa.so AS float) / NULLIF(mpa.pa, 0))
            + 1.49 * (CAST(mpa.bb + mpa.hbp AS float) / NULLIF(mpa.pa, 0))
            + 0.11 * ISNULL(msd.zero_sw, 0.25)
            + 0.08 * ISNULL(msd.one_sw,  0.25)
            + (-0.10) * ISNULL(msd.two_sw,        0.25)
            + (-0.10) * ISNULL(msd.three_plus_sw, 0.25)
            + (CASE WHEN mpa.pa > 0
                    THEN CAST(mpa.pa - mpa.so - mpa.bb - mpa.hbp AS float) / mpa.pa
                    ELSE 0 END) * (
                  1.70 * (CAST(mp.n_barrel AS float) / NULLIF(mp.n_bip_tracked, 0))
                + 1.09 * (ISNULL(mp.avg_useful_ev, 0) / 100.0)
              )
         ) AS DECIMAL(5,3))                              AS mlb_gcoba

FROM afa_swings    s
JOIN afa_pa        apa ON apa.batter_id = s.batter_id
LEFT JOIN afa_pitch       ap  ON ap.batter_id  = s.batter_id
LEFT JOIN afa_swing_dist  asd ON asd.batter_id = s.batter_id
LEFT JOIN Astros.Players  p   ON p.groundcontrol_id = s.batter_id
LEFT JOIN mlb_pa          mpa ON mpa.batter_id = s.batter_id
LEFT JOIN mlb_pitch       mp  ON mp.batter_id  = s.batter_id
LEFT JOIN mlb_swing_dist  msd ON msd.batter_id = s.batter_id

WHERE s.swings > 0
  AND (
        -- Schiavone bypasses both gates so he always shows
        s.batter_id = 218498
        OR (
            apa.pa >= 50
            AND 100.0 * s.contacts / NULLIF(s.swings, 0) < 60
        )
      )

ORDER BY
    CASE WHEN s.batter_id = 218498 THEN 0 ELSE 1 END,   -- Schiavone first
    reached_mlb DESC,                                    -- MLB grads next
    afa_ctct_pct ASC,                                    -- worst contact at top
    afa_pa DESC;
