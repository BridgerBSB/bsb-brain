---
paths:
  - "**/src/*.py"
  - "**/scripts/*.py"
---
# Multi-Level Org Rollup — Weight Column Rule (BLOCKING)

> **For all percentile (P*) metrics, the implementation pattern lives in
> `rules/pooled-percentile-pattern.md` (BLOCKING).** That rule is the
> canonical 5-piece raw-obs implementation across all trackers. This file
> covers the math/iron-rule weighting that pattern enforces.

## TWO-TIER ARCHITECTURE FOR PERCENTILE METRICS (READ THIS FIRST)

Percentile metrics (Arm P99, Exch P10, TopSpd P95, React P25, Pop2B P01, AugPop P01, etc.) are aggregated in **two tiers** that behave differently. The shape never changes based on what scope (years × levels) is selected — same rule everywhere.

| Selection scope | Individual tier (one player's value) | Org tier (30 players → 1 org value) |
|---|---|---|
| 1 yr, 1 lvl | Pool his raw obs in that scope → his P-value | Weighted-mean of every player's individual P-value |
| Multi yr, 1 lvl | **Pool his raw obs across ALL selected years** | Weighted-mean of every player's individual P-value |
| 1 yr, multi lvl | **Pool his raw obs across ALL selected levels** | Weighted-mean of every player's individual P-value |
| Multi yr, multi lvl | **Pool his raw obs across ALL (year × level) combos** | Weighted-mean of every player's individual P-value |

**Individual = ALWAYS pool raw obs.** Whatever scope is selected, his entire pool of observations → one true P-value (e.g. P99 of his arm-strength throws). This is the same shape as `get_player_all_time_bests` (MIN/MAX across all his raw obs, no aggregation) and `*_postgame_percentiles.py` (PERCENTILE_CONT season-wide pool per player).

**Org = ALWAYS weighted-mean of individuals.** Weighted by per-metric n_obs (`n_arm` for arm_strength, `n_react` for reaction_time, etc. — see "Iron Rule" below). Mediocre players still get their proportional vote; no single starter dominates the org value.

### Why both tiers, not one direct pool?

If you naively pooled all 30 orgs' throws together with `PERCENTILE_CONT OVER (PARTITION BY org)`, every throw counts equally, and a starter with 200 throws drowns out a backup with 5 throws — the "org P99 arm" effectively becomes "the starter's P99 arm." Doesn't represent org strength.

If you naively weighted-mean per-(year, level) percentile values at the INDIVIDUAL tier, you get a number that doesn't exist anywhere in his physical throws (May 2026 Nunez incident: weighted-mean of his 87.5 P99 [2025] and 80.6 P99 [2026] = 85.9, but his TRUE pooled P99 across both years' throws is ~87.5 since his hardest 2025 throws still hold the top 1% of the combined pool).

### Canonical implementation (fielding, May 16 2026)

`intangibles/src/fielding_tracker_data.py::_ORG_POOLED_TRACKING_AGG_QUERY` is the reference. Two-stage SQL CTE in one pass:

```sql
WITH per_fielder AS (
    -- INDIVIDUAL TIER: pool raw obs per fielder across scope
    SELECT DISTINCT org, fielder_id,
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY
            CASE WHEN arm_strength BETWEEN 70 AND 108 THEN arm_strength END)
            OVER (PARTITION BY fielder_id) AS arm_strength,
        COUNT(CASE WHEN arm_strength BETWEEN 70 AND 108 THEN 1 END)
            OVER (PARTITION BY fielder_id) AS n_arm,
        -- ... same pattern for top_speed, reaction_time, exchange, etc.
    FROM base   -- already scoped by level_code IN (...) AND year IN (...)
),
org_agg AS (
    -- ORG TIER: weighted-mean of per-fielder values by per-metric n_obs
    SELECT org,
        SUM(CASE WHEN arm_strength IS NOT NULL THEN arm_strength * n_arm END)
            / NULLIF(SUM(CASE WHEN arm_strength IS NOT NULL THEN n_arm END), 0) AS arm_strength,
        -- ... same pattern for every percentile metric
    FROM per_fielder
    GROUP BY org
)
```

Sibling helper `get_indiv_leaderboard_pooled` returns per-fielder rows directly (skips org_agg) for the individual leaderboard display.

### Where pooled is used (May 16 2026)

| Surface | Pooled? | Notes |
|---|---|---|
| Fielding (OF/IF) ORG view, multi-level OR multi-year | ✅ `get_org_rankings_pooled` | Both tiers correct in one SQL. Now PIN-BACKED for all 7-level combos (May 21 2026) |
| Fielding (OF/IF) INDIVIDUAL leaderboard, multi-level OR multi-year | ✅ `get_indiv_leaderboard_pooled` | Per-fielder pooling. Now PIN-BACKED for all 7-level combos (May 21 2026) |
| Postgame `get_player_all_time_bests` | ✅ MIN/MAX across all his raw obs | Pre-existing canonical pattern |
| Postgame percentile pools (`*_postgame_percentiles.py`) | ✅ Season-wide PERCENTILE_CONT per fielder | Pre-existing canonical pattern |
| **Catcher (any view)** | ❌ NOT YET — no pooled SQL exists in `catching_tracker_data.py` | Same fix pattern needs porting (~6-8 hr) |
| BR | N/A — uses AVG (additive, math-equivalent to pooled) | No fix needed |
| Hitter / Pitcher rate metrics | N/A — re-derive from SUM(numer)/SUM(denom) | No fix needed |
| **PERCENTILE metrics on hitter/pitcher trackers (if any get added)** | Would need pooled SQL too | None currently surfaced at org level |

