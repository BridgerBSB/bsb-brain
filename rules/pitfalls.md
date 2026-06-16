---
paths:
  - "**/*.py"
  - "**/*.sql"
---

# Common Pitfalls

## SQL Server BIT Columns
`SUM(bit_col)` throws `"Operand data type bit is invalid for sum operator"` and returns 0 rows. Known bit columns:
- `Defense_Combined_By_Pos.out_made`, `.competitive_play`, `.competitive_throw`
- `Tracking_Defensive_Metrics.competitive_play`, `.competitive_throw`
- `Events_StolenBases.success` — MUST `CAST(esb.success AS INT)` before SUM
- `Pitches_Baserunner_Leads.runner_going`, `.next_base_open` — BIT, compare directly (=1) but CAST for SUM
- Events_View PA columns (`[1b]`, `[2b]`, `[3b]`, etc.)

## Events_View.pa = 0 for IBBs — BLOCKING (Fixed Apr 15, 2026)
`CAST(ev.pa AS int) = 1` excludes intentional walks. ALL PA counts and PA gates must include IBB:

**PA SUM:** `SUM(CAST(ev.pa AS int)) + SUM(CAST(ISNULL(ev.ibb, 0) AS int)) AS pa`
**PA gate:** `(CAST(ev.pa AS int) = 1 OR CAST(ISNULL(ev.ibb, 0) AS int) = 1)`

Applied to ALL files in ALL worktrees (Barrelsville, Arm Farm, PD Goals). wOBA/xwOBA denominators use `AB + BB - IBB + SF + HBP` (not `pa`) and handle IBB separately — leave those alone.

**When adding `is_ibb` or any new column for IBB support:** Files with MULTIPLE query strings (e.g., `org_kpi_data.py` has pitching AND hitting queries) require the column in EVERY subquery that references it in the outer SELECT. Bug (Apr 15 2026): `is_ibb` was added to the pitching subquery but missed in the hitting subquery — `SUM(is_ibb)` in the outer SELECT threw "Invalid column name" and silently killed the entire hitting page.

## T-SQL: Cannot SUM() an Expression Containing a Subquery
`SUM(CASE WHEN EXISTS (...) THEN 1 ELSE 0 END)` throws `"Cannot perform an aggregate function on an expression containing an aggregate or a subquery"`. Move EXISTS to the WHERE clause to pre-filter rows before aggregation.

**Wrong:** `SUM(CASE WHEN EXISTS (subquery) THEN 1 ELSE 0 END)`
**Right:** `WHERE ... AND EXISTS (subquery)` then `COUNT(*)`

**ALWAYS CAST before aggregation:** `SUM(CAST(col AS int))` or `SUM(CAST(col AS float))`

## `int(x or 0)` Does NOT Catch NaN — BLOCKING RULE
`NaN` is **truthy** in Python, so `int(val or 0)` passes NaN through and `int(NaN)` raises `ValueError`. This pattern appears throughout the codebase in DataFrame lookups and SQL result processing. **NEVER write `int(x or 0)`.** Use `int(0 if pd.isna(x) else x)` or a `_safe_int` helper. Applies to any numeric conversion from DataFrame/dict values that could contain NaN.

## ignore_flag + did_swing Recovery — BLOCKING RULE

**NEVER filter `WHERE pv.ignore_flag = 0` on Pitches_View** for general pitch queries. It excludes legitimate game pitches (e.g. ABs vs position players pitching), causing PA/hit undercounts vs GC2. The only standard pitch filter is `pv.pitch_id > 0`.

**EXCEPTION 1 — NetK queries MUST filter `ignore_flag = 0`.** GC2's NetK formula requires it (verified Apr 16 2026 against GC2 catcher profile SQL). Apply in WHERE for standalone NetK queries, or inside CASE WHEN for combined queries that also compute Steal%/Loss%/FramRAA. See `gc2-metrics.md` for full NetK reference.

**EXCEPTION 2 — `Pitches_Baserunner_Leads` (PBL) KEEPS `bl.ignore_flag = 0`.** PBL's `ignore_flag` is a DIFFERENT column with a different meaning — it flags bad tracking data for lead distance measurements (sensor noise, tracking failures), NOT excluded pitches. Always filter `bl.ignore_flag = 0` on PBL queries to exclude garbage lead readings. This applies to all BR lead queries (individual + team, daily + season, percentile distributions).

**BUT: SELECT `pv.ignore_flag` as a column** — needed for swing recovery.

When `ignore_flag = 1`, only two fields are NULL: `did_swing` and `pitch_type`. All other tracking fields ARE populated: `plate_x`, `plate_z`, `release_speed`, `spin_rate`, `pitch_result_id`, `hit_exit_speed` (Hits table). These pitches appear on strike zone plots and have full location/velocity data — they just lack a pitch type label and swing flag. We recover swings from pitch_result_id:

