-- MLB player-seasons with Contact% <= 63% (min 50 PA), 2018 onward
-- =====================================================================
-- One row per (player, season) at the MLB level where the hitter made
-- contact on 63% or fewer of his swings, with at least 50 PA that season.
--
-- Contact% = (swings - whiffs) / swings   [canonical tracker definition,
--   = 1 - Whiff%]. WHIFF_CODES = (10,16,21,22,23,25); swing flag includes
--   the ignore_flag recovery clause (pitfalls.md). Pitch-level metric, so
--   driven FROM Pitches_View. PA is the event-anchored count (cur_event_id),
--   IBB included.
--
-- Interpretation note (flag if Ricky/Sam meant otherwise):
--   * "50PA<" read as a MINIMUM of 50 PA (pa >= 50).
--   * Contact% threshold is <= 63.0.
--   * HITTERS ONLY — pitchers' batting lines excluded (see mlb_pitchers CTE).
--   * All 30 MLB teams (no org filter). Regular season only.
--   Sorted lowest-contact first.
--
-- Caveat: requires Astros DB MLB pitch tracking back to 2018 (it has it).

WITH pitch_agg AS (
    -- Per (batter, season) swings + whiffs at MLB
    SELECT
        pv.batter_id,
        sv.year AS season,
        SUM(CASE WHEN (pv.did_swing = 1
                       OR (pv.ignore_flag = 1 AND pv.did_swing IS NULL
                           AND pv.pitch_result_id IN (7,8,9,10,12,13,14,16,18,19,20,21,22,23,25)))
                 THEN 1 ELSE 0 END) AS swings,
        SUM(CASE WHEN pv.pitch_result_id IN (10,16,21,22,23,25) THEN 1 ELSE 0 END) AS whiffs
    FROM Astros.Pitches_View pv
    JOIN Astros.Schedule_View sv ON pv.sched_id = sv.sched_id
    WHERE sv.level_code = 'mlb'
      AND sv.sched_type = 'R'
      AND sv.year >= 2018
      AND pv.pitch_id > 0
    GROUP BY pv.batter_id, sv.year
),
pa_agg AS (
    -- Per (batter, season) PA at MLB (event-anchored, IBB included)
    SELECT
        pv.batter_id,
        sv.year AS season,
        SUM(CAST(ev.pa AS int)) + SUM(CAST(ISNULL(ev.ibb, 0) AS int)) AS pa
    FROM Astros.Events_View ev
    JOIN Astros.Schedule_View sv ON ev.sched_id = sv.sched_id
    JOIN Astros.Pitches_View pv
        ON ev.sched_id = pv.sched_id AND ev.event_id = pv.cur_event_id
    WHERE sv.level_code = 'mlb'
      AND sv.sched_type = 'R'
      AND sv.year >= 2018
      AND pv.batter_id IS NOT NULL
      AND pv.pitch_id > 0
    GROUP BY pv.batter_id, sv.year
),
mlb_pitchers AS (
    -- (player, season) where the player threw >= 100 pitches at MLB.
    -- Real pitchers throw hundreds+/season; a position player's emergency
    -- mound appearance is ~15-30 pitches, so 100 cleanly separates them.
    -- Used to drop pitchers' batting lines (NL pitcher-hitting 2018-2021).
    -- (A true two-way like Ohtani is also excluded, but his contact% is
    --  far above 63% so he'd never appear on this list anyway.)
    SELECT pv.pitcher_id AS player_id, sv.year AS season
    FROM Astros.Pitches_View pv
    JOIN Astros.Schedule_View sv ON pv.sched_id = sv.sched_id
    WHERE sv.level_code = 'mlb'
      AND sv.sched_type = 'R'
      AND sv.year >= 2018
      AND pv.pitch_id > 0
    GROUP BY pv.pitcher_id, sv.year
    HAVING COUNT(*) >= 100
),
joined AS (
    -- Compute contact_pct ONCE with NULLIF, so there is no raw division
    -- left in any WHERE predicate (SQL Server doesn't guarantee predicate
    -- order, so a `/ swings` in WHERE can divide by zero before `swings > 0`
    -- filters the row). NULLIF -> NULL -> excluded by the <= 63 filter below.
    SELECT
        r.first_name + ' ' + r.last_name AS player,
        pa.season,
        pa.pa,
        pi.swings,
        pi.whiffs,
        100.0 * (pi.swings - pi.whiffs) / NULLIF(pi.swings, 0) AS contact_pct
    FROM pa_agg pa
    JOIN pitch_agg pi ON pi.batter_id = pa.batter_id AND pi.season = pa.season
    JOIN Astros.Players r ON r.groundcontrol_id = pa.batter_id
    WHERE pa.pa >= 50
      AND pi.swings > 0
      -- hitters only: drop any (player, season) where the player pitched
      AND NOT EXISTS (
          SELECT 1 FROM mlb_pitchers mp
          WHERE mp.player_id = pa.batter_id AND mp.season = pa.season
      )
)
SELECT
    player,
    season,
    pa,
    swings,
    whiffs,
    CAST(contact_pct AS decimal(5,1)) AS contact_pct
FROM joined
WHERE contact_pct <= 63.0
ORDER BY contact_pct ASC, season DESC;
