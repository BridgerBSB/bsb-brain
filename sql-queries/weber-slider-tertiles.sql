-- Charlie Weber (gc_id 250211) — slider arm-angle + release-height tertiles
-- 2026 R season, SL only.
--
-- Two queries in one file. Run independently.
--   QUERY A: bucket on computed arm angle (Brodie formula, see db-columns.md)
--   QUERY B: bucket on release height (pht.pitch_release_pos_z, ft)
--
-- Per bucket: n_pitches, min/avg/max of the bucket variable,
-- avg IVB, avg HB (catcher view, raw), avg velo.
--
-- Cleaning: arm-angle hard cap >90° applied (physics cap from
-- data-cleaning.md). 2.5σ per-pitcher trim INTENTIONALLY OMITTED — Weber
-- is explicitly named as a slot-switcher (σ=8.13°, mean 19.88°) and the
-- trim would erase the slot variance we're trying to bucket on.
-- HB is raw (catcher view); for an RHP, more-negative horzbreak = more
-- glove-side break.

-- ============================================================
-- QUERY A — buckets on ARM ANGLE
-- ============================================================
WITH weber_sl AS (
    SELECT
        pv.sched_id, pv.pitch_id,
        pv.release_speed,
        pv.inducedvertbreak,
        pv.horzbreak,
        pv.pitch_result_id,
        pv.did_swing,
        pv.ignore_flag,
        pv.called_strike_chance_mlb,
        h.hit_exit_speed,
        pht.pitch_release_pos_z AS rel_height_z,
        -- Brodie arm-angle formula (per-pitch, no AVG)
        -16.4
        + 1.1 * (90.0 -
            CASE WHEN p.throws = 'L' THEN 180.0/PI() ELSE -180.0/PI() END *
            ATN2(pht.pitch_release_pos_x - pos.x_at_pitch_release,
                 pht.pitch_release_pos_z -
                 SQRT(CASE WHEN
                    POWER((CAST(mp.height_feet AS float) + CAST(mp.height_inches AS float)/12.0) * 0.75, 2) -
                    POWER((60.5 - pos.y_at_pitch_release) * 0.85, 2) < 0
                 THEN 0 ELSE
                    POWER((CAST(mp.height_feet AS float) + CAST(mp.height_inches AS float)/12.0) * 0.75, 2) -
                    POWER((60.5 - pos.y_at_pitch_release) * 0.85, 2)
                 END)))
        + -0.001 * POWER(90.0 -
            CASE WHEN p.throws = 'L' THEN 180.0/PI() ELSE -180.0/PI() END *
            ATN2(pht.pitch_release_pos_x - pos.x_at_pitch_release,
                 pht.pitch_release_pos_z -
                 SQRT(CASE WHEN
                    POWER((CAST(mp.height_feet AS float) + CAST(mp.height_inches AS float)/12.0) * 0.75, 2) -
                    POWER((60.5 - pos.y_at_pitch_release) * 0.85, 2) < 0
                 THEN 0 ELSE
                    POWER((CAST(mp.height_feet AS float) + CAST(mp.height_inches AS float)/12.0) * 0.75, 2) -
                    POWER((60.5 - pos.y_at_pitch_release) * 0.85, 2)
                 END)), 2) AS arm_angle
    FROM Astros.Pitches_View pv
    JOIN Astros.Schedule_View sv ON pv.sched_id = sv.sched_id
    JOIN Astros.Players p ON pv.pitcher_id = p.groundcontrol_id
    JOIN groundcontroltracking.tracking.pitch_hit_trajectories pht
        ON pht.sched_id = pv.sched_id AND pht.tracking_play_id = pv.pitch_id
    JOIN groundcontroltracking.tracking.play_starting_positions pos
        ON pos.sched_id = pv.sched_id AND pos.pitch_id = pv.pitch_id
        AND pos.groundcontrol_id = pv.pitcher_id
    JOIN mlbam.players mp ON p.mlbam_id = mp.player_id
    LEFT JOIN Astros.Hits h ON h.sched_id = pv.sched_id AND h.pitch_id = pv.pitch_id
    WHERE pv.pitcher_id = 250211       -- Charlie Weber
      AND pv.pitch_type = 'SL'
      AND pv.pitch_id > 0
      AND sv.year = 2026
      AND sv.sched_type = 'R'
),
weber_sl_clean_aa AS (
    -- Hard-cap arm angle >90° (physics impossible). Drop those rows so
    -- they don't pollute the NTILE buckets.
    SELECT *
    FROM weber_sl
    WHERE arm_angle <= 90
),
bucketed_aa AS (
    SELECT *,
        NTILE(3) OVER (ORDER BY arm_angle) AS aa_bucket
    FROM weber_sl_clean_aa
)
SELECT
    aa_bucket,
    COUNT(*)                              AS n_pitches,
    ROUND(MIN(arm_angle), 2)              AS aa_min,
    ROUND(AVG(arm_angle), 2)              AS aa_avg,
    ROUND(MAX(arm_angle), 2)              AS aa_max,
    ROUND(AVG(rel_height_z), 2)           AS avg_rel_height_ft,
    ROUND(AVG(release_speed), 1)          AS avg_velo,
    ROUND(AVG(inducedvertbreak), 2)       AS avg_ivb,
    ROUND(AVG(horzbreak), 2)              AS avg_hb_catcher_view,
    -- Whiff% (did_swing-gated + ignore_flag recovery per pitfalls.md)
    ROUND(100.0 * SUM(CASE
        WHEN (did_swing = 1 OR (ignore_flag = 1 AND did_swing IS NULL
                AND pitch_result_id IN (7,8,9,10,12,13,14,16,18,19,20,21,22,23,25)))
         AND pitch_result_id IN (10,16,21,22,23,25)
        THEN 1 ELSE 0 END) /
      NULLIF(SUM(CASE
        WHEN (did_swing = 1 OR (ignore_flag = 1 AND did_swing IS NULL
                AND pitch_result_id IN (7,8,9,10,12,13,14,16,18,19,20,21,22,23,25)))
        THEN 1 ELSE 0 END), 0), 1) AS whiff_pct,
    -- Avg EV (canonical misread filter: BIP codes + 0 < EV < 125)
    ROUND(AVG(CASE
        WHEN pitch_result_id IN (12,13,14)
         AND hit_exit_speed > 0 AND hit_exit_speed < 125
        THEN hit_exit_speed END), 1) AS avg_ev,
    -- InZ% (continuous CSC, not binary)
    ROUND(100.0 * AVG(called_strike_chance_mlb), 1) AS inz_pct
