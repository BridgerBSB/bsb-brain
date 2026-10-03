/* =============================================================================
   2->H diagnostic — Joseph Sullivan, AAX (Corpus Christi), 2026-06-02
   -----------------------------------------------------------------------------
   Zac's dive: a 2->H play scored as a NON-success for Sullivan. Hypothesis:
   the production s2h_success logic requires `outs_after = outs_before`, which
   is meant to catch "the runner HIMSELF was thrown out" — but it ALSO zeroes
   the play when a DIFFERENT runner (the guy at 1st) is thrown out after the
   single, even though Sullivan scored cleanly from 2nd.

   This dumps every Events_View row that day at AAX where Sullivan was on any
   base, with:
     - the full base state (before + after) with runner NAMES,
     - the fielder who got the ball (OF position),
     - the EXACT production 2->H flags (s2h_opps / s2h_success) inlined verbatim
       from br_tracker_data._FT3_S2H_QUERY,
     - outs_made_on_play  = outs_after - outs_before   <-- the smoking gun,
     - sullivan_after     = did Sullivan leave the bases (scored/out) this play.

   READ THE ROW where is_qualifying_2h_play = 1:
     If s2h_success = 0 WHILE outs_made_on_play >= 1 AND sullivan left the bases
     AND no runner_*_after = Sullivan  ->  he scored but the trailing-runner out
     killed the credit. That's the bug to fix in the success logic everywhere.

   T-SQL. Run on the work laptop (GCSQL02 -> GroundControl2). Diagnostic only —
   no production code touched.
   ============================================================================= */

DECLARE @gc   INT  = 218708;        -- Joseph Sullivan
DECLARE @date DATE = '2026-06-02';

SELECT
    ev.sched_id,
    ev.event_id,
    ev.inning,
    ev.top_of_inning,
    ev.event_result,
    ev.event_result_id,
    CAST(ev.[1b] AS INT) AS is_single,
    CAST(ev.hr  AS INT)  AS is_hr,
    CASE
        WHEN ev.first_defender_id = ev.rf_id THEN 'RF'
        WHEN ev.first_defender_id = ev.cf_id THEN 'CF'
        WHEN ev.first_defender_id = ev.lf_id THEN 'LF'
        ELSE 'INF/other'
    END AS fielded_by,

    -- ---------- base state BEFORE (with names) ----------
    ev.runner_1b, LTRIM(RTRIM(ISNULL(r1.first_name,'')+' '+ISNULL(r1.last_name,''))) AS on_1b,
    ev.runner_2b, LTRIM(RTRIM(ISNULL(r2.first_name,'')+' '+ISNULL(r2.last_name,''))) AS on_2b,
    ev.runner_3b, LTRIM(RTRIM(ISNULL(r3.first_name,'')+' '+ISNULL(r3.last_name,''))) AS on_3b,

    -- ---------- base state AFTER (raw ids; NULL = off the bases) ----------
    ev.runner_1b_after,
    ev.runner_2b_after,
    ev.runner_3b_after,

    ev.outs_before,
    ev.outs_after,
    (ev.outs_after - ev.outs_before) AS outs_made_on_play,   -- <-- smoking gun

    -- did Sullivan leave the bases this play (scored OR out)?
    CASE WHEN @gc IN (ev.runner_1b_after, ev.runner_2b_after, ev.runner_3b_after)
         THEN 'STILL ON BASE'
         ELSE 'LEFT BASES (scored or out)'
    END AS sullivan_after,

    -- is THIS the qualifying 2->H single with Sullivan on 2nd?
    CASE WHEN ev.runner_2b = @gc
              AND CAST(ev.[1b] AS INT) = 1
              AND CAST(ev.hr AS INT) = 0
              AND ev.first_defender_id IN (ev.rf_id, ev.cf_id, ev.lf_id)
         THEN 1 ELSE 0 END AS is_qualifying_2h_play,

    -- ---------- PRODUCTION 2->H flags, verbatim from _FT3_S2H_QUERY ----------
    CASE
        WHEN ev.runner_3b IS NOT NULL AND ev.runner_3b_after = ev.runner_3b
        THEN 0 ELSE 1
    END AS s2h_opps,
    CASE
        WHEN (ev.runner_2b_after IS NULL OR ev.runner_2b_after != ev.runner_2b)
             AND (ev.runner_3b_after IS NULL OR ev.runner_3b_after != ev.runner_2b)
             AND ev.outs_after = ev.outs_before          -- <-- the suspect clause
        THEN 1 ELSE 0
    END AS s2h_success,

    -- ---------- PRODUCTION 1->3 flags (in case Sullivan was on 1st) ----------
    CASE
        WHEN ev.runner_3b_after = ev.runner_1b THEN 1
        WHEN (ev.runner_1b_after IS NULL OR ev.runner_1b_after != ev.runner_1b)
             AND (ev.runner_2b_after IS NULL OR ev.runner_2b_after != ev.runner_1b)
             AND (ev.runner_3b_after IS NULL OR ev.runner_3b_after != ev.runner_1b)
             AND ev.outs_after = ev.outs_before
        THEN 1 ELSE 0
    END AS ft3_success
FROM Astros.Events_View ev
JOIN Astros.Schedule_View sv ON ev.sched_id = sv.sched_id
LEFT JOIN Astros.Players r1 ON r1.groundcontrol_id = ev.runner_1b
LEFT JOIN Astros.Players r2 ON r2.groundcontrol_id = ev.runner_2b
LEFT JOIN Astros.Players r3 ON r3.groundcontrol_id = ev.runner_3b
WHERE sv.gc2_level_code = 'aax'
  AND CAST(sv.sched_date AS DATE) = @date
  AND (ev.runner_1b = @gc OR ev.runner_2b = @gc OR ev.runner_3b = @gc)
ORDER BY ev.inning, ev.event_id;
