-- =========================================================================
-- Org SRV × FB Velo — pooled across AAA/AA/A+/A, per year (2025 + 2026)
-- =========================================================================
-- One row per (org, season). 30 orgs × 2 years = 60 rows.
--
-- Pooled aggregation across the 4 upper MiLB levels (matches PD Goals org
-- KPI pool semantics — every pitch from any of the 4 levels counts equally).
--
-- - FB Velo: AVG(release_speed) on FF/FT/SI pitches (matches gc2-metrics.md
--   FB Velo standard — SI included).
-- - SRV: AVG(stuffrelvel_grade_2080) across every graded pitch (any pitch
--   type — SRV is the universal stuff grade per `db-columns.md`).
-- - n_pitches / n_pitchers / n_fb / n_srv: sample sizes per axis, in case
--   we need to gate or annotate dots in the chart.
--
-- Org-code canon: OAK ⇄ ATH collapsed to single canonical 'ATH'
-- (`rules/org-codes.md` cross-source rule — MLBAM.Teams.org_abbrev is the
-- only source here so single-side CASE suffices).
--
-- Driver: Pitches_View (every pitch) → Events_View on ab_event_id (NOT
-- cur_event_id — `rules/db-joins.md` dual-join pattern, ab_event_id is the
-- always-populated key) → MLBAM.Teams on fielding_team_id for org.
-- =========================================================================

SELECT
    CASE UPPER(t.org_abbrev)
        WHEN 'OAK' THEN 'ATH'
        ELSE UPPER(t.org_abbrev)
    END                                                              AS org,
    sv.year                                                          AS season,
    AVG(CASE WHEN pv.pitch_type IN ('FF', 'FT', 'SI')
             THEN pv.release_speed END)                              AS fb_velo,
    AVG(CAST(pv.stuffrelvel_grade_2080 AS float))                    AS srv,
    COUNT(CASE WHEN pv.pitch_type IN ('FF', 'FT', 'SI')
               THEN 1 END)                                           AS n_fb,
    COUNT(pv.stuffrelvel_grade_2080)                                 AS n_srv,
    COUNT(*)                                                         AS n_pitches,
    COUNT(DISTINCT pv.pitcher_id)                                    AS n_pitchers
FROM Astros.Pitches_View pv
JOIN Astros.Schedule_View sv
    ON pv.sched_id = sv.sched_id
JOIN Astros.Events_View ev
    ON pv.sched_id = ev.sched_id
   AND pv.ab_event_id = ev.event_id
JOIN MLBAM.Teams t
    ON t.team_id = ev.fielding_team_id
   AND t.season = sv.year
WHERE sv.level_code IN ('aaa', 'aax', 'afa', 'afx')
  AND sv.sched_type = 'R'
  AND sv.year IN (2025, 2026)
  AND pv.pitch_id > 0
GROUP BY
    CASE UPPER(t.org_abbrev)
        WHEN 'OAK' THEN 'ATH'
        ELSE UPPER(t.org_abbrev)
    END,
    sv.year
ORDER BY sv.year, org;
