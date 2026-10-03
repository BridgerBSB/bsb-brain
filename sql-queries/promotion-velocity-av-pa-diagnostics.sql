-- =========================================================================
-- promotion-velocity-av-pa-diagnostics.sql
-- Resolve 3 issues found 2026-06: (1) pitcher AV dedup, (2) PA/IP must match
-- GC2's official stat page (not pitch-by-pitch), (3) Trammell censored/yo-yo.
-- Players: Bryce Mayer 176229 (P), Kevin Alvarez 213722 (H, AV verified),
--          Taylor Trammell 73618 (H, $7M off + 1314 AAA), Yordan 75884 (PA off).
-- =========================================================================
SET NOCOUNT ON;

-- =========================================================================
-- ISSUE 1 — AV rollup (learn GC2's exact formula incl. pitcher SP/RP)
-- =========================================================================
-- 1a. Raw rows at latest snapshot for all 3 + Kevin. Eyeball SP/RP per season.
;WITH latest AS (
    SELECT groundcontrol_id, MAX(date_generated) AS d
    FROM Player_Val.Asset_Value
    WHERE groundcontrol_id IN (176229, 213722, 73618)
    GROUP BY groundcontrol_id
)
SELECT av.groundcontrol_id, av.season, av.pos,
       CAST(av.mkt_sv AS decimal(18,0)) AS mkt_sv, av.salary
FROM Player_Val.Asset_Value av
JOIN latest l ON l.groundcontrol_id = av.groundcontrol_id AND l.d = av.date_generated
ORDER BY av.groundcontrol_id, av.season, av.pos;

-- 1b. Candidate rollups per player (compare each to GC2's displayed AV):
--     GC2: Mayer 21.3M, Kevin 3.8M (sum_all matched), Trammell ~31.2M (we got 38.2).
;WITH latest AS (
    SELECT groundcontrol_id, MAX(date_generated) AS d
    FROM Player_Val.Asset_Value
    WHERE groundcontrol_id IN (176229, 213722, 73618)
    GROUP BY groundcontrol_id
),
snap AS (
    SELECT av.groundcontrol_id, av.season, av.pos, av.mkt_sv
    FROM Player_Val.Asset_Value av
    JOIN latest l ON l.groundcontrol_id = av.groundcontrol_id AND l.d = av.date_generated
),
per_season_max AS (
    SELECT groundcontrol_id, season, MAX(mkt_sv) AS season_max
    FROM snap GROUP BY groundcontrol_id, season
)
SELECT s.groundcontrol_id,
       CAST(SUM(s.mkt_sv)/1e6 AS decimal(10,2))                                  AS sum_all_rows_M,
       (SELECT CAST(SUM(season_max)/1e6 AS decimal(10,2)) FROM per_season_max p
         WHERE p.groundcontrol_id = s.groundcontrol_id)                          AS sum_seasonmax_M,  -- our current (38.2 for Mayer)
       CAST(SUM(CASE WHEN s.pos = 'SP' THEN s.mkt_sv END)/1e6 AS decimal(10,2))  AS sum_SP_M,
       CAST(SUM(CASE WHEN s.pos = 'RP' THEN s.mkt_sv END)/1e6 AS decimal(10,2))  AS sum_RP_M,
       CAST(SUM(CASE WHEN s.pos NOT IN ('SP','RP') THEN s.mkt_sv END)/1e6 AS decimal(10,2)) AS sum_pos_M,
       COUNT(DISTINCT s.pos) AS n_distinct_pos
FROM snap s
GROUP BY s.groundcontrol_id;
--  >>> Which column equals GC2's number? That's the rollup we adopt.
--      (If Mayer's GC2 21.3 == sum_SP_M or sum_RP_M -> GC2 uses one consistent role.)


-- =========================================================================
-- ISSUE 2 — Official PA source (match GC2 stat page, not Pitches_View)
-- =========================================================================
-- 2a. Columns of the official season-stats table GC2 shows.
SELECT COLUMN_NAME, DATA_TYPE FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'MLBAM' AND TABLE_NAME = 'YTD_Player_Batting_Stats'
ORDER BY ORDINAL_POSITION;

-- 2b. Is there a per-GAME official batting gamelog? (needed for date-windowing yo-yo guys)
SELECT TABLE_SCHEMA, TABLE_NAME FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_NAME LIKE '%Gamelog%Bat%' OR TABLE_NAME LIKE '%Bat%Gamelog%'
ORDER BY TABLE_SCHEMA, TABLE_NAME;

-- 2c. Yordan (75884) official per-level/year PA vs our Pitches_View count.
--     EDIT column names from 2a if 'pa'/'level'/'season' differ (some YTD tables
--     use sport_code / a level id). Goal: confirm DSL=57, A=139, etc. match GC2.
-- SELECT yb.season, yb.<level_col> AS lvl, SUM(yb.pa) AS official_pa
-- FROM MLBAM.YTD_Player_Batting_Stats yb
-- JOIN Astros.Players p ON p.mlbam_id = yb.player_id
-- WHERE p.groundcontrol_id = 75884
-- GROUP BY yb.season, yb.<level_col>
-- ORDER BY yb.season, lvl;

-- 2d. Our current (pitch-derived) PA for Yordan by level — to show the gap.
SELECT sv.gc2_level_code AS level_code, sv.year,
       SUM(CAST(ev.pa AS int)) + SUM(CAST(ISNULL(ev.ibb,0) AS int)) AS our_pa
FROM Astros.Pitches_View pv
JOIN Astros.Schedule_View sv ON pv.sched_id = sv.sched_id
JOIN Astros.Events_View ev ON ev.sched_id = pv.sched_id AND pv.cur_event_id = ev.event_id
WHERE pv.batter_id = 75884
  AND sv.sched_type = 'R' AND pv.pitch_id > 0
  AND sv.gc2_level_code IN ('dsl','rok','afx','afa','aax','aaa','mlb')
GROUP BY sv.gc2_level_code, sv.year
ORDER BY sv.year, level_code;


-- =========================================================================
-- ISSUE 3 — Trammell (73618): why censored at AAA + yo-yo windowing
-- =========================================================================
-- 3a. Per-level first/last date + game count + our PA. Confirms MLB IS reached
--     (so AAA should NOT be censored) and shows the multi-stint AAA spread.
SELECT sv.gc2_level_code AS level_code,
       MIN(sv.sched_date) AS first_game,
       MAX(sv.sched_date) AS last_game,
       COUNT(DISTINCT sv.sched_id) AS n_games,
       SUM(CAST(ev.pa AS int)) + SUM(CAST(ISNULL(ev.ibb,0) AS int)) AS our_pa
FROM Astros.Pitches_View pv
JOIN Astros.Schedule_View sv ON pv.sched_id = sv.sched_id
JOIN Astros.Events_View ev ON ev.sched_id = pv.sched_id AND pv.cur_event_id = ev.event_id
WHERE pv.batter_id = 73618
  AND sv.sched_type = 'R' AND pv.pitch_id > 0
  AND sv.gc2_level_code IN ('dsl','rok','afx','afa','aax','aaa','mlb')
GROUP BY sv.gc2_level_code
ORDER BY MIN(sv.sched_date);
--  >>> If 'mlb' first_game is AFTER 'aaa' first_game with our_pa >= 10, the detector
--      should NOT censor AAA. If it does, the bug is in the rehab/jump logic.

-- 3b. Trammell rehab/injury txns (the ±21d exclusion that may be wrongly killing
--     his MLB call-up detection).
SELECT h.TRANSACTION_DTSTMP, h.TRANSACTIONNAME_LK, lk.transactionname, lk.category
FROM MLB_eBis.TR_HISTORY h
JOIN MLB_eBis.TR_NAME_LKUP lk ON lk.transactionname_lk = h.TRANSACTIONNAME_LK
JOIN Astros.Players p ON p.ebis_id = h.PLAYER_ID
WHERE p.groundcontrol_id = 73618
  AND (h.TRANSACTIONNAME_LK IN ('7RH','15R','60R','REHAB','RHBRT') OR lk.category LIKE 'Injury%')
ORDER BY h.TRANSACTION_DTSTMP;
