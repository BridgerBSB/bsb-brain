---
paths:
  - "**/src/*.py"
  - "**/scripts/*.py"
---
# Three-Surface Parity — BLOCKING

For each domain (Hitting, Pitching, Catcher, OF, IF, BR), the **same metric is computed in three places**. Any change to ONE of these surfaces MUST be propagated to the other TWO before the commit ships. Single-surface fixes silently drift the values across views and break user trust.

## The Three Surfaces

| Domain | Tracker (live app) | KPI Weekly (PDF report + chart) | PD-Goals Org KPI Report |
|---|---|---|---|
| **Hitting** | `barrelsville/src/tracker_data.py` (Org Rankings tab) | `barrelsville/src/hitter_kpi_data.py` + `hitter_kpi_report.py` | `pd-goals/src/org_kpi_data.py` (hitting section via `get_hitting_org_stats`) |
| **Pitching** | `bullpen-report/src/tracker_data.py` (Org Rankings tab) | `bullpen-report/src/pitcher_kpi_data.py` + `pitcher_kpi_report.py` | `pd-goals/src/org_kpi_data.py` (pitching section) |
| **Catcher** | `intangibles/src/catching_tracker_data.py` + `catching_tracker_page.py` | `intangibles/src/c_kpi_data.py` + `c_kpi_report.py` | `pd-goals/src/org_kpi_data.py` (catcher section) |
| **Outfield** | `intangibles/src/fielding_tracker_data.py` + `fielding_tracker_page.py` via `render("OF")` | `intangibles/src/of_kpi_data.py` (uses shared `fielding_tracker_data.py`) | `pd-goals/src/org_kpi_data.py` (OF section) |
| **Infield** | `intangibles/src/fielding_tracker_data.py` + `fielding_tracker_page.py` via `render("IF")` | `intangibles/src/if_kpi_data.py` (uses shared `fielding_tracker_data.py`) | `pd-goals/src/org_kpi_data.py` (IF section) |
| **Baserunning** | `intangibles/src/br_tracker_data.py` + `br_tracker_page.py` | `intangibles/src/br_kpi_data.py` | `pd-goals/src/org_kpi_data.py` (BR section) |

> **Also consumes IF PAA/EO (4th surface, reuse not redefinition):** the daily IF report's "Team PAA/EO" box (`intangibles/src/if_postgame_data.py::get_team_paa_eo`) reuses the canonical `fielding_tracker_data._DCBP_QUERY` calibration math — `SUM(paa_cal)/SUM(expected_outs)` over the level's HOU IF. Any PAA/EO calibration change must keep it in sync. See `if-team-paa-eo-box-status` memory.

## What Counts as a Change Requiring Propagation

ANY of these on a metric query/aggregation:
- WHERE filter (date range, sched_type, level, c_id IS NOT NULL, pitch_id > 0, etc.)
- JOIN keys / extra JOINs
- Range filter (e.g., arm BETWEEN 60 AND 94, pop_time BETWEEN 1.70 AND 2.35)
- Percentile target (P99, P10, P01, etc.)
- Aggregation column (which n_X count is the weight at each tier)
- Sign convention (e.g., br_rv negation for BlockRAA — see `multi-level-rollup.md`)
- Bucket boundaries (CSC framing buckets, pop_time 2B vs 3B ranges)
- Pool gating (Tier 1 6-term gate on fielding, c_id NOT NULL gates on catching)

## Workflow Before ANY Commit That Touches a Metric

```
1. Identify the metric + the surface you changed.
2. grep the OTHER two surface files for the same metric:
     grep -n "metric_name\|column_name\|table_name" <other_surface>.py
3. Confirm the same filter/aggregation logic exists in the other two.
4. If divergent: apply the same fix to the other two.
5. If functionally equivalent (e.g., one uses sv.year=:season, other uses YEAR(sv.sched_date)=:season): no change needed but note it.
6. Test all three views show the same value for HOU.
```

