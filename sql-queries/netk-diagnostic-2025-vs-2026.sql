-- NetK diagnostic — May 10 2026
-- =================================
-- Purpose: troubleshoot why drift_catcher.py returned zero flags despite
-- gate of ≥500 edge pitches.
--
-- Output: one row per HOU MiLB catcher who caught pitches in either
-- 2025 or 2026. Shows total pitches caught, edge pitches (the drift gate
-- denominator), and cumulative NetK for each year.
--
-- Filter mirrors drift_catcher.py exactly:
--   - sched_type = 'R' (regular season only)
--   - level_code != 'mlb' (MiLB only)
--   - level_code NOT IN junk list (no BBC / WIN / IND / etc.)
--   - pv.pitch_id > 0
--   - HOU org via fielding_team_id → MLBAM.Teams.org_abbrev
--
-- Edge pitch definition (gc2-metrics.md NetK rules):
--   pv.called_strike_chance > 0.05 AND < 0.95   -- borderline zone
--   AND pv.pitch_result_id IN (4, 5, 6)         -- called Ball/Ball-in-Dirt/Strike
--   AND pv.ignore_flag = 0
--
-- NOTE: this query does NOT apply the PP_MASTER active-roster filter —
-- shows EVERY catcher who caught for HOU MiLB in those seasons, including
-- released / traded / former players. Useful for sanity-checking the
-- drift module's roster gate (if a catcher appears here with 1000+ 2026
-- edge pitches and big NetK delta but drift returned zero flags, the
-- roster filter is dropping them — check PP_MASTER status).
--
-- Diagnostic columns:
--   ep_2025 / ep_2026          → edge pitch count per year (= week_netk_n in drift)
--   netk_2025 / netk_2026      → cumulative SUM(net_k) per year
--   delta                       → 2026 NetK minus 2025 NetK
--   total_2025 / total_2026    → ALL pitches caught (not just edge) — sanity check
--   gate_500_2026               → 1 if 2026 edge pitches ≥ 500 (would clear drift gate)
--   would_flag                  → 1 if abs(delta) >= 5.0 AND gate_500_2026 = 1

WITH catcher_pitches AS (
    SELECT
        ev.c_id AS catcher_id,
        sv.year,
        CASE WHEN pv.called_strike_chance > 0.05
              AND pv.called_strike_chance < 0.95
              AND pv.pitch_result_id IN (4, 5, 6)
              AND pv.ignore_flag = 0
             THEN 1 ELSE 0 END                                 AS is_edge,
        CASE WHEN pv.called_strike_chance > 0.05
              AND pv.called_strike_chance < 0.95
              AND pv.pitch_result_id IN (4, 5, 6)
              AND pv.ignore_flag = 0
             THEN pv.net_k ELSE 0.0 END                        AS netk_contrib
    FROM Astros.Pitches_View pv
    JOIN Astros.Events_View ev
        ON ev.sched_id = pv.sched_id AND ev.event_id = pv.ab_event_id
    JOIN Astros.Schedule_View sv ON pv.sched_id = sv.sched_id
    JOIN MLBAM.Teams pt
        ON ev.fielding_team_id = pt.team_id AND pt.season = sv.year
    WHERE sv.year IN (2025, 2026)
      AND sv.sched_type = 'R'
      AND pt.org_abbrev = 'HOU'
      AND sv.level_code != 'mlb'
      AND sv.level_code NOT IN ('win','bbc','int','sum','nae','hsb','ind','jcb')
      AND pv.pitch_id > 0
      AND ev.c_id IS NOT NULL
)
SELECT
    cp.catcher_id,
    CONCAT(p.first_name, ' ', p.last_name) AS catcher_name,
    -- 2025 totals
    SUM(CASE WHEN cp.year = 2025 THEN 1 ELSE 0 END)            AS total_2025,
    SUM(CASE WHEN cp.year = 2025 THEN cp.is_edge ELSE 0 END)   AS ep_2025,
    ROUND(SUM(CASE WHEN cp.year = 2025
                   THEN cp.netk_contrib ELSE 0 END), 2)         AS netk_2025,
    -- 2026 totals
    SUM(CASE WHEN cp.year = 2026 THEN 1 ELSE 0 END)            AS total_2026,
    SUM(CASE WHEN cp.year = 2026 THEN cp.is_edge ELSE 0 END)   AS ep_2026,
    ROUND(SUM(CASE WHEN cp.year = 2026
                   THEN cp.netk_contrib ELSE 0 END), 2)         AS netk_2026,
    -- Delta + flag check
    ROUND(SUM(CASE WHEN cp.year = 2026
                   THEN cp.netk_contrib ELSE 0 END)
        - SUM(CASE WHEN cp.year = 2025
                   THEN cp.netk_contrib ELSE 0 END), 2)         AS delta,
    CASE WHEN SUM(CASE WHEN cp.year = 2026 THEN cp.is_edge ELSE 0 END) >= 500
         THEN 1 ELSE 0 END                                     AS clears_gate_500,
    CASE WHEN ABS(SUM(CASE WHEN cp.year = 2026
                           THEN cp.netk_contrib ELSE 0 END)
              - SUM(CASE WHEN cp.year = 2025
                           THEN cp.netk_contrib ELSE 0 END)) >= 5.0
          AND SUM(CASE WHEN cp.year = 2026 THEN cp.is_edge ELSE 0 END) >= 500
         THEN 1 ELSE 0 END                                     AS would_flag_at_500,
    -- Roster status check (does PP_MASTER think they're still HOU active?)
    pm.LEVELOFPLAY_LK                                          AS pm_level,
    pm.ORG_LK                                                  AS pm_org,
    COALESCE(pm.MNROSTERSTATUS_LK, pm.MJROSTERSTATUS_LK)       AS roster_status
FROM catcher_pitches cp
LEFT JOIN Astros.Players p ON p.groundcontrol_id = cp.catcher_id
LEFT JOIN MLB_eBis.PP_MASTER pm ON pm.player_id = p.ebis_id
GROUP BY cp.catcher_id, p.first_name, p.last_name,
         pm.LEVELOFPLAY_LK, pm.ORG_LK,
         pm.MNROSTERSTATUS_LK, pm.MJROSTERSTATUS_LK
ORDER BY ABS(SUM(CASE WHEN cp.year = 2026 THEN cp.netk_contrib ELSE 0 END)
           - SUM(CASE WHEN cp.year = 2025 THEN cp.netk_contrib ELSE 0 END)) DESC;
