---
paths:
  - "**/*kpi*.py"
---
# KPI Weekly Charts — Pool-Then-Aggregate Pattern (BLOCKING)

## What this rule covers

The chart-line implementation for every KPI weekly report — Barrelsville
hitter, Arm Farm pitcher, Intangibles OF/IF/BR/Catcher. Six surfaces,
one shared pattern. Get this wrong and the chart line drifts from the
metric definition shown by the rank box, the tracker, and PD Goals org
KPI — silently breaks three-surface parity (`three-surface-parity.md`)
without raising any error.

**Pairs with `kpi-parallelization.md`** (which handles P2/P3/P4 query
parallelism for these reports). This rule covers chart-line semantics
specifically.

---

## The canonical shape

Every KPI weekly chart consumes data shaped like this:

```
DataFrame: one row per (org, year, iso_week)
Columns:   org, year, week, game_date, game_month, <metric_cols>
```

`game_date` = last date in the iso_week (anchors the x-axis).
`game_month` = month derived from `game_date` (anchors month-end rank
boxes — `groupby("game_month").last()`).

The chart consumer (`_plot_kpi_chart` or equivalent in each report)
does the same thing in every app:

```python
for org, grp in chart_data.groupby("org"):
    ax.plot(grp["game_date"], grp[metric_col], ...)
hou_month_end = hou.groupby("game_month").last().reset_index()
# annotate rank from get_org_cumulative_ranks() at each month-end
```

The line draws from weekly points; rank boxes pin to the most recent
weekly row in each month.

---

## Three metric types, three correct treatments

The math you use to fill `<metric_cols>` depends on what the metric is.
**Picking the wrong one silently breaks the chart values.**

| Metric type | Examples | Correct treatment |
|---|---|---|
| **Cumulative SUM** | OAA, NetK, FramRAA, BlockRAA, SB, CS, 1→3, 2→H | `groupby("org")[col].cumsum()` across weekly rows. Line ramps up; end-of-season = season tracker total exactly. |
| **Rate** (numer/denom) | R2K%, FPinZ%, EW%, K-BB%, xwOBA, R2K%, SurPP, 1B PL, 1B SL, PAA/EO | 4-week rolling SUM on numer + denom components separately, divide AFTER rolling. NEVER rolling-avg the pre-computed rate. |
| **Percentile (per-fielder/player)** | TopSpd P95, React P25, UseReact P25, Arm P99, AugPop2B P01 | Pool 4 weeks of RAW observations per fielder, compute `np.percentile` ON the pool, weighted-avg to org by per-fielder n_obs. NEVER rolling-avg per-week percentiles. |

The mistake on each row of the right column is a real, verifiable bias
that has shipped to production and been caught. See "The
per-week-then-roll bias" below.

---

## Why pool-then-aggregate (not aggregate-then-roll)

### For rates: trivially correct, also commutative

`SUM(numer over 4 weeks) / SUM(denom over 4 weeks)` =
`weighted_avg(weekly_rates, weights=weekly_denom)`. So either
implementation works arithmetically. The "rolling SUM on raw
components" form is preferred because it composes cleanly with
multi-level rollup (`multi-level-rollup.md`) and matches the
established Barrelsville/Arm Farm reference impls.

### For percentiles: the math is fundamentally different

P99 is **non-linear and non-additive**. You CANNOT recover the
4-week-window P99 by averaging the four 1-week P99s. They aren't equal.

**Per-week-then-roll bias (the trap):** P99 over a fielder's 5–15
throws in one week is biased LOW versus P99 over their 50+ season
throws — small samples rarely include the fielder's max-effort throws.
Rolling-avg of those biased weekly percentiles inherits the bias and
the chart line sits 3–5 mph below the season tracker value
indefinitely.

