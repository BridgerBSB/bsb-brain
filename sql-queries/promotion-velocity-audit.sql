-- =========================================================================
-- promotion-velocity-audit.sql
-- PRE-FLIGHT AUDIT for Sam Niedorf's "org promotion velocity" one-off.
-- Run this FIRST on the work laptop (DB access) before any cohort/event SQL.
-- =========================================================================
-- Question we are eventually answering (Sam, 2026-06-02):
--   "Are we a team that moves position players / pitchers from one level to
--    the next quicker or slower than other teams?" — measured as aggregated
--    PA (hitters) / IP (pitchers) accumulated at a level BEFORE first promotion,
--    for the top-10 Asset-Value players in each org's system.
--
-- This file answers the ONLY blocking unknowns before we can build the cohort:
--   A. Does `player_val.asset_value` exist? What is its grain + org coverage?
--   B. What signing-bonus source(s) exist, and how complete are they per org?
--   C. Side-by-side: HOU top-10 under asset_value vs under signing bonus
--      (so Sam can eyeball which "AV" definition he actually wants).
--   D. Acquisition-since-2022 + acquiring-org signal (cohort gate feasibility).
--
-- NOTHING here is destructive — all SELECTs. Run section-by-section, paste
-- the result shapes back, and we lock the cohort definition from real data.
--
-- Column provenance (verified offline by codebase grep, no DB):
--   R4_Draft_Query / PP_MASTER  -> .claude/rules/draft-tables.md
--   TR_HISTORY / TR_NAME_LKUP   -> .claude/rules/org-board.md
--   Pitches_View / Schedule_View/ Events_View / Players -> 02_label_promoted.sql
--   MLBAM.Teams org canon       -> .claude/rules/org-codes.md
--   player_val.*                -> UNKNOWN -> Section A resolves it.
-- =========================================================================

SET NOCOUNT ON;

-- =========================================================================
-- SECTION A — Resolve `player_val.asset_value` (the one undocumented table)
-- =========================================================================
-- We do not know if `player_val` is a schema, a table, or a column. Probe all
-- three interpretations. Run A1-A4; whichever returns rows tells us the shape.

-- A1: Any table whose name OR schema looks like player_val / valuation -------
SELECT TABLE_CATALOG, TABLE_SCHEMA, TABLE_NAME, TABLE_TYPE
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA LIKE '%player%val%'
   OR TABLE_NAME   LIKE '%player%val%'
   OR TABLE_NAME   LIKE '%asset%'
   OR TABLE_NAME   LIKE '%valuation%'
ORDER BY TABLE_SCHEMA, TABLE_NAME;

-- A2: Any COLUMN named asset_value (or similar) anywhere ---------------------
SELECT TABLE_SCHEMA, TABLE_NAME, COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE COLUMN_NAME LIKE '%asset%val%'
   OR COLUMN_NAME LIKE '%surplus%'
   OR COLUMN_NAME LIKE '%player_val%'
ORDER BY TABLE_SCHEMA, TABLE_NAME, COLUMN_NAME;

-- A3: Full column list for the table(s) found in A1/A2 -----------------------
--   >>> EDIT the schema/table below to whatever A1/A2 returned, then run. <<<
-- SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE
-- FROM INFORMATION_SCHEMA.COLUMNS
-- WHERE TABLE_SCHEMA = 'player_val' AND TABLE_NAME = '<TABLE_FROM_A1>'
-- ORDER BY ORDINAL_POSITION;

-- A4: Grain + org coverage + freshness of the value table --------------------
--   >>> EDIT table name + the player/org/date column names from A3. <<<
--   Goal: confirm (a) row grain (1 per player? per player-season? per snapshot?),
--         (b) it spans all 30 orgs (Zac confirmed it should),
--         (c) most recent refresh date (so "top 10 AV" = current snapshot).
-- SELECT TOP 50 *
-- FROM player_val.<TABLE_FROM_A1>
-- ORDER BY <date_or_id_col> DESC;
--
-- -- coverage / grain summary once columns are known:
-- SELECT
--     COUNT(*)                         AS n_rows,
--     COUNT(DISTINCT <player_id_col>)  AS n_distinct_players,
--     COUNT(DISTINCT <org_col>)        AS n_distinct_orgs,        -- expect 30
--     MIN(<date_col>)                  AS earliest,
--     MAX(<date_col>)                  AS latest
-- FROM player_val.<TABLE_FROM_A1>;


-- =========================================================================
-- SECTION B — Signing-bonus sources + per-org completeness
-- =========================================================================
-- Sam's literal phrasing was "how much we signed players for." That is the
-- SIGNING BONUS (acquisition cost), which is a DIFFERENT number than a
-- computed asset_value. We surface both so Sam can choose.

-- B1: R4_Draft_Query signing-bonus coverage by org (drafted players) --------
--   draft_org is LOWERCASE per draft-tables.md.
SELECT
    dq.draft_org,
    COUNT(*)                                              AS n_drafted_rows,
    SUM(CASE WHEN dq.signing_bonus IS NOT NULL THEN 1 ELSE 0 END) AS n_with_bonus,
    SUM(CASE WHEN dq.signed = 1 THEN 1 ELSE 0 END)        AS n_signed,
    MIN(dq.draft_year)                                    AS min_year,
    MAX(dq.draft_year)                                    AS max_year
FROM MLB_eBis.R4_Draft_Query dq
WHERE dq.draft_year >= 2022
GROUP BY dq.draft_org
ORDER BY dq.draft_org;