**SWING_CODES** = `(7,8,9,10,12,13,14,16,18,19,20,21,22,23,25)` (BIP + WHIFF + FOUL)

**SQL pattern** — everywhere you'd write `pv.did_swing = 1`:
```sql
(pv.did_swing = 1 OR (pv.ignore_flag = 1 AND pv.did_swing IS NULL
  AND pv.pitch_result_id IN (7,8,9,10,12,13,14,16,18,19,20,21,22,23,25)))
```

**Python pattern** — in `enrich_pitches()` and anywhere is_swing is derived:
```python
SWING_CODES = BIP_CODES + WHIFF_CODES + FOUL_CODES
_ignore_recovery = (
    (df.get("ignore_flag", pd.Series(0, index=df.index)) == 1)
    & df["did_swing"].isna()
    & df["pitch_result_id"].isin(SWING_CODES)
)
df["is_swing"] = (df["did_swing"] == 1) | _ignore_recovery
```

**Takes** (`did_swing = 0`): same logic inverted — `pitch_result_id NOT IN` swing codes.

**App pitch_type filters MUST include NULL:** `df["pitch_type"].isin(selected) | df["pitch_type"].isna()`. Otherwise ignore_flag pitches with NULL pitch_type are silently excluded from swing tables and charts.

**Rendering (plottable):** NULL pitch_type/pitch_color causes plottable to silently drop rows. Always map None to fallback values (`"UNK"` / `"#888888"`) before passing to Table().

**pitch_type groupby/dropna — SILENT EXCLUSION:** `groupby("pitch_type")` silently drops NaN groups. `pitch_type.dropna().unique()` excludes NULL pitches from plots and legends. Always handle NULL separately:
```python
# Plotting by pitch type — include NULL as "Unknown"
for pt_code in list(df['pitch_type'].dropna().unique()) + ([None] if df['pitch_type'].isna().any() else []):
    pt_sub = df[df['pitch_type'] == pt_code] if pt_code is not None else df[df['pitch_type'].isna()]
    color = PITCH_TYPE_COLORS.get(pt_code, '#888888') if pt_code else '#888888'
```

**enrich_pitches() pitch_name:** `df["pitch_type"].map(NAMES).fillna(df["pitch_type"])` fills with None when pitch_type is None. Use `.fillna("Unknown")` explicitly.

**5-layer fix checklist per app:**
1. SQL WHERE: remove `ignore_flag = 0`, keep `pitch_id > 0`
2. SQL SELECT: add `pv.ignore_flag` as column
3. SQL CASE WHEN: add swing recovery OR clause to every `did_swing = 1`
4. Python data: `enrich_pitches()` is_swing recovery, pitch_name/pitch_color None handling, DataFrame `did_swing==1` filters
5. App/rendering: sidebar pitch_type filter includes NULL, zone plot pitch_type loops include NULL, plottable None handling, pitch arsenal legend includes "Unknown"

Discovered Apr 2026 via Joseph Sullivan (gc_id 218708) missing a single in Barrelsville postgame. Barrelsville DONE. PD Goals, Arm Farm, Intangibles pending.

## Outer/Inner SELECT Parity — BLOCKING RULE

When a SQL query wraps a subquery (`SELECT ... FROM (SELECT ... ) sub`), every column referenced in the outer SELECT MUST be defined in the inner SELECT. SQL Server throws `"Invalid column name 'X'"` if the inner subquery lacks a column the outer one references.

**This is especially dangerous in multi-query files.** When adding a column to parallel queries (e.g., pitching + hitting in `org_kpi_data.py`), you must add it to ALL subqueries — not just one. The bug pattern:
1. Add `is_foo` to pitching subquery + both outer SELECTs ✓
2. Forget to add `is_foo` to hitting subquery ✗
3. Hitting query throws SQL error, silently caught → empty page

**Checklist when adding a column to a wrapped query:**
1. Add the column definition (`CASE WHEN ... AS is_foo`) to the inner subquery
2. Add the aggregation (`SUM(is_foo) AS foo_total`) to the outer SELECT
3. **Grep the file for all other outer SELECTs that reference the same column** — each one needs the inner definition too
4. If the file has parallel query strings (pitching/hitting/fielding), check ALL of them

**Bug history:** Apr 15 2026 — `SUM(is_ibb)` added to hitting outer SELECT but `is_ibb` CASE WHEN only added to pitching subquery. Hitting page silently dropped from org KPI report.

## CTE Alias Mismatch — valid_steals and Similar Patterns

**NOTE (Apr 14, 2026):** `valid_steals` CTEs with `runner_going=1 AND next_base_open=1` are NO LONGER used for SB counts OR lead queries. SB counts use `Events_View.event_result_id` (see `db-columns.md`). Lead queries use direct PBL filters (runner_going=0 on SL/TL only, fielder ≤10 on 1B, next-base-occupied via LEFT JOIN IS NULL). The CTE alias mismatch pattern below still applies to any CTE that joins Schedule_View.

