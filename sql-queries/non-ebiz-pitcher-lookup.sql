-- Non-EBIZ pitcher lookup — diagnostic for the one-off advance flow
-- ===================================================================
-- Use case: opposing pitcher we'll face soon who isn't in PP_MASTER
-- (indy-ball signing, released player, mid-trade between orgs, just
-- promoted from BBC). Standard advance lookup (`search_pitchers_by_name`
-- INNER JOINs PP_MASTER) won't surface them or returns NULL fields.
--
-- This script:
--   1. Lists ALL Astros.Players rows for the name (one human can carry
--      multiple groundcontrol_ids — one with full ebis/mlbam, others
--      stub records).
--   2. Aggregates pitch activity across ALL those rows by
--      (year, level, sched_type) so we can confirm there's data and see
--      where it lives.
--   3. Outputs the gc_id list to feed into:
--      `python scripts/generate_advance_oneoff.py --pitcher-ids ...`
--
-- See: .claude/rules/advance-non-ebiz-pitchers.md  for the full flow.
-- See: .claude/rules/advance-levels.md             for level policy.
-- ===================================================================

-- EDIT THESE TWO LINES FOR YOUR PITCHER:
DECLARE @pitcher_first NVARCHAR(50) = 'Kyle';
DECLARE @pitcher_last  NVARCHAR(50) = 'Funkhouser';


-- =====================================================================
-- Step 1 — All Astros.Players rows for this name
-- One row per groundcontrol_id. The "real" record is the one with
-- non-NULL ebis_id + mlbam_id + birthdate. Others are stub records
-- that GC2 ingest created at different points.
-- =====================================================================
SELECT
    groundcontrol_id,
    ebis_id,
    mlbam_id,
    first_name,
    last_name,
    birthdate,
    throws
FROM Astros.Players
WHERE first_name = @pitcher_first
  AND last_name  = @pitcher_last
ORDER BY
    CASE WHEN ebis_id IS NOT NULL AND mlbam_id IS NOT NULL THEN 0 ELSE 1 END,
    groundcontrol_id;


-- =====================================================================
-- Step 2 — Last-12-months pitch activity by (year, level, sched_type)
-- Aggregates across ALL Players rows that share the name. Confirms data
-- exists, shows level mix, and identifies the recency window.
-- =====================================================================
SELECT
    sv.year,
    sv.level_code,
    sv.gc2_level_code,
    sv.sched_type,
    COUNT(*)                    AS pitches,
    COUNT(DISTINCT pv.sched_id) AS games,
    MIN(sv.sched_date)          AS first_date,
    MAX(sv.sched_date)          AS last_date
FROM Astros.Pitches_View  pv
JOIN Astros.Schedule_View sv ON sv.sched_id = pv.sched_id
JOIN Astros.Players       p  ON p.groundcontrol_id = pv.pitcher_id
WHERE p.first_name = @pitcher_first
  AND p.last_name  = @pitcher_last
  AND sv.sched_date >= DATEADD(YEAR, -1, GETDATE())
GROUP BY sv.year, sv.level_code, sv.gc2_level_code, sv.sched_type
ORDER BY sv.year DESC, sv.level_code, sv.sched_type;


-- =====================================================================
-- Step 3 — Per-game detail for the most recent ~30 IP window
-- Useful for previewing what the advance report will land on. Cumulative
-- IP shown so you can eyeball where the 30-IP boundary falls.
-- =====================================================================
WITH recent AS (
    SELECT
        sv.sched_date,
        sv.sched_type,
        sv.level_code,
        sv.gc2_level_code,
        pv.sched_id,
        sv.home_team_mlbam_id,
        sv.away_team_mlbam_id,
        COUNT(*) AS pitches,
        SUM(CASE WHEN pv.cur_event_id IS NOT NULL
            THEN CAST(ev.outs_after AS int) - CAST(ev.outs_before AS int)
            ELSE 0 END) / 3.0 AS ip
    FROM Astros.Pitches_View  pv
    JOIN Astros.Schedule_View sv ON sv.sched_id = pv.sched_id
    JOIN Astros.Players       p  ON p.groundcontrol_id = pv.pitcher_id
    LEFT JOIN Astros.Events_View ev
        ON pv.sched_id = ev.sched_id AND pv.cur_event_id = ev.event_id
    WHERE p.first_name = @pitcher_first
      AND p.last_name  = @pitcher_last
      AND sv.sched_date >= DATEADD(YEAR, -1, GETDATE())
      AND sv.level_code NOT IN ('nae','hsb','jcb')   -- advance-levels.md
      AND sv.sched_type IN ('R','S','E','I')
      AND pv.pitch_id > 0
    GROUP BY sv.sched_date, sv.sched_type, sv.level_code, sv.gc2_level_code,
             pv.sched_id, sv.home_team_mlbam_id, sv.away_team_mlbam_id
)
SELECT
    sched_date,
    level_code,
    sched_type,
    sched_id,
    pitches,
    CAST(ip AS DECIMAL(5,1)) AS ip,
    CAST(SUM(ip) OVER (ORDER BY sched_date DESC
                       ROWS UNBOUNDED PRECEDING) AS DECIMAL(6,1)) AS cum_ip
FROM recent
ORDER BY sched_date DESC;


-- =====================================================================
-- After confirming the data, run the one-off CLI:
--
--   python scripts/generate_advance_oneoff.py \
--       --pitcher-ids <gc_id_1> <gc_id_2> <gc_id_3> \
--       --first-name <first> --last-name <last> \
--       --throws <R|L> --mlbam-id <id_or_skip> \
--       --level <aaa|aax|afa|afx|rok>
-- =====================================================================
