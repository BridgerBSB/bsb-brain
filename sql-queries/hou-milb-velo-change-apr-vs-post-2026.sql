/* ============================================================================
   HOU MiLB fastball-velo change: April vs after-April (2026)
   ----------------------------------------------------------------------------
   Sam Niedorf ask (Jun 23 2026): biggest velo dips & gainers, April -> now,
   HOU MiLB, no DSL (not in season in April; they also have no April baseline).

   - "Velocity" = fastball velo (FF/FT/SI) avg release_speed. To use ALL pitches
     instead, delete the `pv.pitch_type IN ('FF','FT','SI')` line in the fb CTE.
   - Scope: HOU-affiliate games (fielding-team org = HOU), MiLB only (AAA/AA/A+/A
     + FCL), excludes MLB and DSL. FCL guys have no April games so they drop via
     the April gate naturally.
   - Windows: April = MONTH 4 ; "after April" = May 1 -> now.
   - Gate: >= @min_fb fastballs in EACH window (kills small-sample noise).
   - delta_mph = post-April avg - April avg.  +ve = GAINER, -ve = DIP.
     Ordered gainers (top) -> dips (bottom).
   ============================================================================ */

DECLARE @season  int = 2026;
DECLARE @min_fb  int = 30;     -- min fastballs per window to qualify (lower to ~20 for more relievers)

WITH fb AS (                    -- one row per HOU-MiLB fastball, tagged by window
    SELECT
        pv.pitcher_id,
        pv.release_speed,
        CASE WHEN MONTH(sv.sched_date) = 4        THEN 'apr'
             WHEN sv.sched_date >= '2026-05-01'   THEN 'post' END AS bucket
    FROM Astros.Pitches_View pv
    JOIN Astros.Schedule_View sv ON pv.sched_id = sv.sched_id
    LEFT JOIN Astros.Events_View aev               -- ab_event_id = always-populated event (org)
        ON aev.sched_id = pv.sched_id AND aev.event_id = pv.ab_event_id
    JOIN mlbam.teams mt                            -- fielding team = pitcher's team
        ON aev.fielding_team_id = mt.team_id AND mt.season = sv.year
    WHERE sv.year = @season
      AND sv.sched_type = 'R'
      AND pv.pitch_id > 0
      AND pv.pitch_type IN ('FF','FT','SI')        -- <-- fastballs; delete for all-pitch velo
      AND pv.release_speed > 0 AND pv.release_speed < 110   -- glitch guard
      AND mt.org_abbrev = 'HOU'
      AND (sv.level_code IN ('aaa','aax','afa','afx') OR sv.gc2_level_code = 'rok')  -- MiLB, no MLB, no DSL
      AND (MONTH(sv.sched_date) = 4 OR sv.sched_date >= '2026-05-01')
),
agg AS (
    SELECT pitcher_id,
        AVG(CASE WHEN bucket = 'apr'  THEN release_speed END) AS apr_velo,
        AVG(CASE WHEN bucket = 'post' THEN release_speed END) AS post_velo,
        SUM(CASE WHEN bucket = 'apr'  THEN 1 ELSE 0 END)      AS n_apr,
        SUM(CASE WHEN bucket = 'post' THEN 1 ELSE 0 END)      AS n_post
    FROM fb
    GROUP BY pitcher_id
)
SELECT
    p.first_name + ' ' + p.last_name              AS pitcher,
    p.throws,
    lvl.levels,
    CAST(a.apr_velo  AS DECIMAL(4,1))             AS apr_velo,
    CAST(a.post_velo AS DECIMAL(4,1))             AS post_velo,
    CAST(a.post_velo - a.apr_velo AS DECIMAL(4,1)) AS delta_mph,   -- +gainer / -dip
    a.n_apr, a.n_post
FROM agg a
JOIN Astros.Players p ON p.groundcontrol_id = a.pitcher_id
CROSS APPLY (                   -- distinct level label(s) the pitcher appeared at
    SELECT STRING_AGG(lv, '/') AS levels FROM (
        SELECT DISTINCT CASE sv2.gc2_level_code
            WHEN 'aaa' THEN 'AAA' WHEN 'aax' THEN 'AA'
            WHEN 'afa' THEN 'A+'  WHEN 'afx' THEN 'A'
            WHEN 'rok' THEN 'FCL' ELSE UPPER(sv2.gc2_level_code) END AS lv
        FROM Astros.Pitches_View pv2
        JOIN Astros.Schedule_View sv2 ON pv2.sched_id = sv2.sched_id
        WHERE pv2.pitcher_id = a.pitcher_id AND sv2.year = @season
          AND sv2.sched_type = 'R' AND pv2.pitch_id > 0
          AND (sv2.level_code IN ('aaa','aax','afa','afx') OR sv2.gc2_level_code = 'rok')
          AND (MONTH(sv2.sched_date) = 4 OR sv2.sched_date >= '2026-05-01')
    ) d
) lvl
WHERE a.n_apr >= @min_fb AND a.n_post >= @min_fb
ORDER BY delta_mph DESC;        -- gainers at top, dips at bottom
