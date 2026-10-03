-- ============================================================================
-- Astros-org pitchers (no MLB experience): velo split by 3+ IP vs <3 IP outings
-- ============================================================================
-- For every pitcher in the Houston organization in 2026 who has thrown
-- at least one 3+ IP outing AND has never appeared in an MLB-level game,
-- compute their pitch-weighted average velo in:
--   * 3+ IP outings (outs >= 9)
--   * Sub-3 IP outings (outs < 9)
-- so we can see whether velo drops on heavier workload days.
--
-- Knobs to tweak:
--   @season          year filter on the outings (default 2026)
--   @ip_threshold    outs that count as "3+ IP" (default 9 = exactly 3.0 IP)
--   pitch type       uncomment the pv.pitch_type filter for fastballs only
--   MLB experience   add AND ms.GAME_TYPE = 'R' to count regular-season only
--
-- Verifies:
--   * Astros org via MLBAM.Teams (org_abbrev='HOU') joined on the pitching team
--   * IP via MLBAM.Gamelog_Pitching.outs (gold standard, see ip-calculation.md)
--   * Excludes junk levels (per level-codes.md)
-- ============================================================================

DECLARE @season INT = 2026;
DECLARE @ip_threshold INT = 9;  -- outs (9 = 3.0 IP)

WITH outing_outs AS (
    -- One row per (pitcher, sched_id) for Astros-org outings in the season,
    -- excluding MLB-level appearances (we want their MiLB outings).
    SELECT
        glp.player_id      AS mlbam_id,
        sv.sched_id,
        sv.sched_date,
        sv.level_code,
        glp.outs
    FROM MLBAM.Gamelog_Pitching glp
    JOIN Astros.Schedule_View sv
        ON sv.mlbam_game_pk = glp.game_pk
    JOIN MLBAM.Teams bt
        ON bt.team_id = glp.team_id
       AND bt.season  = sv.year
       AND bt.org_abbrev = 'HOU'
    WHERE sv.year = @season
      AND sv.sched_type = 'R'
      AND sv.level_code NOT IN ('bbc','win','int','sum','nae','hsb','ind','jcb')
      AND sv.level_code <> 'mlb'   -- comparing MiLB workload only
      AND glp.outs IS NOT NULL
),
no_mlb_career AS (
    -- Pitchers with no MLB-level appearance EVER (career-wide).
    -- Tighten with AND ms.GAME_TYPE = 'R' for regular-season-only check.
    SELECT DISTINCT glp.player_id AS mlbam_id
    FROM MLBAM.Gamelog_Pitching glp
    EXCEPT
    SELECT DISTINCT glp2.player_id
    FROM MLBAM.Gamelog_Pitching glp2
    JOIN MLBAM.Schedule ms
        ON ms.GAME_PK = glp2.game_pk
    WHERE ms.SPORT = 'mlb'
),
eligible_pitchers AS (
    -- Pitchers in @season Astros org with at least one 3+ IP outing
    -- AND no MLB experience.
    SELECT DISTINCT oo.mlbam_id
    FROM outing_outs oo
    JOIN no_mlb_career nmc ON nmc.mlbam_id = oo.mlbam_id
    WHERE oo.outs >= @ip_threshold
),
pitch_buckets AS (
    -- Pitch-level data for those pitchers in those outings, bucketed by IP.
    SELECT
        p.groundcontrol_id,
        p.first_name + ' ' + p.last_name AS pitcher_name,
        p.throws,
        CASE WHEN oo.outs >= @ip_threshold THEN '3plus' ELSE 'sub3' END AS bucket,
        pv.release_speed
        -- Uncomment to restrict to fastballs only:
        -- , pv.pitch_type
    FROM Astros.Pitches_View pv
    JOIN Astros.Players p
        ON p.groundcontrol_id = pv.pitcher_id
    JOIN outing_outs oo
        ON oo.mlbam_id = p.mlbam_id
       AND oo.sched_id = pv.sched_id
    JOIN eligible_pitchers ep
        ON ep.mlbam_id = p.mlbam_id
    WHERE pv.pitch_id > 0
      AND pv.release_speed > 0
      -- Uncomment to restrict to fastballs only:
      -- AND pv.pitch_type IN ('FF','FT','SI')
)
SELECT
    groundcontrol_id,
    pitcher_name,
    throws,

    -- 3+ IP outings: pitch-weighted avg velo + pitch count
    AVG(CASE WHEN bucket = '3plus' THEN CAST(release_speed AS float) END) AS velo_3plus_ip,
    SUM(CASE WHEN bucket = '3plus' THEN 1 ELSE 0 END)                     AS n_pitches_3plus,

    -- Sub-3 IP outings: pitch-weighted avg velo + pitch count
    AVG(CASE WHEN bucket = 'sub3'  THEN CAST(release_speed AS float) END) AS velo_sub3_ip,
    SUM(CASE WHEN bucket = 'sub3'  THEN 1 ELSE 0 END)                     AS n_pitches_sub3,

    -- Delta (positive = faster on long days, negative = velo drop)
    AVG(CASE WHEN bucket = '3plus' THEN CAST(release_speed AS float) END)
        - AVG(CASE WHEN bucket = 'sub3' THEN CAST(release_speed AS float) END) AS velo_delta_long_minus_short

FROM pitch_buckets
GROUP BY groundcontrol_id, pitcher_name, throws
ORDER BY pitcher_name;
