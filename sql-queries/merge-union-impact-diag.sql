-- =====================================================================
-- Merge-Union Pattern — Impact Diagnostic
-- =====================================================================
-- Shows exactly which orgs were being silently dropped by the old
-- `df = primary.copy()` pattern vs the new union pattern.
--
-- For each org at a given level/season:
--   old_pattern_visible: did this org appear pre-fix? (only if primary
--                        frame had data for it)
--   new_pattern_visible: will it appear post-fix? (if ANY frame had data)
--   impact:              "BUG FIX" = silently dropped pre-fix
--                        "unchanged" = was already appearing
--
-- Swap @season / @level / @end_date as needed. For DSL pass 'dsl'.
-- =====================================================================

DECLARE @season INT = 2026;
DECLARE @level VARCHAR(10) = 'rok';            -- 'rok' (FCL), 'dsl', 'aaa', 'aax', 'afa', 'afx', 'mlb'
DECLARE @end_date DATE = '2026-05-10';


-- =====================================================================
-- DIAGNOSTIC 1 — BR (highest real-world impact)
-- =====================================================================
-- Compares: Events_View SB/CS (universal) vs PBL leads (HawkEye-only).
-- An org listed with "BUG FIX" was producing SBs that the old pattern
-- silently hid because the org had no PBL row.

WITH events_orgs AS (
    SELECT
        UPPER(mt.org_abbrev) AS org,
        SUM(CASE WHEN ev.event_result_id IN (42, 43, 44) THEN 1 ELSE 0 END) AS sb_total,
        SUM(CASE WHEN ev.event_result_id IN (4, 5, 6, 7, 29, 30, 31) THEN 1 ELSE 0 END) AS cs_total
    FROM Astros.Events_View ev
    JOIN Astros.Schedule_View sv ON ev.sched_id = sv.sched_id
    JOIN MLBAM.Teams mt ON mt.team_id = ev.batting_team_id AND mt.season = sv.year
    WHERE (ev.sb = 1 OR ev.cs = 1)
      AND ((sv.level_code = @level AND @level NOT IN ('dsl','rok'))
           OR (sv.gc2_level_code = @level AND @level IN ('dsl','rok')))
      AND sv.year = @season
      AND CAST(sv.sched_date AS DATE) <= @end_date
      AND sv.sched_type = 'R'
    GROUP BY UPPER(mt.org_abbrev)
),
leads_orgs AS (
    SELECT
        UPPER(mt.org_abbrev) AS org,
        COUNT(*) AS n_lead_pitches,
        SUM(CASE WHEN pbl.occupied_base = 1 THEN 1 ELSE 0 END) AS n_1b_leads
    FROM Astros.Pitches_Baserunner_Leads pbl
    JOIN Astros.Pitches_View pv
        ON pv.sched_id = pbl.sched_id AND pv.pitch_id = pbl.pitch_id
    JOIN Astros.Events_View ev
        ON ev.sched_id = pv.sched_id AND ev.event_id = pv.ab_event_id
    JOIN Astros.Schedule_View sv ON pv.sched_id = sv.sched_id
    JOIN MLBAM.Teams mt ON mt.team_id = ev.batting_team_id AND mt.season = sv.year
    WHERE pbl.ignore_flag = 0
      AND pv.pitch_id > 0
      AND ((sv.level_code = @level AND @level NOT IN ('dsl','rok'))
           OR (sv.gc2_level_code = @level AND @level IN ('dsl','rok')))
      AND sv.year = @season
      AND CAST(sv.sched_date AS DATE) <= @end_date
      AND sv.sched_type = 'R'
    GROUP BY UPPER(mt.org_abbrev)
),
all_orgs AS (
    SELECT org FROM events_orgs
    UNION
    SELECT org FROM leads_orgs
)
SELECT
    'BR' AS domain,
    a.org,
    ISNULL(e.sb_total, 0)        AS sb,
    ISNULL(e.cs_total, 0)        AS cs,
    ISNULL(l.n_lead_pitches, 0)  AS n_lead_pitches,
    ISNULL(l.n_1b_leads, 0)      AS n_1b_leads,
    CASE WHEN l.org IS NOT NULL THEN 'visible'
         ELSE 'DROPPED'
    END AS old_pattern,
    'visible' AS new_pattern,
    CASE
        WHEN e.org IS NOT NULL AND l.org IS NULL
            THEN 'BUG FIX — restored ' + CAST(ISNULL(e.sb_total,0) AS varchar) + ' SB / '
                                       + CAST(ISNULL(e.cs_total,0) AS varchar) + ' CS'
        WHEN e.org IS NOT NULL AND l.org IS NOT NULL THEN 'unchanged'
        WHEN e.org IS NULL AND l.org IS NOT NULL THEN 'leads only — unchanged (no SB events)'
        ELSE 'no data'
    END AS impact
