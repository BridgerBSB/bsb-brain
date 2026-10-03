-- HS first-round shortstops (Xavier Neyens cohort) — all R4_Draft_Query columns
-- Returns every column for SS drafted in round 1 from HS, 2020-2025.
-- Use this to inspect what data we actually have before designing a query.

SELECT *
FROM MLB_eBis.R4_Draft_Query
WHERE draft_round = '1'
  AND position = 'SS'
  AND school_type = 'HS'
  AND draft_year IN (2020, 2021, 2022, 2023, 2024, 2025)
ORDER BY draft_year, overall_pick;

-- Variants:
-- All shortstops (incl. college): drop "AND school_type = 'HS'"
-- Just college SS: change "= 'HS'" to "= '4YR'"
-- Wider draft window: add years to the IN clause
-- Top 10 picks only: AND TRY_CAST(overall_pick AS INT) <= 10
