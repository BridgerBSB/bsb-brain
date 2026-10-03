-- Jacob Morrison — bridge amateur gc_id ↔ pro gc_id via R4_Draft_Query
-- ===================================================================
-- Step 1 of the prior diagnostic showed two candidate ids for the
-- same Jacob Morrison (b. 2003-09-13, RHP):
--   • 197123  → real PP_MASTER row (ebis 5021385, mlbam 804756, MIL A-ball)
--   • 246997  → amateur tracking gc_id (NULL ebis/mlbam, NULL DOB,
--                holds his college bbc + FCL rok pitches in 2025)
--   • 1304303 → duplicate stub of 197123 (same DOB + throws)
-- Plus 119159 (DOB 1999-12-29) — DIFFERENT human, exclude.
--
-- We can't auto-merge on name+throws alone (over-merges 119159).
-- We can't merge on DOB (246997 has NULL DOB).
--
-- The clean bridge for 2025 draftees: R4_Draft_Query records the
-- draft event with whichever gc_id was active at the amateur side.
-- If R4 returns a gc_id for "Jacob Morrison" + draft_year=2025 +
-- school_type=4Y, that gc_id IS the amateur half of the same human
-- whose post-signing PP_MASTER row is gc_id 197123.
--
-- See: .claude/rules/draft-tables.md
-- See: .claude/rules/draft-projects.md (R4-to-MLBAM mapping notes)
-- See: .claude/rules/advance-non-ebiz-pitchers.md (one-off CLI)
-- ===================================================================

DECLARE @first NVARCHAR(50) = 'Jacob';
DECLARE @last  NVARCHAR(50) = 'Morrison';


-- =====================================================================
-- Step 1 — R4_Draft_Query rows for this name
-- Returns the amateur-side gc_id + draft metadata.
-- =====================================================================
SELECT
    groundcontrol_id   AS r4_gc_id,
    mlbam_id           AS r4_mlbam_id,
    first_name,
    last_name,
    draft_year,
    draft_round,
    overall_pick,
    position,
    school_type,
    draft_org
FROM MLB_eBis.R4_Draft_Query
WHERE first_name = @first
  AND last_name  = @last
ORDER BY draft_year DESC, overall_pick;


-- =====================================================================
-- Step 2 — Confirm the bridge
-- If Step 1 returned r4_gc_id = 246997 with draft_year = 2025 AND
-- r4_mlbam_id = 804756 (matching Astros.Players gc_id 197123's
-- mlbam_id from the prior diagnostic) → CONFIRMED same human.
-- Use both gc_ids in the one-off:
--
--   python scripts/generate_advance_oneoff.py \
--       --pitcher-ids 246997 197123 1304303 \
--       --first-name Jacob --last-name Morrison \
--       --throws R --level afx --org MIL --mlbam-id 804756
--
-- Heaviest-data id (246997 = 723 pitches) listed FIRST so arm angle
-- resolves on the largest sample (per advance-non-ebiz-pitchers.md).
--
-- If R4 returns a different mlbam_id → 246997 is a different human
-- entirely (just shares the name); use only 197123 + 1304303.
-- =====================================================================