FROM all_orgs a
LEFT JOIN events_orgs e ON e.org = a.org
LEFT JOIN leads_orgs  l ON l.org = a.org
ORDER BY
    CASE WHEN l.org IS NULL AND e.org IS NOT NULL THEN 0 ELSE 1 END,  -- dropped orgs first
    a.org;


-- =====================================================================
-- DIAGNOSTIC 2 — OF/IF (defensive — should rarely show "BUG FIX")
-- =====================================================================
-- Compares: TDM tracking (Tier 1 6-term gate) vs DCBP value (broader).
-- An org with "BUG FIX" had DCBP rows (out_made / paa) but zero plays
-- passing the Tier 1 gate. In practice this almost never fires.

WITH tdm_orgs AS (
    SELECT
        UPPER(mt.org_abbrev) AS org,
        COUNT(*) AS n_tier1_plays
    FROM Astros.Tracking_Defensive_Metrics tdm
    JOIN Astros.Schedule_View sv ON tdm.sched_id = sv.sched_id
    JOIN Astros.Events_View ev
        ON tdm.sched_id = ev.sched_id AND tdm.event_id = ev.event_id
    JOIN MLBAM.Teams mt ON mt.team_id = ev.fielding_team_id AND mt.season = sv.year
    LEFT JOIN Astros.Defense_Combined_By_Pos dcbp
        ON tdm.sched_id = dcbp.sched_id AND tdm.event_id = dcbp.event_id
        AND tdm.pos_id = dcbp.pos_id AND tdm.groundcontrol_id = dcbp.groundcontrol_id
    WHERE tdm.pos_id IN (3, 4, 5, 6, 7, 8, 9)
      AND ((sv.level_code = @level AND @level NOT IN ('dsl','rok'))
           OR (sv.gc2_level_code = @level AND @level IN ('dsl','rok')))
      AND sv.year = @season
      AND CAST(sv.sched_date AS DATE) <= @end_date
      AND sv.sched_type = 'R'
      AND (CAST(ISNULL(dcbp.out_made, 0) AS int)
           + CAST(ISNULL(dcbp.competitive_play, 0) AS int)
           + CAST(ISNULL(dcbp.competitive_throw, 0) AS int)
           + CAST(ISNULL(tdm.competitive_play, 0) AS int)
           + CAST(ISNULL(tdm.competitive_throw, 0) AS int)
           + CASE WHEN tdm.arm_strength >= 70 THEN 1 ELSE 0 END) > 0
    GROUP BY UPPER(mt.org_abbrev)
),
dcbp_orgs AS (
    SELECT
        UPPER(mt.org_abbrev) AS org,
        COUNT(*) AS n_dcbp_rows,
        SUM(CAST(ISNULL(dcbp.out_made, 0) AS int)) AS outs_made
    FROM Astros.Defense_Combined_By_Pos dcbp
    JOIN Astros.Schedule_View sv ON dcbp.sched_id = sv.sched_id
    JOIN Astros.Events_View ev
        ON dcbp.sched_id = ev.sched_id AND dcbp.event_id = ev.event_id
    JOIN MLBAM.Teams mt ON mt.team_id = ev.fielding_team_id AND mt.season = sv.year
    WHERE dcbp.pos_id IN (3, 4, 5, 6, 7, 8, 9)
      AND ((sv.level_code = @level AND @level NOT IN ('dsl','rok'))
           OR (sv.gc2_level_code = @level AND @level IN ('dsl','rok')))
      AND sv.year = @season
      AND CAST(sv.sched_date AS DATE) <= @end_date
      AND sv.sched_type = 'R'
    GROUP BY UPPER(mt.org_abbrev)
),
all_field_orgs AS (
    SELECT org FROM tdm_orgs
    UNION
    SELECT org FROM dcbp_orgs
)
SELECT
    'OF/IF' AS domain,
    a.org,
    ISNULL(t.n_tier1_plays, 0)  AS n_tier1_plays,
    ISNULL(d.n_dcbp_rows, 0)    AS n_dcbp_rows,
    ISNULL(d.outs_made, 0)      AS outs_made,
    CASE WHEN t.org IS NOT NULL THEN 'visible'
         ELSE 'DROPPED'
    END AS old_pattern,
    'visible' AS new_pattern,
    CASE
        WHEN d.org IS NOT NULL AND t.org IS NULL
            THEN 'BUG FIX — restored ' + CAST(ISNULL(d.outs_made,0) AS varchar) + ' outs (OAA basis)'
        WHEN t.org IS NOT NULL AND d.org IS NOT NULL THEN 'unchanged'
        WHEN t.org IS NOT NULL AND d.org IS NULL THEN 'tracking only — unchanged'
        ELSE 'no data'
    END AS impact
