-- TR_HISTORY + TR_NAME_LKUP discovery queries
-- Source: Connor Dwyer (Astros DB) confirmed via Slack May 6 2026
--
-- STATUS (May 6 2026): Sections 1-4 ANSWERED via initial discovery run.
-- Sections 5-10 are the next round — focused queries to nail down the
-- club-id → level-code mapping (the one missing piece for the Org Dash
-- transactions backend) + HOU-scoped sanity checks for the timeline UI.
--
-- Run on work laptop. Capture results inline as comments after each block.
-- Findings graduate to rules/db-columns.md once club_lk lookup is solved.


-- ============================================================
-- ANSWERED §1-4 (May 6 2026 results captured inline)
-- ============================================================

/* §1 SCHEMA — TR_HISTORY columns identified:
     PLAYER_ID                int  (8-digit, looks like ebis_id format)
     TRANSACTION_ID           int  (unique per row)
     TRANSACTIONTYPE_LK       varchar(2)  ('MS', 'IL', 'AA', etc — coarse bucket)
     TRANSACTIONNAME_LK       varchar(5)  ('ACPAC', 'RESTR', 'TRANS' — joins to TR_NAME_LKUP)
     TRANSACTIONSTATUS_LK     varchar  ('AP' = Approved)
     PRE_CLUB_LK              int  (NUMERIC club ID — NOT a level code)
     PRE_ORG_LK               varchar(3) UPPERCASE ('SF', 'LA', 'DET', 'SD', 'HOU')
     PRE_MJROSTERSTATUS_LK    varchar (NULL or 'ACT'/'PAC'/'NES'/'RES')
     PRE_MNROSTERSTATUS_LK    varchar (NULL or 'ACT'/'PAC'/'NES'/'RES')
     POST_CLUB_LK             int  (same numeric club ID space as PRE)
     POST_ORG_LK              varchar(3) UPPERCASE
     POST_MJROSTERSTATUS_LK   varchar
     POST_MNROSTERSTATUS_LK   varchar
     TRANSACTION_DTSTMP       datetime  (the date for timeline display)
     SUBMITTOCLUB_DTSTMP      datetime
     SUBMITTOBOC_DTSTMP       datetime
     APPR_DTSTMP              datetime
     SVE_*                    many  (service flags — outright, loaned, waivers, IL details)

   Note: SVE_* columns are mostly NULL on standard moves. Only flagged for
   contractual / waiver / IL-extension events. Skip for V1; surface later
   if a specific use case demands them.
*/

/* §1 SCHEMA — TR_NAME_LKUP columns:
     transactionname_lk       varchar(5)  (PK — join key)
     transactionname          varchar     (full English label)
     category                 varchar (NULL or 'Injury - IL Placement' /
                                              'Injury - IL Transfer' /
                                              'Injury' /
                                              'Roster Removal')
     show_by_default          bit  (1 = include in default timeline; 0 = noise)
*/

/* §2 PLAYER_ID — confirmed eBis ID format (10030xxx). Join path:
     TR_HISTORY.PLAYER_ID  ==  PP_MASTER.player_id  ==  Astros.Players.ebis_id
     Verify with one of our known HOU players below in §5.
*/

/* §3 ORG_LK — confirmed 'HOU' uppercase in PP_MASTER per db-columns.md.
   Same convention here. Filter as `WHERE post_org_lk = 'HOU' OR pre_org_lk = 'HOU'`.
*/

/* §3 CLUB_LK — STILL UNKNOWN. Numeric IDs (235=SF AAA?, 232=LA?, 689=SD MLB?,
   848=SD other affiliate?). Need a CLUB lookup table to map these → our
   level codes (ml/3a/2a/1a/1f/r/ds). See §6 below.
*/

