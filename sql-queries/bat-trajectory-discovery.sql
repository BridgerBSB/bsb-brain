-- Bat Trajectory Discovery (work laptop only — needs DB access)
-- =============================================================
-- Goal: find whether GC2 has per-timestamp bat barrel positions
-- (not just the contact-frame snapshot in swing_contact_values).
--
-- Context: Barrelsville Postgame Visuals tab swing-path integration.
-- The user's existing Statcast-based swing-path project at
-- https://swingpath.streamlit.app reconstructs the arc via Hermite
-- interpolation because MLB doesn't expose raw frames. We want to
-- know if HawkEye (Astros side) gives us the actual frame-by-frame
-- bat trajectory.
--
-- Run these in order. Paste results back into the conversation.
-- =============================================================

-- ---------------------------------------------------------------
-- 1. Tables in groundcontroltracking.Tracking schema with "bat",
--    "barrel", "swing", or "trajectory" in the name
-- ---------------------------------------------------------------
SELECT TABLE_NAME
FROM groundcontroltracking.INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'Tracking'
  AND (TABLE_NAME LIKE '%bat%'
    OR TABLE_NAME LIKE '%barrel%'
    OR TABLE_NAME LIKE '%swing%'
    OR TABLE_NAME LIKE '%trajectory%'
    OR TABLE_NAME LIKE '%kinematic%')
ORDER BY TABLE_NAME;


-- ---------------------------------------------------------------
-- 2. Column-name search across ALL Tracking tables for bat/barrel
--    position-like columns
-- ---------------------------------------------------------------
SELECT TABLE_NAME, COLUMN_NAME, DATA_TYPE
FROM groundcontroltracking.INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'Tracking'
  AND (COLUMN_NAME LIKE '%bat_x%'
    OR COLUMN_NAME LIKE '%bat_y%'
    OR COLUMN_NAME LIKE '%bat_z%'
    OR COLUMN_NAME LIKE 'batx%'
    OR COLUMN_NAME LIKE 'baty%'
    OR COLUMN_NAME LIKE 'batz%'
    OR COLUMN_NAME LIKE '%barrel%'
    OR COLUMN_NAME LIKE '%handle%'
    OR COLUMN_NAME LIKE '%sweetspot%')
ORDER BY TABLE_NAME, COLUMN_NAME;


-- ---------------------------------------------------------------
-- 3. Sample rows from the 4 candidate tables (5 rows each)
--    Replace with TOP 1 if any are huge / slow.
-- ---------------------------------------------------------------

-- 3a. Swing_Shapes — described as "Bat path shape metrics"
SELECT TOP 5 *
FROM groundcontroltracking.Tracking.Swing_Shapes
WHERE 1=1;

-- 3b. Hitter_Kinematics — biomech per-event kinematics
SELECT TOP 5 *
FROM groundcontroltracking.Tracking.Hitter_Kinematics
WHERE 1=1;

-- 3c. Swing_Damage_Windows — per-swing damage window data
SELECT TOP 5 *
FROM groundcontroltracking.Tracking.Swing_Damage_Windows
WHERE 1=1;

-- 3d. Bat_Tracking_Metrics — Astros side (NOT groundcontroltracking)
SELECT TOP 5 *
FROM Astros.Bat_Tracking_Metrics
WHERE 1=1;


-- ---------------------------------------------------------------
-- 4. Row counts on each candidate (to gauge if they have per-frame
--    rows-per-swing vs one-row-per-swing). Per-frame would mean
--    LOTS of rows per (sched_id, pitch_id) pair — e.g. ~30 fps over
--    ~1 second = ~30 rows per swing.
-- ---------------------------------------------------------------

-- Pick ANY HOU MLB pitch we know has SCV data, and count rows in
-- each candidate table for that same (sched_id, pitch_id).
-- Replace :sched_id / :pitch_id with a known pair from a recent game.

DECLARE @sched_id INT = NULL;  -- TODO fill in
DECLARE @pitch_id INT = NULL;  -- TODO fill in

-- SCV (baseline — should be 1 row at contact)
SELECT 'swing_contact_values' AS tbl, COUNT(*) AS rows_for_this_pitch
FROM groundcontroltracking.Tracking.swing_contact_values
WHERE sched_id = @sched_id
UNION ALL
SELECT 'Swing_Shapes', COUNT(*)
FROM groundcontroltracking.Tracking.Swing_Shapes
WHERE sched_id = @sched_id
UNION ALL
SELECT 'Hitter_Kinematics', COUNT(*)
FROM groundcontroltracking.Tracking.Hitter_Kinematics
WHERE sched_id = @sched_id
UNION ALL
SELECT 'Swing_Damage_Windows', COUNT(*)
FROM groundcontroltracking.Tracking.Swing_Damage_Windows
WHERE sched_id = @sched_id;
-- If any of these return >> 1 row per pitch, that's a candidate
-- for per-timestamp data.


-- ---------------------------------------------------------------
-- 5. Fallback: do we have swing_length / swing_path_tilt /
--    attack_direction stored as scalars anywhere? If yes, we can
--    do the Hermite reconstruction (the swing-path project's
--    approach) without needing raw frames.
-- ---------------------------------------------------------------
SELECT TABLE_NAME, COLUMN_NAME, DATA_TYPE
FROM groundcontroltracking.INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'Tracking'
  AND (COLUMN_NAME LIKE '%swing_length%'
    OR COLUMN_NAME LIKE '%attack_angle%'
    OR COLUMN_NAME LIKE '%attack_direction%'
    OR COLUMN_NAME LIKE '%swing_path_tilt%'
    OR COLUMN_NAME LIKE '%path_tilt%'
    OR COLUMN_NAME LIKE '%intercept%')
ORDER BY TABLE_NAME, COLUMN_NAME;

-- Also check the Astros side
SELECT TABLE_NAME, COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'Astros'
  AND (COLUMN_NAME LIKE '%swing_length%'
    OR COLUMN_NAME LIKE '%attack_angle%'
    OR COLUMN_NAME LIKE '%attack_direction%'
    OR COLUMN_NAME LIKE '%swing_path_tilt%'
    OR COLUMN_NAME LIKE '%path_tilt%')
ORDER BY TABLE_NAME, COLUMN_NAME;
