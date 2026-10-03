-- ============================================================================
-- DIAGNOSIS: why Hunter Brown (gc 95843) is NOT in the Low-A FF/2S usage list.
-- ----------------------------------------------------------------------------
-- Hypothesis: he NEVER pitched at Low-A (afx). His pre-AA time was SHORT-SEASON
-- A ("A-", the old Tri-City / NY-Penn level), which (a) is a DIFFERENT level than
-- Single-A / Low-A, and (b) does not exist as a level_code in this DB at all
-- (retired after 2020). So an afx-only query finds zero rows for him -> excluded.
-- A- and A are NOT the same level: A- = short-season, A = full-season Single-A.
--
-- Run both sections. Expect: Section A shows NO 'afx' rows; Section B shows his
-- actual levels (likely 'asx' = short-season A, then 'afa'=High-A, 'aax'=AA, mlb).
-- ============================================================================

-- A) TRACKED pitches in GC2 by level + year (this is the exact source the
--    usage% query reads). If there's no 'afx' row here, he can't be in the list.
SELECT  sv.gc2_level_code               AS level_code,
        sv.year,
        COUNT(*)                        AS pitches,
        SUM(CASE WHEN pv.pitch_type IS NOT NULL THEN 1 ELSE 0 END) AS classified
FROM    Astros.Pitches_View  pv
JOIN    Astros.Schedule_View sv ON sv.sched_id = pv.sched_id
WHERE   pv.pitcher_id = 95843            -- Hunter Brown
  AND   pv.pitch_id  > 0
GROUP BY sv.gc2_level_code, sv.year
ORDER BY sv.year, level_code;

-- B) OFFICIAL season pitching lines by level (covers years with NO pitch
--    tracking too) — shows WHERE he actually pitched in the minors.
SELECT  yp.season,
        yp.level,
        SUM(CAST(yp.gs   AS int))       AS gs,
        SUM(CAST(yp.outs AS int))       AS outs,
        CAST(SUM(CAST(yp.outs AS int)) / 3.0 AS decimal(5,1)) AS ip
FROM    mlbam.ytd_player_pitching_stats yp
WHERE   yp.player_id = (SELECT mlbam_id FROM Astros.Players WHERE groundcontrol_id = 95843)
  AND   yp.gm_type  = 'r'
  AND   yp.split_id = 0
GROUP BY yp.season, yp.level
ORDER BY yp.season, yp.level;