### Pooled-combo pinning (May 21 2026) — BLOCKING

The May 16 pooled SQL fix introduced live-DB queries on every multi-level
selection — architecturally inconsistent with the codebase's pin-first
standard. May 21 2026 fix: **pin all 2+-level combos** so multi-level
Org Rankings + Indiv Leaderboard become pin lookups (instant) instead of
live DB.

**Scope:** all 7 levels (MLB, AAA, AA, A+, A, Rookie, DSL). User
direction: "every level must be part of the pool — no exclusions."

**Combo count:** 2^7 − 7 − 1 = **120 combos**.

**Pin shape (added to `fielding_tracker_data.py`):**

| Constant | What |
|---|---|
| `POOLED_LEVEL_COMBOS` | Tuple of all 120 sorted-tuple level combos |
| `PREFIX_ORGS_POOLED = "orgs_pooled"` | Bundle-key prefix for pooled org rankings |
| `PREFIX_INDIV_POOLED = "indiv_pooled"` | Bundle-key prefix for pooled per-fielder leaderboard |
| `pooled_combo_tag(level_codes)` | Returns sorted `"+"`-joined tag, e.g. `"aaa+aax+afa+afx"` |

**Bundle key shape:** `<prefix>_<combo_tag>_<ha>_<hand>`
e.g. `orgs_pooled_aaa+aax+afa+afx_all_all`,
`indiv_pooled_aaa+aax_home_all`.

**Pin-first lookup helper:** `_try_pin_pooled_combo(domain, prefix, season,
level_codes, sched_types, ha_split)` in `fielding_tracker_data.py`.
Gates:
- Pins module importable
- Single-year selection only (multi-year would 120× the combos)
- `sched_types` + `ha_split` match canonical pinned combo
- `sorted(level_codes) ∈ POOLED_LEVEL_COMBOS`

`get_org_rankings_pooled` + `get_indiv_leaderboard_pooled` BOTH check
the pin first; fall back to live SQL on miss (multi-year, MLB-only-2-team
combos, non-canonical sched_types, etc.).

**Pin CLI cost:** 120 combos × 2 prefixes × 3 H/A = 720 extra keys per
(domain, year). Pin time per (domain, year) = ~12 hours. Full backfill
of 5 historical years × 2 domains = ~5 days of pin runtime. One-time
cost; Connect's daily refresh handles current year going forward.

**Replication checklist for catcher** (when the catcher pooling fix
finally ships):
1. Add `get_org_rankings_pooled` + `get_indiv_leaderboard_pooled`
   equivalents to `catching_tracker_data.py`.
2. Add `POOLED_LEVEL_COMBOS` + `PREFIX_ORGS_POOLED` + `PREFIX_INDIV_POOLED`
   + `_try_pin_pooled_combo` mirroring fielding.
3. Extend `pin_catching_tracker_seasons.py` to iterate combos and
   write the pooled keys.
4. Re-pin all historical years on work laptop. Same ~12 hr/year cost.

### Bug class — what to NOT do

- **DON'T** weighted-mean per-(year, level) percentiles at the individual tier. That's the Nunez 85.9 bug. Pool the raw obs across scope, ALWAYS.
- **DON'T** direct-pool all org throws together at the org tier (`PERCENTILE_CONT OVER (PARTITION BY org)`). Top thrower dominates. Use weighted-mean of individuals.
- **DON'T** assume "multi-year" needs special handling vs "multi-level". The math is identical — pool the individual's raw obs across whatever (year × level) scope is selected, then weighted-mean to org.

---

## PER-PLAYER `_combine_multi_level` — ALLOWLIST ENFORCEMENT (BLOCKING)

### What this section covers

`_combine_multi_level(df)` in every tracker page file
(`catching_tracker_page.py:649`, `br_tracker_page.py:634`,
`fielding_tracker_page.py:927`, `barrelsville/pages/2_Affiliate_Tracker.py:688`,
`bullpen-report/pages/3_Affiliate_Tracker.py:715`) collapses a multi-level
catcher/runner/fielder/hitter/pitcher's per-level rows into ONE combined row
for the leaderboard display when 2+ levels are selected.

These functions all use an **explicit allowlist pattern** with named bucket
groups (`_SUM_KEYS`, `_PITCH_WEIGHTED_KEYS`, `_COUNT_WEIGHTED_KEYS`,
`_PA_WEIGHTED_KEYS`, `_DERIVE_KEYS`, `_ON_BASE_WEIGHTED_KEYS`,
`_COMP_PLAY_WEIGHTED_KEYS`, `_THROW_WEIGHTED_KEYS` — exact names vary per
tracker). The combine builds a fresh empty `row` dict and copies columns
INTO it from those buckets.

### The bug class — silent NULL on unregistered columns

