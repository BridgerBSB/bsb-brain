-- ============================================================
-- HOU 2026 — every IL placement whose specific body part is blank or 'Other'
-- (exactly the rows the pie now re-labels to their body_part_group).
-- Source: SportsMed.DL_Stints. Eyeball body_part_group + diagnosis to confirm
-- where each "Other" lands (e.g. Head 'Other' -> Concussion).
-- ============================================================
DECLARE @season INT = 2026;

SELECT
    s.txn_date                              AS placed_on,
    CASE LOWER(c.LEVELOFPLAY_LK)
        WHEN 'ml' THEN 'MLB' WHEN '3a' THEN 'AAA' WHEN '2a' THEN 'AA'
        WHEN '1a' THEN 'A+'  WHEN '1f' THEN 'A'   WHEN 'r'  THEN 'FCL'
        WHEN 'ds' THEN 'DSL' ELSE UPPER(c.LEVELOFPLAY_LK) END  AS level,
    c.CLUBSHORTNAME                         AS affiliate,
    s.first_name + ' ' + s.last_name        AS player,
    s.groundcontrol_id                      AS gc_id,
    s.bodypart                              AS body_part_group,   -- where it re-pools
    s.bodypartdetail                        AS detail_raw,        -- NULL / '' / 'Other'
    s.BODYSIDE_LK                           AS side,
    s.diagnosis                             AS injury_type,
    s.INJURY_DTE                            AS injury_date,
    s.EARLIESTREINSTATEMENT_DTE             AS est_return,
    s.total_days                            AS dl_days,
    s.TRANSACTIONNAME_LK                    AS txn_code
FROM SportsMed.DL_Stints s
OUTER APPLY (
    SELECT TOP 1 g.LEVELOFPLAY_LK, g.CLUBSHORTNAME
    FROM MLB_eBis.GBL_CLUB_LKUP g
    WHERE g.CLUB_LK = TRY_CAST(COALESCE(NULLIF(s.POST_CLUB_LK, ''), s.PRE_CLUB_LK) AS INT)
    ORDER BY g.ACTIVE_FLG DESC
) c
WHERE YEAR(s.txn_date) = @season
  AND s.POST_ORG_LK = 'HOU'
  AND s.transactionname LIKE 'Place%'
  AND (s.bodypartdetail IS NULL OR s.bodypartdetail IN ('', 'Other'))
ORDER BY s.txn_date DESC;