/* §4 TRANSACTION_TYPE catalog — TR_NAME_LKUP enumerated. Key categories
   the Phase 5 UI needs:

     CATEGORY                   Codes (sample)               Badge color (suggested)
     ────────────────────────── ─────────────────────────── ──────────────────────────
     Promotion / Sign / Recall  RECOP (Recall),             green  #36B37E
                                SGNFA (Sign To MLR),
                                SGNMN (Sign To MiLR),
                                MJSEL (ML Roster Selection),
                                ACPAC (Activate Pending Active)
     Optional Assignment        OPTAS, OPTTR                blue   #0052CC
     Roster Removal             URREL, UNCRL, RELES,        grey   #6B7794
                                FAOTH, ELFA, RETIR,
                                FAXAC, FAXAD, FAXIA
     Injury — IL Placement      DL07J/DL10J/DL15J/DL60J,    yellow #FFAB00
                                PILMJ/PILMN/PFSMN/PL15L
     Injury — IL Transfer       TR07N/TR10J/TR15J/TR60J,    orange #EB6E1F
                                TFSMN/TILMJ/TILMN
     Injury (other)             REINS (Reinstate from DL),  navy   #0044A0
                                RECRT, REHAB, RHBRT
     Trade / Outright           TRANS, OUTRT, MNOUT         orange-soft #FF8A47
     Other (NULL category)      ASGEE, MXFRM, ADMIN         pass through

   Default timeline filter: `show_by_default = 1`. Skips signing housekeeping
   like ASGEE (Reassign Employee), MXFRM (Outright from Mexican League),
   R5SEL (Rule 5 Selection — already shown via SGNMN), R5RET, etc.
*/


-- ============================================================
-- §5 — VERIFY PLAYER_ID == ebis_id (sanity check)
-- ============================================================
-- Pick a known HOU player. Yainer Diaz (catcher) groundcontrol_id
-- and ebis_id should both resolve via Astros.Players. If TR_HISTORY
-- joins cleanly, we're locked.

DECLARE @gc_id INT = 1305158;  -- Dezenzo (AAA→MLB this season per kpi-roster-filter rule)

SELECT TOP 5 a.first_name, a.last_name, a.groundcontrol_id, a.ebis_id,
       h.TRANSACTION_ID, h.TRANSACTIONNAME_LK, h.TRANSACTION_DTSTMP,
       h.PRE_ORG_LK, h.PRE_CLUB_LK, h.POST_ORG_LK, h.POST_CLUB_LK
FROM Astros.Players a
JOIN MLB_eBis.TR_HISTORY h ON h.PLAYER_ID = a.ebis_id
WHERE a.groundcontrol_id = @gc_id
ORDER BY h.TRANSACTION_DTSTMP DESC;
-- Expected: returns Dezenzo's recent transactions.
-- If returns 0 rows but the player has known moves → PLAYER_ID is NOT ebis_id;
--   try a.mlbam_id or PLAYER_ID directly.


-- ============================================================
-- §6 — FIND THE CLUB → LEVEL LOOKUP TABLE (the missing piece)
-- ============================================================
-- We need to map numeric *_CLUB_LK values (235, 232, 689, 848, etc.)
-- to our level codes (ml/3a/2a/1a/1f/r/ds). Three places to look:

-- 6a. Look for any table named CLUB_* in MLB_eBis schema:
SELECT TABLE_NAME
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'MLB_eBis'
  AND (TABLE_NAME LIKE '%CLUB%' OR TABLE_NAME LIKE '%TEAM%' OR TABLE_NAME LIKE '%LK%')
ORDER BY TABLE_NAME;

-- 6b. If a CLUB_LKUP / CLUB_LK_LOOKUP / TR_CLUB_LK exists, peek at it:
-- SELECT TOP 20 * FROM MLB_eBis.<club_table>;

-- 6c. Try joining to MLBAM.Teams via team_id (might be the same numeric ID):
SELECT DISTINCT h.PRE_CLUB_LK, h.PRE_ORG_LK,
       t.team_full_name, t.org_abbrev, t.sport_abbrev
FROM MLB_eBis.TR_HISTORY h
LEFT JOIN MLBAM.Teams t ON t.team_id = h.PRE_CLUB_LK AND t.season = 2026
WHERE h.PRE_ORG_LK = 'HOU'
  AND h.TRANSACTION_DTSTMP >= '2026-01-01'
ORDER BY h.PRE_CLUB_LK;
-- If this returns matched team rows, MLBAM.Teams.team_id is the bridge.
-- sport_abbrev maps directly to our level codes (mlb/aaa/aax/afa/afx/rok/dsl).

-- 6d. Alternatively check Astros schema:
SELECT TABLE_NAME
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'Astros'
  AND (TABLE_NAME LIKE '%Club%' OR TABLE_NAME LIKE '%Team%')
ORDER BY TABLE_NAME;


-- ============================================================
-- §7 — HOU-ONLY VOLUME (drives Phase 5 design decisions)
-- ============================================================

-- 7a. Total HOU transactions per season (do we need a pin or is live OK?):
SELECT YEAR(TRANSACTION_DTSTMP) AS season,
       COUNT(*) AS n_transactions,
       COUNT(DISTINCT PLAYER_ID) AS n_unique_players
