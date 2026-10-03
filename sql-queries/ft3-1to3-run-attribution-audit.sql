/* =============================================================================
   1->3 (ft3) run-attribution audit
   -----------------------------------------------------------------------------
   Purpose: measure whether the SAME outs-proxy bug we fixed in 2->H actually
   moves the 1->3 number, BEFORE deciding to touch 1->3.

   Why 1->3 is probably already fine:
     * The COMMON 1->3 success path is "reached 3rd" = (runner_3b_after = runner_1b)
       -- POSITION-based, immune to the bug. We never touch it.
     * The outs proxy (ev.outs_after = ev.outs_before) ONLY gates the RARE
       "scored all the way home from 1st on a single" branch.
     * That proxy sits in BOTH the success numerator (an out elsewhere wrongly
       FAILS a scored-from-1st runner -> deflates) AND the opportunity
       denominator (same play drops from the LF/CF/RF opp count -> inflates).
       The two errors push OPPOSITE directions and may cancel.

   This query:
     RESULT SET 1 = roll-up: old (outs-proxy) vs new (run-attribution)
                    ft3_success, ft3_opps, and rate. If old ~= new, 1->3 is fine.
     RESULT SET 2 = the exact disagreeing plays (eyeball / pull video).

   Run on the WORK LAPTOP (DB access) in SSMS against GroundControl2.
   Scoped to AAX 2026 to match SQLQuery32.sql (the 2->H harness). Change the
   two DECLAREs to re-scope.

   Metric definition mirrored from intangibles/src/br_tracker_data.py::_FT3_S2H_QUERY
   (1->3 is SINGLE-ONLY: CAST(ev.[1b] AS INT)=1, hr=0, first_defender in rf/cf/lf).
   ============================================================================= */

DECLARE @level   VARCHAR(8) = 'aax';   -- AAX = AA. (Not a DSL/FCL case, so level_code is safe.)
DECLARE @season  INT        = 2026;

