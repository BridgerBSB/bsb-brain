-- ============================================================================
-- ALVARO'S ROSTER QUERIES (from R app)
-- ============================================================================
-- Source: Alvaro (teammate)
-- Purpose: Player selection with photos, age, position
-- Last Updated: 2026-01-26
-- ============================================================================

-- ============================================================================
-- ASTROS_PLAYERS_QUERY
-- ============================================================================
-- Includes: Age calculation, primary position, roster status
-- Better filtering logic for excluding VOL/RES players

SELECT 
    b.groundcontrol_id,
    b.mlbam_id,
    b.ebis_id,
    a.LASTNAME + ', ' + a.FIRSTNAME as Player,
    DATEDIFF(year, b.birthdate, getdate()) as Age,
    b.bats + '/' + b.throws as Bats_Throws,
    c.primary_position,
    a.MJROSTERSTATUS_LK,
    a.MNROSTERSTATUS_LK
FROM MLB_eBis.PP_MASTER a
LEFT JOIN astros.Players b ON a.PLAYER_ID = b.ebis_id
LEFT JOIN mlbam.Players_Position_Majority_Seasonal c ON b.mlbam_id = c.player_id AND c.season = 2024
WHERE 
    -- Main filter: exclude VOL/RES at either level
    (
        (mnrosterstatus_lk <> 'VOL' OR mjrosterstatus_lk <> 'VOL') 
        AND (mnrosterstatus_lk <> 'RES' OR MJROSTERSTATUS_LK <> 'RES')
        AND (ORG_LK = 'HOU' AND EMPLOYEE_FLG = 0)
    )
    -- OR: Include 2016 draft picks (legacy check)
    OR EXISTS (
        SELECT 1 
        FROM mlb_ebis.R4_Draft_Query 
        WHERE draft_year = 2016 AND draft_org = 'hou' AND player_id = a.PLAYER_ID
    )
    -- Always exclude Released, Free Agent, NXT
    AND a.mnrosterstatus_lk NOT IN ('REL','FA','NXT')
    AND a.mjrosterstatus_lk NOT IN ('REL','FA','NXT')
ORDER BY last_name, first_name;


-- ============================================================================
-- ASTROS_TEAMS_QUERY
-- ============================================================================
-- Maps players to team names (full team names, not abbreviations)
-- Handles restricted DSL players specially

SELECT DISTINCT 
    r.groundcontrol_id,
    CASE 
        WHEN pm.LEVELOFPLAY_Lk = 'ml' THEN 'Houston Astros'
        WHEN pm.LEVELOFPLAY_Lk = '3a' THEN 'Sugar Land Space Cowboys'
        WHEN pm.LEVELOFPLAY_LK = '2a' THEN 'Corpus Christi Hooks'
        WHEN pm.LEVELOFPLAY_Lk = '1a' THEN 'Asheville Tourists'
        WHEN pm.LEVELOFPLAY_Lk = '1f' THEN 'Fayetteville Woodpeckers'
        WHEN pm.LEVELOFPLAY_Lk = 'r' THEN 'FCL Astros'
        WHEN pm.LEVELOFPLAY_LK = 'ds' THEN 'DSL Astros'
    END AS team_name,
    CONCAT(r.last_name, ', ', r.first_name) AS player_name
FROM astros.players r
LEFT JOIN mlb_ebis.pp_master pm ON pm.player_id = r.ebis_id
LEFT JOIN MLBAM.Rosters bam ON bam.player_id = r.mlbam_id
LEFT JOIN mlb_ebis.PP_PLAYERDATA pd ON pd.PLAYER_ID = r.ebis_id
WHERE 
    -- Exclude problem statuses
    CASE 
        WHEN pm.MNROSTERSTATUS_LK IS NULL THEN pm.MJROSTERSTATUS_LK 
        ELSE pm.MNROSTERSTATUS_LK 
    END NOT IN ('res','ti','vol','dis')
    AND pm.org_lk = 'hou'
    -- OR: Special case for restricted DSL players (awaiting investigations)
    OR (
        pm.MNROSTERSTATUS_LK IN ('res')
        AND pm.LEVELOFPLAY_LK = 'ds'
        AND pm.org_lk = 'hou'
    )
ORDER BY player_name;


-- ============================================================================
-- PLAYER PHOTO URLS
-- ============================================================================
-- Logic from Alvaro's R code:
-- 
-- Photo = case_when(
--     MNROSTERSTATUS_LK == "ACT" ~ 
--         paste0("https://img.mlbstatic.com/mlb-photos/image/upload/c_fill,g_auto/w_180/v1/people/", mlbam_id, "/headshot/milb/current"),
--     TRUE ~ 
--         paste0("https://securea.mlb.com/mlb/images/players/head_shot/", mlbam_id, ".jpg")
-- )
--
-- Active MiLB players: Use the new mlbstatic CDN
-- Others (MLB/inactive): Use the legacy securea.mlb.com URL


-- ============================================================================
-- NOTES FROM ALVARO:
-- ============================================================================
-- 
-- 1. MLB_eBis rosters are more frequently updated than MLBAM.Rosters
--    "some players not assigned to a bam roster; I usually use eBIS rosters 
--     exclusively as they are most frequently updated"
--
-- 2. VOL/DIS players can be annoying:
--    "some players exist as VOL and DIS that would otherwise show up"
--
-- 3. Restricted (RES) DSL players:
--    "some players are restricted only because they are awaiting investigations; 
--     this group functions as signed players, they just don't appear in games 
--     -- at complex, training etc."
--
-- 4. MJROSTERSTATUS_LK vs MNROSTERSTATUS_LK:
--    - MJ = Major League roster status
--    - MN = Minor League roster status
--    Use coalesce logic: CASE WHEN MN IS NULL THEN MJ ELSE MN END
