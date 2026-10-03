-- ============================================================================
-- Current MLB SP (made MLB starts in 2026, career WAR >= 2, >=30 IP at Low-A):
--   their 4-seam (FF) and 2-seam/sinker (FT+SI) usage% back in Low-A.
--   Jagger Beck (gc 269548) pinned at the TOP as the comparison anchor.
-- ----------------------------------------------------------------------------
-- DECISIONS (per Zac, 2026-06-19):
--   * Pool = pitchers with >=1 MLB game STARTED in 2026 (mlbam YTD, gm_type='r').
--   * Quality gate = CAREER MLB WAR >= 2  (SUM of Astros internal WAR, MLB-level
--     ONLY — Proj.Pitching_MLEs total row bat_side='-' AND role='--', team_id
--     restricted to MLB clubs so MiLB MLE value is NOT counted). This is the only
--     WAR source in GC2 — there is no FanGraphs/bbref WAR in the DB.
--   * A-ball = LOW-A ONLY (level_code 'afx' = Single-A). High-A (afa) excluded.
--     Note: short-season "A-" does NOT exist in this DB (retired after 2020), and
--     starters who skipped Low-A (e.g. High-A-debut guys like Hunter Brown) will
--     not appear. Edit the usage CTE WHERE to add 'afa' if you want High-A back.
--   * SAMPLE GATE: only starters with >= @min_ip (=30) IP at Low-A qualify
--     (career outs at afx from mlbam YTD pitching). Keeps thin-sample levels out.
--
-- COVERAGE CAVEAT: MiLB pitch-by-pitch pitch_type is only populated where
--   Trackman/HawkEye recorded the game. It is sparse-to-absent at A-ball before
--   ~2021, so older starters' A-ball years may carry few/zero classified pitches
--   and drop out. low_a_ip + n_classified are in the output so thin samples are
--   VISIBLE, not hidden. Rows with zero classified Low-A pitches are excluded
--   (except Beck, always shown).
--
-- USAGE% denominator = classified pitches (pitch_type IS NOT NULL), so FF% + 2S%
--   read as a share of his identified arsenal. Rounded ONCE at display.
-- LAYOUT: row 1 = Jagger Beck (anchor), row 2 = pool AVERAGE (per-pitcher mean,
--   Beck excluded), then every MLB starter sorted by COMBINED FF+FT+SI usage%
--   high -> low. combined_fb_pct = ff_pct + two_seam_pct (total fastball share).
-- ============================================================================

DECLARE @beck_id      int = 269548;   -- Jagger Beck (pd-goals/data/slack_channels.csv)
DECLARE @war_floor    float = 2.0;    -- career MLE WAR gate
DECLARE @season       int = 2026;     -- season the MLB starts are counted in
DECLARE @min_ip       int = 30;       -- min IP at Low-A to qualify (sample gate)

-- A-ball = Low-A only ('afx'). Set in the usage CTE WHERE clause below.

