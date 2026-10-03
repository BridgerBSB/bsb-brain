/* =============================================================================
   Extra bases taken on a single, by baserunner (per player)
   -----------------------------------------------------------------------------
   One-off for Cristian Perez (PD), via Zac — June 2026.

   Cristian's definition: "any single (with no error) when a baserunner scores
   from second (2->H) or advances to third from first (1->3)."

   This is the canonical 1->3 / 2->H baserunning-advancement metric, lifted
   verbatim from the reference impl:
       intangibles/src/br_tracker_data.py :: _FT3_S2H_QUERY
   (see .claude/rules/reference-impl-index.md "1->3 / 2->H").

   Why it matches "single, no error":
     - Gated on CAST(ev.[1b] AS INT) = 1  -> the play was officially scored a
       SINGLE. A batter who reaches on an error is NOT scored a single, so the
       "no error on the batter" condition is inherent. Doubles, triples, HR,
       fielder's choices, and errors are intentionally excluded (matches
       Statcast XBT% / FanGraphs convention) — going 1B->3B on a double is the
       default outcome and doesn't reflect baserunning read/aggression.
     - first_defender_id IN (rf, cf, lf)  -> outfield single (you take the
       extra base on OF singles, not infield dribblers).

   Columns returned (one row per player):
     player, org, level info aside,
     ft3_success / ft3_opps / ft3_pct   = 1st -> 3rd on a single
     s2h_success / s2h_opps / s2h_pct   = 2nd -> Home on a single
     xb_success                          = ft3_success + s2h_success (total)

   TWO TOGGLES (each on its own line, edit and re-run):
     1. Season:  change  @season = 2026
     2. Org:     HOU only by default. Delete the `AND org = 'HOU'` line near the
                 bottom for league-wide (all 30 orgs).

   "Just by player" per Cristian -> one row per player, summed across whatever
   levels he played. To break out BY LEVEL instead, see the commented block at
   the very bottom.

   T-SQL (SQL Server). Run on the work laptop (GCSQL02 -> GroundControl2).
   ============================================================================= */

DECLARE @season INT = 2026;   -- <-- toggle 1: season

