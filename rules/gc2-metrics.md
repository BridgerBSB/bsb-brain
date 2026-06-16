---
paths:
  - "**/src/*.py"
  - "**/scripts/*.py"
---

# GC2 Metric Standardization

All postgame + tracker metrics standardized to match GC2 production.

## gcOBA (VERIFIED Apr 16 2026 — matches GC2 production EXACTLY)

### Formula
```
gcOBA = MLB_OBP * (
    0.50 * K_rate
    + 1.49 * BB_HBP_rate
    + 0.11 * zero_whiff_pct
    + 0.08 * one_whiff_pct
    + (-0.10) * two_whiff_pct
    + (-0.10) * three_plus_whiff_pct
    + BIP_rate * (1.70 * barrel_rate + 1.09 * avg_useful_ev / 100)
)
```

### BLOCKING RULES — DO NOT CHANGE ANY OF THESE
1. **Swing distribution = WHIFF count per PA** (`pitch_result_id IN (10, 22, 23)` = S/W/T gumbo codes). NOT all swings. NOT `did_swing=1`. GC2 counts S+W+T characters in `Events_View.pitches` string.
2. **Swing distribution gates on PA events** (`ev.pa=1 OR ev.ibb=1`). Non-PA events (SB, WP) must be excluded.
3. **Python-side swing groupby uses `(sched_id, ab_event_id)` composite key** — NOT `ab_event_id` alone. `event_id` is NOT globally unique (repeats across games). Using `event_id` alone collapses PAs and breaks the distribution. (Bug found Apr 16: 36 PAs → 26 unique event_ids → SUM check 0.72 instead of 1.0.)
4. **IBB included in BB+HBP rate** — `(bb + hbp) / pa`, NOT `(bb - ibb + hbp) / pa`. Only **wOBA** excludes IBB (subtracts from numer + denom). **xwOBA INCLUDES IBB as walk per GC2** (May 19 2026 — woba_bb to numer, +1 to denom).
5. **PA denominator includes IBB** — `Events_View.pa=0` for IBBs, fixed with `OR ibb=1` gate at SQL level. Python uses `len(pa_df)` not `sum(pa column)`.
6. **Barrel formula uses integer truncation** — `int(ev) * 1.5 - int(la) >= 117` etc. GC2 casts to `decimal(4,0)`.
7. **BIP for barrel/EV uses (12,13,14) only** — NOT pitchout BIPs (18,19,20). Matches GC2's `HitsNoBunts` join.
8. **MLB OBP always** — `_get_level_obp(season, "mlb")`. Prior year before May.
9. **No EV misread filter in gcOBA BIP** — GC2 only filters `LA < -25` in junk levels (`hsb, sum, bbc`). Our P95 misread filter is for display metrics, NOT gcOBA.

### Files (6 compute, 2 receive)
| File | Method | Notes |
|------|--------|-------|
| `postgame_data.py` | Python `_compute_gcoba()` | `(sched_id, ab_event_id)` composite groupby |
| `tracker_data.py` | SQL `_SWING_DIST_QUERY` + Python | PA gate in SQL |
| `hitter_kpi_data.py` | SQL `_SWING_DIST_QUERY` + Python | PA gate in SQL |
| `postgame_percentiles.py` | SQL `_BATTER_SWING_DIST_QUERY` + Python | PA gate in SQL |
| `weekly_hitter_data.py` | Inline SQL + Python | PA gate in SQL |
| `org_kpi_data.py` (PD Goals) | SQL `gcoba_query` + Python + `_HITTING_ORG_QUERY` | PA gate in SQL. **Has 2 query strings** (pitching + hitting) — changes must go in BOTH subqueries |
| `hitter_analysis.py` | Receives from postgame | Does NOT compute |
| `kpi_snapshot_3.py` | Receives from postgame | Does NOT compute |

### Diagnostic
`python scripts/gcoba_diagnostic.py --batter 244959 --start 2026-04-03 --end 2026-04-14`

