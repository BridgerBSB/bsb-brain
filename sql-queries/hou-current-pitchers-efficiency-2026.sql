/* ============================================================================
   Current Astros pitchers — pitch-efficiency metrics (P/Out, P/PA, P/K, P/BB)
   ----------------------------------------------------------------------------
   Matches the Arm Farm affiliate-tracker definitions:
     P/Out = pitches / outs        (lower = more efficient)
     P/PA  = pitches / batters faced (lower = more efficient)
     P/K   = pitches / strikeouts   (lower = more efficient)
     P/BB  = pitches / walks         (HIGHER = better — walk avoidance)

   Scope: pitchers currently in the HOU org (MLB_eBis.PP_MASTER, active roster,
   pitcher positions), ALL levels incl. MLB, 2026 regular season.

   Sources (mirror the tracker):
     - pitches : COUNT(*) FROM Pitches_View          (pitch_id > 0)
     - BF/SO/BB: Events_View PA stream via cur_event_id (one row per PA)
     - outs    : MLBAM.Gamelog_Pitching (gold; incl. CS/pickoff), with the
                 Events_View PA-outs as a graceful fallback. This is why
                 P/Out matches the app exactly.
   Blank (NULL) when a denominator is 0 (e.g. a pitcher with no walks).
   ============================================================================ */

DECLARE @season int = 2026;

WITH roster AS (              -- current HOU-org pitchers (active roster)
    SELECT DISTINCT
        p.groundcontrol_id AS pitcher_id,
        p.first_name, p.last_name, p.throws
    FROM Astros.Players p
    JOIN MLB_eBis.PP_MASTER pm ON pm.player_id = p.ebis_id
    WHERE LOWER(pm.ORG_LK) = 'hou'
      AND pm.EMPLOYEE_FLG = 0
      AND pm.POSITION_LK IN ('RHS','RHR','LHS','LHR','TWP','SHS','P')
      AND COALESCE(pm.MNROSTERSTATUS_LK, pm.MJROSTERSTATUS_LK)
          NOT IN ('rel','fa','vol','dis','ti','RES','REL','FA','VOL','DIS','TI','res')
    -- For MiLB-only, add:  AND LOWER(pm.LEVELOFPLAY_LK) <> 'ml'
),
pitches AS (                  -- total pitches (tracker n_pitches definition)
    SELECT pv.pitcher_id, COUNT(*) AS n_pitches
    FROM Astros.Pitches_View pv
    JOIN Astros.Schedule_View sv ON pv.sched_id = sv.sched_id
    WHERE sv.level_code IN ('mlb','aaa','aax','afa','afx','rok')  -- 'rok' incl. FCL+DSL+ACL
      AND YEAR(sv.sched_date) = @season
      AND sv.sched_type = 'R'
      AND pv.pitch_id > 0
    GROUP BY pv.pitcher_id
),
pa AS (                       -- PA outcomes (one ev row per PA via cur_event_id)
    SELECT pv.pitcher_id,
        SUM(CAST(ev.pa AS int)) + SUM(CAST(ISNULL(ev.ibb,0) AS int)) AS bf,
        SUM(CAST(ev.so AS int))                                      AS so,
        SUM(CAST(ev.bb AS int))                                      AS bb,
        SUM(CAST(ev.outs_after AS int) - CAST(ev.outs_before AS int)) AS pa_outs,
        -- pitches thrown IN the K-ending / BB-ending PAs (pv = PA-final pitch,
        -- ab_pitch_number 1-indexed = that PA's pitch count). Numerators for
        -- P/K, P/BB per Sean Buchanan: only pitches in the specific K/BB PAs.
        SUM(CASE WHEN CAST(ev.so AS int)=1 THEN ISNULL(pv.ab_pitch_number,0) ELSE 0 END) AS pitches_in_k_pa,
        SUM(CASE WHEN CAST(ev.bb AS int)=1 THEN ISNULL(pv.ab_pitch_number,0) ELSE 0 END) AS pitches_in_bb_pa
    FROM Astros.Events_View ev
    JOIN Astros.Pitches_View pv
        ON ev.sched_id = pv.sched_id AND ev.event_id = pv.cur_event_id
    JOIN Astros.Schedule_View sv ON pv.sched_id = sv.sched_id
    WHERE sv.level_code IN ('mlb','aaa','aax','afa','afx','rok')
      AND YEAR(sv.sched_date) = @season
      AND sv.sched_type = 'R'
      AND pv.pitch_id > 0
      AND (CAST(ev.pa AS int) = 1 OR CAST(ISNULL(ev.ibb,0) AS int) = 1)
    GROUP BY pv.pitcher_id
),
gl AS (                       -- gold-standard outs (incl. CS / pickoff)
    SELECT p.groundcontrol_id AS pitcher_id, SUM(glp.outs) AS gamelog_outs
    FROM MLBAM.Gamelog_Pitching glp
    JOIN Astros.Schedule_View sv ON sv.mlbam_game_pk = glp.game_pk
    JOIN Astros.Players p ON p.mlbam_id = glp.player_id
    WHERE sv.level_code IN ('mlb','aaa','aax','afa','afx','rok')
      AND YEAR(sv.sched_date) = @season
      AND sv.sched_type = 'R'
    GROUP BY p.groundcontrol_id
)
SELECT
    r.first_name + ' ' + r.last_name              AS pitcher,
    r.throws,
    pit.n_pitches                                 AS pitches,
    ISNULL(gl.gamelog_outs, pa.pa_outs)           AS outs,
    pa.bf, pa.so, pa.bb,
    CAST(CAST(pit.n_pitches AS float)    / NULLIF(ISNULL(gl.gamelog_outs, pa.pa_outs), 0) AS DECIMAL(5,1)) AS p_per_out,
    CAST(CAST(pit.n_pitches AS float)    / NULLIF(pa.bf, 0)                               AS DECIMAL(5,1)) AS p_per_pa,
    -- P/K, P/BB: pitches in the K/BB PAs only (NOT total pitches), 1 decimal
    CAST(CAST(pa.pitches_in_k_pa AS float)  / NULLIF(pa.so, 0)                            AS DECIMAL(5,1)) AS p_per_k,
    CAST(CAST(pa.pitches_in_bb_pa AS float) / NULLIF(pa.bb, 0)                            AS DECIMAL(5,1)) AS p_per_bb
FROM roster r
JOIN pitches pit ON pit.pitcher_id = r.pitcher_id   -- only pitchers who threw in @season
LEFT JOIN pa ON pa.pitcher_id = r.pitcher_id
LEFT JOIN gl ON gl.pitcher_id = r.pitcher_id
-- Optional noise filter:  WHERE pit.n_pitches >= 100
ORDER BY pit.n_pitches DESC;   -- workhorses first; re-sort by p_per_pa etc. as you like
