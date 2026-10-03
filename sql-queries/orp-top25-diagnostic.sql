/* ============================================================================
   ORP diagnostic v3 — CANONICAL ORP-Bat = Proj.Batting_MLEs.mle_orp
   Run on work laptop. Corrects v1/v2, which used
   MLBAM.YTD_Player_Batting_RAR_Produced.orp_bat — a raw per-level figure GC2
   does NOT display. Per GC2's player-card SQL (Jun 2026), the ORP-Bat
   management sees is:
       SUM(Proj.Batting_MLEs.mle_orp)  WHERE pitcher_throws = '-'
   keyed on groundcontrol_id, summed across (year, team) stints = cumulative.
   GC2 pulls only orp_run (baserunning) from RAR. Both sources carry a
   team_id=0 rollup row that double-counts each stint -> filter team_id <> 0
   (GC2 uses batting_team_id <> 0).
   ============================================================================ */

-- ----------------------------------------------------------------------------
-- A. GRAIN PROBE — what does Proj.Batting_MLEs look like for 3 known guys?
--    Bazzana (110290), Kurtz (156775), Crews (108225). Confirms columns,
--    pitcher_throws values, team_id (incl. any team_id=0 rollup), mle_orp.
-- ----------------------------------------------------------------------------
SELECT *
FROM Proj.Batting_MLEs
WHERE groundcontrol_id IN (110290, 156775, 108225)
ORDER BY groundcontrol_id, [year], team_id, pitcher_throws;

-- A2. Per-player career ORP-Bat for those 3 (eyeball vs what GC2's card shows
--     for them — should match GC2's "ORP-Bat" line).
SELECT groundcontrol_id,
       SUM(CAST(mle_orp AS float)) AS career_orp_bat
FROM Proj.Batting_MLEs
WHERE groundcontrol_id IN (110290, 156775, 108225)
  AND [year] >= 2022
  AND pitcher_throws = '-'
  AND team_id <> 0
GROUP BY groundcontrol_id;


-- ----------------------------------------------------------------------------
-- B. TOP 25 by career ORP-Bat (GC2-canonical mle_orp) — drafted hitters,
--    2022-25, league-wide. Mirrors the hardened fetch_pro_orp().
--    UDFAs not included here (full pipeline adds them).
-- ----------------------------------------------------------------------------
WITH drafted AS (
    SELECT
        TRY_CAST(d.groundcontrol_id AS INT) AS groundcontrol_id,
        CONCAT(d.first_name, ' ', d.last_name) AS player_name,
        d.draft_year,
        TRY_CAST(d.draft_round AS INT)  AS draft_round,
        TRY_CAST(d.overall_pick AS INT) AS overall_pick,
        d.position AS draft_pos,
        UPPER(d.school_type) AS school_type,
        UPPER(d.draft_org)   AS draft_org
    FROM MLB_eBis.R4_Draft_Query d
    WHERE d.draft_year IN (2022, 2023, 2024, 2025)
      AND TRY_CAST(d.groundcontrol_id AS INT) IS NOT NULL
      AND d.position NOT IN ('RHP','LHP','RHS','RHR','LHS','LHR','P','SHS','TWP')
),
orp_bat AS (
    SELECT groundcontrol_id,
           SUM(CAST(mle_orp AS float)) AS career_orp_bat
    FROM Proj.Batting_MLEs
    WHERE [year] >= 2022
      AND pitcher_throws = '-'
      AND team_id <> 0
    GROUP BY groundcontrol_id
),
orp_run AS (
    SELECT pl.groundcontrol_id,
           SUM(CAST(r.orp_run AS float)) AS career_orp_run,
           SUM(CAST(r.pa AS int))        AS pro_pa
    FROM Astros.Players pl
    JOIN MLBAM.YTD_Player_Batting_RAR_Produced r ON r.player_id = pl.mlbam_id
    WHERE r.season >= 2022
      AND r.team_id <> 0
      AND LOWER(RTRIM(r.level)) IN ('mlb','aaa','aax','afa','afx','rok','dsl')
    GROUP BY pl.groundcontrol_id
)
SELECT TOP 25
    dr.player_name, dr.draft_org, dr.draft_year, dr.draft_round,
    dr.overall_pick, dr.draft_pos, dr.school_type,
    rn.pro_pa,
    CAST(ob.career_orp_bat AS decimal(6,1)) AS career_orp_bat,
    CAST(ISNULL(rn.career_orp_run, 0) AS decimal(6,1)) AS career_orp_run
FROM drafted dr
JOIN orp_bat ob       ON ob.groundcontrol_id = dr.groundcontrol_id
LEFT JOIN orp_run rn  ON rn.groundcontrol_id = dr.groundcontrol_id
ORDER BY ob.career_orp_bat DESC;
