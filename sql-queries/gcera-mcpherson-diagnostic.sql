-- ============================================================================
-- gcERA diagnostic — McPherson 2026 per-game breakdown
-- ============================================================================
-- Purpose: show EVERY input that flows into gcERA per game, using GC2's exact
-- filter set. Run this on the work laptop and compare against postgame PDF +
-- GC2 player page. Any cell that differs is a divergence to investigate.
--
-- McPherson groundcontrol_id = 97366 (from the GC2 SQL paste).
-- Season = 2026.
--
-- Output: one row per game with:
--   - All 8 gcERA inputs (HR rate + 7 per-game counts)
--   - All 4 component rates
--   - Final gcERA computed canonically
--
-- Expected: gcera_canonical column should match what postgame_data.py
-- produces for the same game. If they differ, the bug is in Python (stale
-- code, missing filter, IBB handling). If they match but BOTH differ from
-- GC2's player page, the bug is in our SQL filter set or GC2 is using a
-- different formula than what they pasted.
-- ============================================================================

DECLARE @gc_id INT = 97366;       -- McPherson
DECLARE @season INT = 2026;

-- Step 1: resolve HR rate from MLB league pool (matches GC2 + our code).
-- Before-May fallback to prior year.
DECLARE @hr_rate FLOAT;
DECLARE @hr_lookup_year INT = CASE
    WHEN YEAR(GETDATE()) = @season AND MONTH(GETDATE()) < 5 THEN @season - 1
    ELSE @season
END;

SELECT @hr_rate = CAST(hr AS FLOAT) / NULLIF(CAST(hr AS FLOAT) + CAST(ao AS FLOAT), 0)
FROM mlbam.ytd_team_pitching_stats
WHERE team_id = 0 AND split_id = 0 AND gm_type = 'r' AND level = 'mlb'
  AND season = @hr_lookup_year;

-- Diagnostic 1: print the HR rate + lookup year so we can verify.
SELECT
    @hr_lookup_year AS hr_lookup_year,
    @hr_rate AS hr_rate,
    3.9 + 31.1 * @hr_rate AS barrel_multiplier;  -- coefficient on barrels

