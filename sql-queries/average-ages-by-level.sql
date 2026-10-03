-- Average Ages: Astros vs All 30 Orgs at Each MiLB Level
-- Uses PP_MASTER for org/level assignment + Players for birthdate
-- Age: one decimal, FLOOR (never rounds up) — per project standard
-- Filters: ACT roster only, excludes 'boc' junk org and NULL orgs
-- Levels: 3A=AAA, 2A=AA, 1A=A+, 1F=A, R=FCL, DS=DSL
-- Point-in-time query — age and roster reflect GETDATE()
-- Rank: 1 = youngest at that level (lower = better)

WITH org_ages AS (
    SELECT
        pm.ORG_LK                      AS org,
        LOWER(pm.LEVELOFPLAY_LK)       AS level_code,
        COUNT(*)                        AS n_players,
        CAST(FLOOR(AVG(
            FLOOR(DATEDIFF(day, p.birthdate, GETDATE()) * 10.0 / 365.25) / 10.0
        ) * 10.0) / 10.0 AS decimal(4,1))  AS avg_age
    FROM MLB_eBis.PP_MASTER pm
    JOIN Astros.Players p
        ON p.ebis_id = pm.PLAYER_ID
    WHERE pm.LEVELOFPLAY_LK IN ('3A','2A','1A','1F','R','DS')
      AND pm.MNROSTERSTATUS_LK = 'ACT'
      AND pm.ORG_LK <> 'boc'
      AND pm.ORG_LK IS NOT NULL
      AND p.birthdate IS NOT NULL
    GROUP BY pm.ORG_LK, pm.LEVELOFPLAY_LK
),
ranked AS (
    SELECT
        org,
        level_code,
        avg_age,
        RANK() OVER (PARTITION BY level_code ORDER BY avg_age ASC) AS age_rank
    FROM org_ages
)
SELECT
    r.level_code,
    hou.avg_age                                                                 AS hou_avg_age,
    hou.age_rank                                                                AS rank,
    CAST(FLOOR(AVG(r.avg_age) * 10.0) / 10.0 AS decimal(4,1))                  AS level_avg_age,
    CAST(FLOOR((hou.avg_age - AVG(r.avg_age)) * 10.0) / 10.0 AS decimal(4,1))  AS age_diff
FROM ranked r
LEFT JOIN ranked hou
    ON hou.level_code = r.level_code
    AND hou.org = 'hou'
GROUP BY r.level_code, hou.avg_age, hou.age_rank
ORDER BY
    CASE r.level_code
        WHEN '3a' THEN 1 WHEN '2a' THEN 2
        WHEN '1a' THEN 3 WHEN '1f' THEN 4
        WHEN 'r'  THEN 5 WHEN 'ds' THEN 6
    END;
