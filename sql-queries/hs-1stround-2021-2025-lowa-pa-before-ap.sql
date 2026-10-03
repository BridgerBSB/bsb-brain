-- HS first-round HITTERS (draft 2021+) — Low-A PA + gcOBA/Brl%/SLG before A+
-- =====================================================================
-- Population: first-round (draft_round='1') HIGH-SCHOOL (school_type='HS')
--   position players (pitchers excluded), draft_year >= 2021.
-- Scope of ALL metrics: each player's Low-A (afx) games BEFORE reaching A+
--   (afa). Promoted -> up to first A+ game; not-yet-promoted (e.g. Neyens)
--   -> all Low-A to date. Multi-season windows re-pool raw components.
-- Bottom row: AVERAGE across the listed players.
--
-- COLUMN SOURCES (intentional mix):
--   * low_a_pa  = OFFICIAL Gamelog_Batting.pa (stat-line PA; NOT pitch-derived;
--                 db-columns.md BLOCKING). Heliot-2018 class fix.
--   * gcOBA / Brl% / SLG = computed from PITCH/EVENT data (Pitches_View /
--                 Hits / Events_View) — because that is how the Barrelsville
--                 affiliate tracker computes them. "Exactly match the tracker"
--                 => use the tracker's sources for these. So gcOBA/Brl%/SLG
--                 reflect the TRACKED-PA subset, which can be < Gamelog PA.
--
-- METRICS — ported VERBATIM from barrelsville/src/tracker_data.py (LIVE), which
-- matches gcoba_canonical.py. NOTE: this DIVERGES from gc2-metrics.md rules
-- #6/#7/#9 (int-truncation barrel, (12,13,14)-only no-misread gcOBA barrel) —
-- the rule text is STALE; the shipped tracker uses the float barrel, BIP codes
-- (12,13,14,18,19,20), and the EV-misread+bunt filters for the gcOBA barrel too.
--   gcOBA = MLB_OBP * ( 0.50*k_rate + 1.49*bb_hbp_rate
--                     + 0.11*zero_sw + 0.08*one_sw - 0.10*two_sw - 0.10*three_plus_sw
--                     + bip_rate*(1.70*barrel_rate + 1.09*avg_useful_ev/100) )
--     k_rate=so/pa ; bb_hbp_rate=(bb+hbp)/pa (IBB in) ; bip_rate=max((pa-so-bb-hbp)/pa,0)
--     barrel_rate = n_barrel/n_bip_tracked ; avg_useful_ev = AVG(hit_useful_exit_speed)
--     pa = SUM(ev.pa)+SUM(ibb) ; MLB_OBP from mlbam.YTD_Team_Batting_Stats (team_id=0)
--   Brl% (display) = 100*n_barrel/n_bip_tracked   (pct1, higher better)
--   SLG = (1B + 2*2B + 3*3B + 4*HR)/AB            (f3)
--   swing_count per PA = pitch_result_id IN (10,22,23) grouped by (sched_id, ab_event_id)
--   n_bip_tracked/n_barrel/avg_useful_ev: BIP IN (12,13,14,18,19,20), EV in (0,125),
--     bunt-excl (hit_trajectory_id NOT IN 2,3,4), EV-misread excl vs batter_ev_p95.
--   MLB_OBP anchored to each player's LAST Low-A season in-window (gcOBA is a
--     per-season-anchored metric; multi-season windows pick the latest season).
-- draft_round='1' excludes Competitive Balance Round A picks.