FROM MLB_eBis.TR_HISTORY
WHERE PRE_ORG_LK = 'HOU' OR POST_ORG_LK = 'HOU'
GROUP BY YEAR(TRANSACTION_DTSTMP)
ORDER BY season DESC;
-- Target: 2026 row count. If < 2000 transactions, live query is fine
-- (no pin needed). If > 5000, plan a daily Connect-scheduled pin.

-- 7b. HOU transactions in the last 7 days (drives the right rail "Recent Moves"):
SELECT TOP 25 a.first_name + ' ' + a.last_name AS player,
       h.TRANSACTION_DTSTMP, h.TRANSACTIONNAME_LK,
       lk.transactionname, lk.category,
       h.PRE_CLUB_LK, h.POST_CLUB_LK,
       h.PRE_ORG_LK, h.POST_ORG_LK,
       COALESCE(h.POST_MNROSTERSTATUS_LK, h.POST_MJROSTERSTATUS_LK) AS post_status
FROM MLB_eBis.TR_HISTORY h
LEFT JOIN MLB_eBis.TR_NAME_LKUP lk
    ON lk.transactionname_lk = h.TRANSACTIONNAME_LK
LEFT JOIN Astros.Players a ON a.ebis_id = h.PLAYER_ID
WHERE (h.PRE_ORG_LK = 'HOU' OR h.POST_ORG_LK = 'HOU')
  AND h.TRANSACTION_DTSTMP >= DATEADD(DAY, -7, GETDATE())
  AND lk.show_by_default = 1
ORDER BY h.TRANSACTION_DTSTMP DESC;


-- ============================================================
-- §8 — ONE-PLAYER FULL HISTORY (timeline render validation)
-- ============================================================
-- Max Holy gc_id 283966 (per user direction May 6 2026).

DECLARE @holy_gc INT = 283966;

SELECT a.first_name + ' ' + a.last_name AS player,
       h.TRANSACTION_DTSTMP,
       h.TRANSACTIONNAME_LK,
       lk.transactionname,
       lk.category,
       h.PRE_CLUB_LK, h.POST_CLUB_LK,
       h.PRE_ORG_LK, h.POST_ORG_LK,
       COALESCE(h.PRE_MNROSTERSTATUS_LK, h.PRE_MJROSTERSTATUS_LK) AS pre_status,
       COALESCE(h.POST_MNROSTERSTATUS_LK, h.POST_MJROSTERSTATUS_LK) AS post_status
FROM MLB_eBis.TR_HISTORY h
LEFT JOIN MLB_eBis.TR_NAME_LKUP lk
    ON lk.transactionname_lk = h.TRANSACTIONNAME_LK
LEFT JOIN Astros.Players a ON a.ebis_id = h.PLAYER_ID
WHERE a.groundcontrol_id = @holy_gc
ORDER BY h.TRANSACTION_DTSTMP DESC;


-- ============================================================
-- §9 — ONE-TEAM SEASON TRANSACTIONS (Page 2 timeline validation)
-- ============================================================
-- After §6 identifies the club_lk for Sugar Land (AAA), substitute
-- the right value below.

-- DECLARE @sugar_land_club_lk INT = ???;  -- TBD from §6
-- SELECT a.first_name + ' ' + a.last_name AS player,
--        h.TRANSACTION_DTSTMP, lk.transactionname, lk.category,
--        h.PRE_CLUB_LK, h.POST_CLUB_LK
-- FROM MLB_eBis.TR_HISTORY h
-- LEFT JOIN MLB_eBis.TR_NAME_LKUP lk ON lk.transactionname_lk = h.TRANSACTIONNAME_LK
-- LEFT JOIN Astros.Players a ON a.ebis_id = h.PLAYER_ID
-- WHERE (h.PRE_CLUB_LK = @sugar_land_club_lk OR h.POST_CLUB_LK = @sugar_land_club_lk)
--   AND YEAR(h.TRANSACTION_DTSTMP) = 2026
--   AND lk.show_by_default = 1
-- ORDER BY h.TRANSACTION_DTSTMP DESC;


-- ============================================================
-- §10 — LAST-TRANSACTION DATE PER HOU PLAYER (Org Board card stub)
-- ============================================================
-- Replaces the "moved —" stub on Org Board cards with a real date.
-- Inline LEFT JOIN to org_board_data — should be fast if HOU active
-- roster is ~250 players.

