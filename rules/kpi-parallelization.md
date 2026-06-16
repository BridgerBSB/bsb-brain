# KPI Report Parallelization Pattern

Applied Apr 12, 2026. Barrelsville gets all 3 tiers. Arm Farm + Intangibles get P2+P4 only (monolithic CTE queries, no sub-queries to parallelize). PD Goals TBD.

## Three Tiers

### P3: Parallelize Sub-Queries Within `get_player_table_data`

**Problem:** After the main player query, 4 supplemental queries (xwoba, swing_dist, bat_speed, aacon) run sequentially. Each opens its own connection, waits for results, merges.

**Fix:** Extract into `_fetch_supplemental_data()` that runs all 4 via `ThreadPoolExecutor(max_workers=4)`. Each thread gets its own connection from the SQLAlchemy engine pool.

```python
from concurrent.futures import ThreadPoolExecutor

def _fetch_supplemental_data(engine, level_filter, sched_filter, sd, ed, weights, exps):
    def _run(sql, params):
        with engine.connect() as conn:
            return pd.read_sql(text(sql), conn, params=params)

    results = {}
    with ThreadPoolExecutor(max_workers=4) as pool:
        futures = {
            pool.submit(_run, xwoba_sql, xwoba_params): "xwoba",
            pool.submit(_run, swing_sql, date_params): "swing_dist",
            pool.submit(_run, bs_sql, date_params): "bat_speed",
            pool.submit(_run, aacon_sql, date_params): "aacon",
        }
        for future in futures:
            key = futures[future]
            try:
                results[key] = future.result()
            except Exception:
                results[key] = pd.DataFrame()
    return results
```

**Key rule:** Each sub-query result merges onto `all_players` by `batter_id` AFTER all futures complete. The merge logic stays sequential — only the DB I/O is parallel.

### P2: Query Season + Span Concurrently

**Problem:** Reports call `get_player_table_data` twice — once for full season, once for 14-day span. These are independent until percentile ranking.

**Fix:** New `get_player_tables_for_level()` runs both calls via `ThreadPoolExecutor(max_workers=2)`, then applies `apply_season_percentiles()` after both complete.

```python
def get_player_tables_for_level(level_code, season, start_date, end_date, ...):
    with ThreadPoolExecutor(max_workers=2) as pool:
        season_future = pool.submit(get_player_table_data, level_code, season, None, None, ...)
        span_future = pool.submit(get_player_table_data, level_code, season, start_date, end_date, ...)
        season_df = season_future.result()
        span_df = span_future.result()

    if not span_df.empty and not season_df.empty:
        span_df = apply_season_percentiles(span_df, season_df, TABLE_METRIC_KEYS)
    return season_df, span_df
```

**Callers to update:**
- Report generator: `_draw_level_page()` — replace two `get_player_table_data` calls
- Streamlit page: replace two `_load_player_table` cached calls with one `_load_player_tables_both`

### P4: Parallelize Across Levels

**Problem:** Multi-level report generation loops through levels sequentially.

**Fix:** `ThreadPoolExecutor` processes levels concurrently. **Delivery stays sequential** after all PDFs finish.

**Worker cap depends on P3 presence:**
- **Barrelsville** (has P3): `max_workers=3` — each level opens ~10 connections (P2×2 + P3×4×2)
- **Arm Farm / Intangibles** (no P3): `max_workers=min(len(codes), 7)` — each level opens ~2 connections (P2 only), so 7 concurrent is safe

**Placement:** Put the parallelism wherever the level loop lives — CLI script (Barrelsville) or report module (Intangibles BR). Match the existing architecture.

## App-Specific Differences (Audited Apr 12, 2026)

