# Query Performance — Multi-Column-OR Scans + Diagnostic Playbook

When a SQL query feels slow, **before** considering caching, pinning, or
precomputation, work through this diagnostic in order. Most slow queries in
this codebase fall into one of the patterns below, and the SQL fix is
usually 25–80% on the first pass.

---

## When this pattern applies

Any query whose `WHERE` clause filters on **2+ columns combined with `OR`**,
where each branch is on a different column. The signature looks like:

```sql
WHERE col_a = :x OR col_b = :x OR col_c = :x
```

**Why it's slow:** SQL Server builds B-tree indexes on individual columns.
A 3-way OR forces it to scan the whole table because no single index can
satisfy all three branches. The optimizer typically falls back to a clustered
index scan or hash join — both linear in table size.

**Worst offenders in this codebase:**

| Table | Multi-column-OR pattern | Used for |
|---|---|---|
| `Events_View` | `runner_1b = :x OR runner_2b = :x OR runner_3b = :x` | SB/CS attribution, lead queries, baserunning percentiles |
| `Events_View` | `first_defender_id IN (rf_id, cf_id, lf_id)` (less bad — IN over few values) | OF advancement |
| `Pitches_View` | (none currently — `batter_id` / `pitcher_id` are well-indexed single columns) | — |
| `Hits` | (joined via `pitch_id`, no OR pattern) | — |

---

## Diagnostic — 5-step checklist (in order)

When ANY query feels slow, work through these in order. Don't skip ahead.

### 1. Count the table scans

How many times does the slow query touch each big table? Look at:
- Each `FROM` / `JOIN` against the same table = +1 scan
- Each `UNION ALL` branch = +1 scan
- Each CTE that re-references the table = +1 scan
- Subqueries that don't merge into the outer scan = +1 scan

Rule of thumb: 1–2 scans is fine. 3 scans deserves attention. 4+ scans of a
multi-million-row table is almost always the bottleneck.

### 2. Identify filter columns and check for multi-column-OR

If the slow query filters on `col_a OR col_b OR col_c`, that's the structural
problem. See "When this pattern applies" above. Fix in step 3.

If the filter is single-column on a well-indexed column (`batter_id`,
`pitcher_id`, `sched_id`, `groundcontrol_id`), the scan count is the issue —
go to step 4.

### 3. Collapse multi-column-OR into UNION ALL of single-column probes

Each branch becomes its own `WHERE col_X = :x` filter, which the optimizer
CAN satisfy via index seek if any index exists on that column.

```sql
-- BEFORE (forces table scan)
WHERE (event_result_id IN (42, 4, 29) AND runner_1b = :gc_id)
   OR (event_result_id IN (43, 5, 30) AND runner_2b = :gc_id)
   OR (event_result_id IN (44, 6, 31) AND runner_3b = :gc_id)

-- AFTER (3 single-column probes, optimizer can pick best index per branch)
WHERE runner_1b = :gc_id AND event_result_id IN (42, 4, 29)
UNION ALL
SELECT ... WHERE runner_2b = :gc_id AND event_result_id IN (43, 5, 30)
UNION ALL
SELECT ... WHERE runner_3b = :gc_id AND event_result_id IN (44, 6, 31)
```

Add a highly selective BIT pre-filter to each branch when one exists.
`(ev.sb | ev.cs) = 1` narrows to ~1% of `Events_View` rows BEFORE the
runner-column filter and often hits a different index path:

```sql
WHERE (ev.sb | ev.cs) = 1
  AND ev.runner_1b = :gc_id
  AND ev.event_result_id IN (42, 4, 29)
  ...
```

The `event_result_id IN (...)` filter is still required for correctness
(filters out other SB/CS bases per branch).

### 4. Reduce CTE count by inlining flags into existing UNIONs

If a query has 4 scans (e.g., 3 in a `tob` CTE for COUNT + 1 in a `sb` CTE
for SB count), collapse them by inlining a flag column into each UNION
branch. SUM the flag and COUNT all rows in a single `GROUP BY` pass.