-- Step 2: per-game gcERA components using GC2's EXACT filter set.
-- Drive FROM Events_View, JOIN Pitches via cur_event_id (one row per
-- PA-ending pitch). Match GC2's "Event" query topology exactly.
WITH per_pitch AS (
    SELECT
        sv.sched_id,
        sv.sched_date,
        sv.gc2_level_code,
        ev.pa,
        ev.so,
        ev.bb,
        ev.ibb,
        ev.hbp,
        pv.pitch_id,
        pv.pitch_result_id,
        h.hit_exit_speed,
        h.hit_vertical_angle,
        ev.hit_trajectory_id
    FROM Astros.Events_View ev
    JOIN Astros.Schedule_View sv ON sv.sched_id = ev.sched_id
    JOIN Astros.Pitches_View pv
        ON pv.sched_id = ev.sched_id AND pv.cur_event_id = ev.event_id
    LEFT JOIN Astros.Hits h
        ON h.sched_id = pv.sched_id AND h.pitch_id = pv.pitch_id
    WHERE pv.pitcher_id = @gc_id
      AND sv.year = @season
      AND pv.pitch_id > 0
),
per_game AS (
    SELECT
        sched_id,
        sched_date,
        gc2_level_code,
        -- Inputs 2-6: PA-level counts (GC2 gates each on pa=1)
        SUM(CAST(CASE WHEN pa = 1 THEN 1 ELSE 0 END AS INT)) AS bf_pa1,
        SUM(CAST(CASE WHEN pa = 1 AND so = 1 THEN 1 ELSE 0 END AS INT)) AS so_pa1,
        SUM(CAST(CASE WHEN pa = 1 AND bb = 1 THEN 1 ELSE 0 END AS INT)) AS bb_pa1,
        SUM(CAST(CASE WHEN pa = 1 AND hbp = 1 THEN 1 ELSE 0 END AS INT)) AS hbp_pa1,
        SUM(CAST(CASE WHEN pa = 1 AND so = 0 AND bb = 0 AND hbp = 0 THEN 1 ELSE 0 END AS INT)) AS bip_pa,
        -- IBB count for sanity check (should = pa=0 AND ibb=1)
        SUM(CAST(CASE WHEN ibb = 1 THEN 1 ELSE 0 END AS INT)) AS ibb_count,
        -- Input 7: tracked_bip with GC2's HitsNoBunts filter set
        --   pitch_result_id IN (12,13,14) AND EV NOT NULL AND EV<125 AND bunt-excluded
        --   NO `EV > 0` filter (GC2 doesn't have it)
        SUM(CAST(CASE WHEN pitch_result_id IN (12, 13, 14)
                  AND hit_exit_speed IS NOT NULL
                  AND hit_exit_speed < 125
                  AND (hit_trajectory_id NOT IN (2, 3, 4) OR hit_trajectory_id IS NULL)
            THEN 1 ELSE 0 END AS INT)) AS tracked_bip,
        -- Input 8: pbarrels (tracked_bip meeting barrel threshold)
        SUM(CAST(CASE WHEN pitch_result_id IN (12, 13, 14)
                  AND hit_exit_speed IS NOT NULL
                  AND hit_exit_speed < 125
                  AND (hit_trajectory_id NOT IN (2, 3, 4) OR hit_trajectory_id IS NULL)
                  AND hit_exit_speed >= 0.011 * POWER(ISNULL(hit_vertical_angle, 0), 2)
                                         - 0.91 * ISNULL(hit_vertical_angle, 0) + 95.0
            THEN 1 ELSE 0 END AS INT)) AS pbarrels
    FROM per_pitch
    GROUP BY sched_id, sched_date, gc2_level_code
),
with_rates AS (
    SELECT
        sched_date,
        sched_id,
        gc2_level_code,
        bf_pa1,
        so_pa1,
        bb_pa1,
        hbp_pa1,
        bip_pa,
        ibb_count,
        tracked_bip,
        pbarrels,
        -- Component rates
        CAST(so_pa1 AS FLOAT) / NULLIF(bf_pa1, 0) AS so_rate,
        CAST(bb_pa1 + hbp_pa1 AS FLOAT) / NULLIF(bf_pa1, 0) AS bb_hbp_rate,
        CAST(bip_pa AS FLOAT) / NULLIF(bf_pa1, 0) AS bip_rate_direct,
        CASE WHEN bf_pa1 > 0 THEN
            1.0 - CAST(so_pa1 AS FLOAT) / bf_pa1 - CAST(bb_pa1 + hbp_pa1 AS FLOAT) / bf_pa1
        END AS bip_rate_derived,
        CAST(pbarrels AS FLOAT) / NULLIF(tracked_bip, 0) AS pbarrel_rate
    FROM per_game
)
SELECT
    sched_date,
    sched_id,
    gc2_level_code AS lvl,
    @hr_rate AS hr_rate,
    bf_pa1 AS bf,
    so_pa1 AS so,
    bb_pa1 AS bb_non_ibb,
    hbp_pa1 AS hbp,
    bip_pa,
    ibb_count,
    tracked_bip,
    pbarrels,
    CAST(so_rate * 100 AS DECIMAL(5,2)) AS so_pct,
    CAST(bb_hbp_rate * 100 AS DECIMAL(5,2)) AS bb_hbp_pct,
    CAST(bip_rate_derived * 100 AS DECIMAL(5,2)) AS bip_pct_derived,
    CAST(bip_rate_direct * 100 AS DECIMAL(5,2)) AS bip_pct_direct,  -- should match derived
    CAST(pbarrel_rate * 100 AS DECIMAL(5,2)) AS pbarrel_pct,
    -- Final gcERA — canonical formula
    CAST(
        (3.9 + 31.1 * @hr_rate) * ISNULL(bip_rate_derived, 0) * ISNULL(pbarrel_rate, 0)
        + 3.5 * ISNULL(bip_rate_derived, 0) * (1.0 - ISNULL(pbarrel_rate, 0))
        - 3.3 * ISNULL(so_rate, 0)
        + 9.9 * ISNULL(bb_hbp_rate, 0)
    AS DECIMAL(5, 2)) AS gcera_canonical,
    -- gcERA decomposition: contribution of each term
    CAST((3.9 + 31.1 * @hr_rate) * ISNULL(bip_rate_derived, 0) * ISNULL(pbarrel_rate, 0) AS DECIMAL(5,3)) AS contrib_barrel,
    CAST(3.5 * ISNULL(bip_rate_derived, 0) * (1.0 - ISNULL(pbarrel_rate, 0)) AS DECIMAL(5,3)) AS contrib_non_barrel,
    CAST(-3.3 * ISNULL(so_rate, 0) AS DECIMAL(5,3)) AS contrib_so,
    CAST(9.9 * ISNULL(bb_hbp_rate, 0) AS DECIMAL(5,3)) AS contrib_bb_hbp
FROM with_rates
ORDER BY sched_date DESC;

-- ============================================================================
-- HOW TO USE THIS OUTPUT
-- ============================================================================
-- 1. Find McPherson's most recent game row.
-- 2. Compare `gcera_canonical` to:
--    a) Our postgame PDF gcERA value — should match within 0.01 rounding.
--    b) GC2 player page gcERA value — should match within 0.01.
--
-- 3. If postgame matches this but GC2 differs:
--    → GC2 is computing something different than what they pasted, OR
--    → GC2 uses a different time window, OR
--    → 6.08 was ERA not gcERA (different metric entirely)
--
-- 4. If postgame DIFFERS from this query:
--    → Compare per-input. Which one differs?
--    → BF/SO/BB/HBP off → check `get_game_pa_outcomes` SQL in postgame_data.py
--    → tracked_bip / pbarrels off → check the BIP filter in `_compute_pitcher_statline`
--    → pbarrel_rate off but counts match → check the barrel threshold formula
--    → All inputs match but gcERA different → check the Python formula combination
--
-- 5. If GC2 player page is unreachable, compare to the gamelog ERA column
--    from the GC2 SQL paste — that's `ER * 9 / IP`, NOT gcERA. They're
--    different metrics and don't need to match.
-- ============================================================================

