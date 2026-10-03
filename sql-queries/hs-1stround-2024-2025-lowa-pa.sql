-- 2024 & 2025 HS first-round HITTERS — PAs spent in Low A (afx), 2025 + 2026
-- =====================================================================
-- Sam's ask: how many PAs each 2024 & 2025 high-school first-round
-- POSITION PLAYER has spent in Low A, over the 2025 and 2026 seasons.
-- One row per HS first-round hitter (all 30 orgs), total Low-A PA +
-- a 2025/2026 split. LEFT JOIN, so a hitter who never reached Low A shows 0.
--
-- PA SOURCE — OFFICIAL, NOT pitch-derived (BLOCKING):
--   Low-A PA = SUM(MLBAM.Gamelog_Batting.pa) per game. A pitch-derived
--   count (Events_View x Pitches_View on cur_event_id) UNDERCOUNTS MiLB PA
--   wherever pitch-by-pitch tracking is incomplete (verified: Heliot Ramos
--   2018 Low-A official 535 vs pitch-derived 444). Gamelog_Batting.pa is
--   the proven official source (ref: pd-goals/src/promotion_velocity_data.py,
--   verified Yordan 2016 DSL = 57 vs GC2). Level from Astros Schedule_View
--   gc2_level_code='afx', regular season only.
--
-- Population: MLB_eBis.R4_Draft_Query, draft_round='1' (string),
--   school_type='HS', draft_year IN (2024, 2025), pitchers excluded
--   (position NOT IN PITCHER_POSITIONS, draft-tables.md §1).
-- draft_round='1' excludes Competitive Balance Round A picks.

WITH draftees AS (
    SELECT
        d.first_name,
        d.last_name,
        d.draft_year,
        TRY_CAST(d.overall_pick AS int) AS overall_pick,
        d.position,
        d.draft_org,
        p.groundcontrol_id AS gc_id,
        p.mlbam_id
    FROM MLB_eBis.R4_Draft_Query d
    JOIN Astros.Players p
        ON TRY_CAST(d.groundcontrol_id AS int) = p.groundcontrol_id
    WHERE d.draft_round = '1'
      AND d.school_type = 'HS'
      AND d.draft_year IN (2024, 2025)
      -- hitters only — exclude pitchers (draft-tables.md §1 PITCHER_POSITIONS)
      AND d.position NOT IN ('RHP','LHP','RHS','RHR','LHS','LHR','P','SHS','TWP')
),
lowa_pa AS (
    -- OFFICIAL Low-A (afx) PA from Gamelog_Batting, regular season, 2025-2026.
    SELECT
        d.gc_id AS batter_id,
        SUM(CAST(glb.pa AS int)) AS pa_total,
        SUM(CASE WHEN sv.year = 2025 THEN CAST(glb.pa AS int) ELSE 0 END) AS pa_2025,
        SUM(CASE WHEN sv.year = 2026 THEN CAST(glb.pa AS int) ELSE 0 END) AS pa_2026
    FROM draftees d
    JOIN MLBAM.Gamelog_Batting glb ON glb.player_id = d.mlbam_id
    JOIN Astros.Schedule_View sv   ON sv.mlbam_game_pk = glb.game_pk
    WHERE sv.gc2_level_code = 'afx'        -- Low A only
      AND sv.sched_type = 'R'
      AND sv.year IN (2025, 2026)          -- PA window
    GROUP BY d.gc_id
)
SELECT
    d.draft_year,
    d.overall_pick,
    d.first_name + ' ' + d.last_name AS player,
    d.position,
    UPPER(d.draft_org) AS draft_org,
    ISNULL(la.pa_total, 0) AS low_a_pa,
    ISNULL(la.pa_2025, 0)  AS low_a_pa_2025,
    ISNULL(la.pa_2026, 0)  AS low_a_pa_2026
FROM draftees d
LEFT JOIN lowa_pa la ON la.batter_id = d.gc_id
ORDER BY d.draft_year, d.overall_pick;