```sql
-- BEFORE: 4 scans (tob has 3, sb has 1, then LEFT JOIN)
WITH tob AS (
    SELECT runner_id, COUNT(*) AS n_tob
    FROM (
        SELECT runner_1b AS runner_id FROM Events_View ... -- scan 1
        UNION ALL SELECT runner_2b FROM Events_View ...    -- scan 2
        UNION ALL SELECT runner_3b FROM Events_View ...    -- scan 3
    ) r GROUP BY runner_id HAVING COUNT(*) >= 50
),
sb AS (
    SELECT CASE WHEN event_result_id = 42 THEN runner_1b ... END AS runner_id,
           COUNT(*) AS sb_count
    FROM Events_View ...                                     -- scan 4
    WHERE event_result_id IN (42, 43, 44) GROUP BY ...
)
SELECT tob.runner_id, ISNULL(sb.sb_count, 0)
FROM tob LEFT JOIN sb ON sb.runner_id = tob.runner_id

-- AFTER: 3 scans (flag inlined per branch, single GROUP BY)
WITH per_runner_events AS (
    SELECT runner_1b AS runner_id,
           CASE WHEN event_result_id = 42 THEN 1 ELSE 0 END AS is_sb
    FROM Events_View ... WHERE runner_1b IS NOT NULL ...     -- scan 1
    UNION ALL
    SELECT runner_2b,
           CASE WHEN event_result_id = 43 THEN 1 ELSE 0 END
    FROM Events_View ... WHERE runner_2b IS NOT NULL ...     -- scan 2
    UNION ALL
    SELECT runner_3b,
           CASE WHEN event_result_id = 44 THEN 1 ELSE 0 END
    FROM Events_View ... WHERE runner_3b IS NOT NULL ...     -- scan 3
)
SELECT runner_id, SUM(is_sb) AS sb_count
FROM per_runner_events
GROUP BY runner_id HAVING COUNT(*) >= 50
```

Each branch tags rows where the SB `event_result_id` matches THAT runner
column (42→runner_1b, 43→runner_2b, 44→runner_3b), so `SUM(is_sb)` gives
the SB count and `COUNT(*)` gives the TOB count — both in one pass.

### 5. Push date filter as deep as possible

`sv.sched_date BETWEEN :start AND :end` should be applied INSIDE every
UNION ALL branch and EVERY CTE that touches the date-filterable table.
SQL Server doesn't always push predicates down through UNIONs reliably.

```sql
-- BAD: date filter only in outer SELECT
SELECT ... FROM (
    SELECT ... FROM Events_View ev JOIN Schedule_View sv ...
    UNION ALL
    SELECT ... FROM Events_View ev JOIN Schedule_View sv ...
) x JOIN Schedule_View sv ON x.sched_id = sv.sched_id
WHERE sv.sched_date BETWEEN :start AND :end   -- ← too late, scan already done

-- GOOD: date filter in each branch
SELECT ... FROM (
    SELECT ... FROM Events_View ev JOIN Schedule_View sv ON ev.sched_id = sv.sched_id
        WHERE sv.sched_date BETWEEN :start AND :end          -- ← here
    UNION ALL
    SELECT ... FROM Events_View ev JOIN Schedule_View sv ON ev.sched_id = sv.sched_id
        WHERE sv.sched_date BETWEEN :start AND :end          -- ← and here
) x
```

---

## Caching — apply AFTER SQL is optimized

`@lru_cache(maxsize=256)` on percentile distribution helpers is standard
in `pd-goals/src/percentiles.py`. After SQL optimization, this makes
repeat hits within the same process instant.

```python
@lru_cache(maxsize=256)
def _get_X_distribution(level: str, season: int, ...) -> Tuple[float, ...]:
    ...
```

**Cache key reality:** for seasonal pools, the key is `(level, season, ...)`.
First hit per unique key pays the full SQL cost. Subsequent calls within
the same Python process are instant. Across Streamlit sessions or Connect
worker restarts, cache is cold again.

If cold-load is still painful after SQL optimization, the next-level fix
is **precomputing the distribution to a parquet pin** (daily refresh) —
same pattern Barrelsville/Intangibles trackers use for cold-load wins.
See `tracker-parquet-pins.md`. Do this LAST, not first.

---

## Real-world fixes from this codebase

### Apr 26 2026 — PD Goals SB queries

Two queries hit this pattern. User reported "stolen bases takes longer
than any other single metric" in PD Goals rolling chart + percentiles.