| App | Architecture | P2 | P3 | P4 | Notes |
|-----|-------------|----|----|----|----|
| **Barrelsville** (Hitting KPI) | Main query + 4 sub-queries | YES | YES — xwoba, swing_dist, bat_speed, aacon | YES — CLI, cap 3 | Only app with P3 |
| **Arm Farm** (Pitcher KPI) | Monolithic CTE (pitcher_org → pitch_stats → pa_stats → r2k_stats) | YES | NO — single query, all metrics in CTEs | N/A — single level | gcPerf/gcERA derived in Python post-query |
| **Intangibles — OF** | Monolithic CTE (8 CTEs: base → tier1 → org → counts → percentiles) | YES | NO — single query | N/A — single level per report | |
| **Intangibles — IF** | Monolithic CTE (9 CTEs, similar to OF) | YES | NO — single query | N/A — single level | |
| **Intangibles — BR** | Monolithic CTE (9 CTEs: runner_org → steals → ft3 → s2h → leads) | YES | NO — single query | YES — report module, cap 7 | Only Intangibles KPI with multi-level |
| **Intangibles — Catcher** | Monolithic CTE (8 CTEs) + 1 cached lookup (_get_baserunner_advance_rv) | YES | NO — lookup is cached, not worth threading | N/A — single level | |
| **PD Goals** | per-player metrics | TBD | TBD | TBD | Audit pending |

**Why Arm Farm and Intangibles skip P3:** Their data modules compute everything in a single SQL statement using chained CTEs (each CTE references the previous one). There are no independent sub-queries to parallelize. Barrelsville is the exception — it splits xwOBA, swing distribution, bat speed, and attack angle into separate queries because they hit different tables (Hits_Probabilities, tracking.swing_contact_values).

## Tracker Query Consolidation (Apr 13, 2026)

Affiliate trackers already have P3/P4 equivalent parallelism built in. But the **catcher tracker** had 13 queries per level — too many concurrent connections. Consolidate queries that scan the same base tables.

### Pattern: Merge queries with identical JOINs into single-pass CASE WHEN

**Before (3 separate Pitches_View queries):**
- `_NETK_QUERY` — NetK/P from edge-zone called pitches
- `_STEAL_LOSS_QUERY` — Steal%/Loss% from called pitches  
- `_FRAMING_RAA_RAW_QUERY` — FramRAA from edge-zone takes

**After (1 combined query):**
```sql
SELECT ev.c_id AS catcher_id,
    -- NetK: only CSC 0.05-0.95
    SUM(CASE WHEN pv.called_strike_chance_mlb BETWEEN 0.05 AND 0.95
              AND pv.pitch_result_id IN (cs_codes) THEN ... END) AS netk_per_pitch,
    -- Steal%: only CSC <= 0.05
    CASE WHEN SUM(CASE WHEN ... <= 0.05 THEN 1 END) > 0 THEN ... END AS steal_pct,
    -- Loss%: only CSC >= 0.95
    CASE WHEN SUM(CASE WHEN ... >= 0.95 THEN 1 END) > 0 THEN ... END AS loss_pct,
    -- FramRAA: only pitch_result_id IN (4,5,6) + CSC 0.05-0.95 + rv cols
    SUM(CASE WHEN pv.pitch_result_id IN (4,5,6) AND ... THEN ... END) AS framing_raa_raw
FROM Pitches_View pv JOIN Events_View ev ... WHERE (called pitches) ...
GROUP BY ev.c_id
```

**Same pattern for blocking:** `_BLOCKING_BYPITCH_QUERY` + `_BLOCKING_RAA_RAW_QUERY` → 1 query (both scan CatcherDefense_Blocking_ByPitch).

### Catcher Tracker Results

| | Before | After |
|---|:---:|:---:|
| Season queries/level | 13 | 10 |
| Monthly queries/level | 8 | 7 |
| All 6 levels (season) | 79 | 61 |

### When NOT to Consolidate

- Queries on **different base tables** (TDM vs Pitches_View vs CatcherDefense_Framing)
- Queries with **incompatible WHERE clauses** (R2K needs all pitches, framing needs called pitches only)
- Year-level aggregate tables (CatcherDefense_Framing, CatcherDefense_Blocking) — no level_code filter, different granularity

