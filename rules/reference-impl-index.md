---
paths:
  - "**/*.py"
  - "**/*.sql"
---

# Reference Implementation Index

**BEFORE writing SQL for any metric below, open the reference file and read the working implementation. Do not reconstruct from memory or textbook. The references are battle-tested and the conventions exist to prevent known bugs.**

## Hitting metrics

| Metric | Canonical implementation | Notes |
|---|---|---|
| **wOBA (per-batter)** | `pd-goals/src/org_kpi_data.py::_HITTING_ORG_QUERY` (line ~720) — SQL inline with `AVG(w) * SUM(event)` | Denom = `AB + BB - IBB + HBP + SF`. Event-anchored driver (Events_View), `cur_event_id` JOIN |
| **wOBA (per-batter Python)** | `barrelsville/src/tracker_data.py` (line ~1080) + `hitter_kpi_data.py::get_player_table_data` (line ~1270) | Fetch PA counts via SQL, apply weights in Python. Same math as SQL inline |
| **wOBA weights** | `barrelsville/src/hitter_kpi_data.py::_get_woba_weights` (line 145) — `AVG(woba_*)` across league splits | Falls back to season-1 before May |
| **wRC+ league env** | `barrelsville/src/hitter_kpi_data.py::_get_league_woba_env` (line 191) — `AVG(wOBA) / AVG(wOBA_scale) / AVG(runs_per_pa)` | Per-level. Never `SELECT wOBA` without AVG |
| **wRC+ formula** | `(wOBA - lg_wOBA) / scale + runs_per_pa) / runs_per_pa * 100` | Same across pd-goals + barrelsville |
| **xwOBA (per-batter)** | `barrelsville/src/hitter_kpi_data.py` (xwoba block) | Hits_Probabilities + exponents from Guts.hit_specs_ratios. **Exponents do NOT fall back to prior year** (rule in woba-rules.md) |
| **xwOBA exponents** | `barrelsville/src/hitter_kpi_data.py::_get_hit_specs_exponents` | Global, no level dim. Default fallback = identity `{1.0, 1.0, 1.0, 1.0, 1.0}` |
| **gcOBA (per-batter)** | `barrelsville/src/tracker_data.py` (gcOBA block) | Composite: swing dist (zero_sw/one_sw/two_sw/three_plus_sw) + barrel + useful_ev. GC2 production reference provided in parity audits |
| **K% / BB%** | `barrelsville/src/tracker_data.py` | Denom = `SUM(pa) + SUM(ibb)` (total PA including IBB + SH). **Distinct** from wOBA denom |
| **Ctct% / Whiff%** | `barrelsville/src/tracker_data.py` | Denom = swings. Whiff requires `did_swing = 1` gate (blocking rule #4) |
| **ZCtct% / ZSw% / OSw%** | `barrelsville/src/tracker_data.py` | Zone definition via `called_strike_chance_mlb > 0.5`. Denom = zone/OOZ pitch count |
| **Barrel% / Hard% / PullAir% / Dmg%** | `barrelsville/src/tracker_data.py` | Denom = `n_bip_tracked`. Barrel excludes bunts |
| **Avg EV / Max EV** | `barrelsville/src/postgame_data.py::EV_MISREAD_CTE` | Misread filter: `pitch_result_id IN (12,13,14)` + `hit_exit_speed > 0 AND < 125`. Max EV = true `MAX()` after cleaning, never P99 |
| **InZ% (pitcher view)** | `barrelsville/src/tracker_data.py` (pitcher-side) + `bullpen-report/src/tracker_data.py` | `AVG(called_strike_chance_mlb)` — NOT binary `CSC > 0.5` (Pre2K IZ% fix Apr) |
| **zxwOBA** | `barrelsville/src/postgame_data.py` | Per-pitch delta scaled by wOBA_scale. Norm constant `_ZXWOBA_NORM_RANGE = 0.015` |

## Pitching metrics

| Metric | Canonical implementation | Notes |
|---|---|---|
| **FPinZ%** | `bullpen-report/src/tracker_data.py` | First-pitch-in-zone rate |
| **R2K%** | `bullpen-report/src/tracker_data.py` + `pd-goals/src/org_kpi_data.py` | GC2 formula: `(pa=0 OR so=1)` denom filter. Display `pct2` (2 decimals) |
| **K-BB% (pitcher)** | `bullpen-report/src/tracker_data.py` | `K% - BB%` subtraction. Hitter inverse direction |
| **gcERA** | `bullpen-report/src/tracker_data.py` | pBarrel formula: `EV >= 0.011*LA² - 0.91*LA + 95` + `EV < 125`. pBarrel computed in Python from `h.hit_exit_speed` + `h.hit_vertical_angle`, NOT from `hp.pbarrel` (column doesn't exist) |
| **Stuff+ / Loc Grade** | `bullpen-report/src/tracker_data.py` | Pitch-weighted |
| **Org aggregation (pitching)** | `pd-goals/src/org_kpi_data.py` | Pitch-weighted for rate metrics, PA-weighted for K%/BB%/K-BB%/gcERA |

## Fielding metrics (OF/IF/Catcher)

| Metric | Canonical implementation | Notes |
|---|---|---|
| **OF/IF Tier 1 gate** | `intangibles/src/fielding_tracker_data.py` + `pd-goals/src/org_kpi_data.py` | **6-term OR**: `DCBP.out_made + DCBP.CP + DCBP.CT + TDM.CP + TDM.CT + (arm >= floor) > 0`. Blocking rule #12 |
| **OF/IF tracking (TopSpd P95, React P25, Arm P99, etc.)** | `intangibles/src/fielding_tracker_data.py` — **SINGLE-POOL SQL for multi-level** via `_build_levels_filter` + `_get_pooled_org_stats` + `get_org_rankings_pooled` (commit `1dd24bb`) | Reference pattern for Bug B fix |
| **OF/IF PAA/EO** | `intangibles/src/fielding_tracker_data.py` (port of PD-Goals formula) + `pd-goals/src/org_kpi_data.py` | Event-level calibrated via PAA_EO table |
| **OF/IF OAA** | `intangibles/src/fielding_tracker_data.py` | SUM (cumulative, not percentile) |
| **Catcher Arm P99 / Exch P10 / Pop2B/3B P01 / AugPop P01** | `intangibles/src/catching_tracker_data.py` — per-level pattern only | ⚠️ **Bug B pending** — cross-level pooling fix not yet applied. See `rules/multi-level-rollup.md` section "Catcher P-metrics". Pattern to port = `fielding_tracker_data.py`'s `_build_levels_filter` + `_get_pooled_org_stats` |
| **Catcher FramRAA / BlockRAA / NetK** | `intangibles/src/catching_tracker_data.py::_ORG_PITCHES_COMBINED_QUERY` | SUM metrics, immune to pooling issue. `br_rv` must be NEGATED for BlockRAA (Apr 18 fix, commit `2aa1555`) |
| **Catcher framing buckets (E Stl/Stl/Mid/Loss/B Loss)** | `intangibles/src/catching_tracker_data.py` | Rate metrics re-derived from count sums at multi-level (not pitch-weighted avg) |

## Baserunning metrics

| Metric | Canonical implementation | Notes |
|---|---|---|
| **BR tracking (TopSpd/Reaction/T22/Split1/Accel)** | `intangibles/src/br_tracker_data.py` | AVG of per-play values (not percentile). Bug B doesn't apply |
| **Leads (PL/SL/TL)** | `intangibles/src/br_tracker_data.py` | PL = all leads (no `runner_going` filter). SL/TL filter `runner_going = 0`. 1B leads gate on `closest_fielder_distance <= 10`. Exclude next-base-occupied via LEFT JOIN IS NULL. **`ignore_flag = 0`** + **`pv.pitch_id > 0`** required on all 4 lead queries (`6907e01`) |
| **SB/CS counts** | `intangibles/src/br_tracker_data.py` + PD-Goals | **Events_View.event_result_id** (official scoring). Never `Events_StolenBases` for totals (ESB is play-by-play only) |
| **1→3 / 2→H** | `intangibles/src/br_tracker_data.py::_FT3_S2H_QUERY` | Cumulative SUMs from Events_View. **SINGLE-ONLY by design** — gates on `CAST(ev.[1b] AS INT) = 1`. Doubles / triples / errors / FCs do NOT count even when the runner physically went 1B→3B. Going 1B→3B on a double is the default outcome (long throw home), so it doesn't reflect baserunning aggression / read. Matches Statcast XBT% / FanGraphs convention. Confirmed Apr 30 2026 (Yamal Encarnacion case) — see `sql-queries/yamal-ft3-investigation.sql` for the play-level diagnostic, `sql-queries/bases-loaded-doubles-1to3.sql` for the LF-pulled bases-loaded-doubles comp-set search with M-angle video. |

## Database schema references

| Topic | Reference |
|---|---|
| Column names (batter_id, CSC, BIT casting, etc.) | `rules/db-columns.md` |
| **Org-code canon (BLOCKING)** — PP_MASTER ↔ MLBAM cross-source JOINs | **`rules/org-codes.md`** |
| Join keys (cur_event_id vs ab_event_id, dual-join pattern) | `rules/db-joins.md` |
| DB connection (FreeTDS vs ODBC 17, dual-mode) | `rules/db-connection.md` |
| Pitch result codes | `rules/pitch-codes.md` |
| Level codes (DSL/FCL split, junk levels) | `rules/level-codes.md` |
| Common pitfalls (BIT SUM, NaN IN clause, etc.) | `rules/pitfalls.md` |

## Query-drafting workflow

1. **Identify the metric** — what are you computing?
2. **Open this file, find the metric row, open the reference implementation**
3. **Read the reference** — driver table, JOIN keys, filters, aggregation pattern
4. **Read the linked rule file** (woba-rules, event-vs-pitch-anchored, db-joins, etc.)
5. **Adapt, don't reconstruct** — copy the reference pattern, change only what the user's scope requires
6. **Sanity check output** — does one known player's PA count look right? Does the metric match a reference view?

Skipping step 2-4 leads to PA inflation, wrong denom, wrong JOIN keys, mismatched weights. Every bug in the Apr 22 FCL zSw query chain came from skipping these steps.
