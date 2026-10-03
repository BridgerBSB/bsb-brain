---
tags:
  - reference
  - db
  - sql
  - baseball
created: '2026-06-29'
source: codebase audit 2026-06-29
---
# DB gotcha: DSL & FCL live in `gc2_level_code`, NOT `level_code`

In the Astros `Schedule_View` (`sv`), the **full-season** affiliate levels are in
`sv.level_code` (`'mlb','aaa','aax','afa','afx'`), but **DSL and FCL/Rookie are only in
`sv.gc2_level_code`** as `'dsl'` and `'rok'`. A query that filters
`level_code IN (...,'dsl','rok')` returns **zero** complex-level rows silently.

**Correct filter (the established pattern — appears in pd-engine, arm 25vs26.sql,
injury_tracker, paa_eo_matrix, csc_balls_vs_bb_rate):**
```sql
AND (sv.level_code IN ('mlb','aaa','aax','afa','afx')
     OR sv.gc2_level_code IN ('dsl','rok'))
```
Unified level expression:
```sql
CASE WHEN sv.gc2_level_code IN ('dsl','rok') THEN sv.gc2_level_code
     WHEN sv.gc2_level_code = 'asx' THEN 'afx'   -- short-season A normalizes to A
     ELSE sv.level_code END
```

**Two different code worlds — don't mix them:**
- **gc2 / MLBAM world** (Pitches_View / Schedule_View, what the modeling uses): `dsl`, `rok`, `afx`, `afa`, `aax`, `aaa`, `mlb`.
- **EBIS / roster world** (`LEVELOFPLAY_LK`, `sport_code`): DSL=`ds`, FCL=`r`, A=`1f`/`1a`, AA=`2a`, AAA=`3a`, MLB=`ml`. (`score_active_roster.py` excludes `{ml,ds,r}` using THIS world.)

Used by: [[promotion-release-models]] (adding DSL/FCL to the promote model). See
`sql/09_promote_ready.sql`.
