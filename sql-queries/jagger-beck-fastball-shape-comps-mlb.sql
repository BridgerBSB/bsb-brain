-- ============================================================================
-- FASTBALL-SHAPE COMPS — MLB starting pitchers similar to Jagger Beck (gc 269548).
--   Ask (DJ Engle, pitching coordinator): "ML starting pitchers who have had this
--   combination of fastball shapes?"  Match on FF + FT shape (IVB + HB), within a
--   tolerance of Jagger's 2026 averages.
-- ----------------------------------------------------------------------------
-- Jagger's 2026 avgs per the Arm Farm card (for sanity-check vs Section 0 below):
--      FF: Velo 91.9 | IVB 12.1 | HB -6.7 | 19.3% use
--      FT: Velo 91.5 | IVB  8.4 | HB -14.1 | 22.0% use
--
-- METRICS (Astros.Pitches_View): inducedvertbreak (IVB), horzbreak (HB),
--   release_speed (velo). The anchor (#jagger) is computed from the SAME RAW
--   columns as the MLB pool, so the |diff| <= tol matching is internally
--   consistent. NOTE: the Arm Farm APP negates horzbreak for catcher-view display,
--   so the printed HB sign here may be opposite the card's -6.7 / -14.1 — that does
--   NOT affect matching (both sides use raw horzbreak). If you want the output to
--   read in card orientation, negate horzbreak in the SELECTs.
--
-- SAMPLE (v1, all knobs are DECLAREs up top):
--   * MLB starter-SEASONS, @yr_from..@yr_to (default 2018-2026), regular season.
--     One row per pitcher PER SEASON he started >=1 MLB game, so a pitcher's
--     fastball is matched as it actually was that year (shape drifts year to year).
--   * Same throwing hand as Jagger (shape comps mirror across handedness).
--   * Needs >= @min_pitches of that pitch type in that season for a stable avg.
--   * Tolerance @tol applied to BOTH IVB and HB, +/- each direction.
--   To use ALL MLB pitchers (not just starters): delete the EXISTS block in #mlb.
--   For ONE blended row per pitcher (not per season): remove `sv.year AS season`
--     + `sv.year` from #mlb SELECT/GROUP BY and the season join in Section 3.
--   To widen/tighten: change @tol (coordinator floated 0.5 or 1.0).
--
-- FUTURE: this is the seed for an Arm Farm app tab — pick any anchor pitcher (or
--   type manual IVB/HB/velo), per-metric tolerances, and a configurable sample
--   (season range / level / WAR filter / hand). That build lives in the
--   bsb-wt-bullpen worktree; this .sql is the proof-of-concept.
-- ============================================================================

DECLARE @beck_id      int   = 269548;   -- Jagger Beck
DECLARE @season       int   = 2026;     -- Jagger's anchor season (his current shape)
DECLARE @yr_from      int   = 2018;     -- MLB comparison window: earliest season
DECLARE @yr_to        int   = 2026;     -- MLB comparison window: latest season
DECLARE @tol          float = 1.0;      -- +/- tolerance on IVB and HB (try 0.5)
DECLARE @min_pitches  int   = 50;       -- min pitches of the type per pitcher-SEASON

DECLARE @hand char(1);
SET @hand = (SELECT throws FROM Astros.Players WHERE groundcontrol_id = @beck_id);

-- Anchor: Jagger's FF + FT averages from RAW columns (all levels, @season, R) ----
IF OBJECT_ID('tempdb..#jagger') IS NOT NULL DROP TABLE #jagger;
SELECT
    pv.pitch_type,
    AVG(pv.inducedvertbreak) AS ivb,
    AVG(pv.horzbreak)        AS hb,
    AVG(pv.release_speed)    AS velo,
    COUNT(*)                 AS n
INTO #jagger
FROM   Astros.Pitches_View  pv
JOIN   Astros.Schedule_View sv ON sv.sched_id = pv.sched_id
WHERE  pv.pitcher_id = @beck_id
  AND  sv.year       = @season
  AND  sv.sched_type = 'R'
  AND  pv.pitch_id  > 0
  AND  pv.pitch_type IN ('FF','FT')
GROUP BY pv.pitch_type;

-- MLB starter-SEASONS' FF + FT shapes, @yr_from..@yr_to, same hand, reg season ---
-- One row per (pitcher, season, pitch_type). A season counts only if the pitcher
-- STARTED >=1 MLB game that year (EXISTS gate — keeps n_pitches honest for guys
-- traded mid-year, which a JOIN would double-count).
IF OBJECT_ID('tempdb..#mlb') IS NOT NULL DROP TABLE #mlb;
SELECT
    pv.pitcher_id,
    sv.year                  AS season,
    pv.pitch_type,
    AVG(pv.inducedvertbreak) AS ivb,
    AVG(pv.horzbreak)        AS hb,
    AVG(pv.release_speed)    AS velo,
    COUNT(*)                 AS n_pitches
INTO #mlb
FROM   Astros.Pitches_View  pv
JOIN   Astros.Schedule_View sv ON sv.sched_id = pv.sched_id
JOIN   Astros.Players       p  ON p.groundcontrol_id = pv.pitcher_id
WHERE  sv.level_code = 'mlb'
  AND  sv.sched_type = 'R'
  AND  sv.year BETWEEN @yr_from AND @yr_to
  AND  pv.pitch_id  > 0
  AND  pv.pitch_type IN ('FF','FT')
  AND  pv.pitcher_throws = @hand                 -- same arm side as Jagger
  AND  EXISTS (                                  -- <<< STARTED >=1 MLB game THAT season. Delete this EXISTS to use all MLB pitchers.
        SELECT 1
        FROM   mlbam.ytd_player_pitching_stats yp
        WHERE  yp.player_id = p.mlbam_id AND yp.season = sv.year
          AND  yp.level = 'mlb' AND yp.gm_type = 'r' AND yp.split_id = 0
          AND  yp.gs >= 1
       )
GROUP BY pv.pitcher_id, sv.year, pv.pitch_type;


-- SECTION 0 — Jagger's anchor (verify vs the card; HB sign may be flipped) -------
SELECT pitch_type,
       CAST(velo AS decimal(4,1)) AS velo,
       CAST(ivb  AS decimal(4,1)) AS ivb,
       CAST(hb   AS decimal(4,1)) AS hb,
       n AS n_pitches
FROM   #jagger
ORDER BY pitch_type DESC;   -- FF then FT


-- SECTION 1 — MLB starters with similar FF (within @tol IVB & HB) ----------------
SELECT
    LTRIM(RTRIM(ISNULL(r.first_name,'') + ' ' + ISNULL(r.last_name,''))) AS pitcher,
    m.season,
    m.pitcher_id AS gc_id,
    m.n_pitches,
    CAST(m.velo AS decimal(4,1))                                  AS velo,
    CAST(m.ivb  AS decimal(4,1))                                  AS ivb,
    CAST(m.hb   AS decimal(4,1))                                  AS hb,
    CAST(m.ivb - j.ivb AS decimal(4,1))                           AS ivb_diff,
    CAST(m.hb  - j.hb  AS decimal(4,1))                           AS hb_diff,
    CAST(SQRT(POWER(m.ivb - j.ivb,2) + POWER(m.hb - j.hb,2)) AS decimal(4,2)) AS shape_dist
FROM        #mlb m
JOIN        #jagger j ON j.pitch_type = 'FF'
LEFT JOIN   Astros.Players r ON r.groundcontrol_id = m.pitcher_id
WHERE  m.pitch_type = 'FF'
  AND  m.n_pitches >= @min_pitches
  AND  ABS(m.ivb - j.ivb) <= @tol
  AND  ABS(m.hb  - j.hb)  <= @tol
ORDER BY shape_dist;


-- SECTION 2 — MLB starters with similar FT / 2-seam (within @tol IVB & HB) -------
SELECT
    LTRIM(RTRIM(ISNULL(r.first_name,'') + ' ' + ISNULL(r.last_name,''))) AS pitcher,
    m.season,
    m.pitcher_id AS gc_id,
    m.n_pitches,
    CAST(m.velo AS decimal(4,1))                                  AS velo,
    CAST(m.ivb  AS decimal(4,1))                                  AS ivb,
    CAST(m.hb   AS decimal(4,1))                                  AS hb,
    CAST(m.ivb - j.ivb AS decimal(4,1))                           AS ivb_diff,
    CAST(m.hb  - j.hb  AS decimal(4,1))                           AS hb_diff,
    CAST(SQRT(POWER(m.ivb - j.ivb,2) + POWER(m.hb - j.hb,2)) AS decimal(4,2)) AS shape_dist
FROM        #mlb m
JOIN        #jagger j ON j.pitch_type = 'FT'
LEFT JOIN   Astros.Players r ON r.groundcontrol_id = m.pitcher_id
WHERE  m.pitch_type = 'FT'
  AND  m.n_pitches >= @min_pitches
  AND  ABS(m.ivb - j.ivb) <= @tol
  AND  ABS(m.hb  - j.hb)  <= @tol
ORDER BY shape_dist;


-- SECTION 3 — THE "COMBINATION": starter-seasons whose FF *and* FT both match ----
SELECT
    LTRIM(RTRIM(ISNULL(r.first_name,'') + ' ' + ISNULL(r.last_name,''))) AS pitcher,
    ff.season,
    ff.pitcher_id AS gc_id,
    ff.n_pitches AS ff_n, ft.n_pitches AS ft_n,
    CAST(ff.ivb AS decimal(4,1)) AS ff_ivb, CAST(ff.hb AS decimal(4,1)) AS ff_hb,
    CAST(ft.ivb AS decimal(4,1)) AS ft_ivb, CAST(ft.hb AS decimal(4,1)) AS ft_hb,
    CAST( SQRT(POWER(ff.ivb - jff.ivb,2) + POWER(ff.hb - jff.hb,2))
        + SQRT(POWER(ft.ivb - jft.ivb,2) + POWER(ft.hb - jft.hb,2)) AS decimal(5,2)) AS combined_dist
FROM        #mlb ff
JOIN        #mlb ft  ON ft.pitcher_id = ff.pitcher_id AND ft.season = ff.season AND ft.pitch_type = 'FT'
JOIN        #jagger jff ON jff.pitch_type = 'FF'
JOIN        #jagger jft ON jft.pitch_type = 'FT'
LEFT JOIN   Astros.Players r ON r.groundcontrol_id = ff.pitcher_id
WHERE  ff.pitch_type = 'FF'
  AND  ff.n_pitches >= @min_pitches AND ft.n_pitches >= @min_pitches
  AND  ABS(ff.ivb - jff.ivb) <= @tol AND ABS(ff.hb - jff.hb) <= @tol
  AND  ABS(ft.ivb - jft.ivb) <= @tol AND ABS(ft.hb - jft.hb) <= @tol
ORDER BY combined_dist;

DROP TABLE #jagger;
DROP TABLE #mlb;
