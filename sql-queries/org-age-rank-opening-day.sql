-- ============================================================================
-- Org Age Rank — TRUE Opening Day vs. Now (AAA / AA / A+ / A only)
-- ============================================================================
-- One-off for Sam Niedorf, May 7 2026.
--
-- Methodology
-- -----------
-- "now" pool: PP_MASTER directly. Source of truth for the current roster —
--   matches the Org Board page exactly. Same Alvaro-style blacklist.
--
-- "opening day" pool: reconstructed from TR_HISTORY because PP_MASTER doesn't
--   store historical state. For each player, find their MOST RECENT
--   transaction at or before 2026-04-01; the POST_* of that row describes
--   their state on opening day. Same blacklist applied to POST_MN/MJ status
--   so guys who were on IL on 4-1 are excluded from the opening-day pool.
--
-- Levels: AAA / AA / A+ / A only. MLB removed per user direction.
--
-- Status filter (intentionally different per pool):
--   NOW pool: Alvaro blacklist matching Org Board's `roster.get_roster()`.
--     Includes ACT, PAC, OPT, OUTRT, DEVEL, anything else not in the
--     inactive/IL list. Required for hou_age_now to match Org Board.
--   OPENING-DAY pool: strict whitelist on TR_HISTORY POST status —
--     ACT, PAC, or DEVEL only (per user direction). Cleanest way to
--     answer "was this guy actually rostered + healthy on 4-1." A
--     COALESCE(MN, MJ) gives MN precedence (MiLB-specific over 40-man).
--
-- Org universe: 30 MLB orgs only (orgs that currently have an active
-- ML-level club in GBL_CLUB_LKUP).
--
-- Rank #1 = YOUNGEST org. Age is one decimal, truncated, never rounded up.
--
-- Caveats
-- -------
-- - Opening-day cutoff = transactions dated < 2026-04-02.
-- - Same-day tiebreaks pick by TR_HISTORY natural order.
-- ============================================================================

;WITH mlb_orgs AS (
    -- Canonical 30-org universe (every org with an active ML-level club)
    SELECT DISTINCT UPPER(ORG_LK) AS org
    FROM MLB_eBis.GBL_CLUB_LKUP
    WHERE ACTIVE_FLG = 1
      AND UPPER(LEVELOFPLAY_LK) = 'ML'
      AND ORG_LK IS NOT NULL
),
gbl AS (
    -- club_id → (org, level), restricted to the 30 MLB orgs
    SELECT g.CLUB_LK             AS club_id,
           LOWER(g.LEVELOFPLAY_LK) AS lvl,
           UPPER(g.ORG_LK)        AS org
    FROM MLB_eBis.GBL_CLUB_LKUP g
    INNER JOIN mlb_orgs m ON UPPER(g.ORG_LK) = m.org
    WHERE g.ACTIVE_FLG = 1
      AND g.LEVELOFPLAY_LK IS NOT NULL
),

-- ---------------------------------------------------------------------------
-- NOW POOL — PP_MASTER (matches Org Board)
-- ---------------------------------------------------------------------------
roster_now AS (
    SELECT UPPER(pm.ORG_LK)        AS org,
           LOWER(pm.LEVELOFPLAY_LK) AS lvl,
           ap.birthdate
    FROM MLB_eBis.PP_MASTER pm
    INNER JOIN mlb_orgs m ON UPPER(pm.ORG_LK) = m.org
    LEFT JOIN Astros.Players ap ON ap.ebis_id = pm.player_id
    WHERE LOWER(pm.LEVELOFPLAY_LK) IN ('3a','2a','1a','1f')
      AND pm.EMPLOYEE_FLG = 0
      AND UPPER(COALESCE(pm.MNROSTERSTATUS_LK, pm.MJROSTERSTATUS_LK)) NOT IN (
          'REL','FA','VOL','DIS','TI','RES',
          '7DL','DL','10D','15D','60D','FSIL',
          '7RH','15R','60R','DFA'
      )
      AND ap.birthdate IS NOT NULL
),
org_age_now AS (
    SELECT org, lvl,
           AVG(CAST(DATEDIFF(day, birthdate, GETDATE()) AS float) / 365.25) AS mean_age,
           COUNT(*) AS n_players
    FROM roster_now
    GROUP BY org, lvl
    HAVING COUNT(*) >= 5
),
ranked_now AS (
    SELECT lvl, org, mean_age, n_players,
           ROW_NUMBER() OVER (PARTITION BY lvl ORDER BY mean_age) AS rk,
           COUNT(*)    OVER (PARTITION BY lvl)                    AS total_orgs
    FROM org_age_now
),

