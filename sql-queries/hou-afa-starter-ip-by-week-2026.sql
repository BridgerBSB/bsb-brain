-- ============================================================================
-- HOU AFA Starter Avg IP — Week by Week from 2026-04-01 (weeks end Monday)
-- ============================================================================
-- Sibling to hou-starter-ip-by-affiliate-2026.sql, scoped to AFA (A+
-- Asheville) only, bucketed by Tue–Mon weeks.
--
-- Week boundaries: each row's week_end is the Monday on/after sched_date.
--   week 1 = 2026-04-01 (Wed) through 2026-04-06 (Mon)  — 6 days, partial
--   week 2 = 2026-04-07 (Tue) through 2026-04-13 (Mon)  — 7 days
--   week 3 = 2026-04-14 (Tue) through 2026-04-20 (Mon)  — 7 days
--   ...
--
-- Anchor Monday for the modulo: '2026-01-05' (a known Monday before scope).
-- Formula: DATEADD(day, (7 - DATEDIFF(day, ANCHOR_MON, sched_date) % 7) % 7, sched_date)
--   → returns the Monday on/after sched_date.
--
-- Starter detection + IP source: same as parent (first-pitch detection +
-- MLBAM.Gamelog_Pitching.outs). Baseball notation display via canonical
-- outs_int/3 + "." + outs_int%3.
-- ============================================================================

DECLARE @season    INT  = 2026;
DECLARE @start_dt  DATE = '2026-04-01';

WITH starters AS (
    SELECT sched_id, pitcher_id, top_of_inning
    FROM (
        SELECT pv.sched_id, pv.pitcher_id, ev.top_of_inning,
               ROW_NUMBER() OVER (
                   PARTITION BY pv.sched_id, ev.top_of_inning
                   ORDER BY pv.game_pitch_number
               ) AS rn
        FROM Astros.Pitches_View pv
        JOIN Astros.Schedule_View sv ON sv.sched_id = pv.sched_id
        JOIN Astros.Events_View ev
            ON ev.sched_id = pv.sched_id AND ev.event_id = pv.ab_event_id
        WHERE sv.year       = @season
          AND sv.sched_type = 'R'
          AND sv.level_code = 'afa'
          AND sv.sched_date >= @start_dt
          AND pv.pitch_id > 0
          AND ev.inning = 1
    ) t
    WHERE rn = 1
),
hou_starts AS (
    SELECT
        -- Monday on/after sched_date (Tue–Mon week, ending Monday)
        DATEADD(day,
            (7 - DATEDIFF(day, '2026-01-05', sv.sched_date) % 7) % 7,
            sv.sched_date)        AS week_end,
        s.sched_id,
        s.pitcher_id              AS gc_id,
        sv.sched_date,
        glp.outs
    FROM starters s
    JOIN Astros.Players ap         ON ap.groundcontrol_id = s.pitcher_id
    JOIN Astros.Schedule_View sv   ON sv.sched_id = s.sched_id
    JOIN MLBAM.Gamelog_Pitching glp
        ON glp.game_pk  = sv.mlbam_game_pk
       AND glp.player_id = ap.mlbam_id
    JOIN MLBAM.Teams bt
        ON bt.team_id   = glp.team_id
       AND bt.season    = sv.year
    WHERE bt.org_abbrev = 'HOU'
      AND glp.outs IS NOT NULL
),
stats AS (
    SELECT
        week_end,
        COUNT(*)                 AS n_starts,
        COUNT(DISTINCT gc_id)    AS n_unique_starters,
        SUM(outs)                AS total_outs,
        AVG(CAST(outs AS float)) AS avg_outs
    FROM hou_starts
    GROUP BY week_end
),
ip_calc AS (
    SELECT *,
        -- Week start = Tuesday before week_end, clipped to @start_dt for week 1
        CASE WHEN DATEADD(day, -6, week_end) < @start_dt
             THEN @start_dt
             ELSE DATEADD(day, -6, week_end)
        END AS week_start,
        ROW_NUMBER() OVER (ORDER BY week_end) AS week_num,
        CAST(ROUND(avg_outs, 0) AS INT)       AS avg_outs_int
    FROM stats
)
SELECT
    week_num,
    week_start,
    week_end,
    n_starts,
    n_unique_starters,
    total_outs,
    CAST(avg_outs AS DECIMAL(5,2))                       AS avg_outs,
    CAST(avg_outs_int / 3 AS varchar(3))
        + '.'
        + CAST(avg_outs_int % 3 AS varchar(1))           AS avg_ip,
    CAST(total_outs / 3 AS varchar(4))
        + '.'
        + CAST(total_outs % 3 AS varchar(1))             AS tot_ip
FROM ip_calc
ORDER BY week_num;

-- ============================================================================
-- Per-start detail (uncomment to see each individual AFA start in order)
-- ============================================================================
-- SELECT
--     DATEADD(day,
--         (7 - DATEDIFF(day, '2026-01-05', hs.sched_date) % 7) % 7,
--         hs.sched_date)                 AS week_end,
--     hs.sched_date,
--     hs.gc_id,
--     p.full_name,
--     hs.outs,
--     CAST(hs.outs / 3 AS varchar(2)) + '.'
--         + CAST(hs.outs % 3 AS varchar(1)) AS ip
-- FROM hou_starts hs
-- LEFT JOIN Astros.Players p ON p.groundcontrol_id = hs.gc_id
-- ORDER BY hs.sched_date, hs.gc_id;
