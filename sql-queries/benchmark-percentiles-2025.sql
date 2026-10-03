-- =============================================================================
-- 2025 PLAYER-LEVEL BENCHMARK PERCENTILES BY LEVEL
-- Each query computes per-player stats, then level-wide distribution (P10-P90)
-- Run on GCSQL02 → GroundControl2
-- =============================================================================

-- =============================================================================
-- 1. FB VELO — AVG fastball velocity per pitcher
--    FF + FT + SI (SI empty at MLB, populated at MiLB)
--    Volume gate: 50+ fastballs thrown
-- =============================================================================
WITH pitcher_velo AS (
    SELECT
        pv.pitcher_id,
        sv.gc2_level_code AS level_code,
        AVG(pv.release_speed) AS fb_velo,
        COUNT(*) AS n_fb
    FROM Astros.Pitches_View pv
    JOIN Astros.Schedule_View sv ON sv.sched_id = pv.sched_id
    WHERE pv.pitch_type IN ('FF', 'FT', 'SI')
      AND pv.pitch_id > 0
      AND sv.year = 2025
      AND sv.sched_type = 'R'
      AND sv.gc2_level_code IN ('mlb', 'aaa', 'aax', 'afa', 'afx', 'rok', 'dsl')
    GROUP BY pv.pitcher_id, sv.gc2_level_code
    HAVING COUNT(*) >= 50
)
SELECT DISTINCT
    level_code,
    CASE level_code WHEN 'mlb' THEN 1 WHEN 'aaa' THEN 2 WHEN 'aax' THEN 3
        WHEN 'afa' THEN 4 WHEN 'afx' THEN 5 WHEN 'rok' THEN 6
        WHEN 'dsl' THEN 7 END AS level_sort,
    COUNT(*) OVER (PARTITION BY level_code) AS n_pitchers,
    PERCENTILE_CONT(0.10) WITHIN GROUP (ORDER BY fb_velo)
        OVER (PARTITION BY level_code) AS p10,
    PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY fb_velo)
        OVER (PARTITION BY level_code) AS p25,
    PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY fb_velo)
        OVER (PARTITION BY level_code) AS p50,
    PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY fb_velo)
        OVER (PARTITION BY level_code) AS p75,
    PERCENTILE_CONT(0.90) WITHIN GROUP (ORDER BY fb_velo)
        OVER (PARTITION BY level_code) AS p90
FROM pitcher_velo
ORDER BY level_sort;


-- =============================================================================
-- 2. R2K% — Race to 2 Strikes per pitcher (GC2 formula)
--    Pitch 3: did pitcher have 2+ strikes?
--    Excludes PAs ending on pitch 3 with non-K contact
--    Volume gate: 30+ qualifying pitch-3 opportunities
-- =============================================================================
WITH pitcher_r2k AS (
    SELECT
        pv.pitcher_id,
        sv.gc2_level_code AS level_code,
        100.0 * AVG(
            CASE WHEN pv.ab_pitch_number = 3
                      AND (ISNULL(cev.pa, 0) = 0 OR ISNULL(cev.so, 0) = 1)
                 THEN CASE WHEN pv.strikes_after >= 2 THEN 1.0 ELSE 0.0 END
            END
        ) AS r2k_pct,
        -- Count qualifying pitch-3 opportunities for volume gate
        SUM(CASE WHEN pv.ab_pitch_number = 3
                      AND (ISNULL(cev.pa, 0) = 0 OR ISNULL(cev.so, 0) = 1)
                 THEN 1 ELSE 0 END) AS n_r2k_opps
    FROM Astros.Pitches_View pv
    JOIN Astros.Schedule_View sv ON sv.sched_id = pv.sched_id
    LEFT JOIN Astros.Events_View cev
        ON pv.sched_id = cev.sched_id AND pv.cur_event_id = cev.event_id
    WHERE pv.pitch_id > 0
      AND sv.year = 2025
      AND sv.sched_type = 'R'
      AND sv.gc2_level_code IN ('mlb', 'aaa', 'aax', 'afa', 'afx', 'rok', 'dsl')
    GROUP BY pv.pitcher_id, sv.gc2_level_code
    HAVING SUM(CASE WHEN pv.ab_pitch_number = 3
                         AND (ISNULL(cev.pa, 0) = 0 OR ISNULL(cev.so, 0) = 1)
                    THEN 1 ELSE 0 END) >= 30
)
SELECT DISTINCT
    level_code,
    CASE level_code WHEN 'mlb' THEN 1 WHEN 'aaa' THEN 2 WHEN 'aax' THEN 3
        WHEN 'afa' THEN 4 WHEN 'afx' THEN 5 WHEN 'rok' THEN 6
        WHEN 'dsl' THEN 7 END AS level_sort,
    COUNT(*) OVER (PARTITION BY level_code) AS n_pitchers,
    PERCENTILE_CONT(0.10) WITHIN GROUP (ORDER BY r2k_pct)
        OVER (PARTITION BY level_code) AS p10,
    PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY r2k_pct)
        OVER (PARTITION BY level_code) AS p25,
    PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY r2k_pct)
        OVER (PARTITION BY level_code) AS p50,
    PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY r2k_pct)
        OVER (PARTITION BY level_code) AS p75,
    PERCENTILE_CONT(0.90) WITHIN GROUP (ORDER BY r2k_pct)
        OVER (PARTITION BY level_code) AS p90
