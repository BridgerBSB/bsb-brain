---
name: pyodbc IN-clause tuples → TVP error
description: NEVER use `IN :param` with a tuple/list in this codebase's SQL queries. pyodbc treats it as a Table-Valued Parameter request (different SQL Server feature) and crashes with "A TVP's rows must be Sequence objects."
type: feedback
originSessionId: ab66b0ed-b07c-45a1-9036-65c1fb626353
---
NEVER pass a tuple or list as a parameter to a SQL `IN` clause in this
codebase. pyodbc + SQL Server interpret `IN :param` with a sequence as a
**Table-Valued Parameter (TVP)** request — a separate SQL Server feature
that requires a `CREATE TYPE` on the server. The query crashes at execute
time with:

```
pyodbc.ProgrammingError: ("A TVP's rows must be Sequence objects.", 'HY000')
```

**Why:** Different from psycopg2 / mysqlclient / sqlite3, which expand
tuples on `IN` automatically. SQLAlchemy with pyodbc does NOT — it would
require explicit `bindparam("x", expanding=True)`, which the `run_query`
helper in this codebase doesn't support.

**How to apply:** When you need a multi-value `IN` clause, use one of
the two patterns that already exist in this codebase:

1. **Loop per value in Python** (the canonical pattern for multi-season
   queries — see `catching_tracker_data.py::_COMBINED_FRAMING_QUERY`
   which uses single `:season` param and is called once per season).
2. **Inline integer/string-enum values as SQL literals via str.format()**
   on a query template. Safe when values are trusted (CLI int args,
   PP_MASTER groundcontrol_id, enum-style level codes — NOT user free
   text). Example pattern:

```python
_QUERY_TEMPLATE = """
SELECT ... WHERE x IN ({values_csv}) AND y = :param
"""
def fetch(values, param):
    values_csv = ",".join(str(int(v)) for v in values)
    sql = _QUERY_TEMPLATE.format(values_csv=values_csv)
    return run_query(sql, params={"param": param})
```

**The deeper miss this is also about:** "matching the reference query"
means matching BOTH the WHERE-clause conditions AND the parameter-binding
mechanics. Copying the columns/filters but inventing a new param shape
is not mirroring. May 12 2026 catcher framing hexbin one-off: the
reference `_COMBINED_FRAMING_QUERY` takes one season; I wanted multi, so
I shipped `IN :seasons` with a tuple. Crashed on first run.

**Before shipping any new SQL with a multi-value gate:** grep the
codebase for `IN :` to see how multi-value params are actually handled.
If you find no matches, that's the answer — invent nothing, inline or
loop.

**Cross-reference:** `.claude/rules/pitfalls.md` is the canonical T-SQL
trap document for this codebase. This trap probably belongs there too
(propose-add when graduating this memory).

Fixed in `feature/astros-intangibles` commit `70e876f`.