WITH draftees AS (
    SELECT
        d.first_name, d.last_name,
        d.draft_year,
        TRY_CAST(d.overall_pick AS int) AS overall_pick,
        d.position,
        d.draft_org,
        p.groundcontrol_id AS gc_id,
        p.mlbam_id
    FROM MLB_eBis.R4_Draft_Query d
    JOIN Astros.Players p
        ON TRY_CAST(d.groundcontrol_id AS int) = p.groundcontrol_id
    WHERE d.draft_round = '1'
      AND d.school_type = 'HS'
      AND d.draft_year >= 2021
      AND d.position NOT IN ('RHP','LHP','RHS','RHR','LHS','LHR','P','SHS','TWP')
),
-- Official gamelog games at Low-A + High-A (drives PA + promotion detection)
games AS (
    SELECT d.gc_id, sv.gc2_level_code AS lvl, sv.sched_date, sv.year, CAST(glb.pa AS int) AS pa
    FROM draftees d
    JOIN MLBAM.Gamelog_Batting glb ON glb.player_id = d.mlbam_id
    JOIN Astros.Schedule_View sv   ON sv.mlbam_game_pk = glb.game_pk
    WHERE sv.gc2_level_code IN ('afx', 'afa') AND sv.sched_type = 'R'
),
ap_promo AS (
    SELECT gc_id, MIN(sched_date) AS afa_date FROM games WHERE lvl = 'afa' GROUP BY gc_id
),
lowa_pre AS (
    -- OFFICIAL Low-A PA before A+ (all Low-A if not yet promoted)
    SELECT g.gc_id, SUM(g.pa) AS lowa_pa_pre_ap, COUNT(DISTINCT g.year) AS n_lowa_seasons
    FROM games g
    LEFT JOIN ap_promo ap ON ap.gc_id = g.gc_id
    WHERE g.lvl = 'afx' AND (ap.afa_date IS NULL OR g.sched_date < ap.afa_date)
    GROUP BY g.gc_id
),
-- Per-(batter, season) EV P95 for the misread filter (tracker EV_MISREAD_CTE,
-- keyed by season so a multi-season window cleans each BIP vs its own season).
batter_ev_p95 AS (
    SELECT sub.batter_id, sub.season, sub.p95_ev
    FROM (
        SELECT DISTINCT pv2.batter_id, YEAR(sv2.sched_date) AS season,
               PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY h2.hit_exit_speed)
                   OVER (PARTITION BY pv2.batter_id, YEAR(sv2.sched_date)) AS p95_ev,
               COUNT(*) OVER (PARTITION BY pv2.batter_id, YEAR(sv2.sched_date)) AS n_bip
        FROM Astros.Pitches_View pv2
        JOIN Astros.Schedule_View sv2 ON pv2.sched_id = sv2.sched_id
        JOIN Astros.Hits h2 ON h2.sched_id = pv2.sched_id AND h2.pitch_id = pv2.pitch_id
        WHERE pv2.pitch_result_id IN (12, 13, 14)
          AND h2.hit_exit_speed > 0 AND h2.hit_exit_speed < 125
          AND pv2.pitch_id > 0
          AND sv2.sched_type IN ('R', 'S', 'E')
          AND YEAR(sv2.sched_date) >= 2021
          AND (sv2.level_code IN ('mlb','aaa','aax','afa','afx') OR sv2.gc2_level_code IN ('rok','dsl'))
          AND pv2.batter_id IN (SELECT gc_id FROM draftees)
    ) sub
    WHERE sub.n_bip >= 20
),
-- Event-anchored PA components over the afx-before-A+ window (tracker _PA_LEVEL_QUERY)
ev_comp AS (
    SELECT pv.batter_id,
        MAX(sv.year) AS last_lowa_season,
        SUM(CAST(ev.pa AS int)) + SUM(CAST(ISNULL(ev.ibb,0) AS int)) AS pa,
        SUM(CAST(ev.ab AS int))  AS ab,
        SUM(CAST(ev.so AS int))  AS so,
        SUM(CAST(ev.bb AS int))  AS bb,
        SUM(CAST(ev.hbp AS int)) AS hbp,
        SUM(CAST(ev.[1b] AS int)) AS h1b,
        SUM(CAST(ev.[2b] AS int)) AS h2b,
        SUM(CAST(ev.[3b] AS int)) AS h3b,
        SUM(CAST(ev.hr AS int))  AS hr
    FROM Astros.Events_View ev
    JOIN Astros.Schedule_View sv ON ev.sched_id = sv.sched_id
    JOIN Astros.Pitches_View pv  ON ev.sched_id = pv.sched_id AND ev.event_id = pv.cur_event_id
    JOIN draftees d              ON d.gc_id = pv.batter_id
    LEFT JOIN ap_promo ap        ON ap.gc_id = pv.batter_id
    WHERE sv.gc2_level_code = 'afx' AND sv.sched_type = 'R'
      AND (ap.afa_date IS NULL OR sv.sched_date < ap.afa_date)
      AND (CAST(ev.pa AS int) = 1 OR CAST(ISNULL(ev.ibb,0) AS int) = 1)
      AND pv.batter_id IS NOT NULL AND pv.pitch_id > 0
    GROUP BY pv.batter_id
),
-- Pitch-anchored BIP metrics over the afx-before-A+ window (tracker _PITCH_LEVEL_QUERY)
bip_comp AS (
    SELECT pv.batter_id,
        SUM(CASE WHEN pv.pitch_result_id IN (12,13,14,18,19,20)
              AND h.hit_exit_speed IS NOT NULL AND h.hit_exit_speed > 0 AND h.hit_exit_speed < 125
              AND NOT (h.hit_exit_speed >= 100 AND h.hit_vertical_angle < -35 AND h.hit_exit_speed > ISNULL(bp95.p95_ev, 105))
              AND (ev1.hit_trajectory_id NOT IN (2,3,4) OR ev1.hit_trajectory_id IS NULL)
             THEN 1 ELSE 0 END) AS n_bip_tracked,
        SUM(CASE WHEN pv.pitch_result_id IN (12,13,14,18,19,20)
              AND h.hit_exit_speed IS NOT NULL AND h.hit_exit_speed > 0 AND h.hit_exit_speed < 125
              AND NOT (h.hit_exit_speed >= 100 AND h.hit_vertical_angle < -35 AND h.hit_exit_speed > ISNULL(bp95.p95_ev, 105))
              AND (ev1.hit_trajectory_id NOT IN (2,3,4) OR ev1.hit_trajectory_id IS NULL)
              AND h.hit_exit_speed * 1.5 - ISNULL(h.hit_vertical_angle, 0) >= 117
              AND h.hit_exit_speed + ISNULL(h.hit_vertical_angle, 0) >= 124
              AND h.hit_exit_speed >= 98
              AND ISNULL(h.hit_vertical_angle, 0) > 4
              AND ISNULL(h.hit_vertical_angle, 0) < 50
             THEN 1 ELSE 0 END) AS n_barrel,
        AVG(CASE WHEN pv.pitch_result_id IN (12,13,14,18,19,20)
              AND h.hit_exit_speed IS NOT NULL AND h.hit_exit_speed > 0 AND h.hit_exit_speed < 125
              AND NOT (h.hit_exit_speed >= 100 AND h.hit_vertical_angle < -35 AND h.hit_exit_speed > ISNULL(bp95.p95_ev, 105))
              AND (ev1.hit_trajectory_id NOT IN (2,3,4) OR ev1.hit_trajectory_id IS NULL)
             THEN h.hit_useful_exit_speed ELSE NULL END) AS avg_useful_ev
    FROM Astros.Pitches_View pv
    JOIN Astros.Schedule_View sv ON pv.sched_id = sv.sched_id
    JOIN draftees d              ON d.gc_id = pv.batter_id
    LEFT JOIN ap_promo ap        ON ap.gc_id = pv.batter_id
    LEFT JOIN Astros.Events_View ev1 ON ev1.sched_id = pv.sched_id AND ev1.event_id = pv.ab_event_id
    LEFT JOIN Astros.Hits h          ON h.sched_id = pv.sched_id AND h.pitch_id = pv.pitch_id
    LEFT JOIN batter_ev_p95 bp95     ON bp95.batter_id = pv.batter_id AND bp95.season = sv.year
    WHERE sv.gc2_level_code = 'afx' AND sv.sched_type = 'R'
      AND (ap.afa_date IS NULL OR sv.sched_date < ap.afa_date)
      AND pv.pitch_id > 0
    GROUP BY pv.batter_id
),
-- Swing distribution (whiffs per PA) over the afx-before-A+ window (tracker _SWING_DIST_QUERY)
sw_comp AS (
    SELECT batter_id,
        1.0 * SUM(CASE WHEN swing_count = 0  THEN 1 ELSE 0 END) / COUNT(*) AS zero_sw,
        1.0 * SUM(CASE WHEN swing_count = 1  THEN 1 ELSE 0 END) / COUNT(*) AS one_sw,
        1.0 * SUM(CASE WHEN swing_count = 2  THEN 1 ELSE 0 END) / COUNT(*) AS two_sw,
        1.0 * SUM(CASE WHEN swing_count >= 3 THEN 1 ELSE 0 END) / COUNT(*) AS three_plus_sw
    FROM (
        SELECT pv.batter_id, pv.sched_id, pv.ab_event_id,
               SUM(CASE WHEN pv.pitch_result_id IN (10, 22, 23) THEN 1 ELSE 0 END) AS swing_count
        FROM Astros.Pitches_View pv
        JOIN Astros.Schedule_View sv ON pv.sched_id = sv.sched_id
        JOIN draftees d              ON d.gc_id = pv.batter_id
        LEFT JOIN ap_promo ap        ON ap.gc_id = pv.batter_id
        JOIN Astros.Events_View ev   ON pv.sched_id = ev.sched_id AND pv.ab_event_id = ev.event_id
        WHERE sv.gc2_level_code = 'afx' AND sv.sched_type = 'R'
          AND (ap.afa_date IS NULL OR sv.sched_date < ap.afa_date)
          AND pv.pitch_id > 0
          AND (CAST(ev.pa AS int) = 1 OR CAST(ISNULL(ev.ibb,0) AS int) = 1)
        GROUP BY pv.batter_id, pv.sched_id, pv.ab_event_id
    ) pa_swings
    GROUP BY batter_id
),
mlb_obp AS (
    SELECT season, obp
    FROM mlbam.YTD_Team_Batting_Stats
    WHERE level = 'mlb' AND gm_type = 'r' AND split_id = 0 AND team_id = 0
      AND season BETWEEN 2021 AND 2026
),
pp AS (
    SELECT
        d.draft_year, d.overall_pick,
        d.first_name + ' ' + d.last_name AS player,
        d.position, UPPER(d.draft_org) AS draft_org,
        YEAR(ap.afa_date) AS promoted_to_ap,
        lp.lowa_pa_pre_ap AS lowa_pa,
        lp.n_lowa_seasons,
        -- gcOBA (LIVE tracker convention)
        CASE WHEN e.pa > 0 THEN
            ISNULL(mo.obp, 0.320) * (
                0.50 * (1.0 * e.so / e.pa)
                + 1.49 * (1.0 * (e.bb + e.hbp) / e.pa)
                + 0.11 * ISNULL(s.zero_sw, 0)
                + 0.08 * ISNULL(s.one_sw, 0)
                + (-0.10) * ISNULL(s.two_sw, 0)
                + (-0.10) * ISNULL(s.three_plus_sw, 0)
                + (CASE WHEN (e.pa - e.so - e.bb - e.hbp) > 0
                        THEN 1.0 * (e.pa - e.so - e.bb - e.hbp) / e.pa ELSE 0 END)
                  * ( 1.70 * (CASE WHEN b.n_bip_tracked > 0 THEN 1.0 * b.n_barrel / b.n_bip_tracked ELSE 0 END)
                    + 1.09 * (CASE WHEN b.avg_useful_ev IS NOT NULL THEN b.avg_useful_ev / 100.0 ELSE 0 END) )
            )
        END AS gcoba,
        CASE WHEN b.n_bip_tracked > 0 THEN 100.0 * b.n_barrel / b.n_bip_tracked END AS barrel_pct,
        CASE WHEN e.ab > 0 THEN 1.0 * (e.h1b + 2*e.h2b + 3*e.h3b + 4*e.hr) / e.ab END AS slg
    FROM draftees d
    JOIN lowa_pre lp      ON lp.gc_id = d.gc_id
    LEFT JOIN ap_promo ap ON ap.gc_id = d.gc_id
    LEFT JOIN ev_comp e   ON e.batter_id = d.gc_id
    LEFT JOIN bip_comp b  ON b.batter_id = d.gc_id
    LEFT JOIN sw_comp s   ON s.batter_id = d.gc_id
    LEFT JOIN mlb_obp mo  ON mo.season = e.last_lowa_season
    WHERE lp.lowa_pa_pre_ap > 0
)
SELECT
    draft_year, pick, player, position, draft_org,
    promoted_to_ap, low_a_pa, gcoba, barrel_pct, slg, n_lowa_seasons