FROM pitcher_r2k
WHERE r2k_pct IS NOT NULL
ORDER BY level_sort;


-- =============================================================================
-- 3. NET K — Cumulative framing (SUM net_k) per catcher
--    Edge-zone called pitches only: CSC > 0.05 AND < 0.95
--    Result codes (4, 5, 6) = Called Ball, Ball In Dirt, Called Strike
--    ignore_flag = 0 required for NetK
--    Volume gate: 200+ edge-zone called pitches
-- =============================================================================
WITH catcher_netk AS (
    SELECT
        ev.c_id AS catcher_id,
        sv.gc2_level_code AS level_code,
        SUM(CASE WHEN pv.called_strike_chance > 0.05
                      AND pv.called_strike_chance < 0.95
                      AND pv.pitch_result_id IN (4, 5, 6)
                      AND pv.ignore_flag = 0
                 THEN pv.net_k ELSE 0 END) AS total_netk,
        SUM(CASE WHEN pv.called_strike_chance > 0.05
                      AND pv.called_strike_chance < 0.95
                      AND pv.pitch_result_id IN (4, 5, 6)
                      AND pv.ignore_flag = 0
                 THEN 1 ELSE 0 END) AS n_edge_pitches
    FROM Astros.Pitches_View pv
    JOIN Astros.Events_View ev
        ON pv.sched_id = ev.sched_id AND pv.ab_event_id = ev.event_id
    JOIN Astros.Schedule_View sv ON pv.sched_id = sv.sched_id
    WHERE pv.pitch_id > 0
      AND ev.c_id IS NOT NULL
      AND sv.year = 2025
      AND sv.sched_type = 'R'
      AND sv.gc2_level_code IN ('mlb', 'aaa', 'aax', 'afa', 'afx', 'rok', 'dsl')
    GROUP BY ev.c_id, sv.gc2_level_code
    HAVING SUM(CASE WHEN pv.called_strike_chance > 0.05
                         AND pv.called_strike_chance < 0.95
                         AND pv.pitch_result_id IN (4, 5, 6)
                         AND pv.ignore_flag = 0
                    THEN 1 ELSE 0 END) >= 200
)
SELECT DISTINCT
    level_code,
    CASE level_code WHEN 'mlb' THEN 1 WHEN 'aaa' THEN 2 WHEN 'aax' THEN 3
        WHEN 'afa' THEN 4 WHEN 'afx' THEN 5 WHEN 'rok' THEN 6
        WHEN 'dsl' THEN 7 END AS level_sort,
    COUNT(*) OVER (PARTITION BY level_code) AS n_catchers,
    PERCENTILE_CONT(0.10) WITHIN GROUP (ORDER BY total_netk)
        OVER (PARTITION BY level_code) AS p10,
    PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY total_netk)
        OVER (PARTITION BY level_code) AS p25,
    PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY total_netk)
        OVER (PARTITION BY level_code) AS p50,
    PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY total_netk)
        OVER (PARTITION BY level_code) AS p75,
    PERCENTILE_CONT(0.90) WITHIN GROUP (ORDER BY total_netk)
        OVER (PARTITION BY level_code) AS p90
FROM catcher_netk
ORDER BY level_sort;


-- =============================================================================
-- 4. REACT — P25 reaction_4mph per fielder (OF + IF separate)
--    Tier 1 gate: out_made + DCBP.CP + DCBP.CT + TDM.CP + (arm >= floor) > 0
--    Per-fielder P25, then level-wide distribution of those P25 values
--    Volume gate: 10+ Tier 1 plays per fielder
-- =============================================================================