## Common Per-Surface Differences (NOT Bugs)

| Aspect | Tracker | KPI Weekly | PD-Goals |
|---|---|---|---|
| Date filter | No `end_date` cutoff (live data) | Per chart date range | `<= :end_date` (report-as-of) |
| Multi-level | Aggregates per-level → all-level via Python | Per-level only (one PDF per level) | Single SQL pass across all levels |
| Caching | Streamlit `@st.cache_data` | Generated on-demand | Generated on-demand |

These differences DON'T break parity as long as the underlying SQL filters/aggregations are equivalent. Date drift is acceptable when small.

## Default Column Parity — Tracker Defaults Mirror PD-Goals Org KPI

**Rule:** Every affiliate tracker's Org Rankings tab MUST default to the
same metric columns as the matching PD-Goals org KPI report section.
Other columns stay selectable via the sidebar but are NOT default.

This isn't about correctness (all columns compute the right value); it's
about the **"immediate visibility"** sign-in experience. Users compare the
tracker to PD-Goals side-by-side. If the default column set diverges, the
tracker feels like a different report even when the numbers agree.

| Tracker | PD-Goals Reference | File |
|---|---|---|
| Catcher | `CATCHER_COLS` in `pd-goals/src/org_kpi_report.py` | `catching_tracker_page.py` `_DEFAULT_METRICS` |
| OF | `OF_COLS` | `fielding_tracker_page.py` via `LEADERBOARD_COLS` order |
| IF | `IF_COLS` | same |
| BR | `BR_COLS` | `br_tracker_page.py` `_DEFAULT_METRICS` |

See Apr 19 2026 commit `6907e01` for the BR + catcher default alignment.

## Bug History (All Domains) — Apr 18-19 2026

Documented as a learning exercise. Each was a single-surface fix that
diverged values across the three views; ALL are now fixed.

### Catcher

| Bug | Affected surfaces | Fix commit |
|---|---|---|
| `_get_baserunner_advance_rv` returned positive (batting-team) instead of negated (pitching-team) → BlockRAA rank inverted | All 3 | `2aa1555` (tracker), `7b9f059` (PD-Goals), `c5e0621` (KPI weekly inherits via import) |
| Tracker Pop2B base filtered to SBA events only; PD-Goals/KPI weekly use all TDM throws → smaller pool, different P01 | Tracker (org + per-catcher) | `99f077d` (org), `28f84ae` (per-catcher) |
| `pv.pitch_id > 0` filter missing on PD-Goals blocking + KPI weekly per-catcher blocking | PD-Goals + KPI weekly | `5541a49` (PD-Goals), `28f84ae` (KPI weekly) |
| Multi-level org Arm/Exch weighted by `comp_throws` instead of `n_arm`/`n_exch` (per-metric n_obs) | Tracker org tab + per-catcher leaderboard | `c19a2f1` (org), `f3a290c` (per-catcher) |
| Framing buckets (E Stl/Stl/Mid/Loss/B Loss) + R2K% blank in tracker org tab — Streamlit cache stale + state issue | Tracker | resolved by user redeploy |
| `FramRAA*` / `BlockRAA*` duplicate display columns | Tracker UI | `4e9e0f2` |
| **FramRAA ~0.4 off at single + multi level** — per-catcher `_FRAMING_QUERY` + `org_map` indirection with `drop_duplicates("catcher_id")` mis-attributed promoted catchers; `ev.c_id IS NOT NULL` gate dropped pitches PD-Goals includes via direct fielding_team_id groupby | Tracker | `bba6fa7` — added direct SUM to `_ORG_PITCHES_COMBINED_QUERY` |
| **Framing buckets off at "All Levels"** — `aggregate_org_across_levels` pitch-weighted per-level rates, but each bucket has its own denominator (n_e_stl_total ≠ n_pitches) | Tracker | `bba6fa7` — exposed 11 count columns in SQL, re-derive rates from sums |
| **Depth NULL at "All Levels"** — not in any aggregation branch of `aggregate_org_across_levels` | Tracker | `bba6fa7` — added to n_sba_events weighted-avg loop |
| **R2K% 1 decimal in PD-Goals PDF** — `CATCHER_COLS` + `PITCHING_COLS` fmt was `pct1` | PD-Goals | `169bda4` — both switched to `pct2` |
| **Depth divergence — 5-surface drift to two definitions** May 9 2026: tracker org + tracker per-catcher + PD-Goals all used per-SBA-event AVG (~100-300 events/catcher); KPI weekly used per-pitch but missing IBB/pitchout exclusion; postgame canon = per-pitch with IBB+pitchout exclusion (5,000-15,000 pitches/catcher). Per-SBA-event tracker per-catcher was completely missing (col absent from query). | All 3 + 2 | Sequence: per-SBA fix shipped `480b51b` (intangibles), then full convergence to postgame canon |

