# SQL Query Playbook

The `sql-queries/` directory at the repo root holds reference and
one-off SQL queries that aren't bound to any single app. This is where
ad-hoc analysis queries live, where canonical reference SQL is
documented, and where you'll find the queries used to verify metric
parity.

This chapter covers: what's in `sql-queries/`, the standard query
patterns we use, the 5-step performance diagnostic, and the
T-SQL/SQL-Server gotchas you'll hit weekly.

::: tip
**What you'll learn:** the `sql-queries/` directory layout, two
canonical query skeletons (hitting + pitching), the
multi-column-OR scan optimization (the slowest query class in the
codebase), the 5-step performance diagnostic, and SQL Server traps.
:::

## What's in `sql-queries/`

Top-level reference docs:

| File | Purpose |
|---|---|
| `README.md` | Index of every query file with a one-line purpose |
| `DATABASE_REFERENCE.md` | Full schema reference (~1400 lines) --- the canonical DB doc |
| `SCHEMA_OVERVIEW.md` | Higher-level schema summary |
| `TABLE_REFERENCE.md` | Per-table column listings |
| `PORTABLE_TRACKMAN_REFERENCE.md` | Trackman bullpen schema (different from in-game) |
| `mlbam-exploration-queries.md`, `mlbam-percentile-discovery.md` | MLBAM tables exploration notes |
| `pd-goals-discovery-queries.md` | PD Goals discovery notes |
| `INTANGIBLES_TABLE_REFERENCE.md` | groundcontroltracking tables |
| `gc-hitter-production-queries.sql` | GC2 production SQL (the canonical reference we port from) |
| `gc2_gcera_query.sql` | GC2 production gcERA reference |

Then a long list of `.sql` files. Selected categories:

### Player performance queries

| File | Description |
|---|---|
| `Player Hitting Stats.sql` | Comprehensive hitting stats by season/level |
| `Player Pitching Stats.sql` | Pitcher stats aggregated by year/level |
| `Player Hitting Tracking - Top Table.sql` / `Bottom Table.sql` | Tracking dashboard top/detail |
| `Player Pitching Tracking - Top Table.sql` / `Bottom Table.sql` | Pitcher tracking dashboard |
| `Pro Player Tracking Per Player.sql` | Individual player tracking report |
| `single pitcher query by year.sql` | Single pitcher season analysis |

### Swing & contact queries

| File | Description |
|---|---|
| `Daily Swing Tracking.sql` | Daily swing mechanics breakdown (Bat Speed, AA, contact point, loft, tilt, damage window) |
| `brl_per_ab.sql` | Barrel rate per at-bat (BRL/AB, BRL/BBE, Whiff%, BRL/Whiff, HR/BRL) |

### Proprietary metrics

| File | Description |
|---|---|
| `flyscore.sql` | Pitcher start scoring system (FlyScore, QualityStart, FlyingStart) |
| `pitcher_perf_by_first_p_outcome.sql` | Pitcher performance by first-pitch count state |

### Projection & value

| File | Description |
|---|---|
| `Historical RAR - Amat Population.sql` | Historical RAR for amateur population (RAR, WAR, Dollar/RAR) |
| `Promo Pressure v2.sql` | Promotion readiness scoring (pRAR, pORP, age + PA percentile) |
| `first_N_ML_PA.sql` | Performance in first N MLB plate appearances |

### Athletic performance

| File | Description |
|---|---|
| `2025 Class Best Speed Gates.sql` | Sprint/speed gate metrics for 2025 class |
| `Recent Jumps and Runs.sql` | Force plate + speed gate data (Concentric Impulse, CMJ) |

### Diagnostics + parity

| File | Description |
|---|---|
| `xwoba-parity-diag.sql` | Tracker vs PD-Goals xwOBA side-by-side (verifies hitting parity) |
| `yamal-ft3-investigation.sql` | 1→3 baserunning verification (the "single only" rule) |
| `bases-loaded-doubles-1to3.sql` | LF-pulled bases-loaded doubles, with M-angle video |
| `damage-percentile-discovery.sql` | Damage percentile discovery (alternative MLBAM join paths) |
| `fielding-pr-audit.sql` | Personal record audit query (reusable template) |