-- 4a. OF React (pos 7, 8, 9 — arm floor 75)
WITH of_plays AS (
    SELECT
        tdm.groundcontrol_id AS fielder_id,
        sv.gc2_level_code AS level_code,
        tdm.reaction_4mph
    FROM Astros.Tracking_Defensive_Metrics tdm
    JOIN Astros.Schedule_View sv ON tdm.sched_id = sv.sched_id
    LEFT JOIN Astros.Defense_Combined_By_Pos dcbp
        ON tdm.sched_id = dcbp.sched_id
        AND tdm.event_id = dcbp.event_id
        AND tdm.pos_id = dcbp.pos_id
        AND tdm.groundcontrol_id = dcbp.groundcontrol_id
    WHERE tdm.pos_id IN (7, 8, 9)
      AND sv.year = 2025
      AND sv.sched_type = 'R'
      AND sv.gc2_level_code IN ('mlb', 'aaa', 'aax', 'afa', 'afx', 'rok', 'dsl')
      AND tdm.reaction_4mph IS NOT NULL
      -- Tier 1 gate (OF: arm floor 75)
      AND (CAST(ISNULL(dcbp.out_made, 0) AS int)
           + CAST(ISNULL(dcbp.competitive_play, 0) AS int)
           + CAST(ISNULL(dcbp.competitive_throw, 0) AS int)
           + CAST(ISNULL(tdm.competitive_play, 0) AS int)
           + CASE WHEN tdm.arm_strength >= 75 THEN 1 ELSE 0 END) > 0
),
of_player AS (
    SELECT DISTINCT
        fielder_id,
        level_code,
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY reaction_4mph)
            OVER (PARTITION BY fielder_id, level_code) AS react_p25,
        COUNT(*) OVER (PARTITION BY fielder_id, level_code) AS n_plays
    FROM of_plays
),
of_qualified AS (
    SELECT * FROM of_player WHERE n_plays >= 10
)
SELECT DISTINCT
    'OF' AS position_group,
    level_code,
    CASE level_code WHEN 'mlb' THEN 1 WHEN 'aaa' THEN 2 WHEN 'aax' THEN 3
        WHEN 'afa' THEN 4 WHEN 'afx' THEN 5 WHEN 'rok' THEN 6
        WHEN 'dsl' THEN 7 END AS level_sort,
    COUNT(*) OVER (PARTITION BY level_code) AS n_fielders,
    PERCENTILE_CONT(0.10) WITHIN GROUP (ORDER BY react_p25)
        OVER (PARTITION BY level_code) AS p10,
    PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY react_p25)
        OVER (PARTITION BY level_code) AS p25,
    PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY react_p25)
        OVER (PARTITION BY level_code) AS p50,
    PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY react_p25)
        OVER (PARTITION BY level_code) AS p75,
    PERCENTILE_CONT(0.90) WITHIN GROUP (ORDER BY react_p25)
        OVER (PARTITION BY level_code) AS p90
FROM of_qualified
ORDER BY level_sort;


-- 4b. IF React (pos 3, 4, 5, 6 — arm floor 70)
WITH if_plays AS (
    SELECT
        tdm.groundcontrol_id AS fielder_id,
        sv.gc2_level_code AS level_code,
        tdm.reaction_4mph
    FROM Astros.Tracking_Defensive_Metrics tdm
    JOIN Astros.Schedule_View sv ON tdm.sched_id = sv.sched_id
    LEFT JOIN Astros.Defense_Combined_By_Pos dcbp
        ON tdm.sched_id = dcbp.sched_id
        AND tdm.event_id = dcbp.event_id
        AND tdm.pos_id = dcbp.pos_id
        AND tdm.groundcontrol_id = dcbp.groundcontrol_id
    WHERE tdm.pos_id IN (3, 4, 5, 6)
      AND sv.year = 2025
      AND sv.sched_type = 'R'
      AND sv.gc2_level_code IN ('mlb', 'aaa', 'aax', 'afa', 'afx', 'rok', 'dsl')
      AND tdm.reaction_4mph IS NOT NULL
      -- Tier 1 gate (IF: arm floor 70)
      AND (CAST(ISNULL(dcbp.out_made, 0) AS int)
           + CAST(ISNULL(dcbp.competitive_play, 0) AS int)
           + CAST(ISNULL(dcbp.competitive_throw, 0) AS int)
           + CAST(ISNULL(tdm.competitive_play, 0) AS int)
           + CASE WHEN tdm.arm_strength >= 70 THEN 1 ELSE 0 END) > 0
),
if_player AS (
    SELECT DISTINCT
        fielder_id,
        level_code,
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY reaction_4mph)
            OVER (PARTITION BY fielder_id, level_code) AS react_p25,
        COUNT(*) OVER (PARTITION BY fielder_id, level_code) AS n_plays
    FROM if_plays
),
if_qualified AS (
    SELECT * FROM if_player WHERE n_plays >= 10
)
SELECT DISTINCT
    'IF' AS position_group,
    level_code,
    CASE level_code WHEN 'mlb' THEN 1 WHEN 'aaa' THEN 2 WHEN 'aax' THEN 3
        WHEN 'afa' THEN 4 WHEN 'afx' THEN 5 WHEN 'rok' THEN 6
        WHEN 'dsl' THEN 7 END AS level_sort,
    COUNT(*) OVER (PARTITION BY level_code) AS n_fielders,
    PERCENTILE_CONT(0.10) WITHIN GROUP (ORDER BY react_p25)
        OVER (PARTITION BY level_code) AS p10,
    PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY react_p25)
        OVER (PARTITION BY level_code) AS p25,
    PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY react_p25)
        OVER (PARTITION BY level_code) AS p50,
    PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY react_p25)
        OVER (PARTITION BY level_code) AS p75,
    PERCENTILE_CONT(0.90) WITHIN GROUP (ORDER BY react_p25)
        OVER (PARTITION BY level_code) AS p90
FROM if_qualified
ORDER BY level_sort;
