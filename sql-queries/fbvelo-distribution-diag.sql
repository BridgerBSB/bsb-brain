-- Diagnostic: show release_speed distribution at FCL/ACL + DSL by year,
-- including counts above plausible thresholds. Run this to confirm which
-- year(s) have tracker-error outliers and how many rows are affected.

SELECT
    YEAR(sv.sched_date)                                       AS yr,
    CASE WHEN sv.gc2_level_code = 'rok' THEN 'FCL/ACL'
         WHEN sv.gc2_level_code = 'dsl' THEN 'DSL'
         ELSE sv.gc2_level_code
    END                                                       AS lvl,
    COUNT(*)                                                  AS n_pitches,
    CAST(MIN(pv.release_speed) AS DECIMAL(5,1))               AS min_v,
    CAST(MAX(pv.release_speed) AS DECIMAL(5,1))               AS max_v,
    CAST(AVG(pv.release_speed) AS DECIMAL(5,1))               AS avg_v_raw,
    CAST(AVG(CASE WHEN pv.release_speed BETWEEN 60 AND 110
                  THEN pv.release_speed END) AS DECIMAL(5,1)) AS avg_v_clean,
    SUM(CASE WHEN pv.release_speed > 110 THEN 1 ELSE 0 END)   AS n_over_110,
    SUM(CASE WHEN pv.release_speed > 105 THEN 1 ELSE 0 END)   AS n_over_105,
    SUM(CASE WHEN pv.release_speed > 120 THEN 1 ELSE 0 END)   AS n_over_120,
    SUM(CASE WHEN pv.release_speed > 150 THEN 1 ELSE 0 END)   AS n_over_150,
    SUM(CASE WHEN pv.release_speed < 60  THEN 1 ELSE 0 END)   AS n_below_60
FROM Astros.Pitches_View pv
JOIN Astros.Schedule_View sv
    ON sv.sched_id = pv.sched_id
WHERE sv.year IN (2023, 2024, 2025)
  AND sv.sched_type = 'R'
  AND sv.gc2_level_code IN ('rok','dsl')
  AND pv.pitch_type IN ('FF','FT','SI')
  AND pv.release_speed IS NOT NULL
  AND pv.pitch_id > 0
GROUP BY YEAR(sv.sched_date), sv.gc2_level_code
ORDER BY lvl, yr;
