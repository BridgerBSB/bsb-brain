-- ============================================================
-- INJURY DASHBOARD — league-wide (30-org) discovery
-- ============================================================
-- Source tables: MLB_eBis.TR_HISTORY + MLB_eBis.TR_NAME_LKUP + MLB_eBis.PP_MASTER
-- (the league-wide eBis transaction log — PRE/POST_ORG_LK covers all 30 orgs).
--
-- GOAL: confirm we can build a 30-org injury dashboard (IL placements, days
-- missed, org rankings, per-org pages) entirely off TR_HISTORY, and find out
-- whether ANY column carries a real injury TYPE / body part (vs only IL length).
--
-- Run on work laptop (DB access). Capture each result inline as a comment.
-- Findings graduate to rules/db-columns.md + the injury-dashboard design doc.
--
-- Confirmed already (tr-history-discovery.sql + transactions_data.py):
--   IL-PLACEMENT codes (category 'Injury - IL Placement'):
--     DL07J(7d concussion) DL07N(7d) DL10J(10d) DL15J(15d) DL60J/DL60N(60d)
--     PILMJ(IL ML) PILMN(IL MiL) PFSMN(Full-Season IL) PL15L(15d IL)
--   IL-TRANSFER codes (category 'Injury - IL Transfer', length change mid-stint):
--     TR07N TR10J TR15J TR60J TFSMN TILMJ TILMN
--   REINSTATEMENT / activation codes (end a stint):
--     REINS RHBRT RSTIL RENES REACT RCACT ACPAC
-- The "type" we can derive = IL LENGTH (7/10/15/60-day, full-season, concussion).
-- The body-part / diagnosis is the open question §3 answers.

DECLARE @season INT = 2026;


-- ============================================================
-- §1 — League-wide IL-placement volume (pin-vs-live decision)
-- ============================================================
-- How many IL placements per season across all 30 orgs? Decides whether
-- the dashboard runs live (6h cache) or needs a Connect-scheduled pin.
SELECT YEAR(h.TRANSACTION_DTSTMP) AS season,
       COUNT(*)                    AS n_il_placements,
       COUNT(DISTINCT h.PLAYER_ID) AS n_players,
       COUNT(DISTINCT h.POST_ORG_LK) AS n_orgs
FROM MLB_eBis.TR_HISTORY h
JOIN MLB_eBis.TR_NAME_LKUP lk ON lk.transactionname_lk = h.TRANSACTIONNAME_LK
WHERE lk.category IN ('Injury - IL Placement', 'Injury - IL Transfer')
GROUP BY YEAR(h.TRANSACTION_DTSTMP)
ORDER BY season DESC;
-- Guidance: if a season has < ~3000 placements, live query w/ 6h cache is fine.
-- If much larger across 5 historical years, plan a parquet pin per season.


-- ============================================================
-- §2 — Enumerate EVERY injury-category code firing league-wide
-- ============================================================
-- Locks the exact placement / transfer / reinstatement code sets so the
-- stint pairing (§4) is complete. Also surfaces any code we haven't seen.
SELECT lk.category,
       lk.transactionname_lk,
       lk.transactionname,
       h.TRANSACTIONTYPE_LK,
       COUNT(*) AS n
FROM MLB_eBis.TR_HISTORY h
JOIN MLB_eBis.TR_NAME_LKUP lk ON lk.transactionname_lk = h.TRANSACTIONNAME_LK
WHERE (lk.category LIKE 'Injury%'
       OR lk.transactionname_lk IN ('REINS','RHBRT','RSTIL','RENES','REACT','RCACT','ACPAC'))
  AND YEAR(h.TRANSACTION_DTSTMP) = @season
GROUP BY lk.category, lk.transactionname_lk, lk.transactionname, h.TRANSACTIONTYPE_LK
ORDER BY lk.category, n DESC;


-- ============================================================
-- §3 — *** THE KEY QUESTION ***: is injury TYPE / body part anywhere?
-- ============================================================
-- The transaction is "Placed on 15-day IL", not "right shoulder strain."
-- Best hope = an SVE_* column or a free-text note. Probe in 3 ways.

-- 3a. List every TR_HISTORY column (look for anything *injury*/*note*/*desc*/*reason*/SVE_*):
SELECT COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'MLB_eBis' AND TABLE_NAME = 'TR_HISTORY'
ORDER BY ORDINAL_POSITION;

-- 3b. For each SVE_* (or note/desc/reason) column, count non-null on IL placements
--     and show a few sample values. Replace <SVE_COL> with each candidate from 3a.
-- SELECT TOP 25 h.<SVE_COL>, COUNT(*) OVER () AS n_nonnull_sample
-- FROM MLB_eBis.TR_HISTORY h
-- JOIN MLB_eBis.TR_NAME_LKUP lk ON lk.transactionname_lk = h.TRANSACTIONNAME_LK
-- WHERE lk.category LIKE 'Injury%' AND h.<SVE_COL> IS NOT NULL
--   AND YEAR(h.TRANSACTION_DTSTMP) = @season;

-- 3c. Is there ANY other eBis table that might hold a diagnosis / medical record?
SELECT TABLE_SCHEMA, TABLE_NAME
FROM INFORMATION_SCHEMA.TABLES
WHERE (TABLE_NAME LIKE '%INJUR%' OR TABLE_NAME LIKE '%MEDIC%'
       OR TABLE_NAME LIKE '%DIAGNOS%' OR TABLE_NAME LIKE '%DISABL%'
       OR TABLE_NAME LIKE '%IL_%'    OR TABLE_NAME LIKE '%HEALTH%'
       OR TABLE_NAME LIKE '%TRAINER%')
