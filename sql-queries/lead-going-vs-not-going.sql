-- Lead comparison: runner_going=0 (normal) vs runner_going=1 (stealing)
-- Shows PL and SL from 1B and 2B, with sample sizes
-- Run on work laptop against GCSQL02

SELECT
    '1B' AS base,
    'Normal (not going)' AS lead_type,
    COUNT(*) AS n_pitches,
    ROUND(AVG(pbl.primary_distance_from_occupied_base), 2) AS avg_pl,
    ROUND(AVG(pbl.secondary_distance_from_occupied_base - pbl.primary_distance_from_occupied_base), 2) AS avg_sl,
    ROUND(AVG(pbl.secondary_distance_from_occupied_base), 2) AS avg_tl
FROM Astros.Pitches_Baserunner_Leads pbl
JOIN Astros.Schedule_View sv ON pbl.sched_id = sv.sched_id
WHERE pbl.occupied_base = 1
  AND pbl.runner_going = 0
  AND pbl.ignore_flag = 0
  AND pbl.closest_fielder_distance_to_occupied_base <= 10
  AND sv.year = 2026 AND sv.sched_type = 'R'
  AND sv.level_code IN ('aaa','aax','afa','afx')

UNION ALL

SELECT
    '1B', 'Stealing (going)',
    COUNT(*),
    ROUND(AVG(pbl.primary_distance_from_occupied_base), 2),
    ROUND(AVG(pbl.secondary_distance_from_occupied_base - pbl.primary_distance_from_occupied_base), 2),
    ROUND(AVG(pbl.secondary_distance_from_occupied_base), 2)
FROM Astros.Pitches_Baserunner_Leads pbl
JOIN Astros.Schedule_View sv ON pbl.sched_id = sv.sched_id
WHERE pbl.occupied_base = 1
  AND pbl.runner_going = 1
  AND pbl.ignore_flag = 0
  AND pbl.closest_fielder_distance_to_occupied_base <= 10
  AND sv.year = 2026 AND sv.sched_type = 'R'
  AND sv.level_code IN ('aaa','aax','afa','afx')

UNION ALL

SELECT
    '2B', 'Normal (not going)',
    COUNT(*),
    ROUND(AVG(pbl.primary_distance_from_occupied_base), 2),
    ROUND(AVG(pbl.secondary_distance_from_occupied_base - pbl.primary_distance_from_occupied_base), 2),
    ROUND(AVG(pbl.secondary_distance_from_occupied_base), 2)
FROM Astros.Pitches_Baserunner_Leads pbl
JOIN Astros.Schedule_View sv ON pbl.sched_id = sv.sched_id
WHERE pbl.occupied_base = 2
  AND pbl.runner_going = 0
  AND pbl.ignore_flag = 0
  AND sv.year = 2026 AND sv.sched_type = 'R'
  AND sv.level_code IN ('aaa','aax','afa','afx')

UNION ALL

SELECT
    '2B', 'Stealing (going)',
    COUNT(*),
    ROUND(AVG(pbl.primary_distance_from_occupied_base), 2),
    ROUND(AVG(pbl.secondary_distance_from_occupied_base - pbl.primary_distance_from_occupied_base), 2),
    ROUND(AVG(pbl.secondary_distance_from_occupied_base), 2)
FROM Astros.Pitches_Baserunner_Leads pbl
JOIN Astros.Schedule_View sv ON pbl.sched_id = sv.sched_id
WHERE pbl.occupied_base = 2
  AND pbl.runner_going = 1
  AND pbl.ignore_flag = 0
  AND sv.year = 2026 AND sv.sched_type = 'R'
  AND sv.level_code IN ('aaa','aax','afa','afx')

ORDER BY base, lead_type DESC