WITH
-- 1) Current MLB starters: >=1 MLB regular-season game started in @season -------
mlb_sp AS (
    SELECT  yp.player_id      AS mlbam_id,
            SUM(yp.gs)        AS gs_season
    FROM    mlbam.ytd_player_pitching_stats yp
    WHERE   yp.season   = @season
      AND   yp.level    = 'mlb'
      AND   yp.gm_type  = 'r'
      AND   yp.split_id = 0
      AND   yp.team_id <> 0          -- skip any per-player aggregate/total row
    GROUP BY yp.player_id
    HAVING  SUM(yp.gs) >= 1
),
-- 2) Career MLB WAR (MLB-level ONLY) --------------------------------------------
--    Proj.Pitching_MLEs is MLE (translates MiLB -> MLB-equiv too) and has NO level
--    column, so restrict to MLB team_ids to keep this PURE MLB WAR (level-purity,
--    same discipline as the wRC+ project). Total row = bat_side='-' AND role='--'.
war_career AS (
    SELECT  m.groundcontrol_id,
            SUM(m.war) AS career_war
    FROM    Proj.Pitching_MLEs m
    WHERE   m.bat_side = '-'
      AND   m.role     = '--'
      AND   m.team_id IN (SELECT team_id FROM MLBAM.Teams WHERE sport_code = 'mlb')
    GROUP BY m.groundcontrol_id
),
-- 2b) Career outs at Low-A (afx) — drives the >=@min_ip IP sample gate ----------
ip_afx AS (
    SELECT  yp.player_id AS mlbam_id,
            SUM(CAST(yp.outs AS int)) AS outs_afx
    FROM    mlbam.ytd_player_pitching_stats yp
    WHERE   yp.level    = 'afx'
      AND   yp.gm_type  = 'r'
      AND   yp.split_id = 0
    GROUP BY yp.player_id
),
-- 3) Pool: MLB SP (career WAR>=2) WITH >=@min_ip IP at Low-A, + Beck ------------
pool AS (
    SELECT  p.groundcontrol_id,
            w.career_war,
            s.gs_season,
            ip.outs_afx
    FROM    mlb_sp s
    JOIN    Astros.Players p  ON p.mlbam_id = s.mlbam_id
    JOIN    war_career    w   ON w.groundcontrol_id = p.groundcontrol_id
    JOIN    ip_afx        ip  ON ip.mlbam_id = s.mlbam_id
    WHERE   w.career_war >= @war_floor
      AND   ip.outs_afx  >= @min_ip * 3        -- 30 IP at Low-A = 90 outs
    UNION
    SELECT  @beck_id,
            (SELECT career_war FROM war_career WHERE groundcontrol_id = @beck_id),
            NULL,
            (SELECT ip2.outs_afx FROM ip_afx ip2
               JOIN Astros.Players p2 ON p2.mlbam_id = ip2.mlbam_id
              WHERE p2.groundcontrol_id = @beck_id)
),
-- 4) A-ball FF / 2-seam usage for everyone in the pool --------------------------
usage AS (
    SELECT
        pv.pitcher_id,
        MIN(sv.year) AS first_yr,
        MAX(sv.year) AS last_yr,
        SUM(CASE WHEN pv.pitch_type IS NOT NULL THEN 1 ELSE 0 END)            AS n_classified,
        SUM(CASE WHEN pv.pitch_type = 'FF'            THEN 1 ELSE 0 END)      AS n_ff,
        SUM(CASE WHEN pv.pitch_type IN ('FT','SI')    THEN 1 ELSE 0 END)      AS n_2s
    FROM    Astros.Pitches_View   pv
    JOIN    Astros.Schedule_View  sv ON sv.sched_id = pv.sched_id
    WHERE   sv.level_code = 'afx'            -- <<< Low-A only (Single-A)
      AND   sv.sched_type = 'R'
      AND   pv.pitch_id  > 0
      AND   pv.pitcher_id IN (SELECT groundcontrol_id FROM pool)
    GROUP BY pv.pitcher_id
),
-- 5) Per-pitcher metrics at FULL precision (round once at display) --------------
metrics AS (
    SELECT
        po.groundcontrol_id AS gc_id,
        po.career_war,
        po.gs_season,
        po.outs_afx,
        LTRIM(RTRIM(ISNULL(r.first_name,'') + ' ' + ISNULL(r.last_name,''))) AS name,
        u.first_yr, u.last_yr,
        u.n_classified,
        CASE WHEN u.n_classified > 0 THEN 1.0 * u.n_ff            / u.n_classified END AS ff_ratio,
        CASE WHEN u.n_classified > 0 THEN 1.0 * u.n_2s            / u.n_classified END AS two_ratio,
        CASE WHEN u.n_classified > 0 THEN 1.0 * (u.n_ff + u.n_2s) / u.n_classified END AS fb_ratio
    FROM        pool po
    LEFT JOIN   usage u          ON u.pitcher_id       = po.groundcontrol_id
    LEFT JOIN   Astros.Players r ON r.groundcontrol_id = po.groundcontrol_id
    WHERE       u.n_classified > 0                  -- has tracked A-ball pitches
       OR       po.groundcontrol_id = @beck_id      -- ...or is Beck (always show)
)
SELECT pitcher, gc_id, career_war, gs_2026, low_a_ip,
       n_classified, ff_pct, two_seam_pct, combined_fb_pct
FROM (
    -- Jagger Beck — pinned anchor row
    SELECT 0 AS ord,
        '>>> ' + name                                          AS pitcher,
        gc_id,
        CAST(career_war AS decimal(5,1))                       AS career_war,
        gs_season AS gs_2026,
        CASE WHEN outs_afx IS NULL THEN NULL
             ELSE CONCAT(outs_afx / 3, '.', outs_afx % 3) END AS low_a_ip,
        n_classified,
        CAST(100.0 * ff_ratio  AS decimal(4,1))                AS ff_pct,
        CAST(100.0 * two_ratio AS decimal(4,1))                AS two_seam_pct,
        CAST(100.0 * fb_ratio  AS decimal(4,1))                AS combined_fb_pct
    FROM metrics WHERE gc_id = @beck_id

    UNION ALL

    -- Pool AVERAGE (per-pitcher mean across the qualifying MLB starters; Beck excluded)
    SELECT 1 AS ord,
        'AVERAGE (' + CAST(COUNT(*) AS varchar(10)) + ' starters)' AS pitcher,
        CAST(NULL AS int)                                      AS gc_id,
        CAST(AVG(career_war) AS decimal(5,1))                  AS career_war,
        CAST(NULL AS int)                                      AS gs_2026,
        CAST(NULL AS varchar(8))                               AS low_a_ip,
        CAST(NULL AS int) AS n_classified,
        CAST(100.0 * AVG(ff_ratio)  AS decimal(4,1))           AS ff_pct,
        CAST(100.0 * AVG(two_ratio) AS decimal(4,1))           AS two_seam_pct,
        CAST(100.0 * AVG(fb_ratio)  AS decimal(4,1))           AS combined_fb_pct
    FROM metrics WHERE gc_id <> @beck_id

    UNION ALL

    -- All MLB starters, sorted by combined FF+FT(+SI) usage (high -> low)
    SELECT 2 AS ord,
        name                                                   AS pitcher,
        gc_id,
        CAST(career_war AS decimal(5,1))                       AS career_war,
        gs_season AS gs_2026,
        CASE WHEN outs_afx IS NULL THEN NULL
             ELSE CONCAT(outs_afx / 3, '.', outs_afx % 3) END AS low_a_ip,
        n_classified,
        CAST(100.0 * ff_ratio  AS decimal(4,1))                AS ff_pct,
        CAST(100.0 * two_ratio AS decimal(4,1))                AS two_seam_pct,
        CAST(100.0 * fb_ratio  AS decimal(4,1))                AS combined_fb_pct
    FROM metrics WHERE gc_id <> @beck_id
) x
ORDER BY ord,                       -- Beck, then AVERAGE, then the field
         combined_fb_pct DESC,      -- highest combined FF+FT usage first
         n_classified DESC;
