-- =============================================================================
-- PAA/EO Exclusions Audit — find plays that may unfairly penalize HOU IF fielders
-- =============================================================================
-- Use case: Tommy Sacco (gcid 82035) is showing worse PAA/EO than expected in
-- 2026 R games. Hypothesis: he's getting negative PAA contributions from plays
-- that weren't actually his to make — specifically:
--   1. "singles on a ground ball to pitcher" — pitcher-fielded plays where
--      adjacent IF fielders' DCBP rows may still carry out_prob > 0
--   2. "deflected by" — plays where a ball's trajectory changed mid-play
--      and the model's out_prob assignment may over-credit a non-actor fielder
--   3. "missed catch" — plays where a fielder attempted and failed a catch;
--      model may penalize adjacent fielders too
--   4. "singles on a soft bunt ground ball to pitcher" — bunt plays where
--      pitcher recovers; IF fielders still get out_prob attribution
--
-- Output: one row per HOU-org fielder per matching event, showing:
--   - play_by_play text + event result
--   - first defender (who the model actually assigned the play to)
--   - this fielder's DCBP contribution (out_prob, paa, positional, cp, ct)
--   - is_sacco flag so you can filter to his rows quickly
--   - video URL: angle A with angle M fallback (Astros-side → MLBAM-side)
--
-- To look at ONLY Sacco's rows: add `AND pg.groundcontrol_id = 82035` to WHERE
-- To see who else was on-field: run as-is (all HOU org fielders)
-- =============================================================================

SELECT
    -- Game context
    sv.sched_date,
    sv.level_code,
    sv.gc2_level_code,
    sv.sched_type,
    ev.sched_id,
    ev.event_id,
    ev.inning,
    LEFT(ev.play_by_play, 250) AS play_by_play,
    ev.event_result,

    -- First defender (who the model assigned the play to)
    ev.first_defender_id,
    fd.first_name + ' ' + fd.last_name AS first_defender_name,
    fd_pg.pos_id AS first_defender_pos_id,
    CASE fd_pg.pos_id WHEN 1 THEN 'P' WHEN 2 THEN 'C' WHEN 3 THEN '1B'
                      WHEN 4 THEN '2B' WHEN 5 THEN '3B' WHEN 6 THEN 'SS'
                      WHEN 7 THEN 'LF' WHEN 8 THEN 'CF' WHEN 9 THEN 'RF'
                      END AS first_defender_pos,

    -- This fielder (row-per-HOU-fielder-on-field)
    pg.pos_id AS fielder_pos_id,
    CASE pg.pos_id WHEN 1 THEN 'P' WHEN 2 THEN 'C' WHEN 3 THEN '1B'
                   WHEN 4 THEN '2B' WHEN 5 THEN '3B' WHEN 6 THEN 'SS'
                   WHEN 7 THEN 'LF' WHEN 8 THEN 'CF' WHEN 9 THEN 'RF'
                   END AS fielder_pos,
    pg.groundcontrol_id AS fielder_gcid,
    p.first_name + ' ' + p.last_name AS fielder_name,
    CASE WHEN pg.groundcontrol_id = 82035 THEN 1 ELSE 0 END AS is_sacco,

    -- DCBP contribution for this fielder on this play
    CAST(dcbp.positional AS int) AS is_positional,        -- 1 = first defender per model
    CAST(dcbp.out_made AS int)   AS out_made,
    dcbp.out_prob,                                         -- model's probability this fielder makes the out
    dcbp.paa,                                              -- plays above avg (positive = good, negative = bad)
    dcbp.drv,                                              -- damage/run value of this play
    CAST(ISNULL(dcbp.competitive_play, 0) AS int)  AS dcbp_cp,
    CAST(ISNULL(dcbp.competitive_throw, 0) AS int) AS dcbp_ct,

    -- Hit context (what the ball did)
    h.hit_exit_speed,
    h.hit_distance,
    h.hit_bearing,
    h.hit_hangtime,

    -- Video: angle A with angle M fallback
    ISNULL(vn_A.video_url, vn_M.video_url) AS video_url,
    vn_A.video_url AS video_a,
    vn_M.video_url AS video_m

FROM Astros.Events_View ev

