---
name: tsql-union-orderby-alias
description: "T-SQL UNION/UNION ALL — ORDER BY can't reference a SELECT alias; wrap the union in a CTE/derived table and order the outer query"
metadata: 
  node_type: memory
  type: reference
  originSessionId: 0bfc755b-45b2-477b-a36a-f9af9b4ec50a
---

In SQL Server, an `ORDER BY` on a statement containing `UNION` / `UNION ALL` /
`INTERSECT` / `EXCEPT` **cannot reference a column alias** from the SELECT
(error: "Invalid column name 'X'" + "ORDER BY items must appear in the select
list if the statement contains a UNION..."). The ORDER BY binds to the combined
result, before aliases are visible.

**Fix:** wrap the whole union in a CTE (or derived table), then `SELECT * FROM
final ORDER BY CASE month WHEN ... END` — the outer query exposes the alias so
the ORDER BY (even a CASE expression) resolves cleanly. Ordering by ordinal
(`ORDER BY 1`) also works but is fragile.

Hit Jun 29 2026 building a Brutcher spray query (May/June Pull/Mid/Oppo % +
Delta row via `UNION ALL`, ordered by a `month` CASE). Common shape for any
"two periods + delta row" report. See [[brutcher-spray-poc-query]].
