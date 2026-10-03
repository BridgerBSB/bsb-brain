/* ============================================================================
   DSL split labels STILL show "HOU - Team <id>" after the MLBAM.Teams fix.
   ----------------------------------------------------------------------------
   Goal: get the EXACT team_id the DSL split GROUPs on (== dsl_team_id ==
   what _resolve_dsl_team_label receives), joined to what mlbam.teams calls
   that id (name + league + season). If the Orange team groups on an id that
   mlbam.teams does NOT tag league='DSL' (or stores under a different team_id),
   _load_dsl_team_labels() misses it and the {601,5005} fallback can't catch
   it -> "Team <id>".

   This MIRRORS the split's JOIN exactly (mlbam.teams ON team_id = batting-side
   mlbam id AND season = year), so result-set 1's team_id values ARE the
   dsl_team_id values that flow to the label resolver.

   Run on the work laptop. Paste BOTH result sets back.
   ============================================================================ */

-- 1) The EXACT ids the split groups HOU's DSL teams on, + mlbam's name/league
--    for each. league column is what _load_dsl_team_labels filters on ('DSL').
SELECT
    mt.team_id            AS dsl_team_id,   -- == the split's GROUP BY id
    mt.season,
    mt.name               AS mlbam_name,
    mt.league,                              -- loader filters WHERE league='DSL'
    UPPER(mt.org_abbrev)  AS org,
    COUNT(*)              AS n_pitches
FROM Astros.Pitches_View pv
JOIN Astros.Schedule_View sv ON pv.sched_id = sv.sched_id
JOIN Astros.Events_View ev ON pv.sched_id = ev.sched_id AND pv.ab_event_id = ev.event_id
JOIN mlbam.teams mt
    ON mt.team_id = CASE WHEN ev.top_of_inning = 1
                         THEN sv.away_team_mlbam_id
                         ELSE sv.home_team_mlbam_id END
   AND mt.season = sv.year
WHERE sv.gc2_level_code = 'dsl'
  AND UPPER(mt.org_abbrev) = 'HOU'
  AND YEAR(sv.sched_date) = 2026
  AND pv.pitch_id > 0
GROUP BY mt.team_id, mt.season, mt.name, mt.league, UPPER(mt.org_abbrev)
ORDER BY n_pitches DESC;

-- 2) What _load_dsl_team_labels() actually loads for the Astros DSL clubs
--    (its source: MLBAM.Teams WHERE league='DSL', no season constraint).
--    Compare the team_id values here to result-set 1's dsl_team_id.
SELECT team_id, season, name, league
FROM MLBAM.Teams
WHERE name LIKE 'DSL Astros%'
ORDER BY team_id, season;

/* Read-out:
   - If set-1 Orange dsl_team_id == set-2 Orange team_id AND set-1 league='DSL'
     -> the fix is correct; you're just looking at a NOT-yet-redeployed app.
   - If set-1 Orange dsl_team_id (e.g. 1005) is NOT in set-2 (which has 5005)
     OR set-1's league for that row is NOT 'DSL' -> the loader/fallback can't
     resolve it. Fix = key labels on set-1's id with its set-1 name, and DROP
     the WHERE league='DSL' filter in _load_dsl_team_labels (load all team_id
     -> name and resolve straight on the group-by id). Same fix lands in all 5
     trackers' *_tracker_data.py (identical helper). */
