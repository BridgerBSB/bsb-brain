-- Sam's ask (6/02): In the last 5 years, how many players age <= 18
-- have wRC+'d 120 or more in the first two months of a full season
-- (A, A+, AA, AAA, MLB)? Who are they?
--
-- Output: count + per-player list with wOBA, gcOBA, wRC+, Age.
--
-- Scope:
--   * Years: 2022-2026.
--   * Months: April + May (MONTH IN (4, 5)).
--   * Levels: 'mlb','aaa','aax','afa','afx' — no DSL, no FCL.
--   * sched_type = 'R'.
--   * Age <= 18 (one-decimal) as of June 30 of season year (standard
--     prospect-age convention).
--   * Min 50 PA per (player, year, level) row.
--
-- Methodology:
--   * Per-PA wOBA weights via MLBAM.Schedule -> Guts.woba_lwts on
--     year+league (matches WOBA_WEIGHTS_JOIN canonical pattern). Each
--     PA gets its game's league weights.
--   * wOBA denom = AB + BB - IBB + HBP + SF (FanGraphs / canonical).
--   * wRC+ env = AVG(wOBA), AVG(wOBA_scale), AVG(runs_per_pa) per
--     (year, level_code) from Guts.woba_lwts.
--   * wRC+ formula = 100 * ((wOBA - lg_wOBA) / wOBA_scale + rpa) / rpa.
--   * gcOBA = MLB_OBP * (0.50*K + 1.49*BB+HBP + 0.11*zero_sw + 0.08*one_sw
--     - 0.10*two_sw - 0.10*three_plus_sw + bip_rate*(1.70*barrel +
--     1.09*useful_ev/100)) per gc2-metrics.md formula.
--   * gcOBA whiff codes = (10, 22, 23) gumbo S/W/T per rule 1.
--   * gcOBA gates on (pa=1 OR ibb=1) for swing distribution per rule 2.
--   * IBB included in BB+HBP rate per rule 4. PA includes IBB per rule 5.
--   * Barrel = GC2 linear (5-condition AND), bunts excluded per rule 6+7.
--   * MLB OBP from mlbam.YTD_Team_Batting_Stats (level='mlb',
--     gm_type='r', split_id=0, team_id=0) per rule 8.
--   * No EV misread filter in gcOBA BIP per rule 9.
--
-- A player who hit at multiple levels in the Apr+May window shows up
-- as multiple rows (one per level), each with that level's wRC+ env.

IF OBJECT_ID('tempdb..#qualifying') IS NOT NULL DROP TABLE #qualifying;