### Depth — CANON (BLOCKING, May 9 2026)

**Postgame catcher report is the canonical definition.** All other surfaces MUST mirror it exactly.

```sql
AVG(pos.y_at_pitch_release) AS depth
FROM Astros.Pitches_View pv
JOIN Astros.Events_View ev ON pv.sched_id = ev.sched_id AND pv.ab_event_id = ev.event_id
JOIN groundcontroltracking.Tracking.Play_Starting_Positions pos
    ON pv.sched_id = pos.sched_id AND pv.pitch_id = pos.pitch_id AND pos.pos_id = 2
WHERE ev.c_id IS NOT NULL  -- (or = :catcher_gc_id for per-catcher)
  AND pv.pitch_id > 0
  AND pv.pitch_result NOT IN ('intentional_ball', 'pitch_out')
```

**Reference implementation:** `intangibles/src/catcher_data.py::_SEASON_DEPTH_QUERY` (line 1176).

**5 surfaces in lockstep:**
- Postgame: `intangibles/src/catcher_data.py::get_season_catcher_depth` + `get_catcher_depth` (per-game)
- KPI weekly: `intangibles/src/c_kpi_data.py:813-828` (per-catcher CTE — IBB+pitchout exclusion added with this fix)
- Tracker per-catcher: `intangibles/src/catching_tracker_data.py::_DEPTH_PER_CATCHER_QUERY` (separate from `_SBA_METRICS_AGG_QUERY` because Pitches_View ≠ CatcherDefense_SBA_Metrics)
- Tracker per-catcher monthly: `intangibles/src/catching_tracker_data.py::_MONTHLY_DEPTH_PER_CATCHER_QUERY`
- Tracker org season + monthly: `intangibles/src/catching_tracker_data.py::_ORG_DEPTH_QUERY` + `_ORG_MONTHLY_DEPTH_QUERY` (separate from `_ORG_AUGPOP_DIRECT_QUERY` for the same reason)
- PD-Goals org: `pd-goals/src/org_kpi_data.py::_CATCHER_AUGPOP_ORG_QUERY` `depth_base` CTE (uses Pitches_View, NOT the SBA-event base)

**Multi-level rollup weight:** `n_depth_pitches` (count of non-null `pos.y_at_pitch_release` rows per catcher / org / level after filters). NOT `n_sba_events`. Set in `catching_tracker_page.py::_COUNT_WEIGHTED_KEYS["depth"] = "n_depth_pitches"`. Single-pool == multi-level rollup matches exactly.