When a CTE JOINs `Schedule_View` with a different alias (e.g., `sv2`) than the main query (`sv`), the `{level_filter}` and `{sched_filter}` placeholders produce `sv.level_code`/`sv.sched_type` — **wrong inside the CTE**.

**Wrong (CTE uses sv2 but filter references sv):**
```sql
WITH valid_steals AS (
    ...JOIN Astros.Schedule_View sv2 ON ...
    WHERE ({level_filter})        -- produces sv.level_code = 'aaa' — BROKEN
      AND {sched_filter}          -- produces sv.sched_type IN (...) — BROKEN
)
SELECT ... FROM ... JOIN Astros.Schedule_View sv ON ...
WHERE ({level_filter})            -- correct here (sv exists)
```

**Right — use separate CTE-aliased placeholders:**
```sql
WITH valid_steals AS (
    ...JOIN Astros.Schedule_View sv2 ON ...
    WHERE ({cte_level_filter})    -- produces sv2.level_code = 'aaa'
      AND {cte_sched_filter}      -- produces sv2.sched_type IN (...)
)
```

**At every call site**, build CTE-aliased versions:
```python
cte_lf = _build_level_filter(level_code, sv_alias="sv2")
cte_sf = sched_filter.replace("sv.", "sv2.")
_fmt = dict(..., cte_level_filter=cte_lf, cte_sched_filter=cte_sf)
```

**Applies to:** Any query with a CTE that JOINs Schedule_View under a different alias than the main query. Common in ESB (stolen base) queries, org CTE patterns, and any query that folds org mapping into a CTE.

## `pitcher_throws` vs `throws` — DIFFERENT TABLES
- **`Astros.Pitches_View`** → column is `pitcher_throws` (also has `bat_side`)
- **`Astros.Players`** → column is `throws` (also has `bats`)
- NEVER use `p.pitcher_throws` when joining Players. NEVER use `pv.throws` on Pitches_View.

## PP_MASTER `LEVELOFPLAY_LK` Is Uppercase
DB returns `'1F'`, `'R'`, `'DS'`, etc. — NOT lowercase. Always `.strip().lower()` before comparing to level code constants. Bit us in the HS draft placement script (Apr 2026).

## NaN in SQL IN Clauses
NEVER build SQL IN clauses from raw DataFrame columns without filtering NaN. DataFrame `batter_id`/`pitcher_id` columns can contain NaN (float) values. Using `','.join(str(x) for x in df['col'])` produces literal `nan` in the SQL. ALWAYS filter and cast: `ids = [int(x) for x in df['col'].dropna()]`. Use `_safe_id_list()` helper when available.

## Column Name Verification — BLOCKING RULE
Before writing ANY SQL query, you MUST first either:
1. Check `.claude/rules/db-columns.md` for correct column names
2. Grep the codebase for existing queries that use that table
3. Check `sql-queries/DATABASE_REFERENCE.md`

No exceptions. No "quick" queries. Verify then write.

## Python Variable Names vs SQL Columns
NEVER use Python variable names as SQL column names. Example: `csc` is a Python alias — the real DB column is `called_strike_chance_mlb`. Always grep existing SQL queries in `src/` to find the actual column name.

## Schema Prefixes
ALWAYS use full schema prefixes for cross-schema tables: `MLB_eBis.PP_MASTER`, `Guts.woba_lwts`, `Guts.hit_specs_ratios`, etc. Default schema is `dbo` — anything outside needs the prefix.

## did_swing Data Type
`did_swing` is int (1) in Astros tables, varchar ('Y') in old MLBAM tables.

## Streamlit session_state
Once a widget key exists, `value=`/`default=` params are IGNORED. Must set `st.session_state[key]` before widget renders.

## @st.cache_data Underscore Bug
`_param` names are EXCLUDED from cache hash — never use `_` prefix for cached function params.

## Lazy Queries — NEVER DO THIS
When writing SQL for a specific player, ALWAYS look up their `groundcontrol_id` from `pd-goals/data/slack_channels.csv` first. Use the concrete ID — never use `LIKE '%Name%'` subqueries.

## Key Reference Files — CHECK BEFORE WRITING SQL
- `sql-queries/DATABASE_REFERENCE.md` — full schema docs, join patterns
- `sql-queries/gc-hitter-production-queries.sql` — GC production SQL reference
- `sql-queries/gc2_gcera_query.sql` — GC2 production gcERA reference
- `sql-queries/INTANGIBLES_TABLE_REFERENCE.md` — groundcontroltracking tables
- `pd-goals/data/slack_channels.csv` — player IDs by name