WITH batter_metrics AS (
    SELECT
        pv.batter_id,
        sv.year,
        sv.level_code,
        SUM(CASE WHEN pv.cur_event_id IS NOT NULL
                 THEN CAST(ISNULL(cev.pa, 0) AS int)
                    + CAST(ISNULL(cev.ibb, 0) AS int)
                 ELSE 0 END) AS pa,
        SUM(CASE WHEN pv.cur_event_id IS NOT NULL
                 THEN CAST(ISNULL(cev.so, 0) AS int) ELSE 0 END) AS so,
        SUM(CASE WHEN pv.cur_event_id IS NOT NULL
                 THEN CAST(ISNULL(cev.bb, 0) AS int) ELSE 0 END) AS bb,
        SUM(CASE WHEN pv.cur_event_id IS NOT NULL
                 THEN CAST(ISNULL(cev.hbp, 0) AS int) ELSE 0 END) AS hbp,
        SUM(CASE WHEN pv.cur_event_id IS NOT NULL
                  AND CAST(ISNULL(cev.pa, 0) AS int) = 1
                  AND CAST(ISNULL(cev.ibb, 0) AS int) = 0
                 THEN
                    CAST(ISNULL(cev.bb, 0) AS float) * woba.woba_bb
                    + CAST(ISNULL(cev.hbp, 0) AS float) * woba.woba_hb
                    + CAST(ISNULL(cev.[1b], 0) AS float) * woba.woba_1b
                    + CAST(ISNULL(cev.[2b], 0) AS float) * woba.woba_2b
                    + CAST(ISNULL(cev.[3b], 0) AS float) * woba.woba_3b
                    + CAST(ISNULL(cev.hr, 0) AS float) * woba.woba_hr
                 ELSE 0.0 END) AS woba_numer,
        SUM(CASE WHEN pv.cur_event_id IS NOT NULL THEN
                    CAST(ISNULL(cev.ab, 0) AS int)
                    + CAST(ISNULL(cev.bb, 0) AS int)
                    - CAST(ISNULL(cev.ibb, 0) AS int)
                    + CAST(ISNULL(cev.hbp, 0) AS int)
                    + CAST(ISNULL(cev.sf, 0) AS int)
                 ELSE 0 END) AS woba_denom,
        SUM(CASE WHEN pv.pitch_result_id IN (12, 13, 14)
                  AND h.hit_exit_speed IS NOT NULL
                  AND h.hit_exit_speed > 0 AND h.hit_exit_speed < 125
                  AND (aev.hit_trajectory_id NOT IN (2, 3, 4)
                       OR aev.hit_trajectory_id IS NULL)
                 THEN 1 ELSE 0 END) AS n_bip_tracked,
        SUM(CASE WHEN pv.pitch_result_id IN (12, 13, 14)
                  AND h.hit_exit_speed IS NOT NULL
                  AND h.hit_exit_speed > 0 AND h.hit_exit_speed < 125
                  AND (aev.hit_trajectory_id NOT IN (2, 3, 4)
                       OR aev.hit_trajectory_id IS NULL)
                  AND h.hit_exit_speed * 1.5 - ISNULL(h.hit_vertical_angle, 0) >= 117
                  AND h.hit_exit_speed + ISNULL(h.hit_vertical_angle, 0) >= 124
                  AND h.hit_exit_speed >= 98
                  AND ISNULL(h.hit_vertical_angle, 0) > 4
                  AND ISNULL(h.hit_vertical_angle, 0) < 50
                 THEN 1 ELSE 0 END) AS n_barrel,
        AVG(CASE WHEN pv.pitch_result_id IN (12, 13, 14)
                  AND h.hit_exit_speed IS NOT NULL
                  AND h.hit_exit_speed > 0 AND h.hit_exit_speed < 125
                  AND (aev.hit_trajectory_id NOT IN (2, 3, 4)
                       OR aev.hit_trajectory_id IS NULL)
                 THEN h.hit_useful_exit_speed END) AS avg_useful_ev
    FROM Astros.Pitches_View pv
    JOIN Astros.Schedule_View sv
        ON sv.sched_id = pv.sched_id
    JOIN Astros.Events_View aev
        ON aev.sched_id = pv.sched_id AND aev.event_id = pv.ab_event_id
    LEFT JOIN Astros.Events_View cev
        ON cev.sched_id = pv.sched_id AND cev.event_id = pv.cur_event_id
    LEFT JOIN MLBAM.Schedule ms
        ON ms.game_pk = sv.mlbam_game_pk
    LEFT JOIN (
        SELECT year, league,
            AVG(woba_bb) AS woba_bb, AVG(woba_hb) AS woba_hb,
            AVG(woba_1b) AS woba_1b, AVG(woba_2b) AS woba_2b,
            AVG(woba_3b) AS woba_3b, AVG(woba_hr) AS woba_hr
        FROM Guts.woba_lwts
        GROUP BY year, league
    ) woba
        ON woba.year = sv.year AND woba.league = ms.league
    LEFT JOIN Astros.Hits h
        ON h.sched_id = pv.sched_id AND h.pitch_id = pv.pitch_id
    WHERE sv.year BETWEEN 2022 AND 2026
      AND sv.sched_type = 'R'
      AND sv.level_code IN ('mlb','aaa','aax','afa','afx')
      AND MONTH(sv.sched_date) IN (4, 5)
      AND pv.pitch_id > 0
    GROUP BY pv.batter_id, sv.year, sv.level_code
),
pa_swings AS (
    SELECT
        pv.batter_id, sv.year, sv.level_code,
        pv.sched_id, pv.ab_event_id,
        SUM(CASE WHEN pv.pitch_result_id IN (10, 22, 23)
                 THEN 1 ELSE 0 END) AS whiffs_in_pa
    FROM Astros.Pitches_View pv
    JOIN Astros.Schedule_View sv ON sv.sched_id = pv.sched_id
    JOIN Astros.Events_View ev
        ON ev.sched_id = pv.sched_id AND ev.event_id = pv.ab_event_id
    WHERE sv.year BETWEEN 2022 AND 2026
      AND sv.sched_type = 'R'
      AND sv.level_code IN ('mlb','aaa','aax','afa','afx')
      AND MONTH(sv.sched_date) IN (4, 5)
      AND pv.pitch_id > 0
      AND (CAST(ev.pa AS int) = 1 OR CAST(ISNULL(ev.ibb, 0) AS int) = 1)
    GROUP BY pv.batter_id, sv.year, sv.level_code, pv.sched_id, pv.ab_event_id
),
swing_dist AS (
    SELECT
        batter_id, year, level_code,
        1.0 * SUM(CASE WHEN whiffs_in_pa = 0 THEN 1 ELSE 0 END) / COUNT(*) AS zero_sw,
        1.0 * SUM(CASE WHEN whiffs_in_pa = 1 THEN 1 ELSE 0 END) / COUNT(*) AS one_sw,
        1.0 * SUM(CASE WHEN whiffs_in_pa = 2 THEN 1 ELSE 0 END) / COUNT(*) AS two_sw,
        1.0 * SUM(CASE WHEN whiffs_in_pa >= 3 THEN 1 ELSE 0 END) / COUNT(*) AS three_plus_sw
    FROM pa_swings
    GROUP BY batter_id, year, level_code
),
level_env AS (
    SELECT year, level_code,
        AVG(wOBA) AS lg_woba, AVG(wOBA_scale) AS woba_scale, AVG(runs_per_pa) AS runs_per_pa
    FROM Guts.woba_lwts
    WHERE year BETWEEN 2022 AND 2026
      AND level_code IN ('mlb','aaa','aax','afa','afx')
    GROUP BY year, level_code
),
mlb_obp AS (
    SELECT season AS year, obp
    FROM mlbam.YTD_Team_Batting_Stats
    WHERE level = 'mlb'
      AND gm_type = 'r'
      AND split_id = 0
      AND team_id = 0
      AND season BETWEEN 2022 AND 2026
)
SELECT
    bm.batter_id,
    pl.first_name,
    pl.last_name,
    bm.year,
    bm.level_code,
    bm.pa,
    bm.woba_numer / NULLIF(bm.woba_denom, 0) AS woba,
    100.0 * (
        (bm.woba_numer / NULLIF(bm.woba_denom, 0) - le.lg_woba)
        / NULLIF(le.woba_scale, 0)
        + le.runs_per_pa
    ) / NULLIF(le.runs_per_pa, 0) AS wrc_plus,
    mo.obp * (
        0.50 * (bm.so * 1.0 / NULLIF(bm.pa, 0))
        + 1.49 * ((bm.bb + bm.hbp) * 1.0 / NULLIF(bm.pa, 0))
        + 0.11 * COALESCE(sd.zero_sw, 0)
        + 0.08 * COALESCE(sd.one_sw, 0)
        + (-0.10) * COALESCE(sd.two_sw, 0)
        + (-0.10) * COALESCE(sd.three_plus_sw, 0)
        + CASE WHEN bm.pa - bm.so - bm.bb - bm.hbp > 0
               THEN (bm.pa - bm.so - bm.bb - bm.hbp) * 1.0 / bm.pa
               ELSE 0 END
          * (
              1.70 * CASE WHEN bm.n_bip_tracked > 0
                          THEN bm.n_barrel * 1.0 / bm.n_bip_tracked
                          ELSE 0 END
              + 1.09 * (COALESCE(bm.avg_useful_ev, 0) / 100.0)
          )
    ) AS gcoba,
    CAST(FLOOR(DATEDIFF(DAY, pl.birthdate, DATEFROMPARTS(bm.year, 6, 30))
              * 10.0 / 365.25) / 10.0 AS DECIMAL(4,1)) AS age
