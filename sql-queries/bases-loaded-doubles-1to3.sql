-- =============================================================================
-- Bases-Loaded Doubles where Runner on 1B Hustled to 3B (with Video)
-- =============================================================================
-- Finds every play in 2026 R games (all 7 levels) where:
--   1. Bases loaded BEFORE the play (runner_1b, runner_2b, runner_3b all set)
--   2. Batter DOUBLED (ev.[2b] = 1)
--   3. Runner who started on 1B ended on 3B (runner_3b_after = runner_1b)
--   4. Ball pulled to LF — hit_bearing <= -25 (catcher's view: negative
--      X = LF / 3B side, per .claude/rules/coordinates.md + tracking-schema.md)
--   5. EV under 100 mph — non-rocket doubles. A 105+ mph double to LF
--      gives the runner from 1B more time + a clearer read. Sub-100
--      keeps the comp tight on plays where the read/jump matters.
--
-- The bearing + EV filters narrow to "Yamal-style" reads only: ball into
-- LF or LF-CF gap, hit hard but not rocket-shot, where the runner from
-- 1B has a real read/decision on going to 3B. RF doubles are auto-3B
-- (long throw) and aren't comparable.
--
-- Returns one row per play with a 4-tier video fallback:
--   1. Video_Network 'M' (Main CF — preferred for viewing)
--   2. Astros.Video angle_id=1 (sporty-clips MLB-hosted, phone-safe)
--   3. Video_Network 'v' (alt CF backup)
--   4. Video_Network 'a' (alt CF broadcast, last-resort)
-- M-angle ingestion is inconsistent (RND coverage), so the canonical
-- V-column chain is wired in behind it. video_source column tells you
-- which tier resolved.
--
-- Born from the Apr 30 2026 Yamal Encarnacion case (AAX, 6th inning,
-- Mason Lytle 2B to LF Dylan Dreiling, runners scored from 2B + 3B,
-- Yamal made 3B from 1B). The 1->3 metric excludes this scenario by
-- design (single-only via CAST(ev.[1b] AS INT) = 1 gate).
-- =============================================================================

