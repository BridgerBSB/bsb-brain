/* ============================================================================
   SWING-PATH DISCOVERY  (run on WORK LAPTOP against GroundControl2)
   ----------------------------------------------------------------------------
   Purpose: figure out exactly what in-game bat/swing tracking we have BEFORE
   building the postgame "swing path" visual. We suspect our internal data is
   richer than Savant public (which only ships summary metrics). This script
   is INFORMATION_SCHEMA-first so we never guess a column name.

   HOW TO USE
   - Run each numbered block separately in SSMS / Azure Data Studio.
   - Copy the FULL result grid for each block back to me (Claude).
   - Blocks that need a player use batter_id = 218498 (Schiavone — GC2's own
     swing query used this id, so it definitely has tracking rows). To probe a
     different hitter, change the 218498 in that block only.

   VERIFIED JOIN KEYS (from GC2's production swing query, do not change):
     Astros.Pitches_View                          (batter_id, sched_id, pitch_id)
       -> groundcontroltracking.tracking.plays    ON sched_id = sched_id
                                                  AND astros_pitch_id = pitch_id
       -> groundcontroltracking.tracking.swing_*  ON sched_id = sched_id
                                                  AND tracking_play_id = tracking_play_id
     Astros.bat_tracking_metrics                  ON sched_id, pitch_id

   NOTE: GroundControl2 = the connected DB (schema "Astros").
         groundcontroltracking = a SEPARATE DB (schema "tracking").
         SQL Server identifiers are case-insensitive; schema string in
         INFORMATION_SCHEMA may report 'tracking' or 'Tracking' — the LIKE/=
         comparisons below are collation-insensitive on this server.
   ============================================================================ */


/* ============================================================================
   BLOCK 1 — every table in the tracking DB (names only)
   Goal: see all ~64 tables so we can eyeball candidates we haven't touched
   (frame-level bat position, kinematic sequences, per-segment trajectory).
   ============================================================================ */
SELECT TABLE_SCHEMA, TABLE_NAME
FROM groundcontroltracking.INFORMATION_SCHEMA.TABLES
WHERE TABLE_TYPE = 'BASE TABLE'
ORDER BY TABLE_NAME;


/* ============================================================================
   BLOCK 2 — every bat/swing-ish COLUMN across the tracking DB
   Goal: surface which tables hold bat geometry / kinematics / trajectory and
   what the columns are called. This is the master map.
   ============================================================================ */
SELECT TABLE_NAME, COLUMN_NAME, DATA_TYPE
FROM groundcontroltracking.INFORMATION_SCHEMA.COLUMNS
WHERE
       COLUMN_NAME LIKE '%bat%'
    OR COLUMN_NAME LIKE '%swing%'
    OR COLUMN_NAME LIKE '%barrel%'
    OR COLUMN_NAME LIKE '%knob%'
    OR COLUMN_NAME LIKE '%sweet%'
    OR COLUMN_NAME LIKE '%hand%'
    OR COLUMN_NAME LIKE '%kinematic%'
    OR COLUMN_NAME LIKE '%segment%'
    OR COLUMN_NAME LIKE '%loft%'
    OR COLUMN_NAME LIKE '%tilt%'
    OR COLUMN_NAME LIKE '%plane%'
    OR COLUMN_NAME LIKE '%radius%'
    OR COLUMN_NAME LIKE '%arc%'
    OR COLUMN_NAME LIKE '%attack%'
    OR COLUMN_NAME LIKE '%contact%'
ORDER BY TABLE_NAME, ORDINAL_POSITION;


/* ============================================================================
   BLOCK 3 — PER-FRAME HUNT (the big question)
   Goal: find any table that stores a time-series of the swing (a frame / time /
   sequence axis ALONGSIDE position-ish columns). If one exists, we get the real
   in-game bat path instead of a 6-station curvature summary.
   3a lists tables that have a time/frame/seq axis; 3b lists their full columns.
   ============================================================================ */
