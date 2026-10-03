-- bat-trajectory-discovery-v2.sql
-- Follow-up to bat-trajectory-discovery.sql after v1 revealed:
--   Swing_Shapes has columns Km30, Km15, K0, K15, K30, K45 + plane_p0/p1/p2 + loft, tilt
--   But: K-prefix columns are single scalars (not x/y/z triples) — meaning unclear.
--
-- Goal of v2: nail down what K0 / Km30 / K45 actually represent before plotting.
--
-- Run all 5 sections, paste back to Claude.

-- ============================================================
-- SECTION 1 — Documentation for the K-prefix columns
-- ============================================================
-- LK_Kinematic_Timestamps likely names the canonical timestamp labels.
-- Hoping for rows like: ('Km30', -30, 'ms before contact'), ('K0', 0, 'contact'), etc.

SELECT TOP 100 *
FROM groundcontroltracking.Tracking.LK_Kinematic_Timestamps
ORDER BY 1;

-- ============================================================
-- SECTION 2 — Documentation for the kinematic segments + ball traj
-- ============================================================
-- These might define what Km30..K45 measure (head position? barrel? sweet spot?)

SELECT TOP 100 *
FROM groundcontroltracking.Tracking.LK_Kinematic_Segments
ORDER BY 1;

SELECT TOP 100 *
FROM groundcontroltracking.Tracking.LK_Ball_Trajectory_Types
ORDER BY 1;

-- ============================================================
-- SECTION 3 — Full column list for Swing_Shapes
-- ============================================================
-- v1 only showed the value columns; we want EVERY column including any
-- units / descriptions that might be encoded in the column comments.

SELECT
    c.COLUMN_NAME,
    c.DATA_TYPE,
    c.IS_NULLABLE,
    c.NUMERIC_PRECISION,
    c.ORDINAL_POSITION
FROM groundcontroltracking.INFORMATION_SCHEMA.COLUMNS c
WHERE c.TABLE_SCHEMA = 'Tracking'
  AND c.TABLE_NAME = 'Swing_Shapes'
ORDER BY c.ORDINAL_POSITION;

-- Also pull any extended properties / comments if SQL Server has them:
SELECT
    OBJECT_NAME(ep.major_id) AS table_name,
    c.name AS column_name,
    ep.value AS description
FROM groundcontroltracking.sys.extended_properties ep
JOIN groundcontroltracking.sys.columns c
    ON ep.major_id = c.object_id AND ep.minor_id = c.column_id
WHERE OBJECT_NAME(ep.major_id) IN ('Swing_Shapes', 'Swing_Contact_Values', 'Hitter_Kinematics')
  AND ep.name = 'MS_Description';

-- ============================================================
-- SECTION 4 — Coverage check: HOU MLB BIPs with Swing_Shapes data
-- ============================================================
-- How sparse is this table? % of HOU 2026 MLB BIPs that have a Swing_Shapes row.

SELECT
    COUNT(*) AS total_hou_mlb_bips_2026,
    COUNT(ss.sched_id) AS bips_with_swing_shapes,
    CAST(100.0 * COUNT(ss.sched_id) / NULLIF(COUNT(*), 0) AS DECIMAL(5,2)) AS pct_with_shapes
FROM Astros.Pitches_View pv
JOIN Astros.Schedule_View sv ON pv.sched_id = sv.sched_id
JOIN Astros.Events_View ev
    ON ev.sched_id = pv.sched_id AND ev.event_id = pv.ab_event_id
JOIN groundcontroltracking.Tracking.Plays tp
    ON tp.sched_id = pv.sched_id AND tp.astros_pitch_id = pv.pitch_id
LEFT JOIN groundcontroltracking.Tracking.Swing_Shapes ss
    ON ss.sched_id = tp.sched_id AND ss.tracking_play_id = tp.tracking_play_id