WITH bases_loaded_doubles AS (
    SELECT
        ev.sched_id,
        ev.event_id,
        sv.sched_date,
        sv.level_code,
        ev.inning,
        ev.top_of_inning,
        ev.event_result_id,
        ev.play_by_play,
        ev.runner_1b,
        ev.runner_2b,
        ev.runner_3b,
        ev.runner_1b_after,
        ev.runner_2b_after,
        ev.runner_3b_after,
        ev.first_defender_id,
        ev.lf_id, ev.cf_id, ev.rf_id
    FROM Astros.Events_View ev
    JOIN Astros.Schedule_View sv
        ON ev.sched_id = sv.sched_id
    WHERE sv.year = 2026
      AND sv.sched_type = 'R'
      AND sv.level_code IN ('mlb', 'aaa', 'aax', 'afa', 'afx', 'rok', 'dsl')
      AND CAST(ev.[2b] AS INT) = 1
      AND ev.runner_1b IS NOT NULL
      AND ev.runner_2b IS NOT NULL
      AND ev.runner_3b IS NOT NULL
      AND ev.runner_3b_after = ev.runner_1b
      -- Exclude ground-rule doubles: runner was AUTO-held at 3B by rule,
      -- not by choice. Doesn't show baserunning read/effort.
      AND ev.play_by_play NOT LIKE '%ground-rule double%'
      AND ev.play_by_play NOT LIKE '%ground rule double%'
)
SELECT
    bld.sched_date,
    bld.level_code,
    bld.inning,
    CASE bld.top_of_inning WHEN 1 THEN 'TOP' ELSE 'BOT' END AS half,

    -- Names (joined to Astros.Players for each id)
    p_batter.first_name  + ' ' + p_batter.last_name  AS batter_name,
    p_runner1.first_name + ' ' + p_runner1.last_name AS runner_1b_name,  -- the hustler
    p_runner2.first_name + ' ' + p_runner2.last_name AS runner_2b_name,
    p_runner3.first_name + ' ' + p_runner3.last_name AS runner_3b_name,
    p_def.first_name     + ' ' + p_def.last_name     AS first_defender_name,

    -- Where the ball was hit (LF / CF / RF, or OTHER if first_defender_id
    -- doesn't match an OF id — rare on doubles to OF but possible if the
    -- relay throw fielder is recorded as first_defender)
    CASE
        WHEN bld.first_defender_id = bld.rf_id THEN 'RF'
        WHEN bld.first_defender_id = bld.cf_id THEN 'CF'
        WHEN bld.first_defender_id = bld.lf_id THEN 'LF'
        ELSE 'OTHER'
    END AS first_defender_pos,

    bld.play_by_play,

    -- Where the ball was hit (raw bearing + distance from Astros.Hits)
    -- Bearing convention (catcher's view): 0 = CF straight up middle,
    -- negative = LF / 3B side, positive = RF / 1B side, ±45 = foul lines.
    h.hit_bearing,
    h.hit_distance,
    h.hit_exit_speed,

    -- 4-tier video fallback — Main CF angle FIRST, then canonical V chain.
    -- 1. Video_Network 'M'        (Main CF broadcast — user's preferred angle)
    -- 2. Astros.Video angle_id=1  (sporty-clips, player-phone safe)
    -- 3. Video_Network 'v'        (Astros internal CF backup)
    -- 4. Video_Network 'a'        (Astros internal CF, last-resort)
    -- See .claude/rules/visual-standards.md angle reference +
    --     .claude/rules/video-angles.md for the canonical V chain.
    ISNULL(vn_m.video_url,
      ISNULL(av.video_url,
        ISNULL(vn_v.video_url, vn_a.video_url))) AS video_url,

    CASE
        WHEN vn_m.video_url  IS NOT NULL THEN 'Video_Network M (Main CF)'
        WHEN av.video_url    IS NOT NULL THEN 'Astros.Video (sporty-clips)'
        WHEN vn_v.video_url  IS NOT NULL THEN 'Video_Network v (alt CF backup)'
        WHEN vn_a.video_url  IS NOT NULL THEN 'Video_Network a (alt CF broadcast)'
        ELSE '(no video)'
    END AS video_source,

    bld.sched_id,
    bld.event_id

FROM bases_loaded_doubles bld

-- Find the AB-ending pitch (the BIP) so we can join to Hits + Video tables
LEFT JOIN Astros.Pitches_View pv
    ON pv.sched_id = bld.sched_id
   AND pv.cur_event_id = bld.event_id
   AND pv.pitch_id > 0

-- Astros.Hits gives us hit_bearing for the LF-pulled contingency
JOIN Astros.Hits h
    ON h.sched_id = pv.sched_id
   AND h.pitch_id = pv.pitch_id
   AND h.hit_bearing <= -25      -- ball pulled to LF / LF-CF gap
   AND h.hit_exit_speed < 100    -- non-rocket doubles (tighter read for runner)

-- Video tables — M angle primary, full fallback chain behind it
LEFT JOIN Astros.Video_Network vn_m
    ON vn_m.sched_id = pv.sched_id
   AND vn_m.pitch_id = pv.pitch_id
   AND vn_m.angle = 'M'
LEFT JOIN Astros.Video av
    ON av.sched_id = pv.sched_id
   AND av.pitch_id = pv.pitch_id
   AND av.angle_id = 1
LEFT JOIN Astros.Video_Network vn_v
    ON vn_v.sched_id = pv.sched_id
   AND vn_v.pitch_id = pv.pitch_id
   AND vn_v.angle = 'v'
LEFT JOIN Astros.Video_Network vn_a
    ON vn_a.sched_id = pv.sched_id
   AND vn_a.pitch_id = pv.pitch_id
   AND vn_a.angle = 'a'

-- Player name lookups
LEFT JOIN Astros.Players p_batter
    ON p_batter.groundcontrol_id = pv.batter_id
LEFT JOIN Astros.Players p_runner1
    ON p_runner1.groundcontrol_id = bld.runner_1b
LEFT JOIN Astros.Players p_runner2
    ON p_runner2.groundcontrol_id = bld.runner_2b
LEFT JOIN Astros.Players p_runner3
    ON p_runner3.groundcontrol_id = bld.runner_3b
LEFT JOIN Astros.Players p_def
    ON p_def.groundcontrol_id = bld.first_defender_id

ORDER BY bld.sched_date DESC, h.hit_bearing ASC, bld.inning, bld.event_id;
-- Sort: newest first, then most-pulled-to-LF first (most-negative bearing).