**Any column in the per-level DataFrame that is NOT registered in one of
the buckets is silently dropped from the combined row.** No warning, no
error, no assertion. The metric column simply isn't in `row.keys()` →
becomes NaN downstream → displays as blank in the leaderboard.

This is the same failure mode for all five tracker `_combine_multi_level`
functions. It's an enforcement gap, not a code-correctness gap.

### Concrete bugs caught from this pattern (May 21 2026 catcher)

**`total_netk` missing from `_SUM_KEYS`** — cumulative `SUM(pv.net_k)` per
level. Should be summed across levels just like FramRAA + BlockRAA. Was
missing entirely. Fix: add to `_SUM_KEYS`.

**`surpp` missing from `_DERIVE_KEYS` + derive logic** — derived as
`passed_pitches − x_passed_pitches`. Both inputs were correctly summed via
`_SUM_KEYS`, but the difference was never recomputed on the combined row.
Fix: add to `_DERIVE_KEYS` + add the subtraction in the re-derive block.

### Second bug class — weight column missing (stale-pin scenario)

`_COUNT_WEIGHTED_KEYS` maps each metric to a per-metric weight column
(Iron Rule, see below). When the weight column is missing from the
DataFrame entirely — typically a **stale pin** built before the weight
column was added to the SQL output — the combine code's
`if weight_col in group.columns` check returns False, falls to the `else`
branch, and sets `row[metric_key] = np.nan` for that catcher/fielder/etc.
across all levels.

May 21 2026 catcher symptoms: Arm Strength, Exchange, Depth all blank on
multi-level catchers reading from pins that pre-dated the `n_arm` /
`n_exch` (Apr 18 2026) / `n_depth_pitches` (later) additions to the SQL.

### Unweighted-mean fallback (BLOCKING canonical pattern, May 21 2026)

Every `_COUNT_WEIGHTED_KEYS` loop MUST include an unweighted-mean
fallback for both bug paths:

```python
for metric_key, weight_col in _COUNT_WEIGHTED_KEYS.items():
    if metric_key not in group.columns:
        row[metric_key] = np.nan
        if weight_col in group.columns:
            row[weight_col] = group[weight_col].fillna(0).sum()
        continue
    metric_notna = group[metric_key].notna()
    if weight_col in group.columns:
        valid = group[metric_notna
                      & group[weight_col].notna()
                      & (group[weight_col] > 0)]
        if len(valid) > 0:
            # Canonical Iron-Rule weighted mean
            row[metric_key] = round(
                float(np.average(valid[metric_key], weights=valid[weight_col])), 2,
            )
        else:
            # Weight col present but all-zero / all-NaN.
            # Unweighted fallback — defensible value beats silent NULL.
            valid_uw = group[metric_notna]
            row[metric_key] = (
                round(float(valid_uw[metric_key].mean()), 2)
                if len(valid_uw) > 0 else np.nan
            )
        row[weight_col] = group[weight_col].fillna(0).sum()
    else:
        # Weight col missing entirely (stale pin). Unweighted fallback.
        valid_uw = group[metric_notna]
        row[metric_key] = (
            round(float(valid_uw[metric_key].mean()), 2)
            if len(valid_uw) > 0 else np.nan
        )
```

The fallback degrades Iron-Rule weighting to equal-level weighting. Math
drift is small (equal weight per level instead of n_obs weight). The
canonical math returns as soon as the pin is rebuilt with the current
SQL output shape — until then, the user sees a populated cell instead of
a mysterious blank.

### Per-tracker bucket coverage audit (May 21 2026)

| Tracker | File | Status |
|---|---|---|
| **Catcher** | `catching_tracker_page.py` | FIXED — `total_netk` added to `_SUM_KEYS`, `surpp` added to `_DERIVE_KEYS` + derive logic, count-weighted unweighted fallback added |
| BR | `br_tracker_page.py` | Clean — sb_pct, ft3_frac, s2h_frac all re-derived correctly |
| Fielding (OF/IF) | `fielding_tracker_page.py` | Clean — oaa, paa_cal, raa, paa_eo, raa_eo all in correct buckets |
| Hitter (Barrelsville) | `barrelsville/pages/2_Affiliate_Tracker.py` | Clean — all metrics are rates, no SUM-class to drop |
| Pitcher (Arm Farm) | `bullpen-report/pages/3_Affiliate_Tracker.py` | Clean — `fb_pct`/`gb_pct` documented NaN on multi-level by design (count-derived, multi-level org rollup re-derives in `tracker_data.aggregate_org_across_levels`) |

### Checklist when adding a NEW column to ANY tracker

1. **Add the column to the SQL** in `*_tracker_data.py` per-level query.
2. **Decide which bucket it belongs in:**
   - Cumulative SUM (e.g. NetK, FramRAA, OAA, SB) → `_SUM_KEYS`
   - Pitch-rate (e.g. R2K%, NetK/P, Whiff%) → `_PITCH_WEIGHTED_KEYS`
   - PA-rate (e.g. K%, BB%, wOBA) → `_PA_WEIGHTED_KEYS`
   - Per-metric-count-weighted percentile (e.g. Arm, Exch, Pop) → `_COUNT_WEIGHTED_KEYS` with the matching `n_X` weight column
   - On-base/comp-play-weighted (BR, fielding) → respective `_ON_BASE_WEIGHTED_KEYS` / `_COMP_PLAY_WEIGHTED_KEYS` / `_THROW_WEIGHTED_KEYS`
   - Derived from other summed cols → `_DERIVE_KEYS` + add the re-derive block
