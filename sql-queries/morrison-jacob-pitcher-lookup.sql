-- Jacob Morrison (MIL A-ball RHP) — non-EBIZ-pitcher diagnostic
-- ===================================================================
-- App showed: "MIL | A | RHP | T: R | 6 games | 341 pitches |
--              06/13 - 05/02/26"
--
-- The 11-month date span is the tell: standard advance flows window
-- to the most recent ~30 IP. Spanning Jun 2025 -> May 2026 means the
-- regular pitcher_id lookup is either grabbing a stub gc_id with a
-- thin trail, OR aggregating across 2-3 gc_ids that point to the
-- same human.
--
-- Step 1 surfaces every Astros.Players row for the name. The "real"
-- row has non-NULL ebis_id + mlbam_id + birthdate. Stubs are
-- everything else. Collect ALL gc_ids returned and feed them to
-- generate_advance_oneoff.py per the rule below.
--
-- Step 2 confirms data exists and shows where it lives, aggregated
-- across every gc_id sharing the name.
--
-- See: .claude/rules/advance-non-ebiz-pitchers.md
-- See: .claude/rules/advance-levels.md
-- ===================================================================

DECLARE @pitcher_first NVARCHAR(50) = 'Jacob';
DECLARE @pitcher_last  NVARCHAR(50) = 'Morrison';


-- =====================================================================
-- Step 1 — All Astros.Players rows for Jacob Morrison
-- =====================================================================
SELECT
    groundcontrol_id,
    ebis_id,
    mlbam_id,
    first_name,
    last_name,
    birthdate,
    throws
FROM Astros.Players
WHERE first_name = @pitcher_first
  AND last_name  = @pitcher_last
ORDER BY
    CASE WHEN ebis_id IS NOT NULL AND mlbam_id IS NOT NULL THEN 0 ELSE 1 END,
    groundcontrol_id;


-- =====================================================================
-- Step 2 — Last-12-months pitch activity, aggregated across ALL
-- Players rows that share the name. Confirms data exists, shows
-- level mix + recency window.
-- =====================================================================
SELECT
    sv.year,
    sv.level_code,
    sv.gc2_level_code,
    sv.sched_type,
    pv.pitcher_id,                                       -- which gc_id holds the pitches
    COUNT(*)                    AS pitches,
    COUNT(DISTINCT pv.sched_id) AS games,
    MIN(sv.sched_date)          AS first_date,
    MAX(sv.sched_date)          AS last_date
FROM Astros.Pitches_View  pv
JOIN Astros.Schedule_View sv ON sv.sched_id = pv.sched_id
JOIN Astros.Players       p  ON p.groundcontrol_id = pv.pitcher_id
WHERE p.first_name = @pitcher_first
  AND p.last_name  = @pitcher_last
  AND sv.sched_date >= DATEADD(YEAR, -1, GETDATE())
  AND pv.pitch_id > 0
GROUP BY sv.year, sv.level_code, sv.gc2_level_code, sv.sched_type, pv.pitcher_id
ORDER BY last_date DESC, sv.level_code, sv.sched_type;


-- =====================================================================
-- After confirming the data, run:
--
--   python scripts/generate_advance_oneoff.py \
--       --pitcher-ids <gc_id_1> [<gc_id_2> ...] \
--       --first-name Jacob --last-name Morrison \
--       --throws R \
--       --level afx \
--       --org MIL
--
-- Pass EVERY gc_id from Step 1 (real + stubs) so the IN-clause
-- aggregates the full data trail. Put the heaviest-data gc_id
-- FIRST so arm angle resolves (per advance-non-ebiz-pitchers.md).
-- =====================================================================