**Pool-then-percentile (the fix):** for each week-ending date, gather
all observations from the trailing 4 weeks per fielder, compute
`np.percentile(pool, 99)` on the combined ~50-80 throws. Big enough
sample for P99 to mean something. Each week the pool slides forward by
1 week so the chart still bumps weekly with real signal — but the
absolute values stay close to the season tracker value as the season
matures (typically <1 mph drift by mid-season).

This was the core of the Apr 27 2026 OF/IF Arm IF fix. Symptoms:
PD Goals tracker showed AAX HOU Arm IF = 92.6 mph; weekly KPI chart
line showed ~89 mph. Three commits to find it (`5478b96`, `237ea2e`,
`8a8f378`); the working fix is `8a8f378`.

---

## Reference implementations (canonical, keep in sync)

When porting a new metric or building a new KPI chart, copy from these:

| Surface | Module | Pattern type | Function |
|---|---|---|---|
| Barrelsville hitter weekly | `barrelsville/src/hitter_kpi_data.py` | Rate (xwOBA, K%, BB%, K-BB%) + count rates | `get_kpi_chart_data` (4-week rolling SUM on numer/denom) |
| Arm Farm pitcher weekly | `bullpen-report/src/pitcher_kpi_data.py` | Rate (FPinZ%, InZ%, R2K%, EW%, 2K Proj, K-BB%) | `get_kpi_chart_data` (same pattern) |
| Intangibles OF | `intangibles/src/of_kpi_data.py` | Percentile (TopSpd, UseReact, Arm) + cumsum (OAA) + rate (PAA/EO) | `_PER_FIELDER_DAILY_RAW_QUERY` + `_rolling_pool_org_weekly` + `get_kpi_chart_data` |
| Intangibles IF | `intangibles/src/if_kpi_data.py` | Same as OF but React (not UseReact) and arm range 70-108 | Same shape |
| Intangibles BR | `intangibles/src/br_kpi_data.py` | Cumsum (SB, CS, 1→3, 2→H) + rate (1B PL, 1B SL) | `_ORG_DAILY_*` queries + groupby(org, year, week).sum() + cumsum/rolling |
| Intangibles Catcher | `intangibles/src/c_kpi_data.py` | Rate (R2K%, SurPP, AugPop2B) + cumsum (NetK, FramRAA, BlockRAA) | `_ORG_DAILY_PITCHES_QUERY` + `_ORG_DAILY_BLOCKING_QUERY` + `_ORG_WEEKLY_AUGPOP_QUERY` + `_fetch_weekly_org_chart_data` |

---

## Chart line vs rank box vs card — they intentionally differ

This is documented because users repeatedly ask "why doesn't the chart
endpoint match the card?" — they assume mismatch is a bug.

| View | What it shows | Source |
|---|---|---|
| **Chart line at week N** | 4-week rolling rate or pool-percentile **as of week N** | `get_kpi_chart_data` (this rule) |
| **Rank box at month-end** | HOU's standing vs other 29 orgs | `get_org_cumulative_ranks` — for percentile metrics, applies SEASON-TO-DATE tracker rank to every month; for cumulative SUMs, ranks the running cumsum at each month |
| **Card / season-to-date** | Season tracker / season aggregate | `_fetch_season_org_ranks` or equivalent |

Last week's chart value ≠ card value, by design. The chart shows
"recent form" (4-week rolling). The card shows "season standing." Both
useful, both correct, both intentional.

The rank box uses the chart line's month-end value for cumulative SUM
metrics (because they share the same x-axis math), but for percentile
metrics applies the same season-to-date rank to every month (because
weekly percentile noise would make ranks oscillate misleadingly). See
`get_org_cumulative_ranks` in any of the intangibles `*_kpi_data.py`
files.

---

## T-SQL gotchas (BLOCKING)

When writing daily-grain SQL for KPI chart data, two SQL Server quirks
have bit me. Avoid them.

### 1. Column aliases NOT visible in same CTE's WHERE clause