WITH adv AS (
    SELECT
        runner_id,
        org,
        SUM(ft3_opps)    AS ft3_opps,
        SUM(ft3_success) AS ft3_success,
        SUM(s2h_opps)    AS s2h_opps,
        SUM(s2h_success) AS s2h_success
    FROM (
        /* ---------- 1B -> 3B on a single ---------- */
        SELECT
            ev.runner_1b AS runner_id,
            UPPER(mt.org_abbrev) AS org,
            CASE
                WHEN ev.first_defender_id IN (ev.rf_id, ev.cf_id) THEN
                    CASE
                        WHEN (ev.runner_1b_after IS NULL OR ev.runner_1b_after != ev.runner_1b)
                             AND (ev.runner_2b_after IS NULL OR ev.runner_2b_after != ev.runner_1b)
                             AND (ev.runner_3b_after IS NULL OR ev.runner_3b_after != ev.runner_1b)
                             AND ev.outs_after = ev.outs_before
                        THEN 1
                        WHEN ev.runner_3b_after = ev.runner_1b THEN 1
                        WHEN ev.runner_3b_after IS NULL THEN 1
                        ELSE 0
                    END
                WHEN ev.first_defender_id = ev.lf_id THEN
                    CASE
                        WHEN ev.runner_3b_after = ev.runner_1b THEN 1
                        WHEN (ev.runner_1b_after IS NULL OR ev.runner_1b_after != ev.runner_1b)
                             AND (ev.runner_2b_after IS NULL OR ev.runner_2b_after != ev.runner_1b)
                             AND (ev.runner_3b_after IS NULL OR ev.runner_3b_after != ev.runner_1b)
                             AND ev.outs_after = ev.outs_before
                        THEN 1
                        ELSE 0
                    END
                ELSE 0
            END AS ft3_opps,
            CASE
                WHEN ev.runner_3b_after = ev.runner_1b THEN 1
                WHEN (ev.runner_1b_after IS NULL OR ev.runner_1b_after != ev.runner_1b)
                     AND (ev.runner_2b_after IS NULL OR ev.runner_2b_after != ev.runner_1b)
                     AND (ev.runner_3b_after IS NULL OR ev.runner_3b_after != ev.runner_1b)
                     AND ev.outs_after = ev.outs_before
                THEN 1
                ELSE 0
            END AS ft3_success,
            0 AS s2h_opps,
            0 AS s2h_success
        FROM Astros.Events_View ev
        JOIN Astros.Schedule_View sv ON ev.sched_id = sv.sched_id
        JOIN mlbam.teams mt
            ON mt.team_id = CASE WHEN ev.top_of_inning = 1
                                 THEN sv.away_team_mlbam_id
                                 ELSE sv.home_team_mlbam_id END
            AND mt.season = sv.year
        WHERE sv.sched_type = 'R'
          AND sv.gc2_level_code IN ('mlb','aaa','aax','afa','afx','rok','dsl')
          AND YEAR(sv.sched_date) = @season
          AND ev.runner_1b IS NOT NULL
          AND CAST(ev.[1b] AS INT) = 1     -- single only (excludes error reach)
          AND CAST(ev.hr AS INT) = 0
          AND ev.first_defender_id IN (ev.rf_id, ev.cf_id, ev.lf_id)

        UNION ALL

        /* ---------- 2B -> Home on a single ---------- */
        SELECT
            ev.runner_2b AS runner_id,
            UPPER(mt.org_abbrev) AS org,
            0 AS ft3_opps,
            0 AS ft3_success,
            CASE
                WHEN ev.runner_3b IS NOT NULL
                     AND ev.runner_3b_after = ev.runner_3b
                THEN 0       -- runner ahead on 3B stayed -> no clean opp
                ELSE 1
            END AS s2h_opps,
            CASE
                WHEN (ev.runner_2b_after IS NULL OR ev.runner_2b_after != ev.runner_2b)
                     AND (ev.runner_3b_after IS NULL OR ev.runner_3b_after != ev.runner_2b)
                     AND ev.outs_after = ev.outs_before
                THEN 1       -- runner left 2B, not held at 3B, no out -> scored
                ELSE 0
            END AS s2h_success
        FROM Astros.Events_View ev
        JOIN Astros.Schedule_View sv ON ev.sched_id = sv.sched_id
        JOIN mlbam.teams mt
            ON mt.team_id = CASE WHEN ev.top_of_inning = 1
                                 THEN sv.away_team_mlbam_id
                                 ELSE sv.home_team_mlbam_id END
            AND mt.season = sv.year
        WHERE sv.sched_type = 'R'
          AND sv.gc2_level_code IN ('mlb','aaa','aax','afa','afx','rok','dsl')
          AND YEAR(sv.sched_date) = @season
          AND ev.runner_2b IS NOT NULL
          AND CAST(ev.[1b] AS INT) = 1     -- single only (excludes error reach)
          AND CAST(ev.hr AS INT) = 0
          AND ev.first_defender_id IN (ev.rf_id, ev.cf_id, ev.lf_id)
    ) AS x
    GROUP BY runner_id, org
)
SELECT
    LTRIM(RTRIM(ISNULL(p.first_name,'') + ' ' + ISNULL(p.last_name,''))) AS player,
    adv.org,
    adv.ft3_success,
    adv.ft3_opps,
    CASE WHEN adv.ft3_opps > 0
         THEN CAST(100.0 * adv.ft3_success / adv.ft3_opps AS DECIMAL(5,1)) END AS ft3_pct,
    adv.s2h_success,
    adv.s2h_opps,
    CASE WHEN adv.s2h_opps > 0
         THEN CAST(100.0 * adv.s2h_success / adv.s2h_opps AS DECIMAL(5,1)) END AS s2h_pct,
    (adv.ft3_success + adv.s2h_success) AS xb_success
FROM adv
JOIN Astros.Players p ON p.groundcontrol_id = adv.runner_id
WHERE adv.org = 'HOU'                      -- <-- toggle 2: delete this line for all 30 orgs
ORDER BY xb_success DESC, adv.org, player;


/* =============================================================================
   ALTERNATE: break out BY PLAYER x LEVEL (if Cristian wants level granularity)
   -----------------------------------------------------------------------------
   Replace `GROUP BY runner_id, org` above with `GROUP BY runner_id, org,
   level_code`, add `sv.gc2_level_code AS level_code` to BOTH inner SELECTs
   (and to the CTE's outer SELECT/GROUP BY), then add `adv.level_code` to the
   final SELECT. Leaves the rest identical.
   ============================================================================= */