3. **If `_COUNT_WEIGHTED_KEYS`**: also add the weight column (`n_X`) to the SQL output AND register the mapping `{metric_key: weight_col}`.
4. **Update the stale-pin shim** in `*_tracker_data.py` to NaN-fill the new column on old pins:
   ```python
   if "new_col" not in _pinned.columns:
       _pinned["new_col"] = np.nan
   ```
5. **Visual smoke-test** on a known multi-level catcher/fielder/etc.:
   - Pick a real player with 2+ levels in the current season
   - Confirm the new column is populated (not blank) on the combined row
   - Confirm the value is reasonable given the per-level values
6. **Re-pin all historical years** on work laptop so the canonical math (not the unweighted fallback) becomes active.

### What NOT to do

- **DON'T** add a column to the SQL without registering it in a bucket. The `_combine_multi_level` allowlist silently swallows unknown columns.
- **DON'T** rely on the unweighted-mean fallback as the canonical math. It's a graceful-degradation safety net for stale-pin and zero-weight scenarios. Canonical = Iron-Rule weighted mean. If you find yourself shipping the fallback as "the answer," you've skipped step 4 (stale-pin shim) and step 6 (re-pin).
- **DON'T** remove the unweighted fallback. It prevents the silent-NULL bug class from recurring when columns are added or pins go stale.
- **DON'T** weight a percentile metric by `n_pitches` or `games`. That's the Iron-Rule violation documented below (Per-Metric Weight Reference). Always weight by the metric's own `n_X` count.
- **DON'T** assume "BR/fielding/hitter/pitcher trackers don't have this issue." They use the SAME allowlist pattern. Audit them when adding new columns, with the per-tracker bucket-list grep in the audit table above.

---

## The Iron Rule

**When aggregating a metric from per-level → multi-level (or any tier-to-tier weighted average), the weight column at the OUTER tier MUST equal the count column used at the INNER tier.**

If you weight by a different proxy (e.g., `comp_throws` instead of `n_arm`), the multi-level result silently drifts off the all-pool answer. Math doesn't recover.

## The Bug Pattern

```
Per-level Arm = SUM(catcher_p99 × n_arm) / SUM(n_arm)   ← weighted by n_arm

Multi-level (WRONG):
   = SUM(per_level_Arm × comp_throws) / SUM(comp_throws)   ← weighted by DIFFERENT count

Multi-level (RIGHT):
   = SUM(per_level_Arm × per_level_Σ(n_arm)) / SUM(per_level_Σ(n_arm))
   = SUM(catcher_p99 × n_arm) over ALL levels / SUM(n_arm) over ALL levels
   = ALL-POOL WEIGHTED AVG  ✓
```

The right multi-level expression algebraically reduces to the all-pool answer. The wrong one doesn't, because `comp_throws ≠ n_arm` per level (different filters: competitive_throw=1 vs arm_strength BETWEEN 60-94).

## Why this matters

- PD-Goals queries ALL levels in one SQL pass → no second-tier weighting needed → always right.
- Tracker/KPI queries each level then aggregates in Python → second-tier weighting required → bug if weight column doesn't match per-level denominator.
- The drift looks like rounding noise (~0.1-0.5 mph) so it gets dismissed until you compute the math by hand.

## Fix Pattern

When per-level SQL exposes a metric with an internal weight `n_X`, ALSO expose `Σ(n_X)` per group:

```sql
SELECT org,
    SUM(catcher_p99 × pc.n_arm) / NULLIF(SUM(pc.n_arm), 0) AS arm_strength,
    SUM(pc.n_arm) AS arm_n,                                        -- expose for outer tier
    SUM(catcher_p10 × pc.n_exch) / NULLIF(SUM(pc.n_exch), 0) AS exchange,
    SUM(pc.n_exch) AS exch_n                                       -- expose for outer tier
FROM ...
GROUP BY org
```

Then at the multi-level rollup:

```python
# Multi-level Arm: weight by arm_n (NOT comp_throws, NOT n_pitches, NOT games)
np.average(per_level["arm_strength"], weights=per_level["arm_n"])

# Multi-level Exch: weight by exch_n
np.average(per_level["exchange"], weights=per_level["exch_n"])
```

## Per-Metric Weight Reference (Catcher)

| Metric | Per-level internal weight | Multi-level outer weight | Notes |
|---|---|---|---|
| Arm (P99) | n_arm = COUNT(arm BETWEEN 60-94) per catcher | **arm_n** = SUM of n_arm per org | NOT comp_throws |
| Exch (P10) | n_exch = COUNT(exch≥0.4 AND arm≥60) per catcher | **exch_n** = SUM of n_exch per org | NOT comp_throws |
| Pop2B (P01) | n_obs_2b = COUNT(pop_time BETWEEN 1.70-2.35) | n_throws_2b per org | Same value, OK |
| Pop3B (P01) | n_obs_3b = COUNT(pop_time BETWEEN 1.40-1.85) | n_throws_3b per org | Same value, OK |
| AugPop (P01) | n_aug_pop = COUNT per catcher | n_sba_events per org | Same value, OK |
| NetK (SUM) | — (cumulative) | n_pitches | Cumulative SUMs across levels |
| FramRAA (SUM) | — | n_pitches | Cumulative SUMs |
| BlockRAA (SUM) | — | passed_pitches + xPP | Cumulative SUMs |
| Framing buckets / R2K% (rate) | — (rate from CASE/SUM) | n_pitches | Pitch-weighted across levels |