WITH hou_active AS (
    SELECT DISTINCT a.ebis_id, a.groundcontrol_id
    FROM MLB_eBis.PP_MASTER pm
    JOIN Astros.Players a ON a.ebis_id = pm.player_id
    WHERE pm.ORG_LK = 'HOU'
      AND pm.EMPLOYEE_FLG = 0
      AND COALESCE(pm.MNROSTERSTATUS_LK, pm.MJROSTERSTATUS_LK)
          NOT IN ('rel','fa','vol','dis','ti','RES','REL','FA','VOL','DIS','TI','res')
),
last_txn AS (
    SELECT h.PLAYER_ID, MAX(h.TRANSACTION_DTSTMP) AS last_txn_date
    FROM MLB_eBis.TR_HISTORY h
    JOIN hou_active hr ON hr.ebis_id = h.PLAYER_ID
    GROUP BY h.PLAYER_ID
)
SELECT hr.groundcontrol_id, hr.ebis_id, lt.last_txn_date,
       DATEDIFF(DAY, lt.last_txn_date, GETDATE()) AS days_since
FROM hou_active hr
LEFT JOIN last_txn lt ON lt.PLAYER_ID = hr.ebis_id
ORDER BY lt.last_txn_date DESC;
-- If this runs in < 1 sec → just inline-LEFT JOIN it into get_roster()
-- in pd-goals/src/roster.py. If > 5 sec → consider a 6h-cached helper.


-- ============================================================
-- §11 — FILTERED TRANSACTION TYPES BY PRESENCE IN HOU 2026
-- ============================================================
-- Sanity check: which transaction types actually fire for HOU MiLB
-- promotions in current season. Drives which badge categories get
-- prominent billing in the timeline UI.

SELECT lk.transactionname_lk, lk.transactionname, lk.category,
       lk.show_by_default,
       COUNT(*) AS n
FROM MLB_eBis.TR_HISTORY h
LEFT JOIN MLB_eBis.TR_NAME_LKUP lk
    ON lk.transactionname_lk = h.TRANSACTIONNAME_LK
WHERE (h.PRE_ORG_LK = 'HOU' OR h.POST_ORG_LK = 'HOU')
  AND YEAR(h.TRANSACTION_DTSTMP) = 2026
GROUP BY lk.transactionname_lk, lk.transactionname, lk.category, lk.show_by_default
ORDER BY n DESC;


-- ============================================================
-- §12 — IL CURRENT COUNT (right-rail "12 IL" placeholder)
-- ============================================================
-- HOU players whose current PP_MASTER status is an IL flag.
-- Per Connor's note: IL placements have transaction_type IL or
-- transactionname categories of Injury-* . But for the CURRENT
-- count we just look at PP_MASTER status.

SELECT COUNT(*) AS n_on_il
FROM MLB_eBis.PP_MASTER pm
WHERE pm.ORG_LK = 'HOU'
  AND pm.EMPLOYEE_FLG = 0
  -- IL status codes — verify with discovery on the actual values.
  AND (
       pm.MNROSTERSTATUS_LK LIKE 'PIL%' OR pm.MJROSTERSTATUS_LK LIKE 'PIL%'
    OR pm.MNROSTERSTATUS_LK LIKE 'TIL%' OR pm.MJROSTERSTATUS_LK LIKE 'TIL%'
    OR pm.MNROSTERSTATUS_LK LIKE 'DL%'  OR pm.MJROSTERSTATUS_LK LIKE 'DL%'
    OR pm.MNROSTERSTATUS_LK = 'PAC'  -- Pending Active (often IL-coming-back)
       OR pm.MJROSTERSTATUS_LK = 'PAC'
  );

-- Better: enumerate ALL distinct current PP_MASTER status values for HOU
-- so we know exactly what counts as IL vs Active vs Restricted:
SELECT MNROSTERSTATUS_LK, MJROSTERSTATUS_LK, COUNT(*) AS n
FROM MLB_eBis.PP_MASTER
WHERE ORG_LK = 'HOU' AND EMPLOYEE_FLG = 0
GROUP BY MNROSTERSTATUS_LK, MJROSTERSTATUS_LK
ORDER BY n DESC;


-- ============================================================
-- HOW TO REPORT BACK
-- ============================================================
-- Capture each query's result inline as a comment under the section.
-- Highest priority: §6 (CLUB → level mapping) — that's the single piece
-- blocking Phase 5 wiring.
--
-- Once §6 is solved, §10 + §11 + §12 are quick smoke tests, then we
-- can build the right-rail recent moves + IL count + Team View timeline.
-- Findings graduate to rules/db-columns.md TR_HISTORY section.
