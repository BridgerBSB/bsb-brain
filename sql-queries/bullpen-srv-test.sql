-- =============================================================
-- Do bullpens (sched_type='B') carry stuff grades in Pitches_View?
-- =============================================================
-- Tests three things:
--   1. Do sched_type='B' games even land in Pitches_View? (count rows)
--   2. If yes, is stuffrelvel_grade_2080 populated or all NULL?
--   3. Sidecar: also check fb_grade (Projections_Pitches_Grades),
--      swing_decision_grade_2080, and a couple raw pitch attributes
--      so we know whether it's the grade pipeline skipping B, or
--      Pitches_View itself missing B entirely.
--
-- For context, also runs the same counts against V (Live BP) and
-- I (Instrumented) — both of which are in our "allowed" sched_type
-- whitelists — so you can see whether B behaves the same or differs.
--
-- Run against GCSQL02.ASTROS.COM > GroundControl2.
-- =============================================================

DECLARE @season int = 2026;

-- -------------------------------------------------------------
-- Q1: Row counts + grade coverage per sched_type
-- -------------------------------------------------------------
SELECT
    sv.sched_type,
    COUNT(*)                                                          AS n_pitches_in_pv,
    SUM(CASE WHEN pv.stuffrelvel_grade_2080 IS NOT NULL THEN 1 ELSE 0 END) AS n_with_srv,
    SUM(CASE WHEN pv.swing_decision_grade_2080 IS NOT NULL THEN 1 ELSE 0 END) AS n_with_swdec,
    SUM(CASE WHEN ppg.fb_grade IS NOT NULL THEN 1 ELSE 0 END)         AS n_with_proj_fb,
    SUM(CASE WHEN pv.release_speed IS NOT NULL THEN 1 ELSE 0 END)     AS n_with_velo,
    SUM(CASE WHEN pv.pitch_type IS NOT NULL THEN 1 ELSE 0 END)        AS n_with_pitch_type,
    CAST(100.0 * SUM(CASE WHEN pv.stuffrelvel_grade_2080 IS NOT NULL THEN 1 ELSE 0 END)
         / NULLIF(COUNT(*), 0) AS decimal(6,2))                        AS pct_with_srv
FROM Astros.Pitches_View pv
JOIN Astros.Schedule_View sv
    ON sv.sched_id = pv.sched_id
LEFT JOIN Astros.Projections_Pitches_Grades ppg
    ON ppg.sched_id = pv.sched_id AND ppg.pitch_id = pv.pitch_id
WHERE sv.year = @season
  AND sv.sched_type IN ('B','V','I','R')     -- include R as a sanity baseline
GROUP BY sv.sched_type
ORDER BY sv.sched_type;

-- -------------------------------------------------------------
-- Q2: Sample rows — if Q1 shows any B pitches with SRV,
--     inspect 20 of them to see what they actually look like
-- -------------------------------------------------------------
SELECT TOP 20
    sv.sched_date,
    sv.sched_type,
    sv.level_code,
    sv.gc2_level_code,
    pv.sched_id,
    pv.pitch_id,
    pv.pitcher_id,
    pv.pitch_type,
    pv.release_speed,
    pv.stuffrelvel_grade_2080                                         AS srv,
    pv.swing_decision_grade_2080                                      AS swdec,
    ppg.fb_grade                                                      AS proj_fb
FROM Astros.Pitches_View pv
JOIN Astros.Schedule_View sv
    ON sv.sched_id = pv.sched_id
LEFT JOIN Astros.Projections_Pitches_Grades ppg
    ON ppg.sched_id = pv.sched_id AND ppg.pitch_id = pv.pitch_id
WHERE sv.year = @season
  AND sv.sched_type = 'B'
ORDER BY sv.sched_date DESC, pv.sched_id, pv.pitch_id;

-- -------------------------------------------------------------
-- Q3: How many distinct B games + distinct pitchers exist at all
--     in Schedule_View this season? If Q1 returns 0 rows for B but
--     Q3 returns hundreds of games, it means B games exist in the
--     schedule but their pitch data lives in Trackman.Pitches, not
--     Pitches_View — matching what DATABASE_REFERENCE.md claims.
-- -------------------------------------------------------------
SELECT
    sv.sched_type,
    COUNT(DISTINCT sv.sched_id)   AS n_games_in_schedule,
    MIN(sv.sched_date)            AS first_game,
    MAX(sv.sched_date)            AS last_game
FROM Astros.Schedule_View sv
WHERE sv.year = @season
  AND sv.sched_type IN ('B','V','I')
GROUP BY sv.sched_type
ORDER BY sv.sched_type;