;WITH ft3_plays AS (
    SELECT
        ev.sched_id,
        sv.sched_date,
        ev.runner_1b                                   AS runner_id,
        UPPER(mt.org_abbrev)                           AS org,
        CASE WHEN ev.first_defender_id = ev.lf_id THEN 'LF'
             WHEN ev.first_defender_id = ev.cf_id THEN 'CF'
             ELSE 'RF' END                             AS fielder,

        -- (a) reached 3rd -- position based, CORRECT, common case
        CAST(CASE WHEN ev.runner_3b_after = ev.runner_1b THEN 1 ELSE 0 END AS INT) AS reached_3rd,

        -- runner is GONE after the play (not on 1b/2b/3b) = he scored OR was thrown out
        CAST(CASE WHEN (ev.runner_1b_after IS NULL OR ev.runner_1b_after != ev.runner_1b)
                   AND (ev.runner_2b_after IS NULL OR ev.runner_2b_after != ev.runner_1b)
                   AND (ev.runner_3b_after IS NULL OR ev.runner_3b_after != ev.runner_1b)
                  THEN 1 ELSE 0 END AS INT)            AS gone_after,

        -- OLD proxy: gone-after AND no out added on the play
        CAST(CASE WHEN ev.outs_after = ev.outs_before THEN 1 ELSE 0 END AS INT)     AS no_extra_outs,

        -- runs that crossed for the batting team on this play (official scoring)
        (CASE WHEN ev.top_of_inning = 1
              THEN ev.away_team_score_after - ev.away_team_score_before
              ELSE ev.home_team_score_after - ev.home_team_score_before END)        AS runs_on_play,

        -- run-attribution NEED for a runner from 1st: he is behind anyone on 2B/3B,
        -- so his run is the (1 + #runners-ahead)-th to cross.
        (1 + CASE WHEN ev.runner_2b IS NOT NULL THEN 1 ELSE 0 END
           + CASE WHEN ev.runner_3b IS NOT NULL THEN 1 ELSE 0 END)                  AS need,

        -- is the 3B path blocked by another runner who held? (used in RF/CF opp logic)
        CAST(CASE WHEN ev.runner_3b_after IS NOT NULL
                   AND ev.runner_3b_after != ev.runner_1b THEN 1 ELSE 0 END AS INT) AS three_b_blocked,

        -- SportyClips (Astros.Video angle_id=1 -- plays on phones) for the AB-ending pitch,
        -- + 3-tier fallback to Video_Network 'v' then 'a' per .claude/rules/video-angles.md.
        -- NOTE: SportyClips is NULL on Astros-AWAY MiLB games (HawkEye-venue only), so for an
        -- opponent runner this may be blank -- video_url then falls back to the internal feed.
        av.video_url                                               AS sportyclips_url,
        ISNULL(av.video_url, ISNULL(vnv.video_url, vna.video_url)) AS video_url
    FROM Astros.Events_View ev
    JOIN Astros.Schedule_View sv ON ev.sched_id = sv.sched_id
    JOIN mlbam.teams mt
        ON mt.team_id = CASE WHEN ev.top_of_inning = 1
                             THEN sv.away_team_mlbam_id
                             ELSE sv.home_team_mlbam_id END
       AND mt.season = sv.year
    OUTER APPLY (                                  -- AB-ending pitch for this event
        SELECT TOP 1 pv.pitch_id
        FROM Astros.Pitches_View pv
        WHERE pv.sched_id = ev.sched_id
          AND pv.cur_event_id = ev.event_id
          AND pv.pitch_id > 0
        ORDER BY pv.pitch_id DESC
    ) pp
    LEFT JOIN Astros.Video av
        ON av.sched_id = ev.sched_id AND av.pitch_id = pp.pitch_id AND av.angle_id = 1
    LEFT JOIN Astros.Video_Network vnv
        ON vnv.sched_id = ev.sched_id AND vnv.pitch_id = pp.pitch_id AND vnv.angle = 'v'
    LEFT JOIN Astros.Video_Network vna
        ON vna.sched_id = ev.sched_id AND vna.pitch_id = pp.pitch_id AND vna.angle = 'a'
    WHERE sv.level_code = @level
      AND YEAR(sv.sched_date) = @season
      AND sv.sched_type = 'R'
      AND ev.runner_1b IS NOT NULL
      AND CAST(ev.[1b] AS INT) = 1          -- single only
      AND CAST(ev.hr  AS INT) = 0
      AND ev.first_defender_id IN (ev.rf_id, ev.cf_id, ev.lf_id)
),
classified AS (
    SELECT *,
        -- scored-from-1st verdicts (the only branch the proxy touches)
        CASE WHEN gone_after = 1 AND no_extra_outs = 1 THEN 1 ELSE 0 END  AS old_scored,
        CASE WHEN gone_after = 1 AND runs_on_play >= need THEN 1 ELSE 0 END AS new_scored
    FROM ft3_plays
),
verdicts AS (
    SELECT *,
        -- SUCCESS = reached 3rd  OR  scored from 1st
        CASE WHEN reached_3rd = 1 OR old_scored = 1 THEN 1 ELSE 0 END AS old_success,
        CASE WHEN reached_3rd = 1 OR new_scored = 1 THEN 1 ELSE 0 END AS new_success,
        -- OPPORTUNITY (mirrors _FT3_S2H_QUERY):
        --   RF/CF: opp unless 3B is blocked by another runner AND our runner neither scored nor reached
        --   LF:    opp only on a success (reached 3rd OR scored from 1st)
        CASE WHEN fielder = 'LF'
             THEN CASE WHEN reached_3rd = 1 OR old_scored = 1 THEN 1 ELSE 0 END
             ELSE CASE WHEN old_scored = 1 OR reached_3rd = 1 OR three_b_blocked = 0 THEN 1 ELSE 0 END
        END AS old_opp,
        CASE WHEN fielder = 'LF'
             THEN CASE WHEN reached_3rd = 1 OR new_scored = 1 THEN 1 ELSE 0 END
             ELSE CASE WHEN new_scored = 1 OR reached_3rd = 1 OR three_b_blocked = 0 THEN 1 ELSE 0 END
        END AS new_opp
    FROM classified
)
SELECT * INTO #v FROM verdicts;   -- materialize so BOTH result sets can read it
                                  -- (a ;WITH CTE only binds to the next single statement)

-- ================= RESULT SET 1: roll-up (the headline answer) =================
SELECT
    SUM(old_success)                                   AS old_success,
    SUM(new_success)                                   AS new_success,
    SUM(new_success) - SUM(old_success)                AS success_delta,
    SUM(old_opp)                                       AS old_opps,
    SUM(new_opp)                                       AS new_opps,
    SUM(new_opp) - SUM(old_opp)                        AS opp_delta,
    CAST(100.0 * SUM(old_success) / NULLIF(SUM(old_opp),0) AS DECIMAL(5,1)) AS old_rate_pct,
    CAST(100.0 * SUM(new_success) / NULLIF(SUM(new_opp),0) AS DECIMAL(5,1)) AS new_rate_pct,
    SUM(CASE WHEN old_success != new_success OR old_opp != new_opp THEN 1 ELSE 0 END) AS n_disagree_plays
FROM #v;

-- ================= RESULT SET 2: the disagreeing plays (eyeball / video) ========
-- If RESULT SET 1 shows n_disagree_plays ~ 0 and old_rate_pct ~ new_rate_pct,
-- 1->3 is effectively fine and not worth changing.
SELECT
    sched_id, sched_date, org, runner_id, fielder,
    reached_3rd, gone_after, no_extra_outs, runs_on_play, need,
    old_scored, new_scored, old_success, new_success, old_opp, new_opp,
    sportyclips_url, video_url
FROM #v
WHERE old_success != new_success OR old_opp != new_opp
ORDER BY sched_date, sched_id;

DROP TABLE #v;