## Per-Metric Weight Reference (Fielding OF/IF)

Same pattern. P95 TopSpd, P25 React, P99 Arm, P10 Exchange — each has its own n_obs at per-fielder level. Multi-level rollup must weight per-level org values by per-level Σ(n_obs), not by `comp_plays` or `comp_throws`.

Audit checklist for OF/IF:
- `intangibles/src/fielding_tracker_data.py` — verify `aggregate_org_across_levels` weights by per-metric n_obs
- `intangibles/src/of_tracker_data.py`, `if_tracker_data.py` — same audit needed
- `intangibles/src/snapshot_data.py` — same audit if it has multi-level rollup

## Per-Metric Weight Reference (Hitting — Barrelsville tracker org rollup)

**Same iron rule applies to pitch-level rate metrics.** Ctct%, Whiff%, ZCtct%, ZSw%, OSw%, PullAir%, Barrel%, Hard%, Dmg% all have their own denominators that are NOT equal to `n_pitches`. Weighting a per-level rate by `n_pitches` at the outer tier produces drift vs the single-pool pattern PD-Goals uses.

| Metric | Per-level denom | Correct outer weight | Bug pattern if wrong |
|---|---|---|---|
| Ctct%, Whiff% | n_swings | n_swings — re-derive from `(total_swings - total_whiffs) / total_swings` | Using n_pitches ≠ swings → ~0.1% drift, was in pitch_weighted list until fixed Apr 20 (`10fb0a8`) |
| ZCtct%, ZSw%, OSw% | CSC-weighted (zone swings / zone pitches / OOZ pitches) | Per-metric CSC SUMs (expose them) | Currently still weighted by n_pitches — latent drift, deferred |
| Chase% | OOZ pitches (binary CSC<0.01) | n_ooz_pitches | Same as above |
| Barrel%, Hard%, PullAir%, Dmg% | n_bip_tracked | `SUM(numer) / SUM(n_bip_tracked)` — count-derived | Already correctly count-derived in Barrelsville's `aggregate_org_across_levels` |
| Avg EV | n_ev_rows | n_bip_tracked (close enough, matches PD-Goals AVG) | n_pitches is wrong but was used historically |
| wOBA | AB + BB - IBB + HBP + SF | `(pa - ibb).clip(lower=0)` per level | Using total PA inflates denom by SH count |
| xwOBA | AB + BB + HBP + SF (IBB counted as walk per GC2, May 19 2026) | `_xwoba_n_lv` summed across levels | Pool numer + pa via stash. xwOBA INCLUDES IBB (OPPOSITE of wOBA). |
| gcOBA | (multi-component) | Components pooled across levels (K, BB+HBP, swing dist, barrel, useful EV) | Re-pool all components; can't simply PA-weight per-level gcoba (nonlinear cross-term) |

**Fix pattern for rate metrics still weighted by n_pitches:**
1. Expose the per-metric numerator and denominator counts per level (already done for Ctct% via n_swings + n_whiffs).
2. Remove from `pitch_weighted` list in `aggregate_org_across_levels`.
3. Add count-derived block: `row[metric] = 100 * total_numer / total_denom`.
4. Verify against PD-Goals single-pool output for HOU.

## What NOT to Do

- **Never use `comp_throws` / `comp_plays` / `n_pitches` / `games` as a multi-level weight for percentile metrics.** They count different events than the metric's own n_obs.
- **Never trust that per-level rounding drift is "just rounding."** A consistent 0.1-0.5 unit drift is the signature of a wrong-weight bug, not floating point.
- **Never patch the divergence by adjusting display rounding.** The underlying number is wrong.
- **Never skip the algebra check** when adding multi-level rollup. The expression `Σ(per_level × W) / Σ(W)` must algebraically reduce to the all-pool answer. If not, W is wrong.

## How to Verify

Compute the all-pool weighted avg from per-catcher (or per-player) data manually and compare to the displayed multi-level value:

```
Σ(catcher_p99 × n_arm)  over all catchers in all levels
─────────────────────────────────────────────────────
Σ(n_arm)  over all catchers in all levels
```

If displayed value matches → fix is correct. If not → wrong weight column at the outer tier.

## Bug History

