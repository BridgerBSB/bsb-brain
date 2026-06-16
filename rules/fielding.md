---
paths:
  - "intangibles/**/*"
  - "pd-goals/**/*"
  - "**/fielding*.py"
  - "**/if_*.py"
  - "**/of_*.py"
---

# Fielding Query Standard (Updated Apr 16, 2026)

## Three-Tier Architecture

### Tier 1 — KPI Gate (tracking metric aggregation)
- **OF:** `DCBP.out_made + DCBP.CP + DCBP.CT + TDM.CP + TDM.CT + (arm >= 75) > 0`
- **IF:** `DCBP.out_made + DCBP.CP + DCBP.CT + TDM.CP + TDM.CT + (arm >= 70) > 0`

#### Why both DCBP and TDM competitive_play AND competitive_throw? (Updated Apr 16, 2026)
GC2 only checks DCBP's competitive_play to decide if a play counts. But DCBP
(Defense_Combined_By_Pos) and TDM (Tracking_Defensive_Metrics) independently
flag the same play and **can disagree**. When they do, GC2 drops the play and
all its tracking data. Example: Trammell 04/01 — TDM.CP=1 with TopSpd=27.2,
but DCBP.CP=0. GC2 excluded the play entirely. Same applies to competitive_throw.

Our gate checks BOTH tables for BOTH flags (CP and CT). If either table says
competitive play or competitive throw, the play counts. This catches everything
GC2 catches, plus plays it misses.

#### BLOCKING RULES for Tier 1:
1. **Tier 1 is the ONLY gate for ALL tracking metrics.** NEVER add `competitive_play = 1` as an extra filter on top of Tier 1.
2. **NEVER use CP=1 alone** as a tracking metric gate. A play with `out_made=1, arm=78, CP=0` passes Tier 1 and its tracking data MUST be included.
3. **CP count is display-only.** `SUM(competitive_play)` for volume display, never as a filter. Includes all 4 competitive flags: `DCBP.CP + TDM.CP + DCBP.CT + TDM.CT`.

#### Metric aggregation from Tier 1 rows:
- Speed/reaction/accel: ALL Tier 1 rows (TopSpd capped at 34)
- Arm: arm range filter (OF: 75-108, IF: 70-108) on Tier 1 rows
- Exchange: exchange >= 0.4 AND arm >= floor on Tier 1 rows
- Catcher arm: 60-94 (unchanged from GC2)

#### PR Detection — BLOCKING RULES (Apr 16, 2026)

Personal records in daily postgame (`of/if_postgame_data.py::detect_prs()`) compare today's raw play value against `get_player_all_time_bests()` (MIN/MAX across ALL gated plays, excluding today's sched_ids).

1. **6-term Tier 1 gate** on both today's play AND historical bests query.
2. **Inner `cp_ok`** for speed/reaction PRs: `TDM.CP == 1 OR DCBP.CP == 1 OR TDM.CT == 1`. Arm/exchange use range filters only (no cp_ok).
3. **Strictly better** — `val > prev` (higher=better) or `val < prev` (lower=better). Ties are NOT PRs.
4. **All-time bests include ALL sched types** (R, S, E, V, I) and ALL years. A spring training play can set the bar and block a regular season PR. This is intentional — a PR means best EVER.
5. **No prev_best = no PR** — if a player has zero historical gated plays for a metric, today's play is skipped (not counted as a PR).
6. **Audit query:** `sql-queries/fielding-pr-audit.sql` — reusable template with video. Swap gcid, pos_ids, metric, threshold, arm floor.

#### Implementation (11+ files, 20+ SQL queries + Python):
| File | Instances | Gate |
|------|-----------|------|
| `fielding_base.py` | `filter_tier1()` Python function | 6-term: om + dcbp_cp + dcbp_ct + tdm_cp + tdm_ct + arm |
| `of/if_tracker_data.py` | 4 queries each (player, monthly, org, org/monthly) | SQL WHERE |
| `of/if_kpi_data.py` | Daily tracking + tier1 CTE | SQL WHERE |
| `of/if_postgame_percentiles.py` | base CTE | SQL WHERE |
| `of/if_postgame_data.py` | PR gate + all_time_bests | SQL WHERE (6-term) |
| `of/if_postgame_report.py` | Play display | SQL WHERE |
| `of/if_weekly_report.py` | Weekly display | SQL WHERE |
| `of/if_postgame_page.py` | App display | SQL WHERE |
| `fielding_tracker_data.py` | 4 queries (shared OF/IF) | SQL WHERE |
| `snapshot_data.py` | 1 query | SQL WHERE |
| `pd-goals/src/stats.py` | Fielding metrics | SQL WHERE (6-term) |

