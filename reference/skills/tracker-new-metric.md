---
name: tracker-new-metric
description: Adding / modifying / removing a metric in any affiliate tracker (Arm Farm, Barrelsville, BR, Catching, Fielding/OF/IF). Forces disambiguation questions BEFORE writing code so we don't ship the wrong interpretation (FB%-as-fastball-usage incident May 14 2026). Enforces the 7-place propagation checklist and the percentile-pool / multi-level-aggregation decisions.
---

# Tracker New Metric — Question-First Workflow

## When to Trigger

Any time the user says one of:
- "add [metric] to the [tracker]"
- "we need [X] as a column"
- "drop / remove [metric] from..."
- "change how [metric] is computed"
- "I want [X] in the org rankings too"

In ANY affiliate tracker:
- Arm Farm: `bullpen-report/src/tracker_data.py` + `pages/3_Affiliate_Tracker.py`
- Barrelsville: `barrelsville/src/tracker_data.py` + `pages/2_Affiliate_Tracker.py`
- BR: `intangibles/src/br_tracker_data.py` + `pages/X_BR_Tracker.py`
- Catching: `intangibles/src/catching_tracker_data.py` + `pages/4_Catching.py`
- Fielding (OF + IF, unified): `intangibles/src/fielding_tracker_data.py` + `intangibles/src/fielding_tracker_page.py`

## The Iron Rule — NO ASSUMPTIONS

Common metric names are OVERLOADED in baseball. Default interpretations vary by context. **You MUST ask before assuming.** Wrong-interpretation bugs are silent (the value computes, just measures the wrong thing) and waste hours when the coach asks "wait, why is FB% 55%, my whole staff isn't throwing all fly balls?"

The FB%-as-fastball-usage incident (May 14 2026, commit reverted in `a2cb382`) is the canonical example. Don't repeat it.

## The Mandatory Questionnaire

Use `AskUserQuestion` to surface these as actual choices, not buried text. Skip nothing. Even "obvious" defaults must be confirmed.

### Q1 — Metric name + 1-sentence definition

```
"Tell me the metric name (e.g., 'VAA', 'FB%', 'Whiff%') and a one-sentence
definition of what it measures."
```

### Q2 — Disambiguation (BLOCKING — ask any time the name is overloaded)

If the name matches any of these, ASK before proceeding:

| Name | Possible interpretations |
|---|---|
| **FB%** | (a) Fly Ball rate — `n_fb_traj / n_bip_traj`. (b) Fastball usage — `n_FB_pitches / n_pitches`. |
| **VAA** | (a) Fastball VAA — AVG on FF/FT/SI only. (b) All-pitch VAA — AVG across all pitches. |
| **HAA** | Same disambiguation as VAA. |
| **Whiff%** | (a) Whiffs / swings (canonical). (b) Whiffs / pitches (= SwStr%). |
| **K%** | (a) K / BF (PA-anchored). (b) K / 9 (per-9 rate). |
| **BB%** | (a) BB / BF. (b) BB / 9. |
| **GB%** | (a) GB / tracked BIP (canonical). (b) GB / total BIP including untracked. |
| **Hard%** | (a) HardHit% (95+ mph EV). (b) Hard contact rate by trajectory. |
| **Barrel%** | (a) Predicted-barrel rate (pBrl%). (b) MLBAM barrel rate (EV+LA envelope only). |
| **Contact%** | (a) (Swings - Whiffs) / Swings. (b) BIP / Swings. |
| **In-zone%** | (a) AVG(CSC) — continuous. (b) Binary in-zone flag count. |

Any metric ending in `%` deserves a disambiguation question — ratio numerator/denominator is rarely obvious.

### Q3 — Data source + gate

```
"What's the underlying data?
  - Table + column (e.g., Pitches_View.vert_appr_angle)
  - Any filter (e.g., pitch_type IN ('FF','FT','SI'), or BIP only, or CSC > 0.05)"
```

### Q4 — Display format

| Format | Use for |
|---|---|
| `f0` | Integer-ish floats (Stuff+, Loc grade) |
| `f1` | One-decimal floats (Velo, VAA, BF, Ext) |
| `f2` | Two-decimal floats (gcERA, FIP, BABIP) |
| `f3` | Three-decimal floats (BABIP-style) |
| `pct1` | Percentages (Whiff%, GB%, K%) |
| `pct2` | Two-decimal percentages (R2K%) |
| `int` | Pure integers (Pitches, BF count) |
| `ip_thirds` | Baseball IP notation (12.1, 12.2) |

### Q5 — Coloring (BLOCKING)