-- 3a: tracking tables that contain a frame/time/sequence axis
SELECT DISTINCT TABLE_NAME
FROM groundcontroltracking.INFORMATION_SCHEMA.COLUMNS
WHERE
       COLUMN_NAME LIKE '%frame%'
    OR COLUMN_NAME LIKE '%time%'
    OR COLUMN_NAME = 't'
    OR COLUMN_NAME LIKE 't[_]%'
    OR COLUMN_NAME LIKE '%timestamp%'
    OR COLUMN_NAME LIKE '%seq%'
    OR COLUMN_NAME LIKE '%step%'
    OR COLUMN_NAME LIKE '%idx%'
    OR COLUMN_NAME LIKE '%index%'
ORDER BY TABLE_NAME;

-- 3b: full column list for those candidate tables (so we can see if a frame
-- axis sits next to x/y/z position columns = true per-frame bat trajectory)
SELECT c.TABLE_NAME, c.COLUMN_NAME, c.DATA_TYPE, c.ORDINAL_POSITION
FROM groundcontroltracking.INFORMATION_SCHEMA.COLUMNS c
WHERE c.TABLE_NAME IN (
    SELECT DISTINCT TABLE_NAME
    FROM groundcontroltracking.INFORMATION_SCHEMA.COLUMNS
    WHERE COLUMN_NAME LIKE '%frame%' OR COLUMN_NAME LIKE '%time%'
       OR COLUMN_NAME = 't' OR COLUMN_NAME LIKE 't[_]%'
       OR COLUMN_NAME LIKE '%timestamp%' OR COLUMN_NAME LIKE '%seq%'
       OR COLUMN_NAME LIKE '%step%' OR COLUMN_NAME LIKE '%idx%'
       OR COLUMN_NAME LIKE '%index%'
)
ORDER BY c.TABLE_NAME, c.ORDINAL_POSITION;


/* ============================================================================
   BLOCK 4 — decode Swing_Shapes
   4a: full column list (lock the real column names + types).
   4b: raw rows for a handful of one hitter's recent batted-ball swings, so we
       can see the magnitudes of Km30..K45 (curvature?), plane_p*, x0/y0/z0,
       loft, tilt and confirm units/reference frame.
   ============================================================================ */
-- 4a
SELECT COLUMN_NAME, DATA_TYPE, ORDINAL_POSITION
FROM groundcontroltracking.INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'Swing_Shapes'
ORDER BY ORDINAL_POSITION;

-- 4b  (batter_id 218498; BIP only so a clean contact swing; most recent first)
SELECT TOP 8
    sv.year, sv.sched_date, sv.gc2_level_code, p.bat_side,
    p.pitch_type, p.pitch_result_id,
    ss.*
FROM Astros.Pitches_View p
JOIN Astros.Schedule_View sv
    ON sv.sched_id = p.sched_id
JOIN groundcontroltracking.tracking.plays tp
    ON tp.sched_id = p.sched_id
   AND tp.astros_pitch_id = p.pitch_id
JOIN groundcontroltracking.tracking.swing_shapes ss
    ON ss.sched_id = tp.sched_id
   AND ss.tracking_play_id = tp.tracking_play_id
WHERE p.batter_id = 218498
  AND p.pitch_result_id IN (12, 13, 14)   -- batted ball
  AND p.ignore_flag = 0
  AND p.pitch_id > 0
ORDER BY sv.sched_date DESC, p.pitch_id DESC;


/* ============================================================================
   BLOCK 5 — Swing_Contact_Values (the contact-frame snapshot)
   5a: full column list.  5b: raw rows for the same hitter.
   ============================================================================ */
-- 5a
SELECT COLUMN_NAME, DATA_TYPE, ORDINAL_POSITION
FROM groundcontroltracking.INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'Swing_Contact_Values'
ORDER BY ORDINAL_POSITION;

-- 5b
SELECT TOP 5
    sv.sched_date, p.bat_side, p.pitch_type,
    scv.*
FROM Astros.Pitches_View p
JOIN Astros.Schedule_View sv
    ON sv.sched_id = p.sched_id