FROM bucketed_aa
GROUP BY aa_bucket
ORDER BY aa_bucket;


-- ============================================================
-- QUERY B — buckets on RELEASE HEIGHT
-- ============================================================
WITH weber_sl AS (
    SELECT
        pv.sched_id, pv.pitch_id,
        pv.release_speed,
        pv.inducedvertbreak,
        pv.horzbreak,
        pv.pitch_result_id,
        pv.did_swing,
        pv.ignore_flag,
        pv.called_strike_chance_mlb,
        h.hit_exit_speed,
        pht.pitch_release_pos_z AS rel_height_z,
        -16.4
        + 1.1 * (90.0 -
            CASE WHEN p.throws = 'L' THEN 180.0/PI() ELSE -180.0/PI() END *
            ATN2(pht.pitch_release_pos_x - pos.x_at_pitch_release,
                 pht.pitch_release_pos_z -
                 SQRT(CASE WHEN
                    POWER((CAST(mp.height_feet AS float) + CAST(mp.height_inches AS float)/12.0) * 0.75, 2) -
                    POWER((60.5 - pos.y_at_pitch_release) * 0.85, 2) < 0
                 THEN 0 ELSE
                    POWER((CAST(mp.height_feet AS float) + CAST(mp.height_inches AS float)/12.0) * 0.75, 2) -
                    POWER((60.5 - pos.y_at_pitch_release) * 0.85, 2)
                 END)))
        + -0.001 * POWER(90.0 -
            CASE WHEN p.throws = 'L' THEN 180.0/PI() ELSE -180.0/PI() END *
            ATN2(pht.pitch_release_pos_x - pos.x_at_pitch_release,
                 pht.pitch_release_pos_z -
                 SQRT(CASE WHEN
                    POWER((CAST(mp.height_feet AS float) + CAST(mp.height_inches AS float)/12.0) * 0.75, 2) -
                    POWER((60.5 - pos.y_at_pitch_release) * 0.85, 2) < 0
                 THEN 0 ELSE
                    POWER((CAST(mp.height_feet AS float) + CAST(mp.height_inches AS float)/12.0) * 0.75, 2) -
                    POWER((60.5 - pos.y_at_pitch_release) * 0.85, 2)
                 END)), 2) AS arm_angle
    FROM Astros.Pitches_View pv
    JOIN Astros.Schedule_View sv ON pv.sched_id = sv.sched_id
    JOIN Astros.Players p ON pv.pitcher_id = p.groundcontrol_id
    JOIN groundcontroltracking.tracking.pitch_hit_trajectories pht
        ON pht.sched_id = pv.sched_id AND pht.tracking_play_id = pv.pitch_id
    JOIN groundcontroltracking.tracking.play_starting_positions pos
        ON pos.sched_id = pv.sched_id AND pos.pitch_id = pv.pitch_id
        AND pos.groundcontrol_id = pv.pitcher_id
    JOIN mlbam.players mp ON p.mlbam_id = mp.player_id
    LEFT JOIN Astros.Hits h ON h.sched_id = pv.sched_id AND h.pitch_id = pv.pitch_id
    WHERE pv.pitcher_id = 250211       -- Charlie Weber
      AND pv.pitch_type = 'SL'
      AND pv.pitch_id > 0
      AND sv.year = 2026
      AND sv.sched_type = 'R'
),
weber_sl_clean_rz AS (
    -- Drop the same physics-impossible arm-angle rows so the two queries
    -- are run on the same pitch pool (apples-to-apples comparison).
    SELECT *
    FROM weber_sl
    WHERE arm_angle <= 90
      AND rel_height_z IS NOT NULL
),
bucketed_rz AS (
    SELECT *,
        NTILE(3) OVER (ORDER BY rel_height_z) AS rz_bucket
    FROM weber_sl_clean_rz
)
SELECT
    rz_bucket,
    COUNT(*)                              AS n_pitches,
    ROUND(MIN(rel_height_z), 2)           AS rz_min_ft,
    ROUND(AVG(rel_height_z), 2)           AS rz_avg_ft,
    ROUND(MAX(rel_height_z), 2)           AS rz_max_ft,
    ROUND(AVG(arm_angle), 2)              AS avg_arm_angle,
    ROUND(AVG(release_speed), 1)          AS avg_velo,
    ROUND(AVG(inducedvertbreak), 2)       AS avg_ivb,
    ROUND(AVG(horzbreak), 2)              AS avg_hb_catcher_view,
    -- Whiff% (did_swing-gated + ignore_flag recovery per pitfalls.md)
    ROUND(100.0 * SUM(CASE
        WHEN (did_swing = 1 OR (ignore_flag = 1 AND did_swing IS NULL
                AND pitch_result_id IN (7,8,9,10,12,13,14,16,18,19,20,21,22,23,25)))
         AND pitch_result_id IN (10,16,21,22,23,25)
        THEN 1 ELSE 0 END) /
      NULLIF(SUM(CASE
        WHEN (did_swing = 1 OR (ignore_flag = 1 AND did_swing IS NULL
                AND pitch_result_id IN (7,8,9,10,12,13,14,16,18,19,20,21,22,23,25)))
        THEN 1 ELSE 0 END), 0), 1) AS whiff_pct,
    -- Avg EV (canonical misread filter: BIP codes + 0 < EV < 125)
    ROUND(AVG(CASE
        WHEN pitch_result_id IN (12,13,14)
         AND hit_exit_speed > 0 AND hit_exit_speed < 125
        THEN hit_exit_speed END), 1) AS avg_ev,
    -- InZ% (continuous CSC, not binary)
    ROUND(100.0 * AVG(called_strike_chance_mlb), 1) AS inz_pct
FROM bucketed_rz
GROUP BY rz_bucket
ORDER BY rz_bucket;
