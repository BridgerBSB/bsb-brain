-- ============================================================
-- INJURY DASHBOARD — discovery round 2: the MEDICAL tables
-- ============================================================
-- Round-1 §3c surfaced real medical tables. The Jun-10 "TR_HISTORY is
-- the ONLY injury signal, body-map DROPPED" conclusion may be wrong.
-- This probes the TWO that could carry LEAGUE-WIDE (30-org) injury type
-- / body part — the only kind useful for the league dashboard:
--     MLBAM.PBP_Injury          (MLBAM = all 30 orgs)
--     SportsMed.Injury_Data_BPro (Baseball Prospectus league-wide ledger)
--
-- Plus a quick look at the HOU-internal SportsMed.Sports_Medicine (for a
-- possible HOU-only deep-dive tab later).
--
-- Run on work laptop. Capture each result inline / paste back.
-- KEY QUESTION: does either league-wide table carry body region / diagnosis
-- / mechanism / RTP date keyed to player_id + date, for all 30 orgs?

DECLARE @season INT = 2026;

-- ============================================================
-- §1 — MLBAM.PBP_Injury : columns
-- ============================================================
SELECT COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'MLBAM' AND TABLE_NAME = 'PBP_Injury'
ORDER BY ORDINAL_POSITION;

-- §1b — volume + season coverage + org coverage (look for a player/team/date col)
-- EDIT the column names below to match §1 once you see them, then run.
-- SELECT COUNT(*) AS n_rows, MIN(<date_col>) AS min_dt, MAX(<date_col>) AS max_dt
-- FROM MLBAM.PBP_Injury;

-- §1c — sample 25 rows to eyeball whether body part / diagnosis text is present
SELECT TOP 25 * FROM MLBAM.PBP_Injury;


-- ============================================================
-- §2 — SportsMed.Injury_Data_BPro : columns
-- ============================================================
SELECT COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'SportsMed' AND TABLE_NAME = 'Injury_Data_BPro'
ORDER BY ORDINAL_POSITION;

-- §2b — is it league-wide or HOU-only? sample 25 rows; look for body part,
-- injury type, side, mechanism, RTP/return date, and an org/team spread.
SELECT TOP 25 * FROM SportsMed.Injury_Data_BPro;


-- ============================================================
-- §3 — SportsMed.Sports_Medicine : columns (likely HOU-internal)
-- ============================================================
-- Only relevant if we later add an HOU-only medical deep-dive tab.
SELECT COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'SportsMed' AND TABLE_NAME = 'Sports_Medicine'
ORDER BY ORDINAL_POSITION;

-- §3b — quick org spread check: is it >1 org (league) or just HOU?
-- EDIT <org_col> / <player_col> to match §3 once you see them.
-- SELECT TOP 25 * FROM SportsMed.Sports_Medicine;


-- ============================================================
-- HOW TO REPORT BACK
-- ============================================================
-- For §1 (PBP_Injury) and §2 (Injury_Data_BPro), the decisive questions:
--   (a) Is there a BODY PART / injury TYPE / DIAGNOSIS / SIDE column?
--   (b) Is there a RETURN / RTP date (so days-missed could come from medical,
--       not just the IL-stint proxy)?
--   (c) Does it span ALL 30 orgs (league-wide) or only HOU?
-- If (a)+(c) are YES on EITHER table -> body-map + diagnosis breakdowns are
-- back ON for the league dashboard. Paste the column lists + a couple sample
-- rows (redact nothing — it's internal) and I'll wire the source decision.