## What NOT to Parallelize

- The main `_PLAYER_QUERY` itself — it's one big CTE chain, can't be split
- Percentile computation — must happen after all data is merged
- `apply_season_percentiles` — needs both season and span results
- Delivery (Slack/Logic App) — keep sequential to avoid rate limits

## Weighted Chart Aggregation (Apr 13, 2026)

> **For full chart-line implementation patterns, see `kpi-weekly-charts.md`** —
> covers the three metric types (cumulative SUM / rate / per-player percentile),
> the pool-then-aggregate rule, the per-week-then-roll bias trap, and
> reference impls across all 6 KPI weekly surfaces. This section is the
> brief overview; that file is the deep playbook.

KPI trend charts use **4-week/4-month rolling windows** with **play-count-weighted aggregation**. The rolling window gives coaches a bouncy recent-trend visual. The rank box (season-to-date from tracker) shows overall standings. These are intentionally different — chart = recent form, rank = standings.

**Cumulative expanding was tested and reverted** — it flattens out by mid-season (each new week is a tiny fraction of the growing total). Rolling 4-period stays responsive.

**Rule:** NEVER use mean-of-daily-averages for rate stats. Carry raw SUM + COUNT through daily→weekly→rolling, compute ratios at the final step only.

**Reference:** xwOBA in `hitter_kpi_data.py` — carries `xwoba_numer_total` and `xwoba_pa_total` through weekly groupby and rolling window.

### Weekly Hitter Individual Report — Rolling+ Chart
Uses **cumulative expanding** (not rolling window). Each point = season-to-date. The final point matches the table value. This is correct here because it's one player's stats, not 30 orgs trending.

### KPI Report Charts — 4-Period Rolling Window (Weighted)

| Report | Metrics | Aggregation Source | Window |
|--------|---------|-------------------|--------|
| **Barrelsville Hitter** | K%, BB%, Avg EV, Dmg%, xwOBA | Daily SUM/SUM weighted | 4-week rolling |
| **Arm Farm Pitcher** | FPinZ%, InZ%, R2K%, EW%, 2K Proj | Daily SUM/SUM weighted | 4-week rolling |
| **Intangibles OF** | UseReact, TopSpd, ArmOF, PAA/EO | Monthly per-fielder weighted avg from tracker | 4-month rolling |
| **Intangibles IF** | React, TopSpd, ArmIF, PAA/EO | Monthly per-fielder weighted avg from tracker | 4-month rolling |
| **Intangibles BR** | 1B PL, 1B SL | Monthly weighted by n_leads_1b | 4-month rolling |
| **Intangibles Catcher** | SurPP | Monthly weighted by PP+xPP count | 4-month rolling |

**Cumulative SUM metrics (no rolling):** OAA (OF/IF), NetK, FramRAA, BlockRAA, SB, 1→3, 2→H

**Simple rolling OK:** Catcher AugPop2B, R2K% — monthly granularity, no per-catcher pitch counts available

### OF/IF Chart Data Source (Apr 13 fix, updated Apr 17 2026)
Charts pull from `fielding_tracker_data.get_monthly_org_stats()`. The org values themselves (P95 TopSpd, P99 Arm, P25 React, etc.) use **per-fielder weighted avg** — each fielder's individual percentile, then weighted by their observation count to produce one org value per month. This is the **org RANKING value**, not an "org percentile." The 30 orgs are then ranked 1-30 against each other. Matches PD Goals org report + per-position tracker pages exactly. See `gc2-metrics.md` "Org Rollup for P-metrics" for the full pattern.

## Connection Pool Sizing

Barrelsville bumped to `pool_size=10, max_overflow=20` after P2+P3 caused QueuePool timeout on Posit Connect. Other apps may need the same if P2 causes contention under concurrent page loads.

```python
create_engine(url, pool_size=10, max_overflow=20)
```