INTO #qualifying
FROM batter_metrics bm
JOIN level_env le
    ON le.year = bm.year AND le.level_code = bm.level_code
LEFT JOIN swing_dist sd
    ON sd.batter_id = bm.batter_id
   AND sd.year = bm.year
   AND sd.level_code = bm.level_code
LEFT JOIN mlb_obp mo
    ON mo.year = bm.year
JOIN Astros.Players pl
    ON pl.groundcontrol_id = bm.batter_id
WHERE bm.woba_denom > 0
  AND bm.pa >= 50;


-- ============================================================
-- Result Set 1: the count
-- ============================================================
SELECT
    COUNT(*)                     AS [#PlayerSeasons],
    COUNT(DISTINCT batter_id)    AS [#Distinct Players]
FROM #qualifying
WHERE age < 19.0
  AND wrc_plus >= 120;


-- ============================================================
-- Result Set 2: the players
-- ============================================================
SELECT
    CONCAT(first_name, ' ', last_name)              AS [Player],
    batter_id                                       AS [GC ID],
    year                                            AS [Year],
    CASE level_code
        WHEN 'mlb' THEN 'MLB'
        WHEN 'aaa' THEN 'AAA'
        WHEN 'aax' THEN 'AA'
        WHEN 'afa' THEN 'A+'
        WHEN 'afx' THEN 'A'
    END                                             AS [Level],
    age                                             AS [Age (June 30)],
    pa                                              AS [PA],
    CAST(woba     AS DECIMAL(5,3))                  AS [wOBA],
    CAST(gcoba    AS DECIMAL(5,3))                  AS [gcOBA],
    CAST(wrc_plus AS DECIMAL(5,0))                  AS [wRC+]
FROM #qualifying
WHERE age < 19.0
  AND wrc_plus >= 120
ORDER BY wrc_plus DESC;


DROP TABLE #qualifying;