-- ---------------------------------------------------------------------------
-- OPENING DAY POOL — TR_HISTORY reconstruction at 2026-04-01
-- ---------------------------------------------------------------------------
state_open AS (
    SELECT h.PLAYER_ID,
           h.POST_CLUB_LK,
           UPPER(COALESCE(h.POST_MNROSTERSTATUS_LK, h.POST_MJROSTERSTATUS_LK)) AS status,
           ROW_NUMBER() OVER (
               PARTITION BY h.PLAYER_ID
               ORDER BY h.TRANSACTION_DTSTMP DESC
           ) AS rn
    FROM MLB_eBis.TR_HISTORY h
    WHERE h.TRANSACTION_DTSTMP < '2026-04-02'
),
roster_open AS (
    SELECT g.org,
           g.lvl,
           ap.birthdate
    FROM state_open s
    JOIN gbl g ON g.club_id = s.POST_CLUB_LK
    LEFT JOIN Astros.Players ap ON ap.ebis_id = s.PLAYER_ID
    WHERE s.rn = 1
      AND g.lvl IN ('3a','2a','1a','1f')
      -- Opening-day whitelist: only count guys who were rostered + healthy
      -- on 4-1. A NULL POST status means we don't have a confirmed active
      -- flag — exclude conservatively for the historical reconstruction.
      AND UPPER(ISNULL(s.status, '')) IN ('ACT','PAC','DEVEL')
      AND ap.birthdate IS NOT NULL
),
org_age_open AS (
    SELECT org, lvl,
           AVG(CAST(DATEDIFF(day, birthdate, '2026-04-01') AS float) / 365.25) AS mean_age,
           COUNT(*) AS n_players
    FROM roster_open
    GROUP BY org, lvl
    HAVING COUNT(*) >= 5
),
ranked_open AS (
    SELECT lvl, org, mean_age, n_players,
           ROW_NUMBER() OVER (PARTITION BY lvl ORDER BY mean_age) AS rk,
           COUNT(*)    OVER (PARTITION BY lvl)                    AS total_orgs
    FROM org_age_open
)

-- ---------------------------------------------------------------------------
-- HOU SUMMARY
-- ---------------------------------------------------------------------------
SELECT
    CASE n.lvl
        WHEN '3a' THEN 'AAA · Sugar Land'
        WHEN '2a' THEN 'AA  · Corpus Christi'
        WHEN '1a' THEN 'A+  · Asheville'
        WHEN '1f' THEN 'A   · Fayetteville'
    END                                                          AS level_affiliate,
    o.n_players                                                  AS hou_n_open,
    CAST(FLOOR(o.mean_age * 10.0) / 10.0 AS decimal(4,1))        AS hou_age_open,
    o.rk                                                         AS rk_open_youngest,
    n.n_players                                                  AS hou_n_now,
    CAST(FLOOR(n.mean_age * 10.0) / 10.0 AS decimal(4,1))        AS hou_age_now,
    n.rk                                                         AS rk_now_youngest,
    n.total_orgs                                                 AS of_n_orgs,
    -- rank_diff = rk_now - rk_open
    --   negative = moved toward #1 (got YOUNGER vs. league since 4-1)
    --   positive = moved toward #30 (got OLDER vs. league since 4-1)
    (n.rk - o.rk)                                                AS rank_diff
FROM ranked_now n
LEFT JOIN ranked_open o ON o.lvl = n.lvl AND o.org = n.org
WHERE n.org = 'HOU'
ORDER BY
    CASE n.lvl
        WHEN '3a' THEN 1
        WHEN '2a' THEN 2
        WHEN '1a' THEN 3
        WHEN '1f' THEN 4
    END;