### One-offs

The sql-queries directory also accumulates **one-off queries** for
ad-hoc analysis. Examples (every file represents a real coach/FO
question we answered):

```
astros-non-mlb-velo-by-ip.sql
benchmark-percentiles-2025.sql
bullpen-srv-test.sql
funkhouser-int-check.sql
gbl-schteam-leaguename-probe.sql
gc2-of-fielding-hou-detail.sql
hs-1stround-ss-allcols.sql
lead-going-vs-not-going.sql
mlb-starter-ff-ft-iz-pct.sql
r4-school-cols-exploration.sql
schiavone-low-contact-afa-comps.sql
slider-arm-angle-comps.sql
weber-slider-tertiles.sql
```

When you write a new one-off, drop it into `sql-queries/` with a
descriptive filename. The directory is the institutional memory of
"what we've already asked."

## Standard query skeletons

Memorize these. Every metric query in the codebase starts from one of
these two skeletons.

### Hitting query (event-anchored, dual JOIN pattern)

```sql
FROM Astros.Pitches_View pv
LEFT JOIN Astros.Schedule_View sv
    ON pv.sched_id = sv.sched_id
LEFT JOIN Astros.Events_View aev                     -- always populated
    ON pv.sched_id = aev.sched_id
   AND pv.ab_event_id = aev.event_id
LEFT JOIN Astros.Events_View cev                     -- NULL on non-final pitches
    ON pv.sched_id = cev.sched_id
   AND pv.cur_event_id = cev.event_id
LEFT JOIN Astros.Hits h                              -- BIPs only
    ON pv.sched_id = h.sched_id
   AND pv.pitch_id = h.pitch_id
   AND pv.pitch_result_id IN (12, 13, 14)
LEFT JOIN Astros.Players p
    ON p.groundcontrol_id = pv.batter_id
WHERE sv.year = :season
  AND sv.sched_type = 'R'
  AND sv.level_code = :level_code
  AND pv.pitch_id > 0
```

Use `aev.*` (event-anchored, every pitch) for: `top_of_inning`,
`fielding_team_id`, `batting_team_id`, `hit_trajectory_id`. Use
`cev.*` (current-event, only final pitch of PA) for: `pa`, `so`, `bb`,
`hbp`, `ibb`, `ab`, `sf`, `[1b]`, `[2b]`, `[3b]`, `hr`.

### Pitching query (PA-anchored)

```sql
FROM Astros.Pitches_View pv
LEFT JOIN Astros.Schedule_View sv
    ON pv.sched_id = sv.sched_id
LEFT JOIN Astros.Events_View ev
    ON ev.sched_id = pv.sched_id
   AND ev.event_id = pv.cur_event_id
   AND ev.pa = 1                                       -- PA-ending pitches only
LEFT JOIN Astros.Players pr
    ON pr.groundcontrol_id = pv.pitcher_id
LEFT JOIN Astros.Hits h
    ON h.sched_id = pv.sched_id
   AND h.pitch_id = pv.pitch_id
   AND pv.pitch_result_id IN (12, 13, 14)
WHERE sv.year = :season
  AND sv.sched_type = 'R'
  AND pv.pitch_id > 0
```

### Defense query (event + tracking + DCBP)

```sql
FROM Astros.Events_View CurEvents
LEFT JOIN Astros.Players_Games PlayersGames
    ON CurEvents.sched_id = PlayersGames.sched_id
   AND PlayersGames.pos_id <> 0
LEFT JOIN Astros.Defense_Combined_By_Pos OutProbs
    ON CurEvents.sched_id = OutProbs.sched_id
   AND CurEvents.event_id = OutProbs.event_id
   AND PlayersGames.pos_id = OutProbs.pos_id
LEFT JOIN Astros.Tracking_Defensive_Metrics DefensiveMetrics
    ON CurEvents.sched_id = DefensiveMetrics.sched_id
   AND CurEvents.event_id = DefensiveMetrics.event_id
```