FROM all_field_orgs a
LEFT JOIN tdm_orgs  t ON t.org = a.org
LEFT JOIN dcbp_orgs d ON d.org = a.org
ORDER BY
    CASE WHEN t.org IS NULL AND d.org IS NOT NULL THEN 0 ELSE 1 END,
    a.org;


-- =====================================================================
-- DIAGNOSTIC 3 — Catcher (most defensive — should never show "BUG FIX")
-- =====================================================================
-- Compares: Pitches_View framing data (universal) vs SBA events.
-- Pitches_View is universal, so this almost never fires. Included for
-- completeness.

WITH pv_catcher_orgs AS (
    SELECT
        UPPER(mt.org_abbrev) AS org,
        COUNT(*) AS n_called_pitches
    FROM Astros.Pitches_View pv
    JOIN Astros.Schedule_View sv ON pv.sched_id = sv.sched_id
    JOIN Astros.Events_View ev
        ON pv.sched_id = ev.sched_id AND pv.ab_event_id = ev.event_id
    JOIN MLBAM.Teams mt ON mt.team_id = ev.fielding_team_id AND mt.season = sv.year
    WHERE pv.pitch_result_id IN (4, 5, 6)
      AND pv.pitch_id > 0
      AND pv.ignore_flag = 0
      AND ((sv.level_code = @level AND @level NOT IN ('dsl','rok'))
           OR (sv.gc2_level_code = @level AND @level IN ('dsl','rok')))
      AND sv.year = @season
      AND CAST(sv.sched_date AS DATE) <= @end_date
      AND sv.sched_type = 'R'
    GROUP BY UPPER(mt.org_abbrev)
),
sba_orgs AS (
    SELECT
        UPPER(mt.org_abbrev) AS org,
        SUM(CASE WHEN ev.event_result_id IN (42, 43, 44) THEN 1 ELSE 0 END) AS sb_against,
        SUM(CASE WHEN ev.event_result_id IN (4, 5, 6, 7, 29, 30, 31) THEN 1 ELSE 0 END) AS cs_caught
    FROM Astros.Events_View ev
    JOIN Astros.Schedule_View sv ON ev.sched_id = sv.sched_id
    JOIN MLBAM.Teams mt ON mt.team_id = ev.fielding_team_id AND mt.season = sv.year
    WHERE (ev.sb = 1 OR ev.cs = 1)
      AND ((sv.level_code = @level AND @level NOT IN ('dsl','rok'))
           OR (sv.gc2_level_code = @level AND @level IN ('dsl','rok')))
      AND sv.year = @season
      AND CAST(sv.sched_date AS DATE) <= @end_date
      AND sv.sched_type = 'R'
    GROUP BY UPPER(mt.org_abbrev)
),
all_c_orgs AS (
    SELECT org FROM pv_catcher_orgs
    UNION
    SELECT org FROM sba_orgs
)
SELECT
    'Catcher' AS domain,
    a.org,
    ISNULL(p.n_called_pitches, 0) AS n_called_pitches,
    ISNULL(s.sb_against, 0)       AS sb_against,
    ISNULL(s.cs_caught, 0)        AS cs_caught,
    CASE WHEN p.org IS NOT NULL THEN 'visible'
         ELSE 'DROPPED'
    END AS old_pattern,
    'visible' AS new_pattern,
    CASE
        WHEN s.org IS NOT NULL AND p.org IS NULL
            THEN 'BUG FIX — restored ' + CAST(ISNULL(s.sb_against,0) AS varchar) + ' SB / '
                                       + CAST(ISNULL(s.cs_caught,0) AS varchar) + ' CS'
        WHEN p.org IS NOT NULL AND s.org IS NOT NULL THEN 'unchanged'
        WHEN p.org IS NOT NULL AND s.org IS NULL THEN 'pitches only — unchanged'
        ELSE 'no data'
    END AS impact
FROM all_c_orgs a
LEFT JOIN pv_catcher_orgs p ON p.org = a.org
LEFT JOIN sba_orgs        s ON s.org = a.org
ORDER BY
    CASE WHEN p.org IS NULL AND s.org IS NOT NULL THEN 0 ELSE 1 END,
    a.org;