#### Daily/Weekly Play Queries — dcbp_comp_play column (Apr 16, 2026)
Play queries now SELECT `dcbp_comp_play` column from DCBP (`CAST(dcbp.competitive_play AS int)`) for display-level competitive play counting.

### Tier 2 — Play Visibility (individual play display)
5-condition OR filter:
1. `out_prob BETWEEN 0.02 AND 0.98`
2. `competitive_throw = 1 AND first_defender`
3. `|PAA| >= 0.05 AND first_defender`
4. Fly ball by bearing zone (non-HawkEye fallback)
5. `first_defender IS NULL AND TDM exists` (orphaned tracking)

### Tier 3 — Attribution (difficulty analysis)
`first_defender = this fielder AND out_prob IS NOT NULL`

### No Gate — Cumulative Value Metrics (OAA, PAA/EO, RAA)
ALL DCBP rows, no filtering. Matches GC2 exactly.

## KPI Display Difference
- **OF:** TopSpd, AccelCU, AccelCD, React, **UsefulReact**, ReactRad + Arm + Exchange
- **IF:** TopSpd, AccelCU, AccelCD, React, ReactRad, **ReactAccRad** + Arm + Exchange

## GC2 Metric Reference Table (P-values and filters)

**GC2 uses `competitive_play=1` (DCBP only). We use the 6-term Tier 1 gate instead.**

| Metric | Percentile | GC2 Filter | IF | OF |
|--------|-----------|--------|-----|-----|
| TopSpeed | P95 | GC2: `CP=1`, `top_speed<=34` | Same | Same |
| AccelChestUp | P75 | GC2: `CP=1` | Same | Same |
| AccelChestDown | P75 | GC2: `CP=1` | Same | Same |
| ReactionTime | P25 | GC2: `CP=1` | Same | Same |
| UsefulReaction | P25 | GC2: `CP=1` | NULL for IF | Same |
| ReactionRadius | P25 | GC2: `CP=1` | Same | Same |
| ReactionAccuracyRadius | P25 | GC2: `CP=1` | Same | Same |
| ArmStrength | P99 | GC2: `competitive_throw=1`, arm 60-100 (OF), 60-94 (IF), 60-94 (C) | 60-94 | 60-100 |
| Exchange | P10 | GC2: `competitive_throw=1`, `exchange>=0.4`, `arm>=60` | `exchange_dp` col | `exchange` col |

**Our code differs:** Arm/Exchange do NOT use `competitive_throw=1`. Arm floor IS the filter (OF=75, IF=70). Arm ceiling=108 (GC2: 100 OF, 94 IF).

## Org-Level Rollup — Per-Fielder Weighted Avg (Apr 17 2026)

The P-metrics above are individual-level (one value per fielder, partitioned by `fielder_id`). For ORG RANKINGS (where 30 orgs get ranked 1-30), each fielder's value is **weighted-averaged by their observation count** to produce one org value, not recomputed from the raw play pool.

**Files that use this pattern at org level:**
- `pd-goals/src/org_kpi_data.py` — `_OF_TRACKING_ORG_QUERY`, `_IF_TRACKING_ORG_QUERY`
- `intangibles/src/fielding_tracker_data.py` — `_ORG_TRACKING_AGG_QUERY`, `_ORG_MONTHLY_TRACKING_AGG_QUERY` (shared OF+IF, powers KPI weekly)
- `intangibles/src/of_tracker_data.py` — `_ORG_TRACKING_QUERY`, `_ORG_MONTHLY_TRACKING_QUERY` (OF tracker page)
- `intangibles/src/if_tracker_data.py` — `_ORG_TRACKING_QUERY`, `_ORG_MONTHLY_TRACKING_QUERY` (IF tracker page)

See `gc2-metrics.md` "Org Rollup for P-metrics" section for the full SQL pattern.

## OAA (renamed from DRS, Mar 25)
`SUM(out_made - out_prob)` — matches Statcast definition. Formula unchanged.

## GC2 Aggregation Pattern — PERCENTILE_CONT
```sql
SELECT DISTINCT ...
    PERCENTILE_CONT(x) WITHIN GROUP (ORDER BY CASE WHEN filter THEN col END)
    OVER (PARTITION BY player_id)
```
Window functions compute same value per row in partition, SELECT DISTINCT collapses to 1 row per player.

**Source:** `Astros.Tracking_Defensive_Metrics` for both IF and OF (pos_id differentiates).
**Value metrics:** Separate query from `Defense_Combined_By_Pos` with GROUP BY.

## Shared Module
`intangibles/src/fielding_base.py` — Events_View architecture, position configs, filter functions, Python-side aggregation.

## Design Doc
`intangibles/docs/OF_FIELDING_QUERY_STANDARD.md`