FROM (
    SELECT
        0 AS grp, draft_year AS dy_sort, overall_pick AS pk_sort,
        CAST(draft_year AS varchar(10))   AS draft_year,
        CAST(overall_pick AS varchar(10)) AS pick,
        player, position, draft_org,
        promoted_to_ap,
        CAST(lowa_pa AS int)             AS low_a_pa,
        CAST(gcoba AS decimal(5,3))      AS gcoba,
        CAST(barrel_pct AS decimal(5,1)) AS barrel_pct,
        CAST(slg AS decimal(5,3))        AS slg,
        CAST(n_lowa_seasons AS int)      AS n_lowa_seasons
    FROM pp
    UNION ALL
    SELECT
        1 AS grp, 999999 AS dy_sort, 999999 AS pk_sort,
        'AVERAGE', NULL, NULL, NULL, NULL,
        NULL,
        CAST(ROUND(AVG(CAST(lowa_pa AS float)), 0) AS int),
        CAST(AVG(gcoba) AS decimal(5,3)),
        CAST(AVG(barrel_pct) AS decimal(5,1)),
        CAST(AVG(slg) AS decimal(5,3)),
        CAST(ROUND(AVG(CAST(n_lowa_seasons AS float)), 0) AS int)
    FROM pp
) x
ORDER BY grp, dy_sort, pk_sort;
