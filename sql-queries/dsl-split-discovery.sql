-- DSL sub-team name discovery
-- =============================
-- Purpose: confirm what column / table gives DSL sub-team names
-- (DSL Astros Blue vs DSL Astros Orange) for the affiliate tracker
-- DSL Org Split feature.
--
-- Run on work laptop, paste results back to Claude.
-- =============================


-- Q1. What columns does mlbam.teams actually have?
-- (User's prior team_name attempt failed — confirm what's actually there)
SELECT TOP 5 *
FROM mlbam.teams
WHERE season = 2026 AND UPPER(org_abbrev) = 'HOU'
ORDER BY team_id;


-- Q2. INFORMATION_SCHEMA dump for mlbam.teams columns
SELECT column_name, data_type, character_maximum_length
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'mlbam' AND TABLE_NAME = 'teams'
ORDER BY ordinal_position;


-- Q3. What columns does MLB_eBis.GBL_CLUB_LKUP have? (the rule docs suggest
-- this is where team_name lives; we use it in pd-goals org-board)
-- NOTE: the column is CLUB_LK (not club_id) per the working reference impl
-- at pd-goals/src/transactions_data.py:298.
SELECT TOP 5 *
FROM MLB_eBis.GBL_CLUB_LKUP
WHERE UPPER(ORG_LK) = 'HOU' AND ACTIVE_FLG = 1
ORDER BY CLUB_LK;


-- Q4. INFORMATION_SCHEMA dump for GBL_CLUB_LKUP columns
SELECT column_name, data_type, character_maximum_length
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'MLB_eBis' AND TABLE_NAME = 'GBL_CLUB_LKUP'
ORDER BY ordinal_position;


-- Q5. Verify the JOIN key — does mlbam.teams.team_id equal
-- GBL_CLUB_LKUP.CLUB_LK for HOU DSL clubs (599 = Blue, 10000055 = Orange
-- per org-board.md)? Aliased as club_id in the SELECT so downstream code
-- doesn't change.
SELECT
    t.team_id, t.org_abbrev, t.season,
    g.CLUB_LK AS club_id,
    g.ORG_LK,
    g.team_name,
    g.LEVELOFPLAY_LK AS level_code
FROM mlbam.teams t
LEFT JOIN MLB_eBis.GBL_CLUB_LKUP g ON g.CLUB_LK = t.team_id
WHERE t.season = 2026 AND UPPER(t.org_abbrev) = 'HOU'
ORDER BY t.team_id;


-- Q6. Sanity check — pull the actual HOU DSL game team_ids from Events_View
-- to confirm they're 599 / 10000055 and not some other IDs
SELECT DISTINCT
    sv.gc2_level_code,
    sv.home_team_mlbam_id, sv.away_team_mlbam_id,
    th.team_id AS home_team_id, th.org_abbrev AS home_org,
    ta.team_id AS away_team_id, ta.org_abbrev AS away_org
FROM Astros.Schedule_View sv
LEFT JOIN mlbam.teams th ON th.team_id = sv.home_team_mlbam_id AND th.season = sv.year
LEFT JOIN mlbam.teams ta ON ta.team_id = sv.away_team_mlbam_id AND ta.season = sv.year
WHERE sv.year = 2026
  AND sv.gc2_level_code = 'dsl'
  AND (UPPER(th.org_abbrev) = 'HOU' OR UPPER(ta.org_abbrev) = 'HOU')
  AND sv.sched_type = 'R'
ORDER BY sv.home_team_mlbam_id, sv.away_team_mlbam_id;
