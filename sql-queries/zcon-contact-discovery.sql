-- ============================================================================
-- MLBAM Pitch_fx Discovery Queries
-- Purpose: Find the correct event_result / event_type values that represent
--          swinging strikes (whiffs) since pitch_result_id doesn't exist in Pitch_fx
-- Database: GroundControl2 (SQL Server)
-- Schema: MLBAM
-- Date: Feb 2, 2026
-- ============================================================================

-- Q1: All distinct event_result values where did_swing = 'Y', with counts (2025 data)
-- Shows what happens when a player swings. Look for patterns like 'swinging_strike',
-- 'whiff', 'swing_and_miss', etc.
-- ============================================================================
SELECT TOP 100
    event_result,
    COUNT(*) AS result_count,
    COUNT(DISTINCT year) AS years_present
FROM MLBAM.Pitch_fx
WHERE did_swing = 'Y'
    AND year = 2025
GROUP BY event_result
ORDER BY result_count DESC;


-- Q2: All distinct event_type values where did_swing = 'Y', with counts
-- Different classification system than event_result. May help distinguish whiffs.
-- ============================================================================
SELECT TOP 100
    event_type,
    COUNT(*) AS type_count,
    COUNT(DISTINCT year) AS years_present
FROM MLBAM.Pitch_fx
WHERE did_swing = 'Y'
    AND year = 2025
GROUP BY event_type
ORDER BY type_count DESC;


-- Q3: Cross-tab of event_result vs event_type for swings only (top 20 combos)
-- Shows which event_result + event_type combinations occur most frequently.
-- Helps identify the "whiff" signature.
-- ============================================================================
SELECT TOP 20
    event_result,
    event_type,
    COUNT(*) AS combo_count
FROM MLBAM.Pitch_fx
WHERE did_swing = 'Y'
    AND year = 2025
GROUP BY event_result, event_type
ORDER BY combo_count DESC;


-- Q4: Check if there's a way to distinguish contact vs whiff
-- Look for patterns: rows with 'strike' in event_result likely = whiff
-- Rows with 'foul' likely = contact, 'hit' likely = contact
-- ============================================================================
SELECT TOP 100
    event_result,
    COUNT(*) AS swing_count,
    CASE
        WHEN event_result LIKE '%strike%' THEN 'Possible Whiff (strike)'
        WHEN event_result LIKE '%foul%' THEN 'Possible Contact (foul)'
        WHEN event_result LIKE '%hit%' THEN 'Possible Contact (hit)'
        WHEN event_result LIKE '%miss%' THEN 'Possible Whiff (miss)'
        WHEN event_result LIKE '%swing%' THEN 'Swing Related'
        ELSE 'Other'
    END AS classification
FROM MLBAM.Pitch_fx
WHERE did_swing = 'Y'
    AND year = 2025
GROUP BY event_result, CASE
        WHEN event_result LIKE '%strike%' THEN 'Possible Whiff (strike)'
        WHEN event_result LIKE '%foul%' THEN 'Possible Contact (foul)'
        WHEN event_result LIKE '%hit%' THEN 'Possible Contact (hit)'
        WHEN event_result LIKE '%miss%' THEN 'Possible Whiff (miss)'
        WHEN event_result LIKE '%swing%' THEN 'Swing Related'
        ELSE 'Other'
    END
ORDER BY swing_count DESC;


-- Q5: Sample 10 rows where did_swing='Y' showing event_result, event_type, pitch_type
-- Also shows called_strike_chance_mlb to understand zone context
-- If we can join to Hit_fx, show whether contact occurred (non-null hit data = contact)
-- ============================================================================
SELECT TOP 10
    pf.did_swing,
    pf.event_result,
    pf.event_type,
    pf.pitch_type,
    pf.called_strike_chance_mlb,
    pf.year,
    CASE WHEN hf.hit_id IS NOT NULL THEN 'HAS_HIT_DATA (Contact)' ELSE 'NO_HIT_DATA (Whiff?)' END AS contact_indicator
FROM MLBAM.Pitch_fx pf
LEFT JOIN MLBAM.Hit_fx hf
    ON pf.pitch_id = hf.pitch_id
WHERE pf.did_swing = 'Y'
    AND pf.year = 2025
ORDER BY pf.pitch_id DESC;


-- Q6: Check what tables exist in MLBAM schema that contain pitch_result_id
-- This column might live in a different table (Pitches, Events, etc.)
-- ============================================================================
SELECT
    TABLE_NAME,
    COLUMN_NAME
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'MLBAM'
    AND COLUMN_NAME = 'pitch_result_id'
ORDER BY TABLE_NAME;


-- Q7: Check MLBAM.Pitches table structure (if it exists)
-- This is often where coded result IDs live in MLBAM
-- ============================================================================
SELECT
    COLUMN_NAME,
    DATA_TYPE,
    CHARACTER_MAXIMUM_LENGTH,
    NUMERIC_PRECISION,
    NUMERIC_SCALE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'MLBAM'
    AND TABLE_NAME = 'Pitches'
ORDER BY ORDINAL_POSITION;


-- Q8 (BONUS): If Pitches table exists, show pitch_result_id values for swings
-- This will reveal the actual numeric codes (like 10, 21, 22, 23 mentioned in old query)
-- ============================================================================
SELECT TOP 20
    p.pitch_result_id,
    COUNT(*) AS count_swings
FROM MLBAM.Pitches p
WHERE p.swing = 1
    AND p.year = 2025
GROUP BY p.pitch_result_id
ORDER BY count_swings DESC;


-- Q9 (BONUS): Cross Pitch_fx with Pitches to map event_result to pitch_result_id
-- Once we find the relationship, we can map which event_result values = which pitch_result_ids
-- ============================================================================
SELECT TOP 20
    pf.event_result,
    p.pitch_result_id,
    COUNT(*) AS row_count
FROM MLBAM.Pitch_fx pf
INNER JOIN MLBAM.Pitches p
    ON pf.pitch_id = p.pitch_id
        AND pf.year = p.year
WHERE pf.did_swing = 'Y'
    AND pf.year = 2025
    AND p.pitch_result_id IS NOT NULL
GROUP BY pf.event_result, p.pitch_result_id
ORDER BY row_count DESC;


-- ============================================================================
-- NEXT STEPS (once above queries run):
-- 1. Review Q1-Q3 output to identify event_result values representing whiffs
-- 2. Check Q6-Q7 to see if pitch_result_id exists in Pitches table
-- 3. If Q9 works, use it to create definitive mapping:
--    event_result IN (...) <-- equivalent to --> pitch_result_id NOT IN (10,21,22,23)
-- 4. Validate with domain expert (what counts as a whiff vs contact)
-- ============================================================================