JOIN groundcontroltracking.tracking.plays tp
    ON tp.sched_id = p.sched_id
   AND tp.astros_pitch_id = p.pitch_id
JOIN groundcontroltracking.tracking.swing_contact_values scv
    ON scv.sched_id = tp.sched_id
   AND scv.tracking_play_id = tp.tracking_play_id
WHERE p.batter_id = 218498
  AND p.pitch_result_id IN (12, 13, 14)
  AND p.ignore_flag = 0
  AND p.pitch_id > 0
ORDER BY sv.sched_date DESC, p.pitch_id DESC;


/* ============================================================================
   BLOCK 6 — Astros.bat_tracking_metrics (peak + pitcher-face snapshots)
   This is the table GC2 uses for peak attack angle / loc-adjusted angles, and
   the likely home of the "downswing / follow-through" timestamps + maybe swing
   length. NOTE: it lives in the Astros schema, NOT the tracking DB.
   6a: full column list.  6b: raw rows for the same hitter.
   ============================================================================ */
-- 6a
SELECT COLUMN_NAME, DATA_TYPE, ORDINAL_POSITION
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'Astros'
  AND TABLE_NAME = 'Bat_Tracking_Metrics'
ORDER BY ORDINAL_POSITION;

-- 6b
SELECT TOP 5
    sv.sched_date, p.bat_side, p.pitch_type,
    btm.*
FROM Astros.Pitches_View p
JOIN Astros.Schedule_View sv
    ON sv.sched_id = p.sched_id
JOIN Astros.Bat_Tracking_Metrics btm
    ON btm.sched_id = p.sched_id
   AND btm.pitch_id = p.pitch_id
WHERE p.batter_id = 218498
  AND p.pitch_result_id IN (12, 13, 14)
  AND p.ignore_flag = 0
  AND p.pitch_id > 0
ORDER BY sv.sched_date DESC, p.pitch_id DESC;


/* ============================================================================
   BLOCK 7 — SWING LENGTH hunt
   Savant ships "swing length" (total sweet-spot travel). Find any column named
   like it anywhere in EITHER database. If nothing turns up, we derive it by
   integrating the reconstructed arc.
   ============================================================================ */
-- 7a: tracking DB
SELECT 'groundcontroltracking' AS db, TABLE_NAME, COLUMN_NAME, DATA_TYPE
FROM groundcontroltracking.INFORMATION_SCHEMA.COLUMNS
WHERE COLUMN_NAME LIKE '%length%'
   OR COLUMN_NAME LIKE '%swing_len%'
   OR COLUMN_NAME LIKE '%path_len%'
   OR COLUMN_NAME LIKE '%arc_len%'
   OR COLUMN_NAME LIKE '%dist%'
ORDER BY TABLE_NAME, COLUMN_NAME;

-- 7b: GroundControl2 (Astros schema)
SELECT 'GroundControl2' AS db, TABLE_NAME, COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'Astros'
  AND (   COLUMN_NAME LIKE '%length%'
       OR COLUMN_NAME LIKE '%swing_len%'
       OR COLUMN_NAME LIKE '%path_len%'
       OR COLUMN_NAME LIKE '%arc_len%')
ORDER BY TABLE_NAME, COLUMN_NAME;


/* ============================================================================
   BLOCK 8 — COVERAGE MATRIX (decides MLB-only vs affiliate-wide)
   How many swings actually have each tracking surface, by level x year.
   If swing_shapes is ~MLB-only and sparse below AAA, the postgame tool is
   MLB/AAA-first; if affiliate-wide, we can ship it everywhere.
   ============================================================================ */
SELECT
    sv.gc2_level_code,
    sv.year,
    COUNT(*)                                                   AS swings,            -- did_swing rows
    SUM(CASE WHEN tp.tracking_play_id IS NOT NULL THEN 1 ELSE 0 END)  AS has_play,
    SUM(CASE WHEN scv.tracking_play_id IS NOT NULL THEN 1 ELSE 0 END) AS has_contact_vals,
    SUM(CASE WHEN ss.tracking_play_id IS NOT NULL THEN 1 ELSE 0 END)  AS has_swing_shapes,
    SUM(CASE WHEN btm.pitch_id IS NOT NULL THEN 1 ELSE 0 END)         AS has_bat_tracking