-- B2: Does PP_MASTER carry a signing-bonus column (for IFA / UDFA)? ----------
--   draft-tables.md does NOT list a bonus column on PP_MASTER, so probe for it.
SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'MLB_eBis'
  AND TABLE_NAME   = 'PP_MASTER'
  AND (COLUMN_NAME LIKE '%bonus%'
       OR COLUMN_NAME LIKE '%sign%'
       OR COLUMN_NAME LIKE '%amount%'
       OR COLUMN_NAME LIKE '%val%')
ORDER BY COLUMN_NAME;

-- B3: International-signing bonus source probe -------------------------------
--   IFA bonuses often live in a dedicated eBis table. Probe broadly.
SELECT TABLE_SCHEMA, TABLE_NAME
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'MLB_eBis'
  AND (TABLE_NAME LIKE '%bonus%'
       OR TABLE_NAME LIKE '%ifa%'
       OR TABLE_NAME LIKE '%intl%'
       OR TABLE_NAME LIKE '%international%'
       OR TABLE_NAME LIKE '%sign%')
ORDER BY TABLE_NAME;


-- =========================================================================
-- SECTION C — HOU top-10 under each AV definition, side by side
-- =========================================================================
-- The decision deliverable for Sam: same 10 slots, two valuations. Eyeball
-- which list "looks like our top guys." Whichever he picks becomes the
-- cohort definition for all 30 orgs.

-- C1: HOU top-10 by SIGNING BONUS (drafted, 2022+) --------------------------
--   IFA/UDFA excluded here only because R4 holds drafted players; B2/B3 tell
--   us whether we can union IFA bonuses in for the real cohort build.
SELECT TOP 10
    dq.groundcontrol_id,
    dq.first_name, dq.last_name,
    dq.position,
    dq.draft_year,
    dq.signing_bonus
FROM MLB_eBis.R4_Draft_Query dq
WHERE dq.draft_org = 'hou'
  AND dq.draft_year >= 2022
  AND dq.signing_bonus IS NOT NULL
ORDER BY dq.signing_bonus DESC;

-- C2: HOU top-10 by asset_value ---------------------------------------------
--   >>> FILL IN once Section A resolves the table/columns. Template: <<<
-- SELECT TOP 10
--     pv.<player_id_col>,
--     pv.<asset_value_col>,
--     pl.first_name, pl.last_name
-- FROM player_val.<TABLE_FROM_A1> pv
-- LEFT JOIN Astros.Players pl ON pl.<join_id> = pv.<player_id_col>
-- WHERE pv.<org_col> = 'HOU'           -- or whatever org form A4 shows
--   AND pv.<date_col> = (SELECT MAX(<date_col>) FROM player_val.<TABLE_FROM_A1>)
-- ORDER BY pv.<asset_value_col> DESC;


-- =========================================================================
-- SECTION D — Acquisition-since-2022 + acquiring-org feasibility
-- =========================================================================
-- Cohort gate is "acquired since 2022, any source (draft / IFA / trade)."
-- Draft + IFA acquisition years are easy (draft_year / R4YEAR). Trade-in needs
-- TR_HISTORY. These probes confirm we can attribute an acquisition year+org.

-- D1: TR_HISTORY transaction-name catalog (find the trade-acquire codes) -----
--   org-board.md documents TRANS/OUTRT as trades. Confirm the live catalog so
--   we pick the right POST_ORG_LK = current-org acquisition events.
SELECT
    lk.transactionname_lk,
    lk.transactionname,
    lk.category,
    COUNT(*) AS n_since_2022
FROM MLB_eBis.TR_HISTORY h
JOIN MLB_eBis.TR_NAME_LKUP lk
    ON lk.transactionname_lk = h.TRANSACTIONNAME_LK
WHERE h.TRANSACTION_DTSTMP >= '2022-01-01'
GROUP BY lk.transactionname_lk, lk.transactionname, lk.category
ORDER BY n_since_2022 DESC;

-- D2: PP_MASTER R4YEAR distribution (signing/eligibility year for IFA/UDFA) --
SELECT
    pm.R4YEAR,
    COUNT(*) AS n_players
FROM MLB_eBis.PP_MASTER pm
WHERE pm.EMPLOYEE_FLG = 0
GROUP BY pm.R4YEAR
ORDER BY pm.R4YEAR DESC;


-- =========================================================================
-- SECTION E — Level-ladder + activity-source sanity (reused from modeling)
-- =========================================================================
-- Confirms the PA/IP-at-level machinery the event detector will reuse.

-- E1: Level codes present in real R-season games (which rungs exist?) --------
--   Confirms the ladder we rank. gc2_level_code splits DSL/FCL (level-codes.md).
SELECT
    sv.gc2_level_code,
    sv.level_code,
    COUNT(DISTINCT sv.sched_id) AS n_games
FROM Astros.Schedule_View sv
WHERE sv.sched_type = 'R'
  AND sv.year BETWEEN 2022 AND 2026
GROUP BY sv.gc2_level_code, sv.level_code
ORDER BY n_games DESC;

-- E2: IP source sanity — Gamelog_Pitching.outs exists + populated -----------
--   ip-calculation.md: IP via MLBAM.Gamelog_Pitching.outs (gold standard).
SELECT TOP 20
    gp.*
FROM MLBAM.Gamelog_Pitching gp
ORDER BY gp.outs DESC;
-- (If the table/column name differs, fall back to Events_View outs_after -
--  outs_before per ip-calculation.md.)

-- =========================================================================
-- AFTER RUNNING: paste back the shapes from A1-A4, B1-B3, C1, D1, E1 and we
-- lock (1) the AV definition, (2) IFA-bonus union feasibility, (3) the level
-- ladder, then build the cohort + event-detection SQL.
-- =========================================================================