-- ============================================================================
-- PART 2 — HOU opening-day player roster, by level
-- ============================================================================
-- One row per player on HOU's opening-day roster (per TR_HISTORY rewind).
-- Use this to spot-check the reconstruction in PART 1 — if a name looks
-- wrong (or someone's missing) you'll see it here.
--
-- Same filter as PART 1 opening-day pool: ACT/PAC/DEVEL whitelist on
-- COALESCE(POST_MNROSTERSTATUS_LK, POST_MJROSTERSTATUS_LK). Both MN and
-- MJ are displayed as separate columns so you can audit which field
-- triggered the include.
-- Position + B/T pulled from current PP_MASTER as best-effort context.
-- ============================================================================

;WITH mlb_orgs AS (
    SELECT DISTINCT UPPER(ORG_LK) AS org
    FROM MLB_eBis.GBL_CLUB_LKUP
    WHERE ACTIVE_FLG = 1
      AND UPPER(LEVELOFPLAY_LK) = 'ML'
      AND ORG_LK IS NOT NULL
),
gbl AS (
    SELECT g.CLUB_LK             AS club_id,
           LOWER(g.LEVELOFPLAY_LK) AS lvl,
           UPPER(g.ORG_LK)        AS org,
           g.CLUBSHORTNAME        AS club_short
    FROM MLB_eBis.GBL_CLUB_LKUP g
    INNER JOIN mlb_orgs m ON UPPER(g.ORG_LK) = m.org
    WHERE g.ACTIVE_FLG = 1
      AND g.LEVELOFPLAY_LK IS NOT NULL
),
state_open AS (
    -- Both MN (minor-league) and MJ (major-league) post-status are kept
    -- as separate columns. They're independent fields — a guy can have
    -- MN='ACT' and MJ=NULL (MiLB-only player), or MJ='OPT' and MN='ACT'
    -- (optioned to MiLB but on 40-man), etc. Whitelist filter looks at
    -- BOTH (if either is in ACT/PAC/DEVEL the row passes).
    SELECT h.PLAYER_ID,
           h.POST_CLUB_LK,
           h.TRANSACTIONNAME_LK,
           h.TRANSACTION_DTSTMP,
           UPPER(h.POST_MNROSTERSTATUS_LK) AS mn_status,
           UPPER(h.POST_MJROSTERSTATUS_LK) AS mj_status,
           ROW_NUMBER() OVER (
               PARTITION BY h.PLAYER_ID
               ORDER BY h.TRANSACTION_DTSTMP DESC
           ) AS rn
    FROM MLB_eBis.TR_HISTORY h
    WHERE h.TRANSACTION_DTSTMP < '2026-04-02'
)
SELECT
    CASE g.lvl
        WHEN '3a' THEN '1-AAA'
        WHEN '2a' THEN '2-AA'
        WHEN '1a' THEN '3-A+'
        WHEN '1f' THEN '4-A'
    END                                                          AS level,
    g.club_short,
    ap.last_name + ', ' + ap.first_name                          AS player,
    pm.POSITION_LK                                               AS pos,
    ap.bats,
    ap.throws,
    CAST(FLOOR(DATEDIFF(day, ap.birthdate, '2026-04-01') * 10.0 / 365.25) / 10.0
         AS decimal(4,1))                                        AS age_at_4_1,
    s.mn_status                                                  AS mn_status_4_1,
    s.mj_status                                                  AS mj_status_4_1,
    CAST(s.TRANSACTION_DTSTMP AS date)                           AS last_txn_date,
    lk.transactionname                                           AS last_txn_name,
    ap.groundcontrol_id,
    ap.ebis_id
FROM state_open s
JOIN gbl g ON g.club_id = s.POST_CLUB_LK
JOIN Astros.Players ap ON ap.ebis_id = s.PLAYER_ID
LEFT JOIN MLB_eBis.PP_MASTER pm ON pm.player_id = s.PLAYER_ID
LEFT JOIN MLB_eBis.TR_NAME_LKUP lk ON lk.transactionname_lk = s.TRANSACTIONNAME_LK
WHERE s.rn = 1
  AND g.org = 'HOU'
  AND g.lvl IN ('3a','2a','1a','1f')
  -- Same whitelist as Part 1 opening-day pool. MN takes precedence
  -- over MJ (specific MiLB status beats general 40-man flag) — a guy
  -- with MN='IL' and MJ='ACT' is hurt at his MiLB level, exclude him.
  AND UPPER(ISNULL(COALESCE(s.mn_status, s.mj_status), '')) IN ('ACT','PAC','DEVEL')
  AND ap.birthdate IS NOT NULL
ORDER BY
    CASE g.lvl
        WHEN '3a' THEN 1
        WHEN '2a' THEN 2
        WHEN '1a' THEN 3
        WHEN '1f' THEN 4
    END,
    ap.last_name,
    ap.first_name;