```
"How should this be colored in the table?
  (a) Higher is better — green at top, red at bottom of percentile
  (b) Lower is better — green at bottom (e.g., ERA, BB%, Damage%)
  (c) Uncolored — display only, no percentile coloring (e.g., spin rate, VAA)
       Sets hib=None in LEADERBOARD_COLS"
```

### Q6 — Percentile pool gate (if colored)

```
"What's the minimum observation count for percentile-pool inclusion?
  Examples: 200 pitches (default for pitching), 50 PA, 30 BIP, 20 swings.
  Players below the gate STILL DISPLAY their value — they just don't enter
  the percentile pool used for coloring."
```

Reference: `db-columns.md` Pool Gate section + `pd-goals.md`. NEVER hide a player from the table for failing the pool gate — gating controls coloring only.

### Q7 — Multi-level rollup mechanic (BLOCKING — see `multi-level-rollup.md`)

```
"For multi-level views (a pitcher who played at AAA + AA), how should
this aggregate?

  (a) Pitch-weighted average — SUM(per-level value × n_pitches) / SUM(n_pitches).
      Right for: AVG-of-pitch metrics like Velo, VAA, Stuff+.

  (b) PA-weighted average — same as above but weighted by BF instead.
      Right for: K%, BB%, K-BB%, R2K%, gcERA.

  (c) Count-derived (numer / denom) — re-derive from summed numerator
      and denominator counts. Right for: Whiff% (sum whiffs / sum swings),
      GB% (sum n_gb / sum n_bip_traj), FB%, Barrel%, Damage%, FIP, BABIP.
      REQUIRES exposing the numerator + denominator counts as SQL columns.

  (d) PERCENTILE METRIC — POOLED RAW OBS (MANDATORY path for any P*).
      For P01, P10, P25, P75, P95, P99 etc.: pool the player's raw
      observations across the selected scope and compute np.percentile
      ONCE. Weighted-mean-of-per-slice-percentiles is FORBIDDEN — it
      silently drifts the value (Nunez Arm: 86.0 wrong vs 87.2 true).
      Triggers the 5-piece implementation requirement (see
      pooled-percentile-pattern.md). Asks the hand-dependence
      sub-question below.

  (e) Custom — describe."
```

If user picks (d), ALWAYS follow up with:

```
"Hand-dependence sub-question (BLOCKING for raw-obs pin shape):

  Does this metric VARY by pitcher / batter hand?

  (i)  No — hand-agnostic physical metric (throw velocity, sprint speed,
       exchange time, reaction time on a hit fly ball, etc.).
       Pin: single raw_obs key per H/A (no hand variant).
       Examples: fielding Arm/TopSpd/React, catcher Arm/Pop/Exch.

  (ii) Yes — platoon-sensitive measurement (per-hand EV/Damage/Whiff%
       splits, framing buckets where umpire calls vary by hitter hand,
       lead distance where runner posture changes vs LHP/RHP).
       Pin: 3 raw_obs hand variants (raw_X_all, raw_X_l, raw_X_r).
       Per-hand display = percentile over per-hand raw pool."
```

Get this wrong and the metric silently drifts across multi-level views vs. single-level. The Apr 18-19 2026 audit pass caught a half-dozen of these in catcher/OF/IF/BR; don't reintroduce them. The May 23 2026 fielding raw-obs refactor (`b084ce6f` → `d1a9b129`) is the canonical reference for percentile metrics — read it before implementing any new P*.

### Q8 — Org-aggregation mechanic

```
"For the Org Rankings tab — how should this aggregate across all of an
org's pitchers/players?

  (a) Pool — sum the org's numerator + denominator across players (e.g.
      total org strikeouts / total org BF). Volume-weighted by definition.

  (b) Per-player simple mean — average each player's value equally
      (1 vote per player). Right for development-style framing.

  (c) Per-metric weighted — weight each player's value by their own
      observation count (e.g., per-player P99 Arm weighted by their n_arm
      to produce org Arm P99).

  Defaults: pitcher rates (K%, BB%, FB Velo) usually pool. Per-player
  percentiles usually per-metric weighted. ALWAYS ASK — these answer
  different questions."
```

Cross-reference: `draft-projects.md` BLOCKING rule on per-player vs pool, and `kpi-weekly-charts.md` for the rate vs percentile distinction.

### Q9 — Three-surface parity check

```
"Does this metric ALSO live in:
  - Postgame report / app page?
  - KPI weekly report / chart?
  - PD-Goals org KPI report?

  If yes, we need to propagate the same definition + filter to all
  surfaces. If no, confirm the tracker is the only place."
```

Reference: `three-surface-parity.md`. If a metric diverges across surfaces, that's a parity bug regardless of how clean each individual surface is.

### Q10 — Tooltip

```
"One factual sentence for the column-header tooltip. No marketing,
no padding. Just what it is and the gate."
```

