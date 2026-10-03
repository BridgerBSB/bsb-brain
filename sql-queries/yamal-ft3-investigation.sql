-- =============================================================================
-- Yamal Encarnacion 1->3 investigation — Apr 30 2026 AAX game
-- =============================================================================
-- gc_id: 155788
-- Confirmed scenario: bases loaded, Yamal on 1st, batter DOUBLED to LF,
-- Yamal advanced to 3rd. Did NOT count as 1->3 because the metric is
-- single-only (gates `CAST(ev.[1b] AS INT) = 1`).
-- This SQL inspects every event Yamal was a runner on for that game and
-- explicitly prints YES/NO with the failure reason.
--
-- 1->3 metric query (intangibles/src/br_tracker_data.py::_FT3_S2H_QUERY)
-- requires ALL of these to count an opportunity:
--   1. ev.runner_1b IS NOT NULL (Yamal was on 1st)
--   2. CAST(ev.[1b] AS INT) = 1  (batter SINGLED — not doubled, no error, no FC)
--   3. CAST(ev.hr AS INT) = 0
--   4. ev.first_defender_id IN (ev.rf_id, ev.cf_id, ev.lf_id) (OUTFIELD)
-- =============================================================================
--
-- Verified Events_View columns referenced (greppd from intangibles src):
--   ev.event_id, ev.sched_id, ev.event_result_id, ev.fielding_team_id,
--   ev.batting_team_id, ev.first_defender_id, ev.rf_id, ev.cf_id, ev.lf_id,
--   ev.c_id
-- IF / P / SS position-id columns are NOT direct columns on Events_View.
-- To learn the first defender's position, join Astros.Players_Games on
-- (sched_id, groundcontrol_id) and read pg.pos_id.
-- =============================================================================

SELECT
    sv.sched_date,
    sv.level_code,
    ev.event_id,
    ev.inning,
    CASE ev.top_of_inning WHEN 1 THEN 'TOP' ELSE 'BOT' END AS half,
    ev.outs_before,
    ev.outs_after,

    -- Batter outcome flags (this is where 1->3 typically fails)
    CAST(ev.[1b] AS INT) AS is_1b,
    CAST(ev.[2b] AS INT) AS is_2b,
    CAST(ev.[3b] AS INT) AS is_3b,
    CAST(ev.hr   AS INT) AS is_hr,
    CAST(ev.bb   AS INT) AS is_bb,
    CAST(ev.hbp  AS INT) AS is_hbp,
    ev.event_result_id,
    er.event_result,
    ev.play_by_play,

    -- Pre-play and post-play runner state
    ev.runner_1b,
    ev.runner_2b,
    ev.runner_3b,
    ev.runner_1b_after,
    ev.runner_2b_after,
    ev.runner_3b_after,

    -- First defender — verified columns only (OF + C)
    ev.first_defender_id,
    p_def.first_name + ' ' + p_def.last_name AS first_defender_name,
    -- Position lookup via Players_Games (pos_id 1-9 maps to P/C/1B/2B/3B/SS/LF/CF/RF)
    pg_def.pos_id AS first_defender_pos_id,
    CASE pg_def.pos_id
        WHEN 1 THEN 'P'  WHEN 2 THEN 'C'
        WHEN 3 THEN '1B' WHEN 4 THEN '2B' WHEN 5 THEN '3B' WHEN 6 THEN 'SS'
        WHEN 7 THEN 'LF' WHEN 8 THEN 'CF' WHEN 9 THEN 'RF'
        ELSE 'UNK'
    END AS first_defender_pos,

    -- Cross-check using the metric's own logic (OF id-match path)
    CASE
        WHEN ev.first_defender_id = ev.rf_id THEN 'RF (id match)'
        WHEN ev.first_defender_id = ev.cf_id THEN 'CF (id match)'
        WHEN ev.first_defender_id = ev.lf_id THEN 'LF (id match)'
        WHEN ev.first_defender_id = ev.c_id  THEN 'C (id match)'
        ELSE 'IF/P/UNK (no OF id match)'
    END AS first_defender_of_match,

    -- 1->3 eligibility (only meaningful when Yamal was on 1st)
    CASE
        WHEN ev.runner_1b = 155788
             AND CAST(ev.[1b] AS INT) = 1
             AND CAST(ev.hr AS INT) = 0
             AND ev.first_defender_id IN (ev.rf_id, ev.cf_id, ev.lf_id)
        THEN 'YES'
        WHEN ev.runner_1b = 155788
        THEN 'NO -- failed: '
              + CASE WHEN CAST(ev.[1b] AS INT) <> 1 THEN '[1b]<>1 ' ELSE '' END
              + CASE WHEN CAST(ev.hr AS INT) = 1 THEN 'is_HR ' ELSE '' END
              + CASE WHEN ev.first_defender_id NOT IN (ev.rf_id, ev.cf_id, ev.lf_id)
                     THEN 'first_defender_not_OF ' ELSE '' END
        ELSE 'N/A (Yamal was not on 1st pre-play)'
    END AS ft3_eligibility,

    -- Did Yamal end on 3rd?
    CASE
        WHEN ev.runner_3b_after = 155788 THEN 'YES'
        WHEN ev.runner_2b_after = 155788 THEN 'No, only made 2B'
        WHEN ev.runner_1b_after = 155788 THEN 'No, still on 1B'
        ELSE 'No (scored or recorded out)'
    END AS yamal_ended_on_3rd

FROM Astros.Events_View ev
JOIN Astros.Schedule_View sv
    ON ev.sched_id = sv.sched_id
LEFT JOIN Astros.LK_Event_Results er
    ON ev.event_result_id = er.event_result_id
LEFT JOIN Astros.Players_Games pg_def
    ON pg_def.sched_id = ev.sched_id
   AND pg_def.groundcontrol_id = ev.first_defender_id
LEFT JOIN Astros.Players p_def
    ON p_def.groundcontrol_id = ev.first_defender_id

WHERE sv.sched_date = '2026-04-30'
  AND sv.level_code = 'aax'
  AND (
        ev.runner_1b       = 155788
     OR ev.runner_2b       = 155788
     OR ev.runner_3b       = 155788
     OR ev.runner_1b_after = 155788
     OR ev.runner_2b_after = 155788
     OR ev.runner_3b_after = 155788
      )

ORDER BY ev.inning, ev.top_of_inning DESC, ev.event_id;