WHERE sv.year = 2026
  AND sv.level_code = 'mlb'
  AND sv.sched_type = 'R'
  AND pv.pitch_result_id IN (12, 13, 14)   -- BIP only
  AND pv.pitch_id > 0
  AND EXISTS (
      SELECT 1 FROM MLBAM.Teams t
      WHERE t.team_id IN (ev.batting_team_id, ev.fielding_team_id)
        AND UPPER(t.org_abbrev) = 'HOU'
        AND t.season = sv.year
  );

-- Also for SCV (contact-frame baseline — should be much higher coverage)
SELECT
    COUNT(*) AS total_hou_mlb_bips_2026,
    COUNT(scv.sched_id) AS bips_with_scv,
    CAST(100.0 * COUNT(scv.sched_id) / NULLIF(COUNT(*), 0) AS DECIMAL(5,2)) AS pct_with_scv
FROM Astros.Pitches_View pv
JOIN Astros.Schedule_View sv ON pv.sched_id = sv.sched_id
JOIN Astros.Events_View ev
    ON ev.sched_id = pv.sched_id AND ev.event_id = pv.ab_event_id
JOIN groundcontroltracking.Tracking.Plays tp
    ON tp.sched_id = pv.sched_id AND tp.astros_pitch_id = pv.pitch_id
LEFT JOIN groundcontroltracking.Tracking.Swing_Contact_Values scv
    ON scv.sched_id = tp.sched_id AND scv.tracking_play_id = tp.tracking_play_id
WHERE sv.year = 2026
  AND sv.level_code = 'mlb'
  AND sv.sched_type = 'R'
  AND pv.pitch_result_id IN (12, 13, 14)
  AND pv.pitch_id > 0
  AND EXISTS (
      SELECT 1 FROM MLBAM.Teams t
      WHERE t.team_id IN (ev.batting_team_id, ev.fielding_team_id)
        AND UPPER(t.org_abbrev) = 'HOU'
        AND t.season = sv.year
  );

-- ============================================================
-- SECTION 5 — Sample 10 swings sorted by bat speed
-- ============================================================
-- If K0/K15/K30/K45 are POSITION values, higher bat speed should NOT
-- monotonically increase them (position is independent of speed).
-- If they're VELOCITY/CURVATURE values, they should correlate with bat speed.
-- Eyeball the table to figure out which.

SELECT TOP 20
    pv.sched_id,
    pv.pitch_id,
    pv.batter_id,
    -- Bat speed at contact (canonical, mph)
    CAST(
        SQRT(POWER(scv.batvx_con, 2) + POWER(scv.batvy_con, 2) + POWER(scv.batvz_con, 2))
        * 0.681818 AS DECIMAL(5,2)
    ) AS bat_speed_mph,
    -- Swing_Shapes scalars
    ss.Km30, ss.Km15, ss.K0, ss.K15, ss.K30, ss.K45,
    ss.plane_p0, ss.plane_p1, ss.plane_p2,
    ss.loft, ss.tilt,
    ss.x0, ss.y0, ss.z0
FROM Astros.Pitches_View pv
JOIN Astros.Schedule_View sv ON pv.sched_id = sv.sched_id
JOIN groundcontroltracking.Tracking.Plays tp
    ON tp.sched_id = pv.sched_id AND tp.astros_pitch_id = pv.pitch_id
JOIN groundcontroltracking.Tracking.Swing_Contact_Values scv
    ON scv.sched_id = tp.sched_id AND scv.tracking_play_id = tp.tracking_play_id
JOIN groundcontroltracking.Tracking.Swing_Shapes ss
    ON ss.sched_id = tp.sched_id AND ss.tracking_play_id = tp.tracking_play_id
WHERE sv.year = 2026
  AND sv.level_code = 'mlb'
  AND sv.sched_type = 'R'
  AND pv.pitch_result_id IN (12, 13, 14)
  AND pv.pitch_id > 0
  AND scv.batvx_con IS NOT NULL
ORDER BY bat_speed_mph DESC;

-- Diagnostic note for paste-back:
-- If K0 monotonically increases with bat_speed_mph → it's likely velocity/curvature
-- If K0 stays roughly constant (~0.4) regardless of bat_speed_mph → it's position/coord
-- If K0 correlates with loft → it's an angular measurement
