-- DSL FF Velo Jump — 30-org leaderboard.
-- Same methodology as hou-dsl-ff-velo-jump-2yr.sql, expanded to all 30
-- DSL clubs. Where does HOU rank in first-year-to-final-year FF velo
-- development?
--
-- Per-pitcher definition (unchanged from the HOU-only query):
--   * Min 50 FF (pitch_type='FF') per (pitcher, org, year) to qualify a year.
--   * Pitcher must have 2+ qualifying years AT THE SAME ORG and at
--     least one of those years in {2024, 2025}.
--   * Pair = FIRST qualifying year -> LAST qualifying year at that org.
--   * Cross-org movers (rare in DSL) qualify under whichever org gives
--     them 2+ years; if neither side has 2+ years they're dropped.
--
-- Per-org definition:
--   * org avg_jump = unweighted mean of qualifying pitchers' jumps
--     (each pitcher = 1 vote). Matches the methodology Sam framed in
--     the original ask.
--
-- Org canon: OAK -> ATH (Athletics rebrand spans both forms in
-- MLBAM.Teams across the window). HOU Blue + Orange both map to 'HOU'
-- naturally via MLBAM.Teams.org_abbrev.

IF OBJECT_ID('tempdb..#org_dsl_ff')         IS NOT NULL DROP TABLE #org_dsl_ff;
IF OBJECT_ID('tempdb..#qualified_pitchers') IS NOT NULL DROP TABLE #qualified_pitchers;
IF OBJECT_ID('tempdb..#yoy_pairs')          IS NOT NULL DROP TABLE #yoy_pairs;
IF OBJECT_ID('tempdb..#per_org')            IS NOT NULL DROP TABLE #per_org;

-- Per (pitcher, org, year) mean FF velo at DSL — all 30 orgs
WITH fb_pitches AS (
    SELECT
        pv.pitcher_id,
        CASE UPPER(mt.org_abbrev)
            WHEN 'OAK' THEN 'ATH'
            ELSE UPPER(mt.org_abbrev)
        END                  AS org,
        sv.year,
        pv.release_speed
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
      AND pv.pitch_type = 'FF'
      AND pv.release_speed BETWEEN 60 AND 110
      AND pv.pitch_id > 0
)
SELECT
    pitcher_id,
    org,
    year,
    AVG(release_speed) AS avg_ff_velo,
    COUNT(*)           AS n_ff
INTO #org_dsl_ff
FROM fb_pitches
GROUP BY pitcher_id, org, year
HAVING COUNT(*) >= 50;

-- Pitchers with 2+ qualifying years at the same org AND >=1 year in {2024, 2025}
SELECT pitcher_id, org
INTO #qualified_pitchers
FROM #org_dsl_ff
GROUP BY pitcher_id, org
HAVING COUNT(DISTINCT year) >= 2
   AND MAX(CASE WHEN year IN (2024, 2025) THEN 1 ELSE 0 END) = 1;

-- Pair = first year -> last year at that org
SELECT
    qp.org,
    qp.pitcher_id,
    fy.year                          AS year1,
    ly.year                          AS year2,
    fy.avg_ff_velo                   AS velo_y1,
    ly.avg_ff_velo                   AS velo_y2,
    ly.avg_ff_velo - fy.avg_ff_velo  AS velo_jump
INTO #yoy_pairs
FROM #qualified_pitchers qp
CROSS APPLY (
    SELECT TOP 1 year, avg_ff_velo
    FROM #org_dsl_ff h
    WHERE h.pitcher_id = qp.pitcher_id AND h.org = qp.org
    ORDER BY h.year ASC
) fy
CROSS APPLY (
    SELECT TOP 1 year, avg_ff_velo
    FROM #org_dsl_ff h
    WHERE h.pitcher_id = qp.pitcher_id AND h.org = qp.org
    ORDER BY h.year DESC
) ly;

-- Per-org aggregate + rank
SELECT
    org,
    COUNT(*)                                          AS n_pitchers,
    AVG(velo_jump)                                    AS avg_jump,
    AVG(velo_y1)                                      AS avg_y1,
    AVG(velo_y2)                                      AS avg_y2,
    RANK() OVER (ORDER BY AVG(velo_jump) DESC)        AS rank_in_dsl,
    COUNT(*) OVER ()                                  AS n_orgs
INTO #per_org
FROM #yoy_pairs
GROUP BY org;


-- ============================================================
-- Result Set 1: HOU summary line
-- ============================================================
SELECT
    org                                     AS [Org],
    n_pitchers                              AS [#Pitchers],
    CAST(avg_y1   AS DECIMAL(5,1))          AS [Avg First Yr Velo],
    CAST(avg_y2   AS DECIMAL(5,1))          AS [Avg Last Yr Velo],
    CAST(avg_jump AS DECIMAL(5,2))          AS [Avg Jump (mph)],
    rank_in_dsl                             AS [DSL Rank],
    n_orgs                                  AS [Out Of]
FROM #per_org
WHERE org = 'HOU';


-- ============================================================
-- Result Set 2: Full DSL leaderboard, ranked by avg jump
-- ============================================================
SELECT
    rank_in_dsl                             AS [Rank],
    org                                     AS [Org],
    n_pitchers                              AS [#Pitchers],
    CAST(avg_y1   AS DECIMAL(5,1))          AS [Avg First Yr Velo],
    CAST(avg_y2   AS DECIMAL(5,1))          AS [Avg Last Yr Velo],
    CAST(avg_jump AS DECIMAL(5,2))          AS [Avg Jump (mph)]
FROM #per_org
ORDER BY rank_in_dsl, org;


-- Cleanup
DROP TABLE #org_dsl_ff;
DROP TABLE #qualified_pitchers;
DROP TABLE #yoy_pairs;
DROP TABLE #per_org;