-- Scope to HOU org, 2026 R games
INNER JOIN Astros.Schedule_View sv
    ON ev.sched_id = sv.sched_id

-- One row per HOU-org fielder on the field for this game
INNER JOIN Astros.Players_Games pg
    ON ev.sched_id = pg.sched_id
    AND pg.pos_id <> 0
INNER JOIN Astros.Players p
    ON pg.groundcontrol_id = p.groundcontrol_id
INNER JOIN MLB_eBis.PP_MASTER pm
    ON p.ebis_id = pm.player_id
    AND pm.ORG_LK = 'hou'

-- DCBP row per (event, fielder, position) — may be NULL if model didn't score this fielder
LEFT JOIN Astros.Defense_Combined_By_Pos dcbp
    ON ev.sched_id = dcbp.sched_id
    AND ev.event_id = dcbp.event_id
    AND pg.pos_id = dcbp.pos_id
    AND pg.groundcontrol_id = dcbp.groundcontrol_id

-- First defender info
LEFT JOIN Astros.Players fd
    ON ev.first_defender_id = fd.groundcontrol_id
LEFT JOIN Astros.Players_Games fd_pg
    ON ev.sched_id = fd_pg.sched_id
    AND ev.first_defender_id = fd_pg.groundcontrol_id
    AND fd_pg.pos_id <> 0

-- Pitches_View bridge for pitch_id → video
LEFT JOIN Astros.Pitches_View pv
    ON ev.sched_id = pv.sched_id
    AND ev.event_id = pv.cur_event_id
    AND pv.pitch_id > 0
    AND pv.pitch_result_id IN (12, 13, 14)   -- in-play / HR / grounder / etc

-- Hit data
LEFT JOIN Astros.Hits h
    ON pv.sched_id = h.sched_id
    AND pv.pitch_id = h.pitch_id

-- Video angles A (Astros-side) and M (MLBAM-side)
LEFT JOIN Astros.Video_Network vn_A
    ON pv.sched_id = vn_A.sched_id
    AND pv.pitch_id = vn_A.pitch_id
    AND vn_A.angle = 'A'
LEFT JOIN Astros.Video_Network vn_M
    ON pv.sched_id = vn_M.sched_id
    AND pv.pitch_id = vn_M.pitch_id
    AND vn_M.angle = 'M'

WHERE sv.year = 2026
  AND sv.sched_type = 'R'
  -- Exclude junk levels (winter ball, rehab, DSL-2 — matches GC2 SQL)
  AND sv.gc2_level_id NOT IN ('14', '6', '22', '8', '23')
  -- Match any of the four description patterns
  AND (
      ev.play_by_play LIKE '%singles on a ground ball to pitcher%'
      OR ev.play_by_play LIKE '%singles on a soft bunt ground ball to pitcher%'
      OR ev.play_by_play LIKE '%deflected by%'
      OR ev.play_by_play LIKE '%missed catch%'
  )

ORDER BY
    sv.sched_date DESC,
    ev.sched_id,
    ev.event_id,
    -- Sacco's rows first within each event for quick scanning
    CASE WHEN pg.groundcontrol_id = 82035 THEN 0 ELSE 1 END,
    pg.pos_id
OPTION (RECOMPILE);


-- =============================================================================
-- USAGE NOTES
-- =============================================================================
-- Sacco-only view: add `AND pg.groundcontrol_id = 82035` to the WHERE clause
-- to see ONLY his DCBP rows (one row per matching event where he was on-field).
--
-- Column interpretation for "was Sacco penalized?":
--   - is_positional = 0 AND |paa| > 0.05 → Sacco got non-trivial PAA attribution
--     on a play he wasn't the first defender on. Potentially unfair penalty.
--   - is_positional = 1 AND paa < 0 on a "deflected by" play → model assigned
--     him as first defender but ball was deflected; unlikely fair.
--   - out_prob > 0.1 on "singles on a ground ball to pitcher" → model thinks
--     Sacco had real shot at the ball but pitcher got it first; strange.
--
-- Aggregate the PAA penalty from these plays:
--   SELECT SUM(dcbp.paa) AS total_sacco_paa_from_these_plays
--   FROM <above query> WHERE fielder_gcid = 82035;
--
-- Compare against his season PAA to see how much of it came from these edge cases.
-- =============================================================================