## The HOU one-off query template (BLOCKING)

For ad-hoc HOU hitter queries. One row per batter, multi-level
players get `AA/AAA` in level column. Critical: PA and pitch-level
metrics use **DIFFERENT query paths**.

```sql
SELECT
    dmg.name,
    lvl.level,
    pa.pa,
    dmg.your_metric
FROM (
    -- >>> PITCH-LEVEL METRIC (one row per pitch) <<<
    SELECT
        CONCAT(r.first_name, ' ', r.last_name) AS name,
        pv.batter_id,
        AVG(...) AS your_metric    -- swap your metric here
    FROM Astros.Pitches_View pv
    LEFT JOIN Astros.Schedule_View sv ON pv.sched_id = sv.sched_id
    LEFT JOIN Astros.Events_View ev ON pv.sched_id = ev.sched_id
        AND pv.ab_event_id = ev.event_id
    LEFT JOIN MLBAM.Teams bt ON ev.batting_team_id = bt.team_id
        AND sv.year = bt.season
    LEFT JOIN Astros.Players r ON r.groundcontrol_id = pv.batter_id
    WHERE sv.year = 2026
      AND sv.sched_type = 'R'
      AND sv.level_code NOT IN ('bbc','win','int','sum','nae','hsb','ind','jcb')
      AND bt.org_abbrev = 'HOU'
      AND pv.pitch_id > 0
    GROUP BY r.first_name, r.last_name, pv.batter_id
) dmg
JOIN (
    -- >>> PA COUNT (one row per event — how ALL our apps do it) <<<
    SELECT
        pv.batter_id,
        SUM(CAST(ev.pa AS int)) AS pa
    FROM Astros.Events_View ev
    JOIN Astros.Schedule_View sv ON ev.sched_id = sv.sched_id
    JOIN Astros.Pitches_View pv ON ev.sched_id = pv.sched_id
        AND ev.event_id = pv.cur_event_id
    JOIN MLBAM.Teams bt ON ev.batting_team_id = bt.team_id
        AND sv.year = bt.season AND bt.org_abbrev = 'HOU'
    WHERE YEAR(sv.sched_date) = 2026
      AND sv.sched_type = 'R'
      AND sv.level_code NOT IN ('bbc','win','int','sum','nae','hsb','ind','jcb')
      AND pv.pitch_id > 0
    GROUP BY pv.batter_id
) pa ON pa.batter_id = dmg.batter_id
CROSS APPLY (
    SELECT STRING_AGG(lv, '/') AS level
    FROM (
        SELECT DISTINCT
            CASE sv2.gc2_level_code
                WHEN 'aaa' THEN 'AAA' WHEN 'aax' THEN 'AA'
                WHEN 'afa' THEN 'A+'  WHEN 'afx' THEN 'A'
                WHEN 'rok' THEN 'FCL' WHEN 'dsl' THEN 'DSL'
                ELSE UPPER(sv2.gc2_level_code)
            END AS lv
        FROM Astros.Pitches_View pv2
        JOIN Astros.Schedule_View sv2 ON pv2.sched_id = sv2.sched_id
        WHERE pv2.batter_id = dmg.batter_id
          AND sv2.year = 2026
          AND sv2.sched_type = 'R'
          AND sv2.level_code NOT IN ('bbc','win','int','sum','nae','hsb','ind','jcb')
          AND pv2.pitch_id > 0
    ) lvls
) lvl
ORDER BY dmg.your_metric DESC;
```

Key points:

- **PA subquery separate from metric query** --- PA at event granularity, metrics at pitch granularity
- HOU filter via `MLBAM.Teams bt` on `batting_team_id` (game-level, not roster-level)
- Level label via `CROSS APPLY` subquery (SQL Server `STRING_AGG` doesn't support `DISTINCT`)
- Junk levels excluded, `sched_type = 'R'` only
- One decimal output: `CAST(FLOOR(... * 10.0) / 10.0 AS decimal(4,1))`
- Use `sv.year` over `YEAR(sv.sched_date)` in pitch-level queries for index performance

## Performance diagnostic --- 5 steps

When ANY query feels slow, work through these IN ORDER. Don't skip
ahead.

### 1. Count the table scans

How many times does the slow query touch each big table?

- Each `FROM` / `JOIN` against the same table = +1 scan
- Each `UNION ALL` branch = +1 scan
- Each CTE that re-references the table = +1 scan
- Subqueries that don't merge into the outer scan = +1 scan

Rule of thumb: 1-2 scans is fine. 3 scans deserves attention. 4+ scans
of a multi-million-row table is almost always the bottleneck.

### 2. Identify filter columns and check for multi-column-OR

If the slow query filters on `col_a OR col_b OR col_c`, that's the
structural problem. SQL Server can't use any single index to satisfy
all three branches → falls back to a clustered index scan.

The worst offender in this codebase: **baserunning queries that filter
on `runner_1b OR runner_2b OR runner_3b`**. Stolen base / lead-distance
queries are the slowest query class.

### 3. Collapse multi-column-OR into UNION ALL of single-column probes

```sql
-- BEFORE (forces table scan)
WHERE (event_result_id IN (42, 4, 29) AND runner_1b = :gc_id)
   OR (event_result_id IN (43, 5, 30) AND runner_2b = :gc_id)
   OR (event_result_id IN (44, 6, 31) AND runner_3b = :gc_id)

-- AFTER (3 single-column probes, optimizer picks best index per branch)
WHERE runner_1b = :gc_id AND event_result_id IN (42, 4, 29)
UNION ALL
SELECT ... WHERE runner_2b = :gc_id AND event_result_id IN (43, 5, 30)
UNION ALL
SELECT ... WHERE runner_3b = :gc_id AND event_result_id IN (44, 6, 31)
```

Add a highly-selective BIT pre-filter to each branch when one exists:

```sql
WHERE (ev.sb | ev.cs) = 1   -- narrows to ~1% of Events_View first
  AND ev.runner_1b = :gc_id
  AND ev.event_result_id IN (42, 4, 29)
```

### 4. Reduce CTE count by inlining flags into existing UNIONs

If a query has 4 scans (e.g. 3 in a `tob` CTE for COUNT + 1 in `sb`
CTE for SB count), collapse them by inlining a flag column per UNION
branch:

```sql
-- BEFORE: 4 scans
WITH tob AS (
    SELECT runner_id, COUNT(*) AS n_tob FROM (
        SELECT runner_1b AS runner_id FROM Events_View ... -- scan 1
        UNION ALL SELECT runner_2b ... -- scan 2
        UNION ALL SELECT runner_3b ... -- scan 3
    ) r GROUP BY runner_id
),
sb AS (
    SELECT ... FROM Events_View ... -- scan 4
    WHERE event_result_id IN (42, 43, 44) ...
)
SELECT tob.runner_id, ISNULL(sb.sb_count, 0) FROM tob LEFT JOIN sb ...

-- AFTER: 3 scans (flag inlined per branch, single GROUP BY)
WITH per_runner_events AS (
    SELECT runner_1b AS runner_id,
           CASE WHEN event_result_id = 42 THEN 1 ELSE 0 END AS is_sb
    FROM Events_View ... WHERE runner_1b IS NOT NULL ... -- scan 1
    UNION ALL
    SELECT runner_2b, CASE WHEN event_result_id = 43 THEN 1 ELSE 0 END ... -- scan 2
    UNION ALL
    SELECT runner_3b, CASE WHEN event_result_id = 44 THEN 1 ELSE 0 END ... -- scan 3
)
SELECT runner_id, SUM(is_sb) AS sb_count FROM per_runner_events
GROUP BY runner_id HAVING COUNT(*) >= 50
```

### 5. Push date filter as deep as possible

`sv.sched_date BETWEEN :start AND :end` should be applied INSIDE
every UNION ALL branch and EVERY CTE that touches the date-filterable
table. SQL Server doesn't always push predicates down through UNIONs
reliably.

### When to apply caching --- AFTER SQL is optimized

`@lru_cache(maxsize=256)` on percentile distribution helpers is
standard in `pd-goals/src/percentiles.py`. After SQL optimization,
this makes repeat hits within the same process instant.

```python
@lru_cache(maxsize=256)
def _get_X_distribution(level: str, season: int, ...) -> Tuple[float, ...]:
    ...
```

If cold-load is still painful after SQL optimization, the next-level
fix is **precomputing the distribution to a parquet pin**. Same
pattern as the trackers. See Chapter 13. Do this LAST, not first.

## SQL Server traps

### `SUM(bit_col)` errors

```sql
SUM(ev.so)               -- ERROR: Operand data type bit is invalid
SUM(CAST(ev.so AS int))  -- correct
```

Comparison (`= 1`) works fine. Aggregation requires explicit cast.

### `SUM(CASE WHEN EXISTS (...) THEN 1 ELSE 0 END)` errors

```sql
SUM(CASE WHEN EXISTS (subquery) THEN 1 ELSE 0 END)  -- ERROR
WHERE ... AND EXISTS (subquery)
... COUNT(*)                                          -- correct
```

### Schema prefixes

ALWAYS use full schema prefixes for cross-schema tables:
`MLB_eBis.PP_MASTER`, `Guts.woba_lwts`, `Guts.hit_specs_ratios`.
Default schema is `dbo` --- anything outside needs the prefix.

### `STRING_AGG` doesn't support DISTINCT

Use `CROSS APPLY` with an inner `SELECT DISTINCT` subquery (see the
HOU one-off template above).

### CTE alias mismatch with `{level_filter}` substitution

When a CTE JOINs Schedule_View with a different alias (`sv2`) than
the main query (`sv`), the `{level_filter}` and `{sched_filter}`
template substitutions reference `sv` --- WRONG inside the CTE.
Always build CTE-aliased versions:

```python
cte_lf = _build_level_filter(level_code, sv_alias="sv2")
cte_sf = sched_filter.replace("sv.", "sv2.")
_fmt = dict(..., cte_level_filter=cte_lf, cte_sched_filter=cte_sf)
```

### Outer/inner SELECT parity

When wrapping a subquery, every column in the outer SELECT must be
defined in the inner SELECT. Especially dangerous in multi-query files
(e.g. `org_kpi_data.py` has parallel pitching + hitting subqueries
--- new column must go in BOTH inner subqueries).

### Identifier quoting

SQL Server reserved-ish column names like `[1b]`, `[2b]`, `[3b]` need
square brackets:

```sql
SUM(CAST(ev.[1b] AS int))   -- correct
SUM(CAST(ev.1b AS int))     -- ERROR
```

### Year filter performance

`sv.year = 2026` is index-friendly. `YEAR(sv.sched_date) = 2026` works
but applies a function to every row, defeating the year index. Prefer
`sv.year = :season` in pitch-level queries unless you need date-range
specificity.

### `FLOOR` for one-decimal truncation (not `ROUND`)

To display "Age: 23.4" without rounding up:

```sql
CAST(FLOOR(age_value * 10.0) / 10.0 AS decimal(4,1))
```

Per the never-round-up rule (Ch 6), age is always truncated, never
rounded.

## Where to look next

- **Chapter 6** for SQL Server traps from the data-cleaning perspective.
- **Chapter 14** for the "write a one-off SQL" recipe.
- `sql-queries/DATABASE_REFERENCE.md` --- full schema (~1400 lines).
- `sql-queries/README.md` --- query index with one-line purposes.
- `.claude/rules/db-columns.md` --- column reference + the HOU one-off template.
- `.claude/rules/query-performance.md` --- the 5-step diagnostic playbook.
