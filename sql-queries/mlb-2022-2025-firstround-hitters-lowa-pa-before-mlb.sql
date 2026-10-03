-- HS first-round HITTERS (debut 2019+, MLB 2022-2025) — Low-A PA before MLB
-- =====================================================================
-- Population: first-round (draft_round='1') HIGH-SCHOOL (school_type='HS')
--   position players (pitchers excluded) who debuted in MLB in 2019 or
--   later AND appeared in an MLB game in 2022, 2023, 2024, or 2025.
-- Metric: total Low-A (afx) PA each accumulated BEFORE his MLB debut
--   (Low-A games dated earlier than his first MLB game) + how many Low-A
--   seasons that spanned.
-- Players with 0 Low-A PA before MLB are EXCLUDED.
-- Bottom row: AVERAGE of those Low-A-PA-before-MLB totals across the
--   remaining (non-zero) players (rounded — PA shows no decimals).
--
-- PA SOURCE — OFFICIAL, NOT pitch-derived (BLOCKING):
--   Low-A PA = SUM(MLBAM.Gamelog_Batting.pa) per game. The earlier
--   pitch-derived count (Events_View x Pitches_View on cur_event_id)
--   UNDERCOUNTS older/lower-minors PA because pitch-by-pitch tracking is
--   incomplete pre-~2021 (e.g. Heliot Ramos 2018 Low-A: official 535 PA,
--   pitch-derived only 444). Gamelog_Batting.pa is the proven official
--   source (ref: pd-goals/src/promotion_velocity_data.py, verified Yordan
--   2016 DSL = 57 vs GC2). Level taken from Astros Schedule_View
--   gc2_level_code='afx' (full-season Single-A = 2018 SAL), regular season.
-- MLB debut date stays pitch-derived — MLB tracking is complete, no gap.
-- draft_round='1' excludes Competitive Balance Round A picks.

WITH draftees AS (
    -- First-round HS hitters (all draft years). Pitchers excluded.
    SELECT
        d.first_name, d.last_name,
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
      AND d.position NOT IN ('RHP','LHP','RHS','RHR','LHS','LHR','P','SHS','TWP')
),
mlb_debut AS (
    -- MLB debut date = first MLB game (batting). Keep players who DEBUTED
    -- in 2019 or later AND appeared in MLB during 2022-2025.
    SELECT
        pv.batter_id,
        MIN(sv.sched_date) AS debut_date
    FROM Astros.Pitches_View pv
    JOIN Astros.Schedule_View sv ON pv.sched_id = sv.sched_id
    WHERE sv.level_code = 'mlb'
      AND sv.sched_type = 'R'
      AND pv.pitch_id > 0
      AND pv.batter_id IN (SELECT gc_id FROM draftees)
    GROUP BY pv.batter_id
    HAVING MIN(sv.sched_date) >= '2019-01-01'                              -- debut 2019+
       AND MAX(CASE WHEN sv.year BETWEEN 2022 AND 2025 THEN 1 ELSE 0 END) = 1
),
lowa_pa AS (
    -- OFFICIAL Low-A (afx) PA before MLB debut: SUM(Gamelog_Batting.pa)
    -- over regular-season afx games dated before the player's debut.
    SELECT
        d.gc_id AS batter_id,
        SUM(CAST(glb.pa AS int)) AS lowa_pa_pre_mlb,
        COUNT(DISTINCT sv.year)  AS n_lowa_seasons
    FROM draftees d
    JOIN mlb_debut md            ON md.batter_id = d.gc_id
    JOIN MLBAM.Gamelog_Batting glb ON glb.player_id = d.mlbam_id
    JOIN Astros.Schedule_View sv   ON sv.mlbam_game_pk = glb.game_pk
    WHERE sv.gc2_level_code = 'afx'        -- Low-A / full-season Single-A
      AND sv.sched_type = 'R'
      AND sv.sched_date < md.debut_date     -- before MLB
    GROUP BY d.gc_id
)
SELECT
    draft_year, pick, player, position, draft_org,
    debut_year, lowa_pa_before_mlb, n_lowa_seasons
FROM (
    -- Per-player rows (INNER JOIN + >0 guard drops anyone with no Low-A PA)
    SELECT
        0 AS grp, d.draft_year AS dy_sort, d.overall_pick AS pk_sort,
        CAST(d.draft_year AS varchar(10))   AS draft_year,
        CAST(d.overall_pick AS varchar(10)) AS pick,
        d.first_name + ' ' + d.last_name AS player,
        d.position,
        UPPER(d.draft_org) AS draft_org,
        YEAR(md.debut_date) AS debut_year,
        CAST(la.lowa_pa_pre_mlb AS int)  AS lowa_pa_before_mlb,
        CAST(la.n_lowa_seasons AS int)   AS n_lowa_seasons
    FROM draftees d
    JOIN mlb_debut md ON md.batter_id = d.gc_id
    JOIN lowa_pa la   ON la.batter_id = d.gc_id
    WHERE la.lowa_pa_pre_mlb > 0
    UNION ALL
    -- Bottom average row (over non-zero players only; rounded to whole PA)
    SELECT
        1 AS grp, 999999 AS dy_sort, 999999 AS pk_sort,
        'AVERAGE' AS draft_year, NULL AS pick, NULL AS player, NULL AS position, NULL AS draft_org,
        NULL AS debut_year,
        CAST(ROUND(AVG(CAST(lowa_pa_pre_mlb AS float)), 0) AS int) AS lowa_pa_before_mlb,
        CAST(ROUND(AVG(CAST(n_lowa_seasons AS float)), 0) AS int)  AS n_lowa_seasons
    FROM lowa_pa
    WHERE lowa_pa_pre_mlb > 0
) x
ORDER BY grp, dy_sort, pk_sort;