ORDER BY TABLE_SCHEMA, TABLE_NAME;
-- EXPECTATION: likely returns nothing → confirms TR_HISTORY/PP_MASTER is the
-- only injury signal, and "injury type" == IL length (7/10/15/60/full-season).
-- If §3b OR §3c surface a real body-part/diagnosis field, the anatomical
-- body-map + diagnosis breakdowns become possible (escalate to design).


-- ============================================================
-- §4 — STINT DERIVATION proof-of-concept (the core metric)
-- ============================================================
-- "Days missed" is NOT stored. A stint = IL placement → next reinstatement.
-- Pair each placement with the earliest reinstatement AFTER it for that player.
-- Open stints (still on IL) end at today.
WITH placements AS (
    SELECT h.PLAYER_ID,
           h.TRANSACTION_ID,
           h.TRANSACTION_DTSTMP AS placed_on,
           h.POST_ORG_LK        AS org,
           h.TRANSACTIONNAME_LK AS il_code,
           lk.transactionname   AS il_label
    FROM MLB_eBis.TR_HISTORY h
    JOIN MLB_eBis.TR_NAME_LKUP lk ON lk.transactionname_lk = h.TRANSACTIONNAME_LK
    WHERE lk.category = 'Injury - IL Placement'
      AND YEAR(h.TRANSACTION_DTSTMP) = @season
),
returns AS (
    SELECT h.PLAYER_ID, h.TRANSACTION_DTSTMP AS returned_on
    FROM MLB_eBis.TR_HISTORY h
    WHERE h.TRANSACTIONNAME_LK IN ('REINS','RHBRT','RSTIL','RENES','REACT','RCACT','ACPAC')
)
SELECT TOP 100
       a.first_name + ' ' + a.last_name AS player,
       p.org,
       p.il_label,
       p.placed_on,
       r.returned_on,
       DATEDIFF(DAY, p.placed_on,
                COALESCE(r.returned_on, CAST(GETDATE() AS DATE))) AS days_missed,
       CASE WHEN r.returned_on IS NULL THEN 'OPEN (still out)' ELSE 'closed' END AS stint_status
FROM placements p
LEFT JOIN Astros.Players a ON a.ebis_id = p.PLAYER_ID
OUTER APPLY (
    SELECT MIN(rt.returned_on) AS returned_on
    FROM returns rt
    WHERE rt.PLAYER_ID = p.PLAYER_ID
      AND rt.returned_on > p.placed_on
) r
ORDER BY days_missed DESC;
-- VALIDATE: pick a known IL case and confirm days_missed matches reality.
-- Watch for: (a) multiple placements before one return (transfers 7d→60d —
--   should collapse to ONE stint; may need to keep only the FIRST placement
--   per contiguous out-period), (b) players traded mid-stint (org changes).


-- ============================================================
-- §5 — LEAGUE RANKING by days missed (the 30-org leaderboard)
-- ============================================================
-- Org-level rollup: total days missed, # placements, # players, avg stint.
-- This is the proof the multi-org ranking page is buildable.
WITH placements AS (
    SELECT h.PLAYER_ID, h.TRANSACTION_DTSTMP AS placed_on, h.POST_ORG_LK AS org
    FROM MLB_eBis.TR_HISTORY h
    JOIN MLB_eBis.TR_NAME_LKUP lk ON lk.transactionname_lk = h.TRANSACTIONNAME_LK
    WHERE lk.category = 'Injury - IL Placement'
      AND YEAR(h.TRANSACTION_DTSTMP) = @season
),
returns AS (
    SELECT h.PLAYER_ID, h.TRANSACTION_DTSTMP AS returned_on
    FROM MLB_eBis.TR_HISTORY h
    WHERE h.TRANSACTIONNAME_LK IN ('REINS','RHBRT','RSTIL','RENES','REACT','RCACT','ACPAC')
),
stints AS (
    SELECT p.org, p.PLAYER_ID,
           DATEDIFF(DAY, p.placed_on,
                    COALESCE(r.returned_on, CAST(GETDATE() AS DATE))) AS days_missed
    FROM placements p
    OUTER APPLY (
        SELECT MIN(rt.returned_on) AS returned_on
        FROM returns rt
        WHERE rt.PLAYER_ID = p.PLAYER_ID AND rt.returned_on > p.placed_on
    ) r
)
SELECT org,
       SUM(days_missed)                        AS total_days_missed,
       COUNT(*)                                AS n_stints,
       COUNT(DISTINCT PLAYER_ID)               AS n_players_injured,
       CAST(AVG(days_missed * 1.0) AS DECIMAL(6,1)) AS avg_stint_days,
       RANK() OVER (ORDER BY SUM(days_missed) DESC) AS rank_by_days_missed
FROM stints
GROUP BY org
ORDER BY total_days_missed DESC;
-- If this returns ~30 org rows ranked by days missed → the league dashboard
-- is fully buildable. NOTE org-code canon (CHI/LA/NY, OAK/ATH) only matters
-- if we later JOIN to MLBAM.Teams; grouping on raw ORG_LK is fine standalone.


-- ============================================================
-- HOW TO REPORT BACK
-- ============================================================
-- Priority: §3 (is there a real injury TYPE/body part anywhere?) — that single
--   answer decides whether we ship diagnosis breakdowns + a body-map, or only
--   IL-length "type" + days-missed analytics.
-- Then: §1 volume (pin vs live), §4 a couple validated stints, §5 the 30-org
--   ranking sanity check.