```sql
-- WRONG
WITH base AS (
    SELECT
        ...
        CAST(ISNULL(dcbp.out_made, 0) AS int) AS out_made,
        CAST(ISNULL(dcbp.competitive_play, 0) AS int) AS dcbp_cp
    FROM ...
    WHERE (out_made + dcbp_cp + ...) > 0   -- ❌ aliases not yet defined
)

-- RIGHT
WITH base AS (
    SELECT
        ...
    FROM ...
    WHERE (CAST(ISNULL(dcbp.out_made, 0) AS int)
           + CAST(ISNULL(dcbp.competitive_play, 0) AS int)
           + ...) > 0   -- ✓ inline full expressions
)
```

T-SQL evaluates WHERE before computing SELECT aliases. Same for HAVING,
GROUP BY, ORDER BY in the same level — none can reference SELECT
aliases. Inline the full expression every time, or use a nested CTE.

### 2. Aliasing a column to its own name → "ambiguous column" error

```sql
-- WRONG
SELECT
    ...
    CAST(ISNULL(dcbp.out_made, 0) AS int) AS out_made   -- ❌ alias matches base column
FROM Astros.Tracking_Defensive_Metrics tdm
LEFT JOIN Astros.Defense_Combined_By_Pos dcbp ...
```

If `dcbp.out_made` is already a column, aliasing the wrapped expression
back to `out_made` confuses the optimizer in some cases (Apr 27 incident:
"Ambiguous column name 'out_made' (209)"). Use a distinct alias
(`out_made_int`) or drop the alias entirely if you don't need the
column in the SELECT.

---

## Implementation playbook for a NEW KPI chart metric

When adding a chart metric to any of the 6 KPI weekly reports:

1. **Classify the metric** — cumulative SUM / rate / per-player percentile
2. **Pick the matching SQL grain**:
   - Cumulative SUM: daily SUM, group by `(org, game_date)` → weekly groupby in Python → cumsum
   - Rate: daily numerator + denominator counts, group by `(org, game_date)` → weekly groupby → 4-week rolling SUM → divide AFTER rolling
   - Per-player percentile: RAW per-player observations (no SQL-side percentile), one row per observation → Python rolling-pool percentile per player → org weighted-avg by per-player n_obs
3. **Match an existing reference impl** — find the closest sibling
   metric in the same KPI module and copy its shape. Do not invent a
   third path.
4. **Verify against three-surface parity** — chart at end-of-season
   should match (cumulative) or be a recent-form snapshot of (rate /
   percentile) the season tracker value. Card always equals season
   tracker. See `three-surface-parity.md`.
5. **Smoke-test against PD Goals org KPI** — the season tracker value
   visible in PD Goals at end of season should equal (cumulative) or be
   close to (rolling) the chart endpoint. If drift is more than ~1% at
   end of season for a rolling metric, the implementation is wrong.

---

## What NOT to do

- **Don't compute percentiles inside small per-week SQL partitions then
  rolling-average them.** That's the per-week-then-roll bias. Pool the
  raw observations into the trailing window and percentile ONCE.
- **Don't reuse the rate-rolling pattern for percentile metrics.** Rates
  compose linearly through SUM; percentiles do not.
- **Don't reuse the percentile rolling-pool pattern for rate metrics.**
  Pulling raw per-event rows when you could just pull daily SUMs is
  wasteful — rates aggregate cleanly.
- **Don't try to make the chart endpoint match the card value for
  rolling metrics.** They're different views by design. Match the
  Barrelsville/Arm Farm pattern: chart = recent form, card = season.
- **Don't reference SELECT aliases in the same CTE's WHERE.** Inline
  the full expression. T-SQL doesn't support it.
- **Don't alias a wrapped expression back to the base column's name.**
  Use a distinct alias.
- **Don't add a per-fielder/per-player tier-1 gate to the SQL and ALSO
  filter again in Python.** Pick one. The reference impls all gate at
  SQL level (the 6-term Tier 1 gate in `fielding.md`).
