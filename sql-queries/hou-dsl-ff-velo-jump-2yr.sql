-- Sam's ask (5:45 PM, 5/28, REVISED):
--   Average FF velo jump for HOU DSL arms with 2+ DSL years, where at
--   least one of those years is 2024 or 2025. Compares each pitcher's
--   FIRST DSL year to LAST DSL year (full development arc, not
--   consecutive-year-only).
--
-- Returns BOTH per-player jumps AND the aggregate average.
--
-- Scope:
--   * Strictly HOU DSL R games (gc2_level_code='dsl', sched_type='R').
--   * HOU's DSL Astros Blue + Orange both map to org='HOU' via
--     fielding_team_id -> MLBAM.Teams — sub-team switch between years
--     is fine.
--   * FF only (pv.pitch_type = 'FF'). To swap to all fastballs use
--     pv.pitch_type IN ('FF','FT','SI').
--   * Velo sanity cap 60-110 mph (HawkEye glitch guard).
--   * Min 50 FF pitches per (pitcher, year) to qualify a year.
--   * Pitcher must have a qualifying year in {2024, 2025} (the recency
--     gate) AND >= 2 qualifying years total. No upper-bound cap on
--     first year — Maican-style (2022 first year) is fine.
--   * NO roster filter — released pitchers stay (Maican's last year
--     stays as his last year; we don't replace it with anything).
--   * Pair = MIN(year) -> MAX(year). For a 2022/2023/2024 pitcher the
--     pair is 2022 -> 2024 (full arc). Gaps are fine.
--
-- Mechanics:
--   * pitcher_id = pv.pitcher_id (groundcontrol_id).
--   * Events_View JOIN uses ab_event_id per db-joins.md.
--   * Org gate via ev.fielding_team_id.
--   * Uses #temp tables so both result sets can read the materialized
--     pairs (CTEs only scope to the next stmt).

IF OBJECT_ID('tempdb..#hou_dsl_ff')        IS NOT NULL DROP TABLE #hou_dsl_ff;
IF OBJECT_ID('tempdb..#qualified_pitchers') IS NOT NULL DROP TABLE #qualified_pitchers;
IF OBJECT_ID('tempdb..#yoy_pairs')          IS NOT NULL DROP TABLE #yoy_pairs;

-- Per-pitcher, per-year mean FF velo at HOU DSL (all years)
SELECT
    pv.pitcher_id,
    sv.year,
    AVG(pv.release_speed) AS avg_ff_velo,
    COUNT(*)              AS n_ff
INTO #hou_dsl_ff
FROM Astros.Pitches_View pv
JOIN Astros.Schedule_View sv
    ON sv.sched_id = pv.sched_id
JOIN Astros.Events_View ev
    ON ev.sched_id = pv.sched_id
   AND ev.event_id = pv.ab_event_id
JOIN MLBAM.Teams mt
    ON mt.team_id = ev.fielding_team_id
   AND mt.season  = sv.year
WHERE sv.sched_type = 'R'
  AND sv.gc2_level_code = 'dsl'
  AND UPPER(mt.org_abbrev) = 'HOU'
  AND pv.pitch_type = 'FF'
  AND pv.release_speed BETWEEN 60 AND 110
  AND pv.pitch_id > 0
GROUP BY pv.pitcher_id, sv.year
HAVING COUNT(*) >= 50;

-- Pitchers with 2+ DSL years AND at least one of those in {2024, 2025}
SELECT pitcher_id
INTO #qualified_pitchers
FROM #hou_dsl_ff
GROUP BY pitcher_id
HAVING COUNT(DISTINCT year) >= 2
   AND MAX(CASE WHEN year IN (2024, 2025) THEN 1 ELSE 0 END) = 1;

-- Pair = first qualifying year -> last qualifying year per pitcher
SELECT
    qp.pitcher_id,
    fy.year                          AS year1,
    ly.year                          AS year2,
    fy.avg_ff_velo                   AS velo_y1,
    ly.avg_ff_velo                   AS velo_y2,
    fy.n_ff                          AS n_y1,
    ly.n_ff                          AS n_y2,
    ly.year - fy.year                AS years_apart,
    ly.avg_ff_velo - fy.avg_ff_velo  AS velo_jump
INTO #yoy_pairs
FROM #qualified_pitchers qp
CROSS APPLY (
    SELECT TOP 1 year, avg_ff_velo, n_ff
    FROM #hou_dsl_ff h
    WHERE h.pitcher_id = qp.pitcher_id
    ORDER BY h.year ASC
) fy
CROSS APPLY (
    SELECT TOP 1 year, avg_ff_velo, n_ff
    FROM #hou_dsl_ff h
    WHERE h.pitcher_id = qp.pitcher_id
    ORDER BY h.year DESC
) ly;


-- ============================================================
-- Result Set 1 (Zac context): player-by-player jumps
-- ============================================================
SELECT
    CONCAT(pl.first_name, ' ', pl.last_name)   AS [Pitcher],
    yp.pitcher_id                              AS [GC ID],
    yp.year1                                   AS [First Yr],
    CAST(yp.velo_y1 AS DECIMAL(5,1))           AS [First Yr FF Velo],
    yp.n_y1                                    AS [#Y1 FF],
    yp.year2                                   AS [Last Yr],
    CAST(yp.velo_y2 AS DECIMAL(5,1))           AS [Last Yr FF Velo],
    yp.n_y2                                    AS [#Y2 FF],
    yp.years_apart                             AS [Yrs Apart],
    CAST(yp.velo_jump AS DECIMAL(5,2))         AS [Jump (mph)]
FROM #yoy_pairs yp
LEFT JOIN Astros.Players pl
    ON pl.groundcontrol_id = yp.pitcher_id
ORDER BY yp.velo_jump DESC;


-- ============================================================
-- Result Set 2 (Sam's actual ask): the average
-- ============================================================
SELECT
    COUNT(*)                                AS [#Pitchers],
    CAST(AVG(velo_jump) AS DECIMAL(5,2))    AS [Avg FF Velo Jump (mph)],
    CAST(MIN(velo_jump) AS DECIMAL(5,2))    AS [Min Jump],
    CAST(MAX(velo_jump) AS DECIMAL(5,2))    AS [Max Jump],
    CAST(AVG(velo_y1)   AS DECIMAL(5,1))    AS [Avg First Yr Velo],
    CAST(AVG(velo_y2)   AS DECIMAL(5,1))    AS [Avg Last Yr Velo],
    CAST(AVG(CAST(years_apart AS float)) AS DECIMAL(3,1)) AS [Avg Yrs Apart]
FROM #yoy_pairs;


-- Cleanup
DROP TABLE #hou_dsl_ff;
DROP TABLE #qualified_pitchers;
DROP TABLE #yoy_pairs;