## The Propagation Checklist — 7 places (or 9 if metric is percentile)

ONCE the user has answered Q1-Q10, walk through these sites IN ORDER. Each is a different file/location; skipping any leaves the metric half-working. Mirror `.claude/rules/tracker-new-metric-checklist.md`.

**For non-percentile metrics: 7 places.**

**For percentile metrics (Q7 = option d): 9 places** — adds places 8 + 9 below for the raw_obs pooled implementation. NEVER ship a percentile metric without all 9.

### 1. `LEADERBOARD_COLS` tuple

Add the metric tuple `(key, "Display Label", "format", hib_flag)` in `src/tracker_data.py` (or sibling for non-Arm-Farm trackers).

```python
("vaa_fb", "FB VAA", "f1", None),  # uncolored
```

### 2. SQL queries — 4 sites

In `src/tracker_data.py`:
- Per-pitcher season pitch query (around `_PITCH_LEVEL_QUERY`)
- Per-pitcher monthly pitch query (around `_MONTHLY_PITCH_QUERY`)
- Org season pitch query (around `_ORG_PITCH_QUERY`)
- Org monthly pitch query (around `_ORG_MONTHLY_PITCH_QUERY`)

Same SQL fragment in all 4 (use `Edit replace_all=true` after confirming uniqueness).

### 3. Python derivation (count-derived metrics only — Q7 option c)

If the metric is count-derived, add `df["metric"] = 100 * df["numer"] / df["denom"]` at:
- Per-pitcher season compute (mirror `gb_pct` location)
- Per-pitcher monthly compute
- Org `_merge_org_pa_metrics` compute

### 4. Multi-level rollup — `aggregate_org_across_levels`

In `src/tracker_data.py`, the `aggregate_org_across_levels` function has three lists. Place the metric key in the RIGHT one:

| Q7 answer | List |
|---|---|
| (a) Pitch-weighted | `pitch_weighted` |
| (b) PA-weighted | `pa_weighted` (or special-case if missing) |
| (c) Count-derived | `count_derived` PLUS add the numer + denom accumulators (`total_X = group["n_X"].sum()`) PLUS the row formula (`row["metric"] = 100 * total_numer / total_denom`) |
| (d) Per-metric weight | New per-metric block exposing the metric's own count column |

Check `multi-level-rollup.md` if uncertain.

### 5. Page multi-level combine (`_combine_multi_level`)

In `pages/<tracker>.py`:
- Pitch-weighted → add to `_PITCH_WEIGHTED_KEYS`
- PA-weighted → add to `_PA_WEIGHTED_KEYS`
- Count-derived → match `gb_pct` precedent (leave OUT of weighted sets — accepts NaN at multi-level page-combine if no count-derived block exists in the page). Document the limitation.

### 6. Stale-pin shim

In `src/tracker_data.py`, every `get_*_leaderboard` / `get_*_stats` function has a block:
```python
for _new_col in ("ip_per_start", "n_starts", "outs_in_starts", "fb_vaa", "fb_pct"):
    if _new_col not in _pinned.columns:
        _pinned[_new_col] = np.nan
```

Add the new column name(s) — including any underlying count columns (`n_X_traj`) needed by count-derived metrics. Do this in ALL 5 shim sites (use `grep -n "_new_col not in _pinned"` to find them).

### 7. Tooltip dict

In `METRIC_TOOLTIPS` dict in `src/tracker_data.py`. One sentence from Q10.

---

## Places 8 + 9 — PERCENTILE METRICS ONLY (skip for non-percentile)

If Q7 = option (d) Percentile metric, the rule from `pooled-percentile-pattern.md` requires raw-obs pooling. Implement BOTH places below or the metric silently drifts on multi-level/multi-year views.

### 8. Raw observation SQL query

Mirror `intangibles/src/fielding_tracker_data.py::_RAW_TDM_QUERY` shape:

```python
_RAW_<METRIC>_QUERY = """
SELECT
    <player_id>, <org>, <level>, <season>, <position_cols>,
    <metric_value_col>,
    <gate_flag_cols>   -- comp_play, ignore_flag, etc.
FROM <source_table> JOIN Schedule_View sv ...
WHERE sv.year IN (<all PINNED_YEARS>)
  AND <Tier 1 gate>
  AND <range filter if applicable>
  -- NO PERCENTILE_CONT here
{level_filter} {sched_filter} {ha_filter}
"""
```

Plus thin wrapper `_get_raw_<metric>(domain, season, sched_types, ha_split)` that runs it with the canonical level set.

Add `PREFIX_RAW_<METRIC>` to `tracker_pins.py` + `ALL_<DOMAIN>_PREFIXES`.