- **Don't skip the `min_periods=1` on rolling.** Early-season weeks
  will be NaN and the line will start mid-season instead of at week 1.
- **Don't forget `groupby("org")` before `.rolling()`** — otherwise the
  rolling window crosses org boundaries and you get cross-contamination.

---

## Bug history

- **Apr 12 2026** (`kpi-parallelization.md` Apr 13 entry): Initial
  rolling chart implementation across all 6 surfaces. Used cumulative
  expanding for the trial — flattened by mid-season, abandoned. Settled
  on 4-week rolling.
- **Apr 13 2026**: Carried numerator/denominator counts through daily →
  weekly aggregation (instead of mean-of-daily-rates). Fixed silent
  drift on rate metrics where weekly play counts varied.
- **Apr 26 2026** (catcher): `c_kpi_data.py` originally used
  `_ORG_MONTHLY_PITCHES_QUERY` etc. with monthly grain only. Chart line
  drew as 6 stairsteps, no weekly bumps. Refactored to
  `_ORG_DAILY_PITCHES_QUERY` (daily grain) + `_fetch_weekly_org_chart_data`
  groupby + 4-week rolling SUM on numer/denom. Commit `42c3f6f`.
- **Apr 27 2026** (BR): Same pattern applied. SB / CS / FT3 / S2H
  cumsum across weekly rows; 1B PL / SL 4-week rolling SUM on
  numerator + count denominator. Commit `5478b96`.
- **Apr 27 2026** (OF/IF first attempt — WRONG): Switched to
  per-fielder per-week PERCENTILE_CONT (`_WEEKLY_FIELDER_TRACKING_QUERY`).
  Rolling-avg of weekly P99s. Chart line dropped 3–5 mph below the
  tracker value because of the per-week-then-roll bias described above.
  Commit `5478b96` originally; partial revert in `237ea2e`.
- **Apr 27 2026** (OF/IF second attempt — WRONG #2): Tried using
  count-weighted org AVG instead of percentile. Same daily SQL but org
  AVG instead of per-fielder P95/P25/P99. Broke metric definition —
  chart line was reading a different metric than the rank box. Caught
  immediately. Reverted via `237ea2e`.
- **Apr 27 2026** (OF/IF T-SQL CTE alias bug): When rewriting the
  per-fielder query, aliased gate columns (`out_made`, `dcbp_cp`,
  `dcbp_ct`, `tdm_cp`, `tdm_ct`) in the SELECT and referenced them in
  the same CTE's WHERE. T-SQL doesn't allow that. Plus `out_made`
  alias collided with `dcbp.out_made` → ambiguous column error. Fixed
  by inlining all gate expressions in WHERE. Commit `444cf1f`.
- **Apr 27 2026** (OF/IF correct fix — `8a8f378`): Pool-then-percentile.
  `_PER_FIELDER_DAILY_RAW_QUERY` returns raw per-fielder per-game
  observations. Python `_rolling_pool_org_weekly` gathers trailing 4
  weeks of observations per fielder, computes `np.percentile` on the
  pool, weighted-avgs to org per week. Chart values now within ~1 mph
  of tracker by mid-season. **THIS IS THE CANONICAL PATTERN** for any
  future per-player percentile chart metric.

---

## Cross-references

- `kpi-parallelization.md` — P2/P3/P4 query parallelization (parallel topic)
- `kpi-roster-filter.md` — Season table active-roster filter (display layer; sibling rule)
- `three-surface-parity.md` — chart line vs tracker vs PD Goals invariants
- `multi-level-rollup.md` — per-metric n_obs weighting iron rule
- `fielding.md` — Tier 1 6-term competitive-play gate
- `gc2-metrics.md` — metric definitions (R2K%, SurPP, FramRAA, etc.)
- `pitfalls.md` — T-SQL BIT casting, NaN in IN clauses (related SQL gotchas)
