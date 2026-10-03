-- R4_Draft_Query school_* columns — full exploration
-- Run each query separately to see what each column actually contains.

-- ============================================================================
-- Q1: Distinct (school_type, school_level) combos with COUNT
-- This shows whether school_level is academic class (JR/SR/etc.) or hides
-- conference-style codes (SEC/ACC/etc.).
-- ============================================================================
SELECT school_type, school_level, COUNT(*) AS n
FROM MLB_eBis.R4_Draft_Query
WHERE draft_year IN (2020, 2021, 2022, 2023, 2024, 2025)
  AND position NOT IN ('RHP','LHP','RHS','RHR','LHS','LHR','P','SHS','TWP')
GROUP BY school_type, school_level
ORDER BY n DESC;


-- ============================================================================
-- Q2: For each school_level value, show 10 sample school_names
-- This makes it immediately obvious whether school_level encodes conference
-- info or just academic class.
-- ============================================================================
WITH ranked AS (
    SELECT school_level, school_name, school_type,
           ROW_NUMBER() OVER (PARTITION BY school_level ORDER BY NEWID()) AS rn
    FROM MLB_eBis.R4_Draft_Query
    WHERE draft_year IN (2020, 2021, 2022, 2023, 2024, 2025)
      AND position NOT IN ('RHP','LHP','RHS','RHR','LHS','LHR','P','SHS','TWP')
)
SELECT school_level, school_type, school_name
FROM ranked
WHERE rn <= 10
ORDER BY school_level, school_name;


-- ============================================================================
-- Q3: ALL distinct school_names from 4YR drafts (2020-2025 hitters)
-- Use this to (a) verify the school_name format, (b) spot any Power-5
-- schools missing from our hardcoded dict.
-- ============================================================================
SELECT school_name, school_state, COUNT(*) AS n_drafted
FROM MLB_eBis.R4_Draft_Query
WHERE draft_year IN (2020, 2021, 2022, 2023, 2024, 2025)
  AND school_type = '4YR'
  AND position NOT IN ('RHP','LHP','RHS','RHR','LHS','LHR','P','SHS','TWP')
  AND school_name IS NOT NULL
GROUP BY school_name, school_state
ORDER BY n_drafted DESC;


-- ============================================================================
-- Q4: Sample raw rows for the Xavier Neyens cohort (HS first-round SS)
-- All columns. Confirms the whole row content.
-- ============================================================================
SELECT *
FROM MLB_eBis.R4_Draft_Query
WHERE draft_round = '1'
  AND position = 'SS'
  AND school_type = 'HS'
  AND draft_year IN (2020, 2021, 2022, 2023, 2024, 2025)
ORDER BY draft_year, overall_pick;


-- ============================================================================
-- Q5: Probe MLB_eBis.GBL_SCHTEAM — the school lookup table
-- school_id in R4_Draft_Query joins to this (per the diagnose output, GBL_SCHTEAM
-- is in MLB_eBis schema). May contain a conference column we can JOIN on.
-- ============================================================================
SELECT TOP 20 *
FROM MLB_eBis.GBL_SCHTEAM;


-- ============================================================================
-- Q6: GBL_SCHTEAM column inventory
-- ============================================================================
SELECT COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'MLB_eBis' AND TABLE_NAME = 'GBL_SCHTEAM'
ORDER BY ORDINAL_POSITION;