-- ============================================================================
-- BONUS: same query with `EV > 0` ADDED to see drift size from that filter
-- ============================================================================
-- Run this AFTER the main query to quantify how much the EV>0 filter shifts
-- per-game gcERA. If the difference is < 0.05 per game, EV>0 isn't the
-- dominant divergence source.

WITH per_pitch AS (
    SELECT
        sv.sched_id, sv.sched_date,
        pv.pitch_id, pv.pitch_result_id,
        h.hit_exit_speed, h.hit_vertical_angle, ev.hit_trajectory_id,
        ev.pa, ev.so, ev.bb, ev.hbp
    FROM Astros.Events_View ev
    JOIN Astros.Schedule_View sv ON sv.sched_id = ev.sched_id
    JOIN Astros.Pitches_View pv ON pv.sched_id = ev.sched_id AND pv.cur_event_id = ev.event_id
    LEFT JOIN Astros.Hits h ON h.sched_id = pv.sched_id AND h.pitch_id = pv.pitch_id
    WHERE pv.pitcher_id = @gc_id AND sv.year = @season AND pv.pitch_id > 0
)
SELECT
    sched_date,
    sched_id,
    SUM(CAST(CASE WHEN pitch_result_id IN (12,13,14)
              AND hit_exit_speed IS NOT NULL AND hit_exit_speed < 125
              AND (hit_trajectory_id NOT IN (2,3,4) OR hit_trajectory_id IS NULL)
        THEN 1 ELSE 0 END AS INT)) AS tracked_bip_gc2,
    SUM(CAST(CASE WHEN pitch_result_id IN (12,13,14)
              AND hit_exit_speed IS NOT NULL AND hit_exit_speed > 0 AND hit_exit_speed < 125
              AND (hit_trajectory_id NOT IN (2,3,4) OR hit_trajectory_id IS NULL)
        THEN 1 ELSE 0 END AS INT)) AS tracked_bip_with_ev_gt_0,
    SUM(CAST(CASE WHEN pitch_result_id IN (12,13,14)
              AND hit_exit_speed IS NOT NULL AND hit_exit_speed < 125
              AND (hit_trajectory_id NOT IN (2,3,4) OR hit_trajectory_id IS NULL)
              AND hit_exit_speed >= 0.011 * POWER(ISNULL(hit_vertical_angle, 0), 2)
                                     - 0.91 * ISNULL(hit_vertical_angle, 0) + 95.0
        THEN 1 ELSE 0 END AS INT)) AS pbarrels_gc2,
    SUM(CAST(CASE WHEN pitch_result_id IN (12,13,14)
              AND hit_exit_speed IS NOT NULL AND hit_exit_speed > 0 AND hit_exit_speed < 125
              AND (hit_trajectory_id NOT IN (2,3,4) OR hit_trajectory_id IS NULL)
              AND hit_exit_speed >= 0.011 * POWER(ISNULL(hit_vertical_angle, 0), 2)
                                     - 0.91 * ISNULL(hit_vertical_angle, 0) + 95.0
        THEN 1 ELSE 0 END AS INT)) AS pbarrels_with_ev_gt_0
FROM per_pitch
GROUP BY sched_id, sched_date
ORDER BY sched_date DESC;