**What NOT to do:**
- Don't add depth to any SBA-event-keyed query (`_SBA_METRICS_AGG_QUERY`, `_ORG_AUGPOP_DIRECT_QUERY`, etc). The SBA event subset biases toward situations with runners on, where catcher positioning may legitimately differ.
- Don't drop the IBB/pitchout exclusion. Postgame has it; convergence requires every other surface to match.
- Don't combine depth aggregation with augpop_time aggregation in one CTE. The pools differ — augpop is per-SBA-event, depth is per-pitch. Keep them as separate CTEs and merge on `org` / `catcher_id` in the outer SELECT.
- Don't weight multi-level depth by `n_sba_events`. Use `n_depth_pitches`.



### OF / IF

| Bug | Affected surfaces | Fix commit |
|---|---|---|
| `comp_plays` / `comp_throws` mis-weighting at multi-level | Tracker org tab | `7d4c1d4` — exposed n_X_total columns, rewrote weight_map |
| `COUNT(*) AS comp_plays` was actually total_plays | Tracker | `624bce9` — split into total_plays + comp_plays (4-term OR) |
| **OF multi-level drift on TopSpd / React / UseReact / ranks** — per-level SQL query means `PERCENTILE_CONT OVER (PARTITION BY fielder_id)` partitions WITHIN each level only. Python weighted-avg of per-level percentiles diverges from single-pool percentile for cross-level fielders (CF prospects move up/down more than 2B/SS, so OF drifted visibly while IF looked identical). Same code, different data patterns. | Tracker | `1dd24bb` — new `_build_levels_filter` + `_get_pooled_org_stats` + `get_org_rankings_pooled` + `_load_org_rankings_pooled`; Org Rankings tab branches to pooled path when 2+ levels selected in a single year |

### BR

| Bug | Affected surfaces | Fix commit |
|---|---|---|
| PBL `pbl.ignore_flag = 0` + `pv.pitch_id > 0` missing on all 4 tracker lead queries (`_LEADS_QUERY`, `_MONTHLY_LEADS_QUERY`, `_ORG_LEADS_QUERY`, `_ORG_MONTHLY_LEADS_QUERY`) → lead averages inflated/polluted by ignored tracking reads and junk pitches | Tracker | `6907e01` — all 4 queries now filter both |
| Bases On missing from Org Rankings | Tracker | `6907e01` — new `_ORG_TIMES_ON_QUERY` mirroring PD-Goals `_BR_TIMES_ON_ORG_QUERY`, wired into `_get_single_level_org_stats` as 6th parallel query; `_build_org_display` now respects info_cols and shows Bases On |
| Default columns diverged from PD-Goals BR_COLS | Tracker | `6907e01` — aligned `_DEFAULT_METRICS` to SB, CS, 1→3, 2→H, 1B Prim, 1B Sec, 2B Prim, 2B Sec |
| SB% added as 3rd default column | Tracker + KPI weekly + PD-Goals org KPI | May 5 2026 — `b101384` (PD Goals BR_COLS), `cdc6287` (Intangibles BR KPI TABLE_COLS + tracker `_DEFAULT_METRICS`). Default order now: SB, CS, **SB%**, 1→3, 2→H, 1B Prim, 1B Sec, 2B Prim, 2B Sec. Pooled `100*SUM(SB)/SUM(SB+CS)` for orgs; raw runner counts for per-runner table. CS includes pickoffs (event_result_id 4,5,6,7,29,30,31) per existing canon. Full precision through aggregation per `rules/never-round-until-display.md` |

### Hitting (Apr 20 2026 — BLOCKING rules below)

Multi-session parity push across `barrelsville/src/tracker_data.py` ↔ `pd-goals/src/org_kpi_data.py`. Four display metrics (gcOBA, xwOBA, wRC+, Ctct%) now match cell-for-cell. See `memory/hitting-org-parity-apr20.md` for full session log. Five bug classes surfaced; codify here so they never reappear.

