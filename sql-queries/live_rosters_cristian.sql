-- ============================================================================
-- LIVE ROSTERS QUERY (from Cristian - Asst Director)
-- ============================================================================
-- Purpose: Get current organizational roster for PD Goals app
-- Source: MLB_eBis.PP_MASTER joined with Astros.Players
-- Last Updated: 2026-01-26
-- ============================================================================

SELECT DISTINCT
    r.ebis_id,
    CONCAT(r.last_name, ', ', r.first_name) AS Last_First,
    CASE 
        WHEN pm.LEVELOFPLAY_Lk = 'ml' THEN 'HOU'
        WHEN pm.LEVELOFPLAY_Lk = '3a' THEN 'AAA Sugar Land'
        WHEN pm.LEVELOFPLAY_LK = '2a' THEN 'AA Corpus Christi'
        WHEN pm.LEVELOFPLAY_Lk = '1a' THEN 'A+ Asheville'
        WHEN pm.LEVELOFPLAY_Lk = '1f' THEN 'A Fayetteville'
        WHEN pm.LEVELOFPLAY_Lk = 'r' THEN 'FCL'
        WHEN pm.LEVELOFPLAY_LK = 'ds' THEN 'DSL'
    END AS Affiliate,
    r.groundcontrol_id,
    CONCAT(r.first_name, ' ', r.last_name) AS First_Last,
    CASE 
        WHEN PM.POSITION_LK LIKE '%h%' THEN 'P'
        ELSE pm.POSITION_LK 
    END AS Position,
    r.bats,
    r.throws,
    pm.MNROSTERSTATUS_LK
FROM Astros.Players r
LEFT JOIN MLB_eBis.PP_MASTER pm ON pm.player_id = r.ebis_id
WHERE 
    pm.levelofplay_lk IN ('ml', '3a', '2a', '1a', '1f', 'r', 'ds')
    AND pm.mnrosterstatus_lk NOT IN ('rel', 'fa')  -- Exclude Released and Free Agents only
    AND pm.org_lk = 'hou'
ORDER BY 
    CONCAT(r.last_name, ', ', r.first_name),
    CASE 
        WHEN PM.POSITION_LK LIKE '%h%' THEN 'P'
        ELSE pm.POSITION_LK 
    END DESC;

-- ============================================================================
-- NOTES:
-- ============================================================================
-- Roster Status Codes (mnrosterstatus_lk):
--   ACT = Active (playing)
--   VOL = Voluntary (leave of absence)
--   RES = Restricted
--   DIS = Disqualified  
--   PAC = Pending Active
--   FA  = Free Agent (EXCLUDED)
--   REL = Released (EXCLUDED)
--
-- Level of Play Codes (levelofplay_lk):
--   ml  = MLB (HOU)
--   3a  = AAA Sugar Land
--   2a  = AA Corpus Christi
--   1a  = A+ Asheville
--   1f  = A Fayetteville
--   r   = FCL (Rookie)
--   ds  = DSL (Dominican Summer League)
--
-- Position Codes (POSITION_LK):
--   RHS = Right-Handed Starter (Pitcher)
--   RHR = Right-Handed Reliever (Pitcher)
--   LHS = Left-Handed Starter (Pitcher)
--   LHR = Left-Handed Reliever (Pitcher)
--   C   = Catcher
--   1B  = First Base
--   2B  = Second Base
--   3B  = Third Base
--   SS  = Shortstop
--   IF  = Infield (utility)
--   OF  = Outfield
--   CF  = Center Field
--   LF  = Left Field
--   RF  = Right Field
--
-- The LIKE '%h%' pattern catches RHS, LHS, RHR, LHR and converts to 'P'
-- ============================================================================
