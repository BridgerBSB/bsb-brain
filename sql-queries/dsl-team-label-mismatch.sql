/* ============================================================================
   DSL sub-team label mismatch — affiliate tracker Org Rankings (DSL split)
   ----------------------------------------------------------------------------
   Symptom (see screenshot): DSL split rows render as "<ORG> - Team <id>"
   (e.g. "HOU - Team 601", "HOU - Team 5005") instead of real sub-team names.
   ALL orgs are affected, including HOU.

   Root cause: the DSL split GROUPS by MLBAM team_id (dsl_team_id = mt.team_id,
   so HOU shows 601 / 5005). But _resolve_dsl_team_label() looks names up by
   MLB_eBis.GBL_CLUB_LKUP.CLUB_LK, and the hardcoded HOU fallback is 599 /
   10000055 — a DIFFERENT id space. Nothing matches -> "Team {id}" placeholder.

   Goal: find (a) what each MLBAM DSL team_id should be called, and (b) a clean
   join key so we can build the label map keyed on the SAME id the split groups
   on (MLBAM team_id), instead of GBL_CLUB_LKUP.CLUB_LK.

   Run on the work laptop (DB access). Paste all 3 result sets back.
   ============================================================================ */

-- A) The exact ids the split groups on for HOU (601 / 5005) — every column,
--    so we can see which field holds a usable Blue/Orange name.
SELECT * FROM MLBAM.Teams
WHERE team_id IN (601, 5005) AND season = 2026;

-- B) All HOU teams this season (full picture: which rows are the two DSL clubs,
--    their team_id + every name-ish column). Confirms the DSL team_ids + names.
SELECT * FROM MLBAM.Teams
WHERE season = 2026 AND org_abbrev = 'HOU';

-- C) GBL_CLUB_LKUP DSL rows for HOU. Does it carry an MLBAM team_id column we
--    can bridge CLUB_LK <-> MLBAM team_id with? (If yes, the fix can keep using
--    CLUBSHORTNAME but join on the right key. If no, we label straight from
--    MLBAM.Teams by team_id.)
SELECT * FROM MLB_eBis.GBL_CLUB_LKUP
WHERE LEVELOFPLAY_LK = 'DS' AND ORG_LK = 'HOU';

/* After you paste results:
   - If MLBAM.Teams (A/B) has a clean per-club name for 601/5005 (e.g. a
     short name or a Blue/Orange distinction) -> fix = build the DSL label map
     from MLBAM.Teams keyed on team_id (the grouping key). One source, no
     id-space mismatch.
   - If GBL_CLUB_LKUP (C) exposes an MLBAM team_id column -> fix = keep
     CLUBSHORTNAME but join GBL.<mlbam_id_col> = mt.team_id instead of
     CLUB_LK = dsl_team_id.
   Either way the hardcoded 599/10000055 fallback gets replaced with one keyed
   on MLBAM team_id. */
