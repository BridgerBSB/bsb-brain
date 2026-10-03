-- HOU cumulative NetK by pitch-type bucket — 2025 + 2026 SPLIT.
-- One row per year. Ranks partition within each year (HOU vs 29 other orgs in THAT year).
-- Scope: AAA + AA + A+ + A (MLB / FCL / DSL excluded).
-- Mirror of canonical NetK formula from
--   intangibles/src/catching_tracker_data.py::_ORG_PITCHES_COMBINED_QUERY +
--   pd-goals/src/org_kpi_data.py::_CATCHER_PITCH_ORG_QUERY:
--     * pv.called_strike_chance > 0.05 AND < 0.95 (strict, level-adjusted CSC, NOT _mlb)
--     * pv.pitch_result_id IN (4, 5, 6) (called pitches: ball, blocked ball, called strike)
--     * pv.ignore_flag = 0
--     * org attribution via Events_View.fielding_team_id -> MLBAM.Teams
-- Org canon: OAK -> ATH (rebrand spans the 2025/2026 window).
-- Pitch type buckets per .claude/rules/pitch-codes.md:
--     FB = FF, FT, SI       (fastballs)
--     BB = SL, CU, FC       (breaking balls)
--     OS = CH, FS, SC, KN   (offspeed)

WITH framing_pitches AS (
    SELECT
        sv.year,
        CASE UPPER(mt.org_abbrev)
            WHEN 'OAK' THEN 'ATH'
            ELSE UPPER(mt.org_abbrev)
        END AS org,
        pv.pitch_type,
        pv.net_k
    FROM Astros.Pitches_View pv
    JOIN Astros.Schedule_View sv
        ON sv.sched_id = pv.sched_id
    JOIN Astros.Events_View ev
        ON ev.sched_id = pv.sched_id
       AND ev.event_id = pv.ab_event_id
    JOIN MLBAM.Teams mt
        ON mt.team_id = ev.fielding_team_id
       AND mt.season  = sv.year
    WHERE sv.year IN (2025, 2026)
      AND sv.sched_type = 'R'
      AND sv.level_code IN ('aaa','aax','afa','afx')
      AND pv.called_strike_chance > 0.05
      AND pv.called_strike_chance < 0.95
      AND pv.pitch_result_id IN (4, 5, 6)
      AND pv.ignore_flag = 0
      AND pv.pitch_id > 0
),
per_org_yr AS (
    SELECT
        year,
        org,
        SUM(net_k) AS total_netk,
        SUM(CASE WHEN pitch_type IN ('FF','FT','SI') THEN net_k ELSE 0 END) AS fb_netk,
        SUM(CASE WHEN pitch_type IN ('SL','CU','FC') THEN net_k ELSE 0 END) AS bb_netk,
        SUM(CASE WHEN pitch_type IN ('CH','FS','SC','KN') THEN net_k ELSE 0 END) AS os_netk,
        COUNT(*) AS n_pitches,
        SUM(CASE WHEN pitch_type IN ('FF','FT','SI') THEN 1 ELSE 0 END) AS n_fb,
        SUM(CASE WHEN pitch_type IN ('SL','CU','FC') THEN 1 ELSE 0 END) AS n_bb,
        SUM(CASE WHEN pitch_type IN ('CH','FS','SC','KN') THEN 1 ELSE 0 END) AS n_os
    FROM framing_pitches
    GROUP BY year, org
),
ranked AS (
    SELECT
        year, org, total_netk, fb_netk, bb_netk, os_netk,
        n_pitches, n_fb, n_bb, n_os,
        RANK() OVER (PARTITION BY year ORDER BY total_netk DESC) AS total_rank,
        RANK() OVER (PARTITION BY year ORDER BY fb_netk    DESC) AS fb_rank,
        RANK() OVER (PARTITION BY year ORDER BY bb_netk    DESC) AS bb_rank,
        RANK() OVER (PARTITION BY year ORDER BY os_netk    DESC) AS os_rank
    FROM per_org_yr
)
SELECT
    year                                      AS [Year],
    CAST(total_netk AS DECIMAL(7,2))          AS [Total NetK],
    total_rank                                AS [Total Rk],
    CAST(fb_netk    AS DECIMAL(7,2))          AS [FB NetK],
    fb_rank                                   AS [FB Rk],
    CAST(bb_netk    AS DECIMAL(7,2))          AS [BB NetK],
    bb_rank                                   AS [BB Rk],
    CAST(os_netk    AS DECIMAL(7,2))          AS [OS NetK],
    os_rank                                   AS [OS Rk],
    n_pitches                                 AS [#Pitches],
    n_fb                                      AS [#FB],
    n_bb                                      AS [#BB],
    n_os                                      AS [#OS]
FROM ranked
WHERE org = 'HOU'
ORDER BY year;