- **Apr 18 2026** (catching_tracker_data.py `aggregate_org_across_levels`): Multi-level Arm and Exch weighted by `comp_throws`. Fixed by exposing `arm_n` / `exch_n` from `_ORG_THROWING_DIRECT_QUERY` and using them as outer-tier weights. Commit `c19a2f1`.
- **Apr 18 2026** (catching_tracker_page.py `_combine_multi_level._COUNT_WEIGHTED_KEYS`): Per-catcher multi-level Arm/Exch had same comp_throws weight. Fixed by exposing n_arm/n_exch from `_THROWING_AGG_QUERY` + monthly variant, switching `_COUNT_WEIGHTED_KEYS`. Commit `f3a290c`.
- **Apr 18 2026** (pd-goals/src/org_kpi_data.py OF + IF comp_plays): comp_plays counted `SUM(tdm.competitive_play)` only — undercount vs tracker's 4-term OR (DCBP.CP + TDM.CP + DCBP.CT + TDM.CT). Fixed. Commit `b9fe185`.
- **Apr 18 2026** (pd-goals/src/org_kpi_data.py OF + IF tracking): All 9 tracking metrics weighted by `n_plays` instead of per-metric `n_X`. Fixed — exposed n_top_speed, n_accel_up, n_react, n_react_rad, etc. in per-player CTE and switched org_agg weighting. Commit `dde9b7e`.
- **Apr 19 2026** (fielding_tracker_data.py `aggregate_org_across_levels`): Same comp_plays/comp_throws weight bug. Powered unified fielding tracker + KPI weekly OF/IF charts. Fixed by exposing n_X_total from `_ORG_TRACKING_AGG_QUERY` + `_ORG_MONTHLY_TRACKING_AGG_QUERY` and rewriting Python aggregator with per-metric weight_map. Commit `7d4c1d4`.
- **Apr 19 2026** (br_tracker_data.py `_aggregate_org_tracking` + `aggregate_org_across_levels`): Same pattern for BR (top_speed/reaction/time_to_22/split1/accel_overall). Fixed by adding n_speed/n_react/n_t22/n_s1/n_accel counts to per-org aggregator and switching multi-level weights. comp_plays retained as display-only SUM. Commit `2383432`.
- **Apr 19 2026** (fielding_tracker_data.py counts CTE): `COUNT(*) AS comp_plays` was actually total plays (all Tier 1 rows), not the 4-term competitive plays OR. Fixed by splitting into `total_plays` (COUNT(*)) + `comp_plays` (4-term OR matching PD-Goals). Exposed `dcbp_cp` + `dcbp_ct` in base CTE. Added OAA to LEADERBOARD_COLS (was missing). Reordered default metrics to match PD-Goals OF_COLS / IF_COLS. Commit `624bce9`.
- **Apr 19 2026** — DELETED dead `of_tracker_data.py`, `if_tracker_data.py`, `of_tracker_page.py`, `if_tracker_page.py`. Four prior "fix" commits (`e9886f9`, `4ae1ea3`, `424db7e`, `9b74d6f`) had edited these dead files with zero runtime impact. Replaced long ago by the unified `fielding_tracker_*` modules. See `intangibles/FIELDING_TRACKER_SPEC.md` + CLAUDE.md Blocking Rule #13.
- **May 21 2026** (catching_tracker_page.py `_combine_multi_level`): Two bug-class fixes on multi-level catcher leaderboard. **(1) Unregistered cumulative columns silently dropped:** `total_netk` (display "NetK") was never added to `_SUM_KEYS`, and `surpp` (display "SurPP") was never added to `_DERIVE_KEYS` + re-derive logic — both columns came out of `_combine_multi_level` as missing keys → blank cells. The allowlist pattern silently swallows any column not in one of the four bucket groups. Fix: `total_netk` to `_SUM_KEYS`, `surpp` to `_DERIVE_KEYS` + new re-derive line. Commit `178a97c4`. **(2) Count-weighted metrics NULL when weight col missing or all-zero:** `arm_strength` / `exchange` / `pop_time_2b/3b` / `aug_pop_time` / `aug_pop_acc_penalty` / `aug_pop_bounce_pct` / `depth` are all `_COUNT_WEIGHTED_KEYS` entries. When the weight column (`n_arm`, `n_exch`, `n_throws_2b/3b`, `n_sba_events`, `n_depth_pitches`) was missing from the DataFrame (stale-pin path) OR all rows had weight=0/NaN, the combine fell to `row[metric_key] = np.nan`. Fix: added unweighted-mean fallback that fires when weighted aggregation can't run. Iron-Rule weighting stays canonical when weight col is healthy; unweighted path is graceful degradation. Commit `14da22ea`. Both commits on `feature/astros-intangibles`. New BLOCKING section "PER-PLAYER `_combine_multi_level` — ALLOWLIST ENFORCEMENT" added to this file documenting the bug class, the canonical fallback pattern, the per-tracker audit table, and the checklist for adding new columns.

## Pooled Percentile Bug — Weighted Avg of Per-Level Percentiles ≠ Single-Pool Percentile (BLOCKING)

Even with correct per-metric `n_X_total` weighting (above), there is a
second, deeper divergence for percentile metrics when a player appears in
multiple levels: **percentile-of-pooled-observations ≠ mean-of-per-level-percentiles**.

### The Math

A fielder with 30 TopSpd readings at AAA and 20 at AA:

- Per-level percentile approach (old tracker):
  - P95 over his 30 AAA readings = 28.5
  - P95 over his 20 AA readings = 29.2
  - Weighted avg = (28.5 × 30 + 29.2 × 20) / 50 = **28.78**
- Pooled percentile approach (PD-Goals):
  - P95 over all 50 combined readings = **28.9** (or any value between 28.5 and 29.2)