**`_hitter_sb_per_game`** (`pd-goals/src/rolling_stats.py`, commit `09fb158`):
- Original `WHERE runner_1b=X OR runner_2b=X OR runner_3b=X` → table scan
- Rewrote as UNION ALL of 3 single-column probes (step 3 above)
- Added `(ev.sb | ev.cs) = 1` BIT pre-filter (matches `intangibles/src/br_tracker_data.py::_ESB_QUERY` pattern)
- ~30–50% faster on cold load

**`_get_stolen_bases_distribution`** (`pd-goals/src/percentiles.py`, commit `15ac75b`):
- Original: 4 Events_View scans (tob CTE = 3 + sb CTE = 1)
- Inlined `is_sb` flag per UNION branch, single GROUP BY (step 4 above)
- 4 → 3 scans, ~25% faster on cold load
- Already wrapped in `@lru_cache(maxsize=256)`, so repeat hits per `(level, season)` are instant

### Why SB is uniquely slow vs other metrics

| Metric pool | Filter column | Index | Speed |
|---|---|---|---|
| Damage / Barrel% / EV / Top50EV | `batter_id` on `Hits` (joined via `pitch_id`) | Excellent | Fast |
| xwOBA / Whiff% / Ctct% / Chase% | `batter_id` on `Pitches_View` | Excellent | Fast |
| K% / BB% / SLG | `batter_id` on `MLBAM.SplitsBat` | Excellent | Fast |
| Fielding (TopSpd, React, Arm) | `fielder_id` (`groundcontrol_id` partition) | Good | Moderate |
| Catcher (Pop, Frame, Block) | `catcher_id` | Good | Moderate |
| **SB / Lead distance** | **`runner_1b` OR `runner_2b` OR `runner_3b`** | **None on multi-column-OR** | **Slow** |

The other metric pools key on a SINGLE well-indexed column. SB and lead
metrics are stuck with multi-column-OR attribution because runners can be
on any of three bases per PA, and there's no `is_runner` flag column.

### Apr 2026 — Intangibles BR tracker (precedent)

The `intangibles/src/br_tracker_data.py::_ESB_QUERY` already used the
UNION ALL + `(ev.sb | ev.cs) = 1` pattern. PD Goals' fix was porting that
proven pattern to the rolling chart + percentile pool. Always check
intangibles BR queries first when working on baserunning performance —
they're the reference impl for this query class.

---

## Cross-references

- `db-columns.md` — Events_View runner column meanings, SB/SBA Count Rule
- `db-joins.md` — `cur_event_id` vs `ab_event_id` (different scan-count traps)
- `pitfalls.md` — SQL Server BIT casting, NaN in IN clauses, EXISTS in SUM
- `multi-level-rollup.md` — similar structural traps in cross-level aggregation
- `kpi-parallelization.md` — async parallelization (different lever — apply after SQL is fast)
- `tracker-parquet-pins.md` — precomputed pins (the LAST resort after SQL is optimized)
- `intangibles/src/br_tracker_data.py::_ESB_QUERY` — reference implementation for UNION ALL + BIT pre-filter pattern

---

## What NOT to do

- **Don't** jump to caching / pinning before optimizing SQL. Caching a
  4-scan query masks the cost on cold loads; SQL fixes are durable.
- **Don't** keep multi-column-OR `WHERE` clauses "for readability." UNION ALL
  is the canonical fix and every senior engineer reading the code knows
  why it's there.
- **Don't** add a CTE for clarity if it forces an extra table scan.
  Inline flags into existing UNION branches when possible.
- **Don't** add `(ev.sb | ev.cs) = 1` pre-filter to queries that aren't
  about SB/CS events. It only helps when SB/CS rows are a small fraction
  of the table (~1% of Events_View). For broader queries, it's noise.
- **Don't** skip the diagnostic order. Step 3 (UNION ALL) before step 4
  (CTE collapse) before step 5 (date pushdown). Skipping ahead can produce
  a worse execution plan than the original.
- **Don't** assume a query is fast just because it has `@lru_cache`. The
  cache hides cold-load cost — first hit per unique key still pays it.
  Optimize the SQL first; cache is a multiplier, not a substitute.