## gcPerf Run Values
- CS=-0.02, ball/HBP=+0.02, pBrl=+0.09, non-pBrl=-0.02

## Max EV — STANDARD (Apr 12 2026)
- **Always MAX() after EV misread cleaning.** Never P99. One cleaning pass, then true maximum.
- **Python-side (postgame):** `clean_ev_misreads()` runs upstream, then `.max()` on cleaned DataFrame
- **SQL-side (tracker/pool/DSL script):** `batter_ev_p95` CTE + `NOT (misread condition)` in WHERE, then `MAX(hit_exit_speed)`
- **PD Goals:** inline misread filter in `calculate_hitting_metrics()` (same 3-condition logic)
- Applied consistently across ALL apps and ALL branches.

### EV Misread Cleaning — Single Pass
Three conditions must ALL be true to flag a misread:
1. `hit_exit_speed >= 100` (high EV)
2. `hit_vertical_angle < -35` (severe downward LA)
3. `hit_exit_speed > batter P95` (exceeds batter's own 95th percentile; fallback 105 mph if < 20 BIP)

Python: `clean_ev_misreads()` in `database.py` nulls misread EVs in the DataFrame once.
SQL: `batter_ev_p95` CTE computes P95 per batter, `NOT (...)` clause excludes misreads in WHERE.
Both approaches run ONCE — downstream code (Max EV, Avg EV, Dmg%, etc.) all benefit from the same cleaning.

### GC2 Divergence — May Revisit
GC2 uses `PERCENTILE_CONT(0.99)` for Max EV instead of our MAX()+cleaning approach. GC2 does NOT have a separate EV misread filter — P99 serves as both the metric and the safety net. We chose MAX()+cleaning because our misread filter already removes bad reads, and P99 on top of that discards the player's actual best swing. If we ever drop or weaken the misread filter, P99 should be reconsidered as a fallback safety net.

## Bat Speed at Contact (Standardized Apr 26 2026)

**Replaces peak bat speed (`Bat_Tracking_Metrics.v_true_peak * 0.682`) across every hitting surface.**

### Canonical SQL
```sql
SELECT pv.batter_id,
       SQRT(POWER(scv.batvx_con, 2) + POWER(scv.batvy_con, 2)
          + POWER(scv.batvz_con, 2)) * 0.681818 AS bat_speed_mph
FROM Astros.Pitches_View pv
JOIN groundcontroltracking.tracking.plays tp
    ON tp.sched_id = pv.sched_id AND tp.astros_pitch_id = pv.pitch_id
JOIN groundcontroltracking.tracking.swing_contact_values scv
    ON scv.sched_id = tp.sched_id AND scv.tracking_play_id = tp.tracking_play_id
WHERE scv.batvx_con IS NOT NULL
  AND pv.pitch_id > 0
  -- NO pitch_result_id whitelist (Option C)
```

### 3-step cleaning
1. Top-90% per player (Savant "competitive swings")
2. **Hard floor 57 mph, NO upper cap**
3. Per-player 2.5σ trim
+ min 20 raw rows + min 5 after steps 1+2

### GC2 divergence (intentional)
GC2 leaderboard's `BatSpeedAtContactAvg` filters to `pitch_result_id IN (12,13,14,18,19,20)` (BIP only). We include BIP + fouls + foul tips (~2× sample). Per-player numbers may differ ≤ 0.5 mph; aggregate MLB pool tracks ~71.5 mph (matches public Savant figure).

### Surfaces
Three-surface parity rule applies — see `three-surface-parity.md`.
- PD Goals: bar chart, percentile pool, org KPI, PD Flag Tracker (drift_alert)
- Barrelsville: tracker, hitter KPI weekly, postgame, postgame percentiles, weekly hitter, 3 batch scripts

### VBA at contact (PD Flag Tracker only)
`90 - DEGREES(ACOS(scv.e1z_con))` range `BETWEEN -70 AND 10`. Replaces old `Bat_Tracking_Metrics.adj_vba_pitcher_face`.

### AA at contact
Already SCV-sourced everywhere. Apr 26 2026: dropped the `pitch_result_id IN (12,13,14,18,19,20)` whitelist (kept the `BETWEEN -50 AND 50` range filter as the gate). Now consistent with bat speed and VBA.

### Untouched
- **Blast Motion** (`BlastMotion.Series_Metrics_View`, `blast_swings_vw`) — separate system from Hawkeye. Wearable bat-sensor data (knob attachment) used in **both practice AND in-game swings**. Captures sensor-derived swing metrics (on-plane efficiency, sensor attack angle, etc.) distinct from Hawkeye's camera-based bat-ball collision vectors in SCV. Untouched by this refactor because it's a separate data pipeline.
- **Peak bat speed** — retired from in-game hitting analytics.

## pBarrel
- EV < 125 cap applied
- Bunt filter: exclude `hit_trajectory_id NOT IN (2,3,4)` (requires Events_View JOIN)
- All barrel/pBarrel calcs exclude bunts. Audited Mar 12.

## SwDec — Direction Is Side-Specific (BLOCKING)

`AVG(pv.swing_decision_grade_2080)` (20-80 grade) is the SAME column for hitter
and pitcher SwDec — only the **direction** differs:

- **Hitter SwDec → higher is better** (the batter's own swing-decision quality).
- **Pitcher SwDec → LOWER is better** (`hib=False`). The grade measures the
  HITTER's decision quality on each pitch, so averaged over a pitcher it is "how
  well hitters decided against him." A good pitcher induces BAD decisions →
  wants this LOW. Higher = hitters decided better = WORSE pitcher.

Canonical reference (always correct): `bullpen-report/scripts/pitcher_analysis.py:215`
`("swdec", "SwDec", "f0", "swdec", False)` + L988 comment "higher = batter
decided better = WORSE for pitcher".

**NEVER hardcode pitcher SwDec `higher_is_better=True`.** Jun 10 2026 the
amateur-vs-pro slide deck shipped it `True` in ~6 places → completely INVERTED
HOU's pitcher SwDec conclusion (rendered "develop it best, pure edge / DEVELOP
IT" when the truth was draft-elite 2/30 but develop-worst 29/30). Direction only
affects rank/color/residual-ranking — raw grades + regression slopes are
direction-neutral, so the fix is presentation-layer, NO data re-run. (Rule added
in bsb-resources; sync to sibling worktrees on next `/sync-rules`.)

## Whiff%
- Whiffs/swings (replaced SWM% which was whiffs/pitches)
- **is_whiff MUST be gated by did_swing:** `is_whiff = (did_swing == 1) & pitch_result_id.isin(WHIFF_CODES)`
- Without the `did_swing` gate, data anomalies cause Ctct% + Whf% > 100%
- NEVER check `pitch_result_id.isin(WHIFF_CODES)` without also requiring `did_swing == 1`

## WHIFF_CODES
`(10, 16, 21, 22, 23, 25)` — we intentionally include 16 (missed bunt) and 25 (bunt foul tip). GC2 excludes 16. Our decision: all swinging strikes belong in WHIFF_CODES.

## SWM% missed bunt (16)
Intentionally KEPT in whiff count — GC2 excludes it from Ctct%, we include it. 16 = "Strike - Missed Bunt" (NOT foul tip — foul tip is 10).

## InZ% / FPinZ% / Pre2K InZ%
`AVG(csc)` — skip NULLs (not ISNULL(csc,0)). NEVER use binary `(csc > 0.5).sum() / count` — that's a different metric. All apps use continuous AVG including catcher Pre2K IZ% (fixed Apr 10).

## FPinZ%
`balls_before=0 AND strikes_before=0` (not ab_pitch_number=1)

## FPS% (First Pitch Strike)
Binary outcome — `NOT IN BALL_CODES` = strike. Includes called strikes, whiffs, fouls, AND BIP. Different from FPinZ%.

## R2K% (Race to 2K) — GC2 Formula (Switched Apr 13 2026)
**Definition:** On pitch 3, did the pitcher have 2+ strikes? Only counted when the PA either
didn't end on pitch 3, or ended in a strikeout. Matches GC2 production exactly.

**SQL pattern (all apps, all worktrees):**
```sql
100.0 * AVG(
    CASE WHEN pv.ab_pitch_number = 3
              AND (ISNULL(cev.pa, 0) = 0 OR ISNULL(cev.so, 0) = 1)
         THEN CASE WHEN pv.strikes_after >= 2 THEN 1.0 ELSE 0.0 END
    END
) AS r2k_pct
-- Requires: LEFT JOIN Events_View cev ON pv.sched_id = cev.sched_id AND pv.cur_event_id = cev.event_id
```

**Python PA-loop pattern (postgame files):**
```python
pitch_3 = sorted_p.iloc[2]
pa_val = pitch_3.get("cur_ev_pa", 0) or 0
so_val = pitch_3.get("cur_ev_so", 0) or 0
if pa_val == 1 and so_val != 1:
    continue  # GC2 excludes PAs ending on pitch 3 with non-K contact
```

**"Zach's R2K" (original, retired Apr 13 2026):** Had no `(pa=0 OR so=1)` filter — counted
ALL PAs with 3+ pitches. If a batter was 0-2 and homered on pitch 3, that still counted
as the pitcher winning the race. Better captures the intent of "race to 2 strikes" but
coaches prefer GC2 alignment. Can be reactivated by removing the `(pa=0 OR so=1)` filter
from all queries across all 3 worktrees (~19 query/loop locations).

## Loc Grade
`AVG(stuffrelvelloc - stuffrelvel)` from Pitches_Grades

## FB Velo
`('FF','FT','SI')` — SI IS included. GC2 uses only `('FF','FT')` but we intentionally include SI.

## CSC-Weighted Metrics
OSw%, ZSw%, ZCon%, OCtct%, ZWhiff% all use CSC-WEIGHTED formulas (not binary). Chase% is the ONLY binary metric (CSC < 0.01).
- Chase% (CSC < 0.01) and Oswing% (CSC < 0.5) are DIFFERENT metrics

## EW% (Early Win)
Early-count BIP where `rv_gain_given_hit_specs < 0` (pitcher won the exchange).
- **Early counts:** `balls_before <= 1 AND strikes_before <= 1` (all 4: 0-0, 1-0, 0-1, 1-1)
- Denominator = all BIP in early counts. Numerator = BIP where rv_gain < 0.
- NEVER use `(0-0 OR 1-1)` only — that's a 2-count bug (fixed Apr 6 in pitcher_kpi_data.py)
- Standardized across: pitcher_kpi_data.py, tracker_data.py, postgame_data.py, postgame_percentiles.py

### BIP Codes Inconsistency (Documented Apr 12 2026)
EW% BIP codes differ across worktrees:
- **Barrelsville, pd-goals, Arm Farm KPI:** `(12,13,14,18,19,20)` — includes pitchout BIPs
- **Arm Farm tracker/postgame:** `(12,13,14)` — excludes pitchout BIPs
- **Intangibles:** Python constants say 6, SQL hardcodes 3
- Pitchout BIPs (18,19,20) are extremely rare — negligible numeric impact
- **TODO:** Standardize to (12,13,14,18,19,20) everywhere for consistency

## NetK (Net Called Strikes) — VERIFIED against GC2 Apr 16 2026

### Two Metrics
- **NetK** = `SUM(pv.net_k)` — cumulative total framing contribution. Used everywhere.
- **NetK/P** = `SUM(pv.net_k) / COUNT(*)` — per-pitch rate. ONLY in affiliate tracker as a second column.

### BLOCKING RULES — DO NOT CHANGE ANY OF THESE
1. **NetK is cumulative `SUM(net_k)`.** Displayed as f1-f2 (e.g. `-0.80`, `2.53`). Used in postgame, KPI, snapshot, org reports, H2H, percentile pool.
2. **NetK/P is per-pitch rate `SUM(net_k) / COUNT(edge)`.** Displayed as f3 (e.g. `-0.037`). ONLY appears in affiliate tracker alongside cumulative NetK. Do NOT put NetK/P in postgame, KPI, snapshot, or org reports.
3. **`pv.called_strike_chance`** — level-adjusted CSC (see CSC Column Reference below). NEVER `called_strike_chance_mlb` for NetK.
4. **`pv.net_k`** — pre-computed DB column. NEVER compute manually from CSC (`1-CSC` / `-CSC`).
5. **Strict inequality** `> 0.05 AND < 0.95`. NEVER `BETWEEN` — GC2 excludes boundary values.
6. **Result IDs `(4, 5, 6)` only** — Called Ball, Ball In Dirt, Called Strike. NEVER expanded code groups `(6,3,24,30,31)` / `(1,2,4,5,11,...)`.
7. **`ignore_flag = 0` on every NetK query.** Standalone queries: in WHERE. Combined queries (with Steal%/FramRAA): inside CASE WHEN. This is an EXCEPTION to the general "never filter ignore_flag" rule in pitfalls.md.
8. **`pv.pitch_id > 0`** — standard pitch filter, always present.

### Display Contexts
| Context | Metric | Format | Notes |
|---------|--------|--------|-------|
| **Postgame** (game, season, opp, per-PT, H2H) | NetK (SUM) | f2 | H2H compares raw sums per game |
| **KPI chart** | NetK (cumulative cumsum) | f1 | Season build-up ranking |
| **KPI table** | NetK (SUM per catcher) | f1 | Per-catcher total |
| **Snapshot** | NetK (SUM) | f1 | Per-catcher total |
| **Org KPI report** | NetK (SUM across org) | f1 | All org catchers combined |
| **Percentile pool** | NetK (SUM per game) | — | Min 20 edge pitches per game |
| **Affiliate tracker** | BOTH: NetK (f1) + NetK/P (f3) | f1 + f3 | Only place NetK/P appears |

### Files
| File | Method | Domain | Notes |
|------|--------|--------|-------|
| `catcher_data.py::compute_netk()` | Python filter + sum | Player game | Returns both total_netk + netk_per_pitch |
| `catcher_data.py::get_season_netk()` | Python via `compute_netk()` | Player season | Returns total_netk |
| `catcher_data.py::get_netk_vs_record()` | SQL SUM per side | H2H per game | Raw SUM comparison |
| `catching_tracker_data.py` (6 queries) | SQL SUM + SUM/COUNT | Player + org | Both columns in every query |
| `c_kpi_data.py` | SQL SUM | Org chart + player table | Cumulative |
| `catcher_percentiles.py` | SQL SUM per game | Percentile pool | Min 20 edge pitches |
| `snapshot_data.py` | SQL SUM | Player snapshot | total_netk |
| `org_kpi_data.py` (PD Goals) | SQL SUM | Org report | SUM across org |

### What NetK is NOT
- NOT manual `1 - CSC` for strikes / `-CSC` for balls — use `pv.net_k`
- NOT expanded code groups — only `(4, 5, 6)` real called pitches
- NOT `BETWEEN 0.05 AND 0.95` — strict `>` and `<`
- NOT `called_strike_chance_mlb` — use level-specific `called_strike_chance`

## Catcher Metric Aggregation Standard (Apr 17 2026)

All catcher metrics must use consistent aggregation across PD-Goals org, Intangibles KPI, and Intangibles tracker. Per-catcher values feed the tracker; org values feed KPI weekly and PD-Goals org report.

### PERCENTILE_CONT Metrics (lower = better unless noted)

| Metric | Percentile | Range Filter | Source Table | Notes |
|--------|-----------|-------------|-------------|-------|
| **Pop2B** | P01 | 1.70–2.35 | TDM | Fastest throws to 2B |
| **AugPop2B** | P01 | aug_pop IS NOT NULL | CatcherDefense_SBA_Metrics | Accuracy-adjusted pop time |
| **Arm** | P99 | 60–94 | TDM | Higher = better |
| **Exchange** | P10 | ≥ 0.4 AND arm ≥ 60 | TDM | Fastest exchange times |

**BLOCKING:** AugPop2B is ALWAYS P01 — NEVER AVG. Fixed Apr 17 2026 (KPI weekly was using AVG, diverged from org + tracker).

### SUM Metrics (cumulative)

| Metric | Formula | Source | CSC Column | CSC Range | ignore_flag |
|--------|---------|--------|-----------|-----------|-------------|
| **NetK** | `SUM(pv.net_k)` | Pitches_View | `called_strike_chance` (level-adjusted) | `> 0.05 AND < 0.95` (strict) | `= 0` required |
| **FramRAA** | `SUM((CS_indicator - CSC) * (rv_ball - rv_strike))` | Pitches_View | `called_strike_chance_mlb` (MLB model) | `BETWEEN 0.05 AND 0.95` (inclusive) | N/A (take detection instead) |
| **SurPP** | `SUM(passed_pitch) - SUM(pp_prob)` | CatcherDefense_Blocking_ByPitch | N/A | N/A | N/A |
| **BlockRAA** | `SurPP × baserunner_advance_rv` | Computed in Python | N/A | N/A | N/A |

**BLOCKING:** NetK uses `called_strike_chance` (level-adjusted) with STRICT inequality. FramRAA uses `called_strike_chance_mlb` with BETWEEN. These are INTENTIONALLY different columns and ranges.

### Rate Metrics

| Metric | Formula | Source |
|--------|---------|--------|
| **CS%** | `cs / (sb + cs) * 100` | Events_View event_result_id |
| **R2K%** | GC2 pitch-3 formula | Pitches_View + Events_View |
| **Framing buckets** (E Stl, Stl, Mid, Loss, B Loss) | CS rate per CSC zone | Pitches_View, `called_strike_chance_mlb` |

### Org Rollup for P-metrics — Per-Player Weighted Avg (Apr 17 2026)

**SCOPE:** This rule is for **org RANKINGS only** — producing one "org value" per org (30 rows total) that gets ranked 1-30. It is NOT about computing percentiles across the 30 orgs (that concept doesn't exist in this codebase). It is NOT about individual per-player percentiles (those stay as direct `PERCENTILE_CONT OVER PARTITION BY player_id` — unchanged).

**RULE:** All PERCENTILE_CONT metrics (P99 Arm, P10 Exchange, P01 Pop2B/Pop3B, P01 AugPop, P95 TopSpd, P75 AccelUp/Down, P25 React/UsefulReact/ReactRad/ReactAccRad) at the **org level** MUST use per-player weighted avg, never direct pool.

**Why:** Direct pool `PERCENTILE_CONT OVER (PARTITION BY org)` treats every throw as equal — a starter with 200 throws drowns out a backup with 5 throws, so the "org P99 arm" effectively becomes "the starter's P99 arm." The correct org value is each catcher's individual P-metric, weighted by their observation count.

**Pattern (single SQL query):**
```sql
WITH base AS (
    SELECT org, catcher_id, <metric_col> FROM ... WHERE ...
),
per_catcher AS (
    SELECT DISTINCT org, catcher_id,
        PERCENTILE_CONT(0.01) WITHIN GROUP (ORDER BY
            CASE WHEN <range_filter> THEN <metric_col> END)
            OVER (PARTITION BY catcher_id) AS val,
        COUNT(CASE WHEN <range_filter> THEN 1 END)
            OVER (PARTITION BY catcher_id) AS n_obs
    FROM base
)
SELECT org,
    SUM(CASE WHEN val IS NOT NULL THEN val * n_obs END)
        / NULLIF(SUM(CASE WHEN val IS NOT NULL THEN n_obs END), 0) AS org_val
FROM per_catcher
GROUP BY org
```

**Multi-level rollup:** Same weighted-avg pattern at the level layer. Weight each level's org value by total observation count at that level. Never simple average of levels.

**Applies to EVERY org-level P-metric query across these files (complete inventory):**

Catcher surfaces:
- `pd-goals/src/org_kpi_data.py` — `_CATCHER_THROWING_ORG_QUERY`, `_CATCHER_AUGPOP_ORG_QUERY`
- `intangibles/src/c_kpi_data.py` — `_ORG_MONTHLY_AUGPOP_QUERY`, `_ORG_SEASON_AUGPOP_QUERY`
- `intangibles/src/catching_tracker_data.py` — `_ORG_THROWING_DIRECT_QUERY`, `_ORG_POP_DIRECT_QUERY`, `_ORG_AUGPOP_DIRECT_QUERY`. Monthly variants use Python weighted avg in `_get_single_level_org_monthly()`.

OF/IF surfaces (9 metrics: TopSpd P95, AccelUp/Down P75, React/UsefulReact/ReactRad/ReactAccRad P25, Arm P99, Exchange P10):
- `pd-goals/src/org_kpi_data.py` — `_OF_TRACKING_ORG_QUERY`, `_IF_TRACKING_ORG_QUERY`
- `intangibles/src/fielding_tracker_data.py` — `_ORG_TRACKING_AGG_QUERY`, `_ORG_MONTHLY_TRACKING_AGG_QUERY` (shared OF+IF, powers fielding_tracker_page + OF/IF KPI weekly charts/ranks). The only live tracker file for OF/IF; dedicated of_tracker_*.py and if_tracker_*.py were deleted Apr 19 2026.

BR: no P-metrics at org level (PL/SL/TL are AVG, SB%/CS% are rate, 1→3/2→H are rate). Nothing to fix.

Hitting / Pitching (Barrelsville / Arm Farm): all org metrics are rate (K%, BB%, xwOBA, FPinZ%, R2K%) — SUM/SUM direct pool is correct. No P-metric org rollups exist.

**What stays direct-pool (SUM or SUM/SUM):** NetK, SurPP, BlockRAA, FramRAA, R2K%, CS%, SBA counts, framing buckets. These are arithmetic on raw events, not percentile aggregation.

**Individual per-catcher values** stay as direct `PERCENTILE_CONT OVER (PARTITION BY catcher_id)` — that's each catcher's own distribution. No weighting needed, no change.

### Same Pattern for Fielding P-metrics (OF/IF/BR)

Same rule applies to any P-metric org rollup:
- OF/IF: React P25, TopSpd P95, AccelUp/Down P75, Arm P99, Exchange P10, ReactRad P25
- BR tracking: speed, reaction percentiles

### Performance Note

The per-player weighted avg pattern uses a `per_player/per_fielder/per_catcher` CTE with `PERCENTILE_CONT OVER (PARTITION BY player_id)` + `SELECT DISTINCT`. SQL Server computes the window function per row and collapses duplicates.

Compared to direct pool (one large partition per org), per-player partitioning creates more smaller partitions. Sorts within smaller partitions are faster, but there are more of them. Net performance is similar — typically within 10-20% of direct-pool execution time for the same query.

For fielding (OF/IF tracker org queries), expect **1-3 seconds per level** on production DB. Multi-level (all 4 MiLB) with parallelization: ~3-5 seconds. If a query exceeds 10 seconds, optimize by replacing `SELECT DISTINCT` with `ROW_NUMBER() OVER (PARTITION BY player_id ORDER BY sched_id) = 1` — same result, single-pass instead of distinct sort.

Per-level org = per-player P-metric weighted by comp_plays/throws. Multi-level = per-level org values weighted by level total observations. Already correct in `fielding_tracker_data.aggregate_org_across_levels()`.

## CSC Column Reference (Brodie, Apr 16 2026)

**`called_strike_chance`** = level-adjusted model. Describes actual called-strike behavior at that level. Works at ALL levels including MLB. **This is the preferred column for all new code.**

**`called_strike_chance_mlb`** = MLB model applied to all levels. Identical to `called_strike_chance` for MLB games. For MiLB, it applies MLB zone standards regardless of actual umpire behavior at that level.

**Neither is updated for ABS** (per Brodie — GC2 hasn't done anything there yet).

**Migration:** Existing code using `called_strike_chance_mlb` for zone classification (InZ%, Chase%, O-Swing%, O-Contact%, FPinZ%, Pre2K IZ%, Steal%/Loss%, FramRAA) is functionally fine but should migrate to `called_strike_chance` over time. No urgency — they produce the same results for MLB and very similar results for MiLB.

## gcERA (Aligned with GC2 — Apr 6 2026)
- **All files now PA-weighted** (count/BF), matching GC2 Event query
  - GC2: `FROM Events_View LEFT JOIN Pitches ON cur_event_id` → one row per PA
  - so_rate = K/BF, bb_hbp_rate = (BB+HBP)/BF, bip_rate = 1 - so - bb_hbp (derived)
  - pbarrel_rate = pbarrels / tracked_BIP (bunt-excluded, EV<125)
- **HR rate:** Always global MLB (`level='mlb'`), before-May uses prior year
  - `_get_league_hr_rate_gc2()` in tracker_data.py is the canonical source
  - NEVER use level-specific HR rates for gcERA
- **Formula:** `(3.9 + 31.1*hr_rate)*bip*pBrl + 3.5*bip*(1-pBrl) - 3.3*SO + 9.9*BB_HBP`
- **Reference SQL:** `sql-queries/gc2_gcera_query.sql`

### gcERA Inconsistencies (Documented Apr 12 2026)
| Component | GC2 | pd-goals org | Arm Farm tracker | Arm Farm KPI | Arm Farm postgame |
|-----------|-----|-------------|-----------------|-------------|------------------|
| bip_rate | derived (1-so-bb_hbp) | direct (bip_count/bf) | derived ✓ | direct | pitch-weighted |
| tracked_bip bunt filter | YES | YES | **NO** | **NO** | YES |
| BIP codes | (12,13,14) | (12,13,14,18,19,20) | (12,13,14) | (12,13,14,18,19,20) | (12,13,14) |

**pd-goals org bip_rate should switch to derived** (`1 - so - bb_hbp`) to match GC2.
**Arm Farm tracker + KPI tracked_bip need bunt filter** to match GC2.
**BIP codes:** GC2 uses (12,13,14). Standardize to match GC2 for gcERA/gcPerf.

## xwOBA Aggregation Rule
- **Per-player:** `SUM(xwoba_contrib) / COUNT(xwoba_contrib)` = correct (each PA contributes one value)
- **Cross-time rollup (daily→weekly→rolling):** MUST use `SUM(numer) / SUM(denom)`, NOT `MEAN(daily_ratio)`
- Mean-of-ratios gives equal weight to low-PA days. Fixed Apr 6 in hitter_kpi_data.py.

## Bunt Filter on BIP Metrics (Dmg%, Avg EV, pBarrel)
All barrel/pBarrel/Dmg%/Avg EV calculations MUST exclude bunts: `hit_trajectory_id NOT IN (2,3,4)`.
Applies in BOTH org-level chart queries AND per-player table queries. Audited Apr 6.

## Percentile Architecture (Standardized Apr 7, 2026)
- **Range: 1st–100th ONLY.** Never 0th. Clamp to `max(1, min(100, pctile))`. ALL apps, ALL branches.
- **KPI reports (all 6):** L2W table shows span stats, colored by SEASON distribution. `apply_season_percentiles()` in each data module.
- **Weekly individual (OF/IF):** Player bars use `min_obs=1` (any value shows). Distribution pool uses season-wide 10+ Tier 1 events + n>=3 per metric.
- **Daily postgame:** Season distributions via `*_postgame_percentiles.py`. Same pool gates as weekly.
- **Tracker/Snapshot:** Per-pitch rate metrics, season pool, `compute_percentile_ranks()` (ascending=True, 0.0-1.0).
- **PD Goals:** NO player minimum — percentile always shows if value exists. Pool minimums still apply.
- **NEVER** gate individual player display by n>=3 per metric — that's pool-only. Player shows if they have ANY value.