The two are only equal when the player appears in one level. OF has more
cross-level movement than IF (CF / corner OF prospects get promoted mid-
season more than 2B/SS), so OF drifted visibly while IF looked OK — same
code, different player-mobility patterns.

### The Fix — Single SQL with `IN (levels)` Filter

When the user selects 2+ levels, run ONE SQL that scopes the per-player
percentile CTE to ALL selected levels, so `PERCENTILE_CONT OVER (PARTITION
BY fielder_id)` partitions across pooled observations naturally.

```sql
-- Per-fielder CTE (unchanged pattern, but `base` is now ALL-LEVEL scoped)
per_fielder AS (
    SELECT DISTINCT org, fielder_id,
        PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY
            CASE WHEN top_speed <= 34 THEN top_speed END)
            OVER (PARTITION BY fielder_id) AS top_speed,
        ...
    FROM base
),
-- base:
WHERE ({level_filter})           -- was: sv.level_code = 'aaa'
                                 -- now: sv.level_code IN ('mlb','aaa','aax',...)
```

**Pattern:**

1. Add `_build_levels_filter(level_codes)` helper that returns
   `sv.level_code IN ('mlb','aaa','aax')` — splits gc2-native levels
   (`dsl`, `rok`) into a separate `sv.gc2_level_code IN (...)` OR branch
   when mixed with regular levels.
2. Add an optional `level_filter_override` kwarg to the existing
   `_build_tracking_query` / `_build_nontracking_query` so the pooled path
   can inject the IN filter while the single-level path stays unchanged.
3. Add `_get_pooled_org_stats(domain, level_codes, season, ...)` that
   runs `_ORG_TRACKING_AGG_QUERY` + `_ORG_DCBP_QUERY` with the IN filter
   exactly ONCE — returns one row per org already aggregated.
4. Add a public `get_org_rankings_pooled(...)` wrapper.
5. Add a cached Streamlit loader `_load_org_rankings_pooled(domain, season,
   level_codes_tuple, ...)` keyed on the level tuple.
6. Org Rankings tab in the page branches on `len(selected_level_codes) > 1
   AND len(seasons) == 1` — pooled path skips `aggregate_org_across_levels`
   entirely and just calls `_round_metrics`.

Multi-**year** rollup (single or multi level across years) still goes
through `aggregate_org_across_levels` — years are independent, no
percentile pooling issue.

### When Pooled SQL is Needed vs Not

| Scenario | Pooled SQL Needed? |
|---|---|
| Single level, single year | No — per-level query is already correct |
| Multi level, single year | **Yes** — cross-level fielders diverge under Python rollup |
| Single level, multi year | No — year-over-year rollup uses sums/rates, not percentiles |
| Multi level, multi year | Optionally. Known cosmetic drift for the cross-year × cross-level combo, but rare usage and small effect. |

### Reference Implementation

- `intangibles/src/fielding_tracker_data.py` — `_build_levels_filter`,
  `_get_pooled_org_stats`, `get_org_rankings_pooled` (Apr 19 2026).
- `intangibles/src/fielding_tracker_page.py` — Org Rankings tab branch on
  `_pooled_multi_level`, plus `_load_org_rankings_pooled` cached loader.

### Pending Similar Audit

Catcher's percentile org metrics (Arm P99, Exch P10, Pop2B P01, Pop3B P01,
AugPop P01) have the same architectural issue in `catching_tracker_data.py`
via `_ORG_THROWING_DIRECT_QUERY` / `_ORG_POP_DIRECT_QUERY` /
`_ORG_AUGPOP_DIRECT_QUERY`. **PORT REQUIRED** — user correction May 23
2026: catchers actually move between levels A LOT (depth on 40-man,
injury swaps, callups). The weighted-mean approximation drift is real,
not hypothetical. Apply the raw-obs pattern shipped for fielding May 23
2026 (`b084ce6f` → `d1a9b129`). See
`rules/pooled-percentile-pattern.md` for the canonical 5-piece pattern.
Migration plan:
`docs/plans/2026-05-23-catcher-pooled-percentile-port.md`.

**Same port required for BR**: TopSpd P95, React P25, T22 P25, Split1 P25,
Accel P75 — all per-runner percentile metrics in `br_tracker_data.py`
use the same weighted-mean approximation. Plan:
`docs/plans/2026-05-23-br-pooled-percentile-port.md`.

The tracker's catcher SUM metrics (FramRAA, NetK, BlockRAA, SurPP, framing
bucket COUNT sums) are mathematically immune to the pooling issue
(sum-of-per-level-sums = sum-of-pooled), so those don't need this fix.

## Framing Bucket Multi-Level Aggregation — Expose Counts, Re-Derive Rates

Distinct from the percentile pooling issue above. For rate metrics where
each bucket has its own denominator (e.g. CSC framing buckets — `n_e_stl`
is only CSC≤0.05 called strikes, `n_e_stl_total` is only CSC≤0.05 called
pitches), pitch-weighting per-level rates across levels diverges from the
single-pool sum-of-counts answer because `n_bucket_total != n_pitches`.

### Fix Pattern

Expose BOTH numerator and denominator counts per bucket in the per-level
SQL, then sum them at the multi-level layer and re-derive the rate:

```sql
-- Per-level org query (in addition to the displayed rate)
SUM(CASE WHEN csc <= 0.05 AND pitch_result_id IN (cs_codes) THEN 1 ELSE 0 END) AS n_e_stl,
SUM(CASE WHEN csc <= 0.05 AND pitch_result_id IN (cs_codes,cb_codes) THEN 1 ELSE 0 END) AS n_e_stl_total,
```

```python
# aggregate_org_across_levels
num_sum = group["n_e_stl"].fillna(0).sum()
denom_sum = group["n_e_stl_total"].fillna(0).sum()
row["e_stl_rate"] = 100.0 * num_sum / denom_sum if denom_sum > 0 else np.nan
```

Same pattern for R2K% (`n_r2k_num` / `n_r2k_denom`) and any other rate
metric whose denominator differs from `n_pitches`.

### Reference Implementation

- `intangibles/src/catching_tracker_data.py` `_ORG_PITCHES_COMBINED_QUERY`
  + `aggregate_org_across_levels` (Apr 19 2026).

## SUM Metric Multi-Level Via Direct `fielding_team_id` Groupby

For org-level SUM metrics computed via per-player aggregation (e.g. catcher
FramRAA SUM across per-catcher `_FRAMING_QUERY`), two failure modes exist:

1. **`org_map` indirection via `drop_duplicates("catcher_id", keep="first")`**
   mis-attributes catchers who played for multiple orgs — their full
   season's FramRAA gets assigned to whichever org came first in the dedup.
2. **`ev.c_id IS NOT NULL` gate** drops pitches that PD-Goals includes
   via direct `fielding_team_id` groupby (rare but non-zero).

### Fix

Compute the SUM directly in the ORG-level query by grouping on
`UPPER(mt.org_abbrev)` via `fielding_team_id`, matching PD-Goals. Skip
the per-catcher intermediate for org display.

```sql
-- In _ORG_PITCHES_COMBINED_QUERY (catcher) or equivalent:
SUM(
    CASE WHEN pv.pitch_result_id IN (4, 5, 6)
         AND pv.called_strike_chance_mlb BETWEEN 0.05 AND 0.95
         AND pv.rv_after_if_take_ball IS NOT NULL
         AND pv.rv_after_if_take_strike IS NOT NULL
    THEN (CASE WHEN pv.pitch_result_id = 6 THEN 1.0 ELSE 0.0 END
          - pv.called_strike_chance_mlb)
         * (pv.rv_after_if_take_ball - pv.rv_after_if_take_strike)
    ELSE 0 END
) AS framing_raa
...
GROUP BY UPPER(mt.org_abbrev)
```

Keep the per-catcher query ONLY for the per-catcher leaderboard display
(where each catcher's individual value is needed).

## Audit Status — All Known Bugs Fixed (Apr 19 2026)

Live tracker files in `intangibles/src/` (`fielding_tracker_data.py`,
`br_tracker_data.py`, `catching_tracker_data.py`) now:
- weight multi-level org rollup by per-metric `n_X_total`,
- use single-SQL pooled percentile for multi-level fielding org rankings,
- expose bucket counts and re-derive rates at multi-level for catcher
  framing + R2K%,
- source catcher FramRAA from direct `fielding_team_id` groupby instead
  of per-catcher + `org_map` indirection.

PD-Goals `org_kpi_data.py` matches. Three-surface parity holds for
OF/IF/BR/Catcher on default-display metrics.

**Port required (May 23 2026 — was previously marked deferred):**
- Catcher multi-level percentile pooling (Arm/Exch/Pop2B/Pop3B/AugPop).
  Catchers move between levels frequently; drift is real, not invisible.
  Apply raw_obs pattern. See `rules/pooled-percentile-pattern.md` +
  `docs/plans/2026-05-23-catcher-pooled-percentile-port.md`.
- BR multi-level percentile pooling (TopSpd/React/T22/Split1/Accel).
  Same port. Plan: `docs/plans/2026-05-23-br-pooled-percentile-port.md`.

**Still deferred (low-priority):**
- Non-default metrics (selectable columns like FramRAA650, BlockRAA650,
  AdjNSP, AccPen, Bounce%, xPP, Pop3B, TL 1B/2B, Split 1, Accel) — haven't
  been fully audited across all three surfaces. User is intentionally
  deferring these.

**If drift reappears,** first suspect:
1. Stale Posit Connect deploy (hard-restart app)
2. end_date data-window difference (KPI weekly pulls current; PD-Goals freezes at report-gen time)
3. JOIN path differences (e.g., Pitches_View join vs direct Events_View join)

**Fix template for any future similar case** (apply per metric, per file):
1. Per-fielder CTE already has `COUNT(... range filter ...) OVER (PARTITION BY fielder_id) AS n_metric` — keep.
2. Org_agg CTE: add `SUM(CASE WHEN metric IS NOT NULL THEN n_metric END) AS n_metric_total`
3. Outer SELECT: expose `oa.n_metric_total`
4. `aggregate_org_across_levels`: change `weights=valid["comp_plays"]` to `weights=valid["n_metric_total"]` for that specific metric
5. For cross-level percentile pooling: add `_build_levels_filter` +
   `level_filter_override` kwarg + pooled runner + cached loader + page
   branch. Pattern in `fielding_tracker_data.py`.
