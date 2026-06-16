---
name: T-SQL SUM+EXISTS prohibition
description: NEVER put EXISTS subquery inside SUM(CASE WHEN...) in T-SQL — move EXISTS to WHERE clause and aggregate pre-filtered rows
type: feedback
originSessionId: 41cba412-080d-468e-8ffd-4ad187149d66
---
NEVER write `SUM(CASE WHEN EXISTS (subquery) THEN 1 ELSE 0 END)` in T-SQL. SQL Server throws "Cannot perform an aggregate function on an expression containing an aggregate or a subquery."

**Why:** First attempt at the SB gate fix (Apr 10) used this pattern across 14 queries in 7 files. Broke every single baserunning report on the work laptop. Had to immediately rewrite all 14 queries.

**How to apply:** When you need to count rows that match a subquery condition, put EXISTS in the WHERE clause to pre-filter, then use simple COUNT(*)/SUM() on the result:

```sql
-- WRONG (T-SQL error):
SUM(CASE WHEN EXISTS (SELECT 1 FROM ...) THEN 1 ELSE 0 END)

-- RIGHT:
SELECT COUNT(*) FROM table WHERE ... AND EXISTS (SELECT 1 FROM ...)
```

This applies to ANY correlated subquery inside an aggregate — not just EXISTS. Also covers IN, scalar subqueries, etc. Always filter first, aggregate second.

**Confirmed again Apr 23 2026:** Same error on `SUM(CASE WHEN pitch_result_id IN (SELECT id FROM @codes_table_var) THEN 1 ELSE 0 END)` — table variables as IN-source inside SUM also trigger the error. Same fix: inline the codes as a literal IN list, `SUM(CASE WHEN col IN (3,6,24,...) THEN 1 ELSE 0 END)`. Don't use @table_variables or CTEs as an IN source inside an aggregate.
