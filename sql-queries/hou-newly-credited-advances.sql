/* =============================================================================
   HOU baserunning advances NEWLY credited by the run-attribution fix
   -----------------------------------------------------------------------------
   Lists every HOU play (1->3 AND 2->H) that the OLD outs-proxy scored as a
   FAILURE but the NEW run-attribution scores as a SUCCESS -- i.e. the runner
   actually scored/advanced, but an out made on ANOTHER runner (e.g. the batter
   tagged at 3rd) wrongly failed him before. These are the plays the fix adds.

   One row per newly-credited play, with the SportyClips video so you can judge
   each call yourself. Run on the WORK LAPTOP (DB access) in SSMS.

   Scoped to 2026, all real levels, sched_type R. Change @season / add a level
   filter if you want a narrower look. HOU = the runner's BATTING team that game.

   Metric logic mirrors the shipped fix (intangibles/src/br_data.py etc.):
     * 1->3 is SINGLE-ONLY (CAST(ev.[1b] AS INT)=1, hr=0, fielder in rf/cf/lf).
     * 2->H same single/fielder gating; excludes plays where a 3B runner held.
     * need = (runs that had to cross for THIS runner to have scored):
         1->3 from 1st: 1 + (runner on 2B) + (runner on 3B)
         2->H from 2nd: 2 if a runner was on 3B at the pitch, else 1
   ============================================================================= */

DECLARE @season INT = 2026;

;WITH base AS (
    SELECT
        ev.sched_id, ev.event_id,
        sv.sched_date, sv.level_code,
        ev.runner_1b, ev.runner_2b, ev.runner_3b,
        ev.runner_1b_after, ev.runner_2b_after, ev.runner_3b_after,
        ev.outs_before, ev.outs_after,
        ev.first_defender_id, ev.rf_id, ev.cf_id, ev.lf_id,
        (CASE WHEN ev.top_of_inning = 1
              THEN ev.away_team_score_after - ev.away_team_score_before
              ELSE ev.home_team_score_after - ev.home_team_score_before END) AS runs_on_play
    FROM Astros.Events_View ev
    JOIN Astros.Schedule_View sv ON ev.sched_id = sv.sched_id
    JOIN mlbam.teams mt
        ON mt.team_id = CASE WHEN ev.top_of_inning = 1
                             THEN sv.away_team_mlbam_id
                             ELSE sv.home_team_mlbam_id END
       AND mt.season = sv.year
    WHERE UPPER(mt.org_abbrev) = 'HOU'        -- HOU's own baserunners (batting team)
      AND YEAR(sv.sched_date) = @season
      AND sv.sched_type = 'R'
      AND CAST(ev.[1b] AS INT) = 1            -- single only
      AND CAST(ev.hr  AS INT) = 0
      AND ev.first_defender_id IN (ev.rf_id, ev.cf_id, ev.lf_id)
),
ft3 AS (   -- 1->3 newly credited (runner from 1st scored, old proxy failed him)
    SELECT
        '1->3' AS metric, sched_id, event_id, sched_date, level_code,
        runner_1b AS runner_id, first_defender_id, rf_id, cf_id, lf_id,
        runs_on_play,
        (1 + CASE WHEN runner_2b IS NOT NULL THEN 1 ELSE 0 END
           + CASE WHEN runner_3b IS NOT NULL THEN 1 ELSE 0 END) AS need
    FROM base
    WHERE runner_1b IS NOT NULL
      -- runner is GONE after (scored/out), and NOT simply standing on 3rd
      AND (runner_1b_after IS NULL OR runner_1b_after != runner_1b)
      AND (runner_2b_after IS NULL OR runner_2b_after != runner_1b)
      AND (runner_3b_after IS NULL OR runner_3b_after != runner_1b)
      -- NEW says success: enough runs crossed for him
      AND runs_on_play >= (1 + CASE WHEN runner_2b IS NOT NULL THEN 1 ELSE 0 END
                             + CASE WHEN runner_3b IS NOT NULL THEN 1 ELSE 0 END)
      -- OLD said failure: an out was made on the play
      AND outs_after <> outs_before
),
s2h AS (   -- 2->H newly credited (runner from 2nd scored, old proxy failed him)
    SELECT
        '2->H' AS metric, sched_id, event_id, sched_date, level_code,
        runner_2b AS runner_id, first_defender_id, rf_id, cf_id, lf_id,
        runs_on_play,
        (CASE WHEN runner_3b IS NOT NULL THEN 2 ELSE 1 END) AS need
    FROM base
    WHERE runner_2b IS NOT NULL
      -- not a blocked path: a 3B runner who held makes it a non-opportunity
      AND NOT (runner_3b IS NOT NULL AND runner_3b_after = runner_3b)
      -- runner is GONE after (scored/out)
      AND (runner_2b_after IS NULL OR runner_2b_after != runner_2b)
      AND (runner_3b_after IS NULL OR runner_3b_after != runner_2b)
      -- NEW says success
      AND runs_on_play >= (CASE WHEN runner_3b IS NOT NULL THEN 2 ELSE 1 END)
      -- OLD said failure
      AND outs_after <> outs_before
),
flipped AS (SELECT * FROM ft3 UNION ALL SELECT * FROM s2h)

SELECT
    f.metric,
    f.sched_date,
    f.level_code,
    'HOU' AS org,
    LTRIM(RTRIM(ISNULL(p.first_name,'') + ' ' + ISNULL(p.last_name,''))) AS runner,
    f.runner_id,
    CASE WHEN f.first_defender_id = f.lf_id THEN 'LF'
         WHEN f.first_defender_id = f.cf_id THEN 'CF'
         ELSE 'RF' END AS fielder,
    f.runs_on_play,
    f.need,
    av.video_url                                               AS sportyclips_url,
    ISNULL(av.video_url, ISNULL(vnv.video_url, vna.video_url)) AS video_url
FROM flipped f
LEFT JOIN Astros.Players p ON p.groundcontrol_id = f.runner_id
OUTER APPLY (                                  -- AB-ending pitch for this event
    SELECT TOP 1 pv.pitch_id
    FROM Astros.Pitches_View pv
    WHERE pv.sched_id = f.sched_id
      AND pv.cur_event_id = f.event_id
      AND pv.pitch_id > 0
    ORDER BY pv.pitch_id DESC
) pp
LEFT JOIN Astros.Video av
    ON av.sched_id = f.sched_id AND av.pitch_id = pp.pitch_id AND av.angle_id = 1
LEFT JOIN Astros.Video_Network vnv
    ON vnv.sched_id = f.sched_id AND vnv.pitch_id = pp.pitch_id AND vnv.angle = 'v'
LEFT JOIN Astros.Video_Network vna
    ON vna.sched_id = f.sched_id AND vna.pitch_id = pp.pitch_id AND vna.angle = 'a'
ORDER BY f.metric, f.sched_date, f.sched_id;