| Bug | Affected surfaces | Fix commit |
|---|---|---|
| K/BB ratio in tracker (division) vs K-BB% in weekly + PD-Goals (subtraction) | Tracker | `cc45222` — renamed `kbb` key → `k_bb_pct`, replaced `k/b` with `k - b` throughout; league distribution helper rebuilt |
| Ctct% multi-level rollup weighted by n_pitches (wrong denom — Ctct% denom is swings) | Tracker | `10fb0a8` — removed from `pitch_weighted` list, added count-derived `(total_swings - total_whiffs) / total_swings` alongside whiff_pct/barrel_pct |
| R2K% displaying raw 4-5 decimals | PD-Goals | `f6f5a88` — added `pct2` branch to `_format_value` (was falling through to `str(val)`) |
| PD-Goals xwoba/woba used 4-MiLB-avg blended weights; tracker used per-level | PD-Goals | `6833b16` — added `wl` subquery JOIN on `(year, level_code)` with `AVG` per pair |
| Weight JOIN `ON wl.year = sv.year` NULLed all 2026 weights early-season | PD-Goals | `3035f19` — added `:lookup_year` param via `_lookup_year_for_weights(season)` helper |
| `_get_league_woba_env_by_level` used `SELECT wOBA` (first row via `.iloc[0]`); tracker uses `SELECT AVG(wOBA)`. Guts.woba_lwts has multiple rows per (year, level_code) for league splits | PD-Goals | `a4e08ac` — switched to AVG. Fixed wRC+ 1-point gap |
| `batter_ev_p95` CTE scoped to 4 MiLB only; tracker's `EV_MISREAD_CTE` covers 7 levels (MLB + 4 MiLB + ROK + DSL). Promoted batters had MiLB-only P95 in PD-Goals, full-career in tracker → misread threshold diverged | PD-Goals | `9bd6abf` — aligned scope + added `pitch_result_id IN (12,13,14)` + `hit_exit_speed > 0 AND < 125` (match tracker) |
| **wOBA denom was `COUNT(pa=1 AND ibb=0)` (includes SH since `ev.pa=1` for SH); tracker uses `AB + BB - IBB + HBP + SF` (excludes SH)** | PD-Goals | `8327766` — fixed both `_HITTING_ORG_QUERY` and `wrc_by_level_query` denoms. wRC+ now aligned. Bug was masked pre-`6833b16` because the flat-weight error offset the SH-inclusion error |
| **`_get_hit_specs_exponents` had `if month<5: lookup_year=season-1` prior-year fallback; tracker queries `:season` directly. PD-Goals used 2025 exponents, tracker 2026 → persistent ~0.003 xwoba gap all season ("never aligned")** | PD-Goals | `917e916` — dropped the fallback. xwoba now aligned |

### Hitting At-Contact Metrics (Apr 26 2026)
| Metric | Tracker | KPI Weekly | PD-Goals Org |
|---|---|---|---|
| Bat Speed | `barrelsville/src/tracker_data.py::_BS_QUERY` + `_compute_batter_bat_speeds` | `barrelsville/src/hitter_kpi_data.py::_compute_bat_speed_per_batter` | `pd-goals/src/org_kpi_data.py:813` raw + `:855` cleaning |
| VBA at contact | (not surfaced) | (not surfaced) | (not surfaced) — only PD Flag Tracker `pd-goals/src/drift_hitting.py:266` |
| AA at contact | `barrelsville/src/tracker_data.py::_AACON_QUERY` | (via tracker import) | (not currently surfaced) |

## Hitting Org Parity — BLOCKING Rules

Before shipping ANY change to `pd-goals/src/org_kpi_data.py::get_hitting_org_stats` or `barrelsville/src/tracker_data.py` org rankings:

1. **wOBA denom is ALWAYS `AB + BB - IBB + HBP + SF`.** Never `count of pa=1 non-IBB`. Astros DB `ev.pa=1` for sacrifice hits — using a PA count inflates the denom and drops wOBA (and wRC+) by ~1 point. This rule pairs with event-anchored aggregation: drive FROM `Events_View` with `LEFT JOIN Pitches_View ON cur_event_id` so SUMs aren't also inflated by pitches-per-PA. See `rules/event-vs-pitch-anchored.md` + `rules/woba-rules.md` numerator patterns. Canonical impl: `pd-goals/src/org_kpi_data.py::_HITTING_ORG_QUERY`.
2. **Weight resolution is per-level, NOT blended.** For tracker (single-level per query): pass that level's weights as params. For PD-Goals (single-query all levels): JOIN `Guts.woba_lwts` on `(year, level_code)` per-pitch with `AVG()` per-pair to handle league splits.
3. **Weight lookup_year falls back to `season-1` BEFORE May.** Guts.woba_lwts typically doesn't have current-year rows until mid-season. Both apps MUST use the same fallback: `_lookup_year_for_weights(season)` (PD-Goals) / `_get_woba_weights` internal check (tracker). Drop-in match required.
4. **Exponent lookup does NOT fall back to prior year.** Tracker's `_get_hit_specs_exponents(season)` queries `:season` directly. PD-Goals must match. If the 2026 row is missing, BOTH fall back to `{1.0, 1.0, 1.0, 1.0, 1.0}` defaults (do not cross-contaminate with weight fallback logic).
5. **Misread-filter CTE (`batter_ev_p95`) scopes across 7 levels.** MLB + 4 MiLB + ROK + DSL. Filter BIP-only (`pitch_result_id IN (12,13,14)`) and `hit_exit_speed > 0 AND < 125`. Copy tracker's `EV_MISREAD_CTE` verbatim when porting.
6. **League env helpers use `AVG()`.** `_get_league_woba_env_by_level` → `SELECT AVG(wOBA), AVG(wOBA_scale), AVG(runs_per_pa)`. Any `SELECT wOBA` without AVG picks up `.iloc[0]` which breaks when Guts.woba_lwts has league-split rows.
7. **Multi-level rate metrics re-derive from counts, not weighted-avg by n_pitches.** Ctct% weights by swings. Whiff% by swings. Barrel% / Hard% / PullAir% / Dmg% by tracked BIP. wOBA by AB+BB-IBB+HBP+SF. xwOBA by non-IBB PA. If a per-metric denom count isn't already exposed per-level, expose it; don't substitute `n_pitches`.

## Diagnostic

`sql-queries/xwoba-parity-diag.sql` — runs both tracker-pattern and PD-Goals-pattern xwoba for HOU side-by-side. If numer+pa differ, SQL is the bug; if they match but apps show different values, the bug is in Python post-processing (weight/exponent fetch helpers, rounding, column rename/merge).

## Audit Status — All Known Default-Metric Bugs Fixed (Apr 19 2026)

Pull + redeploy all three apps (Barrelsville, Arm Farm, Intangibles) to
land these. Values match across all three surfaces on default columns.

### Deferred (intentionally, per user Apr 19 2026)

- **Non-default (selectable) metrics** — e.g. FramRAA650, BlockRAA650,
  AdjNSP, AccPen, Bounce%, xPP, Pop3B, TL 1B/2B, Split 1, Accel. Haven't
  been audited across all three surfaces. Low-priority: user explicitly
  deferred. Revisit when one becomes a displayed default or a direction.
- **Catcher multi-level percentile pooling** (Arm/Exch/Pop2B/Pop3B/AugPop).
  Same architectural pattern as the OF/IF fix in `1dd24bb` could apply,
  but catchers move between levels less than CF prospects so drift is
  likely invisible. Revisit if user reports it.

## What NOT to Do

- **Never assume "this is just for the tracker"** — if it touches a defensive metric, all 3 surfaces matter
- **Never trust per-surface tests in isolation** — if the tracker matches itself, that doesn't mean it matches PD-Goals
- **Never patch display rounding to hide drift** — fix the underlying SQL/aggregation
- **Never delete a query without checking all callers** — the consolidation in `6b8485c` only worked because the dead queries were verified unused first
