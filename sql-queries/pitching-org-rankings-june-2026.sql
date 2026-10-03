-- Pitching org rankings — MONTH OF JUNE 2026 (DJ / pitching coordinator request)
-- =====================================================================
-- Six dev metrics per org (all 30 MLB orgs), five ranking scopes:
--   Scope 1  AAA        (level_code = 'aaa')
--   Scope 2  AA         (level_code = 'aax')
--   Scope 3  A+         (level_code = 'afa')
--   Scope 4  A          (level_code = 'afx')
--   Scope 5  All MiLB (DSL–AAA)  pooled: aaa+aax+afa+afx+rok  (rok = FCL + DSL)
--
-- METRICS — ported VERBATIM from the LIVE canonical pitching org query
--   pd-goals/src/org_kpi_data.py::_PITCHING_ORG_QUERY  (+ _compute_gcera_org
--   for gcERA, + _get_league_hr_rate for the MLB HR-rate scalar). Same filters,
--   same GC2 formulas, same per-PA org attribution — just windowed to June.
--     * FPinZ% (0-0 InZone) = AVG(called_strike_chance_mlb) over 0-0 pitches × 100
--     * InZone%             = AVG(called_strike_chance_mlb) over all pitches × 100
--     * R2K%   = GC2 formula: on pitch 3, strikes_after>=2, excluding PAs that
--                ended on pitch 3 with non-K contact (denom = pa=0 OR so=1)
--     * K%     = 100 * SO / BF        (BF = PA incl. IBB)
--     * BB%    = 100 * BB / BF        (BB includes IBB per schema)
--     * gcERA  = (3.9 + 31.1*MLB_HR_rate)*bip_rate*pBrl + 3.5*bip_rate*(1-pBrl)
--                - 3.3*so_rate + 9.9*bb_hbp_rate    (BF/BB use NON-IBB counts)
--                pBrl = pbarrel/tracked_bip; tracked_bip = GC2 codes (12,13,14),
--                EV<125, bunt-excluded, NO EV>0 filter (matches GC2 HitsNoBunts).
--
-- ORG ATTRIBUTION: per-PA via top_of_inning -> pitching (fielding) team ->
--   mlbam.teams.org_abbrev. A mid-June-traded pitcher's June PAs land in the
--   org that actually had him at each game (no majority-org collapse).
--
-- RANK DIRECTION (rk columns, 1 = best within scope):
--   FPinZ% / InZone% / R2K% / K%  -> higher is better (DESC)
--   BB% / gcERA                   -> lower is better  (ASC)
--   NOTE: InZone%/FPinZ% ranks read as "most in-zone"; higher isn't strictly
--   "better" for a staff (can mean more hittable) — interpret with the value.
--
-- Values rounded at display only (ranks computed on full precision).
-- `bf` (batters faced) shown so you can judge sample — June DSL/FCL is early-
-- season, so pooled DSL volume is light. No min-BF gate applied.
-- Change @season / @start / @end below to re-run for another month.
-- =====================================================================

DECLARE @season int  = 2026;
DECLARE @start  date = '2026-06-01';
DECLARE @end    date = '2026-06-30';

