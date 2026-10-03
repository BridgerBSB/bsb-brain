-- Probe MLB_eBis.GBL_SCHTEAM.LEAGUENAME for known Power-5 schools.
-- If it's a clean SEC/ACC/Big 10/Big 12 value, we can JOIN on school_id
-- instead of hardcoding the school_name → conference dict.

-- Q1: LEAGUENAME for top-20 most-drafted schools (2020-2025 4YR hitters)
WITH top_schools AS (
    SELECT TOP 30 d.school_id, d.school_name, COUNT(*) AS n_drafted
    FROM MLB_eBis.R4_Draft_Query d
    WHERE d.draft_year IN (2020, 2021, 2022, 2023, 2024, 2025)
      AND d.school_type = '4YR'
      AND d.position NOT IN ('RHP','LHP','RHS','RHR','LHS','LHR','P','SHS','TWP')
      AND d.school_id IS NOT NULL
    GROUP BY d.school_id, d.school_name
    ORDER BY n_drafted DESC
)
SELECT t.school_name, t.n_drafted, g.LEAGUENAME, g.STATE_LK, g.CITY
FROM top_schools t
LEFT JOIN MLB_eBis.GBL_SCHTEAM g
    ON g.SCHTEAM_ID = t.school_id
ORDER BY t.n_drafted DESC;


-- Q2: Distinct LEAGUENAME values across all 4YR-drafted schools
SELECT g.LEAGUENAME, COUNT(DISTINCT t.school_id) AS n_schools, COUNT(*) AS n_drafted
FROM MLB_eBis.R4_Draft_Query t
LEFT JOIN MLB_eBis.GBL_SCHTEAM g ON g.SCHTEAM_ID = t.school_id
WHERE t.draft_year IN (2020, 2021, 2022, 2023, 2024, 2025)
  AND t.school_type = '4YR'
  AND t.position NOT IN ('RHP','LHP','RHS','RHR','LHS','LHR','P','SHS','TWP')
GROUP BY g.LEAGUENAME
ORDER BY n_drafted DESC;
