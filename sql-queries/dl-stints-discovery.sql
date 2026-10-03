-- ============================================================
-- SportsMed.DL_Stints — discovery for the injury_data.py REBUILD
-- ============================================================
-- The intern's recent-injuries query proved this is THE league-wide,
-- current, body-part + diagnosis injury source. Before rebuilding the
-- dashboard's data layer on it, settle: (a) full columns, (b) is there an
-- actual RETURN/reinstatement date (vs the ESTIMATED one) + open/closed
-- signal, (c) what total_days means, (d) season coverage, (e) the txn-code
-- vocabulary (placements vs reinstatements vs transfers vs releases).
-- Run on work laptop, paste all back. gc_ids below are real (from the
-- recent-injuries result), not guesses.

-- §1 — FULL column list (the intern's query only touched ~19 cols; need all)
SELECT COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'SportsMed' AND TABLE_NAME = 'DL_Stints'
ORDER BY ORDINAL_POSITION;

-- §2 — season coverage: is it just current, or multi-year (drives the
--      season selector)? + placement vs total volume per year.
SELECT YEAR(s.txn_date)                                          AS season,
       COUNT(*)                                                  AS n_rows,
       SUM(CASE WHEN s.transactionname LIKE 'Place%' THEN 1 ELSE 0 END) AS n_placements,
       COUNT(DISTINCT s.groundcontrol_id)                        AS n_players,
       COUNT(DISTINCT s.POST_ORG_LK)                             AS n_orgs
FROM SportsMed.DL_Stints s
GROUP BY YEAR(s.txn_date)
ORDER BY season DESC;

-- §3 — transaction vocabulary: what moves exist? (placement / reinstatement
--      / transfer / release?) — tells us how to detect stint END + open.
SELECT s.TRANSACTIONNAME_LK, s.transactionname, COUNT(*) AS n
FROM SportsMed.DL_Stints s
WHERE YEAR(s.txn_date) = 2026
GROUP BY s.TRANSACTIONNAME_LK, s.transactionname
ORDER BY n DESC;

-- §4 — ONE row per stint, or one row per transaction? Full dump of two
--      multi-stint players. Watch: do reinstatement rows appear? Does
--      total_days change between placement and return? Is there an actual
--      return-date col that's populated once back?
SELECT * FROM SportsMed.DL_Stints s
WHERE s.groundcontrol_id IN (76867, 75825)   -- Gustavo Campero (stint 3), Nick Allen (stint 2)
ORDER BY s.groundcontrol_id, s.txn_date;

-- §5 — what do NON-placement rows look like (reinstatements/transfers)?
--      Confirms how a stint closes + whether final total_days lands here.
SELECT TOP 40 s.txn_date, s.groundcontrol_id, s.first_name, s.last_name,
       s.transactionname, s.TRANSACTIONNAME_LK, s.total_days, s.dl_stint_num,
       s.INJURY_DTE, s.LASTGAME_DTE, s.EARLIESTREINSTATEMENT_DTE
FROM SportsMed.DL_Stints s
WHERE YEAR(s.txn_date) = 2026
  AND s.transactionname NOT LIKE 'Place%'
ORDER BY s.txn_date DESC;