Add `_try_pin_raw_obs(domain, seasons, sched_types, ha_split)` gate (or extend the existing one) so the app can read pooled data instantly.

### 9. Pooled compute helper + parity diagnostic

Two helpers in the data module:

```python
def _compute_pooled_indiv_from_raw_obs(raw_dfs, level_codes, seasons, ...):
    """Filter raw obs to scope. Per-player np.percentile. Per-metric n_X count.
    Apply same display gates (min_plays) as SQL path."""

def _compute_pooled_org_from_raw_obs(raw_dfs, level_codes, seasons, ...):
    """Per-player percentile → org weighted-mean by per-metric n_X."""
```

Wire into `get_indiv_leaderboard_pooled` + `get_org_rankings_pooled`: check `_try_pin_raw_obs` FIRST, fall back to live SQL on miss.

**Parity diagnostic** `scripts/diag_pooled_parity.py` MUST exist + MUST PASS before pin CLI runs in production:
- Path A: new raw_obs path
- Path B: existing PERCENTILE_CONT SQL path
- ±0.05 tolerance on percentile values, ±0.01 on sums, ±0.5 on counts
- Test cases: multi-level player, multi-year player, single-level sanity check
- If parity fails → DO NOT SHIP. Fix the helper math.

Pin CLI integration: 3 raw queries × 3 H/A = 9 keys per (domain, year). Plus existing per-level pins. ~6 min/year vs the 12+ hours of pre-aggregated combos.

Reference impl: fielding raw-obs refactor, `intangibles/src/fielding_tracker_data.py` (`b084ce6f` → `d1a9b129`).

---

## After Implementation — Show the User Before Committing

State explicitly what you did, including the disambiguation answers. Use the format:

```
Implemented [metric name]:
  - Interpretation: [Q2 disambiguation answer]
  - Source: [Q3 column/filter]
  - Format: [Q4]
  - Coloring: [Q5]
  - Pool gate: [Q6]
  - Multi-level rollup: [Q7 option]
  - Org rollup: [Q8 option]
  - Three-surface parity: [Q9 propagated to / scoped to tracker only]
  - Tooltip: "[Q10 text]"

Files touched:
  - src/tracker_data.py — LEADERBOARD_COLS + 4 SQL + Python + multi-level + 5 shims + tooltip
  - pages/3_Affiliate_Tracker.py — weighted-key set (if applicable)

Pin re-run needed before deployed app sees real values. Existing pins
won't crash thanks to the stale-pin shim — columns NaN until re-pin.
```

## What NOT to Do

- **Don't guess at metric disambiguation.** Even "obvious" cases like Whiff% deserve a one-line confirmation question.
- **Don't skip the multi-level rollup decision (Q7).** Putting a count-derived metric in `pitch_weighted` silently drifts the multi-level value (Apr 20 hitting parity incident).
- **Don't add a colored metric without a pool gate decision (Q6).** Sub-200-pitch pitchers get over-bright percentiles.
- **Don't ship without checking three-surface parity (Q9).** Tracker shows one number, postgame shows another, coach files a bug.
- **Don't put `hib=True` on a metric the user said "uncolored" or "no color" for.** Set `hib=None` and add it OUTSIDE the pool-gate / percentile pipeline.
- **Don't write SQL before reading the existing `_PITCH_LEVEL_QUERY` aggregations.** The fragment style + format string variables (`{fb_types}`, `{bip_codes}`, etc.) are conventions; deviating breaks the format() call.
- **Don't change a metric formula on ONE site only.** All 4 SQL sites + the Python derivation + the multi-level rollup move in lockstep, or the multi-level value diverges from the single-level value.
- **Don't promise the user the metric will appear immediately after commit + push.** Re-pin is required for deployed views; live-DB fallback (custom filter) is the only path that shows new metrics without re-pinning.

## Cross-References

- `.claude/rules/pooled-percentile-pattern.md` — **BLOCKING for any P-metric.** 5-piece raw-obs implementation, hand-dependence decision branch, status table per tracker. Canonical reference: fielding's May 23 2026 refactor.
- `.claude/rules/tracker-new-metric-checklist.md` — the 7-place (or 9 for P*) checklist this skill enforces
- `.claude/rules/tracker-parquet-pins.md` — pin schema, stale-pin shim, re-pin workflow
- `.claude/rules/multi-level-rollup.md` — Iron Rule for per-metric weighting + count-derived rules + two-tier architecture
- `.claude/rules/three-surface-parity.md` — tracker / KPI weekly / PD-Goals invariants
- `.claude/rules/kpi-weekly-charts.md` — rate-vs-percentile distinction
- `.claude/rules/db-columns.md` — column reference, pool gate conventions
- `.claude/rules/never-round-until-display.md` — precision through aggregation
