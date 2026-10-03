-- HOU cumulative NetK by 4 plate-space quadrants — 2025 + 2026 SPLIT.
-- One row per year. Ranks partition within each year (HOU vs 29 other orgs).
-- Scope: AAA + AA + A+ + A (MLB / FCL / DSL excluded).
--
-- Zone quadrants (mutually exclusive — every NetK pitch lands in exactly ONE):
--     TopL = plate_z >= SZ_MID AND plate_x <  0   (top-left, catcher's view)
--     TopR = plate_z >= SZ_MID AND plate_x >= 0   (top-right)
--     BotL = plate_z <  SZ_MID AND plate_x <  0   (bottom-left)
--     BotR = plate_z <  SZ_MID AND plate_x >= 0   (bottom-right)
--
-- SZ_MID = (LEAGUE_SZ_BOT + LEAGUE_SZ_TOP) / 2 = (1.626 + 3.221) / 2 = 2.4235 ft
-- Canonical league-avg bounds from
--   intangibles/src/catcher_framing_hexbin_data.py:357-358
--     LEAGUE_SZ_TOP_FT = 3.221 = 0.535 * 6.0212 ft (avg MLB hitter)
--     LEAGUE_SZ_BOT_FT = 1.626 = 0.27  * 6.0212 ft
--
-- All from CATCHER'S VIEW per .claude/rules/coordinates.md:
--     plate_x > 0 = 1B side = right (from catcher looking at pitcher)
--     plate_x < 0 = 3B side = left
--
-- No batter-handedness flip — quadrants are pure plate-space buckets.
-- Trade-off: TopL pools "inside to RHH" + "outside to LHH" together.
--
-- Same NetK gate as the pitch-type query (canonical NetK formula).

WITH framing_pitches AS (
    SELECT
        sv.year,
        CASE UPPER(mt.org_abbrev)
            WHEN 'OAK' THEN 'ATH'
            ELSE UPPER(mt.org_abbrev)
        END AS org,
        pv.plate_z,
        pv.plate_x,
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
      AND pv.plate_x IS NOT NULL
      AND pv.plate_z IS NOT NULL
),
-- SZ_MID = (1.626 + 3.221) / 2 = 2.4235 ft
per_org_yr AS (
    SELECT
        year,
        org,
        SUM(net_k) AS total_netk,
        SUM(CASE WHEN plate_z >= ((1.626 + 3.221) / 2.0) AND plate_x <  0 THEN net_k ELSE 0 END) AS topl_netk,
        SUM(CASE WHEN plate_z >= ((1.626 + 3.221) / 2.0) AND plate_x >= 0 THEN net_k ELSE 0 END) AS topr_netk,
        SUM(CASE WHEN plate_z <  ((1.626 + 3.221) / 2.0) AND plate_x <  0 THEN net_k ELSE 0 END) AS botl_netk,
        SUM(CASE WHEN plate_z <  ((1.626 + 3.221) / 2.0) AND plate_x >= 0 THEN net_k ELSE 0 END) AS botr_netk,
        COUNT(*) AS n_pitches,
        SUM(CASE WHEN plate_z >= ((1.626 + 3.221) / 2.0) AND plate_x <  0 THEN 1 ELSE 0 END) AS n_topl,
        SUM(CASE WHEN plate_z >= ((1.626 + 3.221) / 2.0) AND plate_x >= 0 THEN 1 ELSE 0 END) AS n_topr,
        SUM(CASE WHEN plate_z <  ((1.626 + 3.221) / 2.0) AND plate_x <  0 THEN 1 ELSE 0 END) AS n_botl,
        SUM(CASE WHEN plate_z <  ((1.626 + 3.221) / 2.0) AND plate_x >= 0 THEN 1 ELSE 0 END) AS n_botr
    FROM framing_pitches
    GROUP BY year, org
),
ranked AS (
    SELECT
        year, org, total_netk,
        topl_netk, topr_netk, botl_netk, botr_netk,
        n_pitches, n_topl, n_topr, n_botl, n_botr,
        RANK() OVER (PARTITION BY year ORDER BY total_netk DESC) AS total_rank,
        RANK() OVER (PARTITION BY year ORDER BY topl_netk  DESC) AS topl_rank,
        RANK() OVER (PARTITION BY year ORDER BY topr_netk  DESC) AS topr_rank,
        RANK() OVER (PARTITION BY year ORDER BY botl_netk  DESC) AS botl_rank,
        RANK() OVER (PARTITION BY year ORDER BY botr_netk  DESC) AS botr_rank
    FROM per_org_yr
)
SELECT
    year                                      AS [Year],
    CAST(total_netk AS DECIMAL(7,2))          AS [Total NetK],
    total_rank                                AS [Total Rk],
    CAST(topl_netk  AS DECIMAL(7,2))          AS [TopL NetK],
    topl_rank                                 AS [TopL Rk],
    CAST(topr_netk  AS DECIMAL(7,2))          AS [TopR NetK],
    topr_rank                                 AS [TopR Rk],
    CAST(botl_netk  AS DECIMAL(7,2))          AS [BotL NetK],
    botl_rank                                 AS [BotL Rk],
    CAST(botr_netk  AS DECIMAL(7,2))          AS [BotR NetK],
    botr_rank                                 AS [BotR Rk],
    n_pitches                                 AS [#Pitches],
    n_topl                                    AS [#TopL],
    n_topr                                    AS [#TopR],
    n_botl                                    AS [#BotL],
    n_botr                                    AS [#BotR]
FROM ranked
WHERE org = 'HOU'
ORDER BY year;
