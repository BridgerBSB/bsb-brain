-- How is Xavier Neyens being pitched in 2026?
-- Per-pitch-type usage breakdown of every pitch he's seen.
--
-- Player: Xavier Neyens (gc_id 244959, A Fayetteville, 2026)
-- Scope:  R-season only, junk levels excluded.
-- Output: every pitch type he's faced + count + usage % + avg velo.

SELECT
    ISNULL(pv.pitch_type, 'UNK')                                   AS [Pitch],
    COUNT(*)                                                       AS [#],
    CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER () AS DECIMAL(5,1)) AS [Usage %],
    CAST(AVG(pv.release_speed) AS DECIMAL(5,1))                    AS [Avg Velo]
FROM Astros.Pitches_View pv
JOIN Astros.Schedule_View sv
    ON sv.sched_id = pv.sched_id
WHERE pv.batter_id = 244959
  AND sv.year = 2026
  AND sv.sched_type = 'R'
  AND sv.level_code NOT IN ('win','bbc','int','sum','nae','hsb','ind','jcb')
  AND pv.pitch_id > 0
GROUP BY pv.pitch_type
ORDER BY COUNT(*) DESC;