WITH hr_rate AS (
    -- MLB league-wide HR/(HR+AO) for gcERA (GC2 always uses global MLB rate)
    SELECT CAST(hr AS float) / NULLIF(CAST(hr AS float) + CAST(ao AS float), 0) AS hr_rate
    FROM mlbam.ytd_team_pitching_stats
    WHERE team_id = 0 AND split_id = 0 AND gm_type = 'r'
      AND level = 'mlb' AND season = @season
),
pitch_data AS (
    SELECT
        UPPER(mt.org_abbrev) AS org,
        sv.level_code AS lvl,
        -- FPinZ% (0-0 in-zone chance)
        CASE WHEN pv.balls_before = 0 AND pv.strikes_before = 0
             THEN pv.called_strike_chance_mlb END AS fpinz_csc,
        -- InZ% (in-zone chance, all pitches)
        pv.called_strike_chance_mlb AS inz_csc,
        -- R2K% denom/numer (GC2: pitch 3, exclude PA ended pitch-3 non-K contact)
        CASE WHEN pv.ab_pitch_number = 3
                  AND (ISNULL(cev.pa, 0) = 0 OR ISNULL(cev.so, 0) = 1)
             THEN 1 END AS r2k_denom,
        CASE WHEN pv.ab_pitch_number = 3
                  AND (ISNULL(cev.pa, 0) = 0 OR ISNULL(cev.so, 0) = 1)
                  AND pv.strikes_after >= 2
             THEN 1 END AS r2k_numer,
        -- PA-level (only on final pitch of PA via cev = cur_event_id)
        CASE WHEN pv.cur_event_id IS NOT NULL
                  AND (CAST(ISNULL(cev.pa, 0) AS int) = 1 OR CAST(ISNULL(cev.ibb, 0) AS int) = 1)
             THEN 1 ELSE 0 END AS is_pa,
        CASE WHEN pv.cur_event_id IS NOT NULL
                  AND (CAST(ISNULL(cev.pa, 0) AS int) = 1 OR CAST(ISNULL(cev.ibb, 0) AS int) = 1)
                  AND CAST(ISNULL(cev.so, 0) AS int) = 1
             THEN 1 ELSE 0 END AS is_so,
        CASE WHEN pv.cur_event_id IS NOT NULL
                  AND (CAST(ISNULL(cev.pa, 0) AS int) = 1 OR CAST(ISNULL(cev.ibb, 0) AS int) = 1)
                  AND CAST(ISNULL(cev.bb, 0) AS int) = 1
             THEN 1 ELSE 0 END AS is_bb,
        CASE WHEN pv.cur_event_id IS NOT NULL
                  AND (CAST(ISNULL(cev.pa, 0) AS int) = 1 OR CAST(ISNULL(cev.ibb, 0) AS int) = 1)
                  AND CAST(ISNULL(cev.hbp, 0) AS int) = 1
             THEN 1 ELSE 0 END AS is_hbp,
        CASE WHEN pv.cur_event_id IS NOT NULL
                  AND CAST(ISNULL(cev.ibb, 0) AS int) = 1
             THEN 1 ELSE 0 END AS is_ibb,
        -- gcERA components (GC2 BIP codes 12,13,14 only, bunt-excluded, EV<125,
        -- NO EV>0 filter — matches GC2 HitsNoBunts)
        CASE WHEN pv.pitch_result_id IN (12,13,14) THEN 1 ELSE 0 END AS is_bip,
        CASE WHEN pv.pitch_result_id IN (12,13,14)
                  AND h.hit_exit_speed IS NOT NULL
                  AND h.hit_exit_speed < 125
                  AND h.hit_exit_speed >= 0.011 * h.hit_vertical_angle * h.hit_vertical_angle
                                         - 0.91 * h.hit_vertical_angle + 95
                  AND (aev.hit_trajectory_id NOT IN (2,3,4) OR aev.hit_trajectory_id IS NULL)
             THEN 1 ELSE 0 END AS is_pbarrel,
        CASE WHEN pv.pitch_result_id IN (12,13,14)
                  AND h.hit_exit_speed IS NOT NULL
                  AND h.hit_exit_speed < 125
                  AND (aev.hit_trajectory_id NOT IN (2,3,4) OR aev.hit_trajectory_id IS NULL)
             THEN 1 ELSE 0 END AS is_tracked_bip
    FROM Astros.Pitches_View pv
    JOIN Astros.Schedule_View sv ON pv.sched_id = sv.sched_id
    JOIN Astros.Events_View aev
        ON aev.sched_id = pv.sched_id AND aev.event_id = pv.ab_event_id
    LEFT JOIN Astros.Events_View cev
        ON cev.sched_id = pv.sched_id AND cev.event_id = pv.cur_event_id
    LEFT JOIN Astros.Hits h
        ON pv.sched_id = h.sched_id AND pv.pitch_id = h.pitch_id
    JOIN mlbam.teams mt
        ON mt.team_id = CASE
            WHEN aev.top_of_inning = 1 THEN sv.home_team_mlbam_id
            ELSE sv.away_team_mlbam_id END
        AND mt.season = sv.year
    WHERE sv.level_code IN ('aaa','aax','afa','afx','rok')   -- rok = FCL + DSL
      AND sv.year = @season
      AND CAST(sv.sched_date AS DATE) BETWEEN @start AND @end
      AND sv.sched_type = 'R'
      AND sv.level_code NOT IN ('win','bbc','int','sum','nae','hsb','ind','jcb')
      AND pv.pitch_id > 0
),
-- Fan each pitch into its scope(s): its own level table (AAA/AA/A+/A) if a
-- full-season level, PLUS the pooled All-MiLB table (every MiLB pitch).
scoped AS (
    SELECT s.scope, s.scope_ord, pd.*
    FROM pitch_data pd
    CROSS APPLY (VALUES
        (CASE pd.lvl WHEN 'aaa' THEN 'AAA' WHEN 'aax' THEN 'AA'
                     WHEN 'afa' THEN 'A+'  WHEN 'afx' THEN 'A' END,
         CASE pd.lvl WHEN 'aaa' THEN 1 WHEN 'aax' THEN 2
                     WHEN 'afa' THEN 3 WHEN 'afx' THEN 4 END),
        ('All MiLB (DSL-AAA)', 5)
    ) s(scope, scope_ord)
    WHERE s.scope IS NOT NULL
),
agg AS (
    SELECT scope, scope_ord, org,
        SUM(is_pa) AS bf,
        AVG(fpinz_csc) * 100.0 AS fpinz_pct,
        AVG(inz_csc)   * 100.0 AS inz_pct,
        100.0 * AVG(CASE WHEN r2k_denom = 1
                         THEN CASE WHEN r2k_numer = 1 THEN 1.0 ELSE 0.0 END END) AS r2k_pct,
        CASE WHEN SUM(is_pa) > 0 THEN 100.0 * SUM(is_so) / SUM(is_pa) END AS k_pct,
        CASE WHEN SUM(is_pa) > 0 THEN 100.0 * SUM(is_bb) / SUM(is_pa) END AS bb_pct,
        SUM(is_bip)          AS bip_count,
        SUM(is_pbarrel)      AS pbarrel_count,
        SUM(is_tracked_bip)  AS tracked_bip_count,
        SUM(is_so)           AS so_total,
        SUM(is_bb)           AS bb_total,
        SUM(is_hbp)          AS hbp_total,
        SUM(is_ibb)          AS ibb_total
    FROM scoped
    GROUP BY scope, scope_ord, org
),
gcera AS (
    SELECT a.scope, a.scope_ord, a.org, a.bf,
        a.fpinz_pct, a.inz_pct, a.r2k_pct, a.k_pct, a.bb_pct,
        CASE WHEN r0.bf_ni > 0 THEN
            ROUND(
                (3.9 + 31.1 * hr.hr_rate) * r2.bip_rate * r1.pbarrel_rate
                + 3.5 * r2.bip_rate * (1.0 - r1.pbarrel_rate)
                - 3.3 * r1.so_rate
                + 9.9 * r1.bb_hbp_rate
            , 2)
        END AS gc_era
    FROM agg a
    CROSS JOIN hr_rate hr
    CROSS APPLY (VALUES (CAST(a.bf - a.ibb_total AS float))) r0(bf_ni)
    CROSS APPLY (VALUES (
        CASE WHEN r0.bf_ni > 0 THEN a.so_total / r0.bf_ni ELSE 0 END,
        CASE WHEN r0.bf_ni > 0
             THEN ((a.bb_total - a.ibb_total) + a.hbp_total) / r0.bf_ni ELSE 0 END,
        CASE WHEN a.tracked_bip_count > 0
             THEN CAST(a.pbarrel_count AS float) / a.tracked_bip_count ELSE 0 END
    )) r1(so_rate, bb_hbp_rate, pbarrel_rate)
    CROSS APPLY (VALUES (
        CASE WHEN (1.0 - r1.so_rate - r1.bb_hbp_rate) > 0
             THEN 1.0 - r1.so_rate - r1.bb_hbp_rate ELSE 0 END
    )) r2(bip_rate)
)
SELECT
    scope,
    org,
    bf,
    CAST(ROUND(fpinz_pct, 1) AS decimal(5,1)) AS fpinz_0_0_inz_pct,
    RANK() OVER (PARTITION BY scope ORDER BY fpinz_pct DESC) AS fpinz_rk,
    CAST(ROUND(inz_pct, 1) AS decimal(5,1))   AS inz_pct,
    RANK() OVER (PARTITION BY scope ORDER BY inz_pct DESC)   AS inz_rk,
    CAST(ROUND(r2k_pct, 2) AS decimal(6,2))   AS r2k_pct,
    RANK() OVER (PARTITION BY scope ORDER BY r2k_pct DESC)   AS r2k_rk,
    CAST(ROUND(k_pct, 1) AS decimal(5,1))     AS k_pct,
    RANK() OVER (PARTITION BY scope ORDER BY k_pct DESC)     AS k_rk,
    CAST(ROUND(bb_pct, 1) AS decimal(5,1))    AS bb_pct,
    RANK() OVER (PARTITION BY scope ORDER BY bb_pct ASC)     AS bb_rk,
    gc_era,
    RANK() OVER (PARTITION BY scope ORDER BY gc_era ASC)     AS gcera_rk
FROM gcera
ORDER BY scope_ord, org;
