-- ============================================================
-- Recent injuries (IL placements) — ALL MLB orgs, ALL levels
-- Source: SportsMed.DL_Stints (league-wide IL stints w/ body part +
-- diagnosis), same detail the Transactions tracker Injury tab uses.
--
-- *** THE live, league-wide, body-part + diagnosis injury source. ***
-- Found by intern Jun 2026 — supersedes the TR_HISTORY-derived stint
-- approach in pd-goals/injury_tracker/src/injury_data.py. Earlier
-- discovery rounds missed it (they checked Injury_Data_BPro [frozen 2014]
-- + PBP_Injury [coarse]). KEEP — reference for the injury_data.py rebuild.
--
-- TOGGLE THE TIMEFRAME: just change @days.  (Or set @start/@end explicitly.)
-- ============================================================
DECLARE @days  INT  = 7;                                       -- <<< last N days
DECLARE @end   DATE = CAST(GETDATE() AS DATE);
DECLARE @start DATE = DATEADD(DAY, -@days, @end);

SELECT
    s.txn_date                                   AS placed_on,
    s.POST_ORG_LK                                AS org,
    CASE LOWER(c.LEVELOFPLAY_LK)
        WHEN 'ml' THEN 'MLB' WHEN '3a' THEN 'AAA' WHEN '2a' THEN 'AA'
        WHEN '1a' THEN 'A+'  WHEN '1f' THEN 'A'   WHEN 'r'  THEN 'FCL'
        WHEN 'ds' THEN 'DSL' ELSE UPPER(c.LEVELOFPLAY_LK)
    END                                          AS level,
    c.CLUBSHORTNAME                              AS affiliate,
    s.first_name + ' ' + s.last_name             AS player,
    s.groundcontrol_id                           AS gc_id,
    s.PLAYER_ID                                  AS ebis_id,
    s.transactionname                            AS move,
    s.bodypart                                   AS body_part_group,
    LTRIM(CASE s.BODYSIDE_LK WHEN 'R' THEN 'Right ' WHEN 'L' THEN 'Left ' ELSE '' END
          + ISNULL(NULLIF(s.bodypartdetail, ''), s.bodypart))  AS body_part,
    s.diagnosis                                  AS injury_type,
    LTRIM(CASE s.BODYSIDE_LK WHEN 'R' THEN 'Right ' WHEN 'L' THEN 'Left ' ELSE '' END
          + ISNULL(NULLIF(s.bodypartdetail, ''), s.bodypart)
          + CASE WHEN NULLIF(s.diagnosis, '') IS NOT NULL
                 THEN ' - ' + s.diagnosis ELSE '' END)           AS description,
    s.INJURY_DTE                                 AS injury_date,
    s.LASTGAME_DTE                               AS last_game,
    s.EARLIESTREINSTATEMENT_DTE                  AS est_return,
    s.total_days                                 AS dl_days,
    s.dl_stint_num                               AS stint_num,
    s.TRANSACTIONNAME_LK                         AS txn_code
FROM SportsMed.DL_Stints s
OUTER APPLY (
    SELECT TOP 1 g.LEVELOFPLAY_LK, g.CLUBSHORTNAME
    FROM MLB_eBis.GBL_CLUB_LKUP g
    WHERE g.CLUB_LK = TRY_CAST(COALESCE(NULLIF(s.POST_CLUB_LK, ''), s.PRE_CLUB_LK) AS INT)
    ORDER BY g.ACTIVE_FLG DESC
) c
WHERE s.txn_date BETWEEN @start AND @end
  AND s.transactionname LIKE 'Place%'
ORDER BY s.txn_date DESC, org, player;
