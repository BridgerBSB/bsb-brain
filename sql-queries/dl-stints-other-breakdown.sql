-- ============================================================
-- "Other" on the injury-type pie — what's actually in it
-- Source: SportsMed.DL_Stints (IL placements). Two senses of "Other":
--   §A  the pie's Other SLICE = body parts ranked 12th+ (display rollup)
--   §B  the LITERAL bodypartdetail = 'Other' rows eBis logged
-- Change @season (and the optional level filter) to match what you're viewing.
-- ============================================================
DECLARE @season INT = 2026;

-- §A — full side-stripped body-part distribution with a rank.
--      Rows with rk >= 12 are exactly what the pie lumps into "Other".
WITH bp AS (
    SELECT ISNULL(NULLIF(s.bodypartdetail, ''), s.bodypart) AS body_part,
           COUNT(*) AS n
    FROM SportsMed.DL_Stints s
    WHERE YEAR(s.txn_date) = @season
      AND s.transactionname LIKE 'Place%'
    GROUP BY ISNULL(NULLIF(s.bodypartdetail, ''), s.bodypart)
)
SELECT ROW_NUMBER() OVER (ORDER BY n DESC) AS rk, body_part, n,
       CASE WHEN ROW_NUMBER() OVER (ORDER BY n DESC) >= 12
            THEN 'in "Other" slice' ELSE '' END AS pie_bucket
FROM bp
ORDER BY n DESC;

-- §B — the LITERAL "Other" body part: what was logged + the diagnosis/group
--      behind it (so you see what eBis means when it says "Other").
SELECT s.txn_date,
       s.POST_ORG_LK                               AS org,
       s.first_name + ' ' + s.last_name            AS player,
       s.bodypart                                  AS body_part_group,
       s.bodypartdetail,
       s.BODYSIDE_LK                               AS side,
       s.diagnosis,
       s.TRANSACTIONNAME_LK                        AS txn_code
FROM SportsMed.DL_Stints s
WHERE YEAR(s.txn_date) = @season
  AND s.transactionname LIKE 'Place%'
  AND ISNULL(NULLIF(s.bodypartdetail, ''), s.bodypart) = 'Other'
ORDER BY s.txn_date DESC;
