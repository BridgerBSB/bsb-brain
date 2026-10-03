-- ============================================================
-- INJURY DASHBOARD — discovery round 4: spring-training bulk-IL impact
-- ============================================================
-- §4 of round 1 surfaced a ~70-player cluster of 60-day/Full-Season IL
-- placements all dated 2026-03-17 (end-of-spring roster parking, not real
-- new injuries). This quantifies their impact so we can pick the default
-- treatment (keep / flag-toggle / exclude). Shows the 30-org ranking BOTH
-- WAYS side by side.
--
-- Run on work laptop. Paste back §1 (bulk-date confirm) + §2 (the side-by-side).

DECLARE @season INT = 2026;

-- ============================================================
-- §1 — Confirm the bulk date(s): placements per calendar day, top 15
-- ============================================================
-- If 2026-03-17 dwarfs every other day, it's THE spring-parking date. Look
-- for any OTHER abnormal spike days too (there may be a 2nd around opening day).
SELECT TOP 15
       CAST(h.TRANSACTION_DTSTMP AS DATE) AS placed_day,
       COUNT(*)                            AS n_placements,
       SUM(CASE WHEN h.TRANSACTIONNAME_LK IN ('DL60J','DL60N','PFSMN') THEN 1 ELSE 0 END) AS n_60day_or_fullseason
FROM MLB_eBis.TR_HISTORY h
JOIN MLB_eBis.TR_NAME_LKUP lk ON lk.transactionname_lk = h.TRANSACTIONNAME_LK
WHERE lk.category = 'Injury - IL Placement'
  AND YEAR(h.TRANSACTION_DTSTMP) = @season
GROUP BY CAST(h.TRANSACTION_DTSTMP AS DATE)
ORDER BY n_placements DESC;


-- ============================================================
-- §2 — 30-org ranking: WITH all stints vs WITHOUT the 03-17 bulk cluster
-- ============================================================
-- "Bulk cluster" = 60-day / Full-Season placements dated exactly 2026-03-17.
-- (Edit @bulk_date / the code list if §1 shows a different/second date.)
DECLARE @bulk_date DATE = '2026-03-17';

WITH placements AS (
    SELECT h.PLAYER_ID,
           h.TRANSACTION_DTSTMP AS placed_on,
           h.POST_ORG_LK        AS org_raw,
           CASE WHEN CAST(h.TRANSACTION_DTSTMP AS DATE) = @bulk_date
                 AND h.TRANSACTIONNAME_LK IN ('DL60J','DL60N','PFSMN')
                THEN 1 ELSE 0 END AS is_spring_bulk
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
    SELECT
        -- collapse the Athletics rebrand so OAK + ATH don't split
        CASE WHEN UPPER(p.org_raw) = 'OAK' THEN 'ATH' ELSE UPPER(p.org_raw) END AS org,
        p.PLAYER_ID,
        p.is_spring_bulk,
        DATEDIFF(DAY, p.placed_on,
                 COALESCE(r.returned_on, CAST(GETDATE() AS DATE))) AS days_missed
    FROM placements p
    OUTER APPLY (
        SELECT MIN(rt.returned_on) AS returned_on
        FROM returns rt
        WHERE rt.PLAYER_ID = p.PLAYER_ID AND rt.returned_on > p.placed_on
    ) r
)
SELECT
    org,
    -- WITH everything
    SUM(days_missed)                                        AS days_all,
    COUNT(*)                                                AS stints_all,
    -- WITHOUT the spring-bulk cluster
    SUM(CASE WHEN is_spring_bulk = 0 THEN days_missed ELSE 0 END) AS days_ex_bulk,
    SUM(CASE WHEN is_spring_bulk = 0 THEN 1 ELSE 0 END)          AS stints_ex_bulk,
    -- what the cluster contributes
    SUM(CASE WHEN is_spring_bulk = 1 THEN days_missed ELSE 0 END) AS days_from_bulk,
    SUM(CASE WHEN is_spring_bulk = 1 THEN 1 ELSE 0 END)          AS stints_from_bulk,
    RANK() OVER (ORDER BY SUM(days_missed) DESC)                                       AS rank_all,
    RANK() OVER (ORDER BY SUM(CASE WHEN is_spring_bulk = 0 THEN days_missed ELSE 0 END) DESC) AS rank_ex_bulk
FROM stints
GROUP BY org
ORDER BY days_all DESC;
-- READ: compare rank_all vs rank_ex_bulk (does HOU / the leaderboard reshuffle
-- much when the cluster is removed?) and days_from_bulk (how much of each org's
-- total is spring-parking). If removing it barely moves ranks -> keep + toggle.
-- If it reshuffles a lot -> exclude by default. Paste the full result back.