FROM Astros.Pitches_View p
JOIN Astros.Schedule_View sv
    ON sv.sched_id = p.sched_id
LEFT JOIN groundcontroltracking.tracking.plays tp
    ON tp.sched_id = p.sched_id AND tp.astros_pitch_id = p.pitch_id
LEFT JOIN groundcontroltracking.tracking.swing_contact_values scv
    ON scv.sched_id = tp.sched_id AND scv.tracking_play_id = tp.tracking_play_id
LEFT JOIN groundcontroltracking.tracking.swing_shapes ss
    ON ss.sched_id = tp.sched_id AND ss.tracking_play_id = tp.tracking_play_id
LEFT JOIN Astros.Bat_Tracking_Metrics btm
    ON btm.sched_id = p.sched_id AND btm.pitch_id = p.pitch_id
WHERE p.did_swing = 1
  AND p.ignore_flag = 0
  AND p.pitch_id > 0
  AND sv.year >= 2024
GROUP BY sv.gc2_level_code, sv.year
ORDER BY sv.year DESC, sv.gc2_level_code;


/* ============================================================================
   BLOCK 9 — CHERRY-METRIC INPUTS (squared-up %, smash factor, ideal-AA %)
   Confirm we have: bat speed (have it), exit velocity, and pitch speed at the
   pitch level so squared-up % and smash factor are computable. Just a column
   probe + a one-row sanity pull.
   ============================================================================ */
-- 9a: pitch-level speed / EV columns on Pitches_View
SELECT COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'Astros'
  AND TABLE_NAME = 'Pitches_View'
  AND (   COLUMN_NAME LIKE '%exit_speed%'
       OR COLUMN_NAME LIKE '%hit_exit%'
       OR COLUMN_NAME LIKE '%launch%'
       OR COLUMN_NAME LIKE '%release_speed%'
       OR COLUMN_NAME LIKE '%pitch_speed%'
       OR COLUMN_NAME LIKE '%start_speed%'
       OR COLUMN_NAME LIKE '%plate_speed%'
       OR COLUMN_NAME LIKE '%rel_speed%')
ORDER BY COLUMN_NAME;

-- 9b: one batted ball for the hitter showing EV + (whatever pitch-speed col 9a
--     reveals) + contact-frame bat speed, so we can eyeball squared-up inputs.
SELECT TOP 5
    sv.sched_date, p.pitch_type,
    p.hit_exit_speed,
    p.hit_vertical_angle,
    SQRT(POWER(scv.batvx_con,2)+POWER(scv.batvy_con,2)+POWER(scv.batvz_con,2)) * 0.681818 AS bat_speed_mph
FROM Astros.Pitches_View p
JOIN Astros.Schedule_View sv ON sv.sched_id = p.sched_id
JOIN groundcontroltracking.tracking.plays tp
    ON tp.sched_id = p.sched_id AND tp.astros_pitch_id = p.pitch_id
JOIN groundcontroltracking.tracking.swing_contact_values scv
    ON scv.sched_id = tp.sched_id AND scv.tracking_play_id = tp.tracking_play_id
WHERE p.batter_id = 218498
  AND p.pitch_result_id IN (12, 13, 14)
  AND p.ignore_flag = 0
  AND p.pitch_id > 0
ORDER BY sv.sched_date DESC, p.pitch_id DESC;

/* ============================================================================
   END. Paste back, in order: B1, B2, B3a, B3b, B4a, B4b, B5a, B5b, B6a, B6b,
   B7a, B7b, B8, B9a, B9b. (3b can be big — if it's huge, just paste the table
   names from 3a and I'll tell you which 1-2 to expand.)
   ============================================================================ */
