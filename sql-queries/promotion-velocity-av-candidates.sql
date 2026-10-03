-- =========================================================================
-- promotion-velocity-av-candidates.sql
-- FOLLOW-UP to the audit Section A. `player_val.asset_value` DOES NOT EXIST
-- (INFORMATION_SCHEMA scan found no such schema/table/column). This probes the
-- REAL asset-value candidates surfaced by the audit A2 column scan, so we can
-- pick the cohort source for "top-10 AV per org."
--
-- Run on work laptop. Goal for each candidate: (a) full columns, (b) sample rows
-- to read grain, (c) does it have a player id + an org + a value/rank we can take
-- "top 10 per org" from, (d) does it cover all 30 orgs.
-- =========================================================================
SET NOCOUNT ON;

-- =========================================================================
-- CANDIDATE 1 (TOP) — Astros.Transaction_Analyzer
--   Columns seen in A2: rv_value (numeric), AAVAMT, AVG_ORG_RANK, avg_top_100_rank.
--   This looks like a prospect/asset valuation + org-rank table = best fit.
-- =========================================================================
SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'Astros' AND TABLE_NAME = 'Transaction_Analyzer'
ORDER BY ORDINAL_POSITION;

SELECT TOP 50 * FROM Astros.Transaction_Analyzer;
--   >>> Read: is there one row per player? a player id (groundcontrol_id/mlbam/ebis)?
--       an org column? all 30 orgs? a snapshot/as-of date? is rv_value the "AV"?
--       is avg_top_100_rank / AVG_ORG_RANK populated league-wide?

-- Grain + coverage (EDIT the id/org/date column names from the columns list above):
-- SELECT
--     COUNT(*)                          AS n_rows,
--     COUNT(DISTINCT <player_id_col>)   AS n_distinct_players,
--     COUNT(DISTINCT <org_col>)         AS n_distinct_orgs,      -- expect 30 if league-wide
--     MIN(<date_col>)                   AS earliest,
--     MAX(<date_col>)                   AS latest
-- FROM Astros.Transaction_Analyzer;

-- HOU top-10 by rv_value (EDIT col names) — eyeball against Sam's "top guys":
-- SELECT TOP 10 *
-- FROM Astros.Transaction_Analyzer
-- WHERE <org_col> = 'HOU'
--   AND <date_col> = (SELECT MAX(<date_col>) FROM Astros.Transaction_Analyzer)
-- ORDER BY rv_value DESC;


-- =========================================================================
-- CANDIDATE 2 — Proj schema (projected RAR / MLE asset value)
--   Legacy "Historical RAR - Amat Population.sql" used proj.Batting_MLEs /
--   proj.Pitching_MLEs. Find the live asset/RAR/MLE tables.
-- =========================================================================
SELECT TABLE_SCHEMA, TABLE_NAME
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'Proj'
ORDER BY TABLE_NAME;
--   >>> If a per-player projected-value / surplus / RAR table exists with org +
--       all-30-org coverage, it's a clean AV source. Then probe its columns/sample.


-- =========================================================================
-- CANDIDATE 3 — broad net for any explicit value/surplus/war/rar column
--   In case the real "asset value" lives under a name we haven't guessed.
-- =========================================================================
SELECT TABLE_SCHEMA, TABLE_NAME, COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE COLUMN_NAME IN ('rv_value','asset_value','surplus_value','war','rar',
                      'mle','trade_value','prospect_value','total_value')
   OR COLUMN_NAME LIKE '%surplus_val%'
   OR COLUMN_NAME LIKE '%trade_val%'
   OR COLUMN_NAME LIKE '%prospect_val%'
   OR COLUMN_NAME LIKE '%proj_val%'
ORDER BY TABLE_SCHEMA, TABLE_NAME, COLUMN_NAME;


-- =========================================================================
-- DECIDE after running:
--   - If Transaction_Analyzer is per-player, all-30-org, with rv_value (or a
--     rank) -> that's the asset_value cohort source. Paste its id/org/value/date
--     column names back and we wire build_cohort_asset_value().
--   - If only HOU-scoped -> it can't drive a 30-org cohort; fall back to
--     signing_bonus (already runnable) and ask the coworker for the real source.
--   - Either way, signing_bonus path runs NOW for a first result:
--       python pd-goals/scripts/generate_promotion_velocity.py --av-source signing_bonus
-- =========================================================================
