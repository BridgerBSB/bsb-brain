---
name: metric-audit
description: Cross-app metric parity check. Use when adding, modifying, or removing ANY metric from any app, report, or query. Ensures the metric is consistent across all apps that should have it.
---

# Metric Audit — Cross-App Parity Check

When adding, modifying, or removing ANY metric in ANY app or report, run this checklist to ensure parity across all surfaces that should show the same metric.

## When to Trigger

- Adding a new column to a tracker, KPI, report, or app page
- Changing a metric formula (SQL gate, aggregation, display format)
- Removing a metric
- After any gate change (Tier 1, NetK, etc.) that affects metric computation
- User mentions a metric discrepancy between apps

## Step 1: Identify the Metric

| Question | Answer |
|----------|--------|
| Metric name/key | |
| Domain (hitting/pitching/fielding/catcher/BR) | |
| Formula (SQL or Python) | |
| Display format (f1/f2/f3/pct1/int) | |
| Higher is better? | |
| Gate/filter required? | |

## Step 2: Where Does This Metric Currently Live?

Search ALL worktrees for the metric key. Check every surface:

### Per Domain — Check All of These

**Hitting metrics:** Check across Barrelsville + PD Goals
- [ ] Postgame app page (`1_Postgame.py`)
- [ ] Postgame PDF report (`postgame_report.py`)
- [ ] Postgame data module (`postgame_data.py`)
- [ ] Hitter analysis app/report
- [ ] Weekly hitter report
- [ ] Affiliate tracker (individual + org)
- [ ] KPI report (chart + table)
- [ ] KPI app page
- [ ] Snapshot PDF
- [ ] Org KPI report (PD Goals)
- [ ] PD Goals app (goals display)
- [ ] Advance scouting report

**Pitching metrics:** Check across Arm Farm + PD Goals
- [ ] Postgame app page (`2_Postgame.py`)
- [ ] Postgame PDF report
- [ ] Affiliate tracker (individual + org)
- [ ] KPI report (chart + table)
- [ ] KPI app page
- [ ] Snapshot PDF
- [ ] Org KPI report (PD Goals)
- [ ] PD Goals app
- [ ] Advance pitching report

**Fielding metrics (OF/IF):** Check across Intangibles + PD Goals
- [ ] Daily postgame app page
- [ ] Daily postgame PDF report
- [ ] Weekly player report (PDF + app)
- [ ] Affiliate tracker (individual + org + monthly)
- [ ] KPI report (chart + table)
- [ ] KPI app page
- [ ] Snapshot PDF
- [ ] Org KPI report (PD Goals)
- [ ] PD Goals app (defense goals)
- [ ] Percentile distributions
- [ ] PR detection (`detect_prs` + `all_time_bests`)

**Catcher metrics:** Check across Intangibles + PD Goals
- [ ] Postgame app page (`4_Catching.py`)
- [ ] Postgame PDF report (`catcher_report.py`)
- [ ] Affiliate tracker (individual + org)
- [ ] KPI report (chart + table)
- [ ] KPI app page
- [ ] Snapshot PDF
- [ ] Org KPI report (PD Goals)
- [ ] PD Goals app (catcher goals)

**Baserunning metrics:** Check across Intangibles + PD Goals
- [ ] Daily postgame app + PDF
- [ ] Daily team report
- [ ] Affiliate tracker (individual + org)
- [ ] KPI report
- [ ] Snapshot PDF
- [ ] Org KPI report (PD Goals)
- [ ] PD Goals app

## Step 3: Verify Consistency

For each surface where the metric exists:

| Check | What to verify |
|-------|---------------|
| **SQL formula** | Identical gate, column names, aggregation |
| **Display format** | Same decimals (f1/f2/f3/pct1) |
| **Sort direction** | Same `higher_is_better` flag |
| **Gate** | Same Tier 1 / edge-zone / ignore_flag filter |
| **Org aggregation** | Volume-weighted if rate metric |
| **Multi-level** | Handles promotions / multi-level selection |
| **Percentile pool** | Same distribution feeding the coloring |

## Step 4: Report Findings

```
## Metric Audit: {metric_name}

### Found in:
- {list of files with line numbers}

### Consistency:
- Formula: {MATCH / DIVERGENCE with details}
- Display: {MATCH / DIVERGENCE}
- Gate: {MATCH / DIVERGENCE}

### Missing from:
- {list of surfaces that SHOULD have it but don't}

### Action items:
- {specific changes needed}
```

## Step 5: After Making Changes

- [ ] All surfaces use identical formula
- [ ] Display format consistent
- [ ] Gate consistent
- [ ] Documentation updated in `.claude/rules/`
- [ ] Changes pushed to ALL relevant branches

## Common Org Parity Traps (learned Apr 20 2026 — verify every time)

These are the bugs we've hit multiple times on org rankings. Most are subtle enough to mask each other for months. Check EVERY time you add or modify an org-level hitting/pitching metric:

### Trap 1 — wOBA denom with SH (1-point wRC+ drift)
**Symptom:** Tracker and PD-Goals wRC+ differ by 1 (rankings can match even when absolute numbers don't).
**Cause:** `ev.pa = 1` for sacrifice hits in Astros DB. `COUNT(pa=1 AND ibb=0)` as wOBA denom includes SHs, but FanGraphs-standard wOBA excludes SHs.
**Fix:** Always use explicit `AB + BB - IBB + HBP + SF` formula for wOBA denom. See `rules/woba-rules.md` "wOBA Denominator — BLOCKING".

### Trap 2 — Blended weights vs per-level (~0.003 xwoba drift)
**Symptom:** xwoba and wRC+ off slightly but ranks correlate well.
**Cause:** Using a single `AVG(woba_bb) FROM Guts.woba_lwts WHERE level_code IN ('aaa','aax','afa','afx')` blend applied uniformly to every pitch. Tracker uses per-level weights, so an org with mixed-level PAs diverges.
**Fix:** JOIN `Guts.woba_lwts` per-pitch on `(year, level_code)` with `AVG()` per-pair (PD-Goals pattern) OR query each level separately and pass per-level flat params (tracker pattern).

### Trap 3 — xwoba exponent prior-year fallback (~0.003 xwoba drift all season)
**Symptom:** xwoba "never aligned" — small persistent gap all season.
**Cause:** PD-Goals had `if month<5: lookup_year = season-1` on `_get_hit_specs_exponents`. Tracker does NOT do this fallback — queries `:season` directly.
**Fix:** Both sides query `:season` directly. If current-year row missing in `Guts.hit_specs_ratios`, fall back to `{1.0, 1.0, 1.0, 1.0, 1.0}` defaults. Weight lookup_year fallback is different — weights DO fall back, exponents do NOT.

### Trap 4 — League env `SELECT wOBA` vs `SELECT AVG(wOBA)`
**Symptom:** wRC+ off by 1-2 points.
**Cause:** `Guts.woba_lwts` has multiple rows per `(year, level_code)` for league splits (AL/NL). `SELECT wOBA` + `.iloc[0]` picks one split; tracker uses `AVG()`.
**Fix:** Every helper that queries `Guts.woba_lwts` uses `AVG()` on all columns.

### Trap 5 — n_pitches weight for rate metric at multi-level rollup (~0.1% drift)
**Symptom:** Rate metric drift at multi-level (Ctct%, ZSw%, Chase%).
**Cause:** Tracker's `aggregate_org_across_levels` weights by `n_pitches` across levels. For Ctct%, denom is swings (not pitches). Pitch-weighted avg of per-level rates ≠ pool of all swings.
**Fix:** Expose per-metric numerator + denominator counts per level. Re-derive rate from SUM(numer) / SUM(denom) in the count-derived block. Remove from `pitch_weighted` list. See `rules/multi-level-rollup.md` Hitting table.

### Trap 6 — Misread filter CTE scope divergence (~0.1% drift on Avg EV / Dmg% / Hard% / PullAir%)
**Symptom:** BIP-based metrics off slightly.
**Cause:** `batter_ev_p95` CTE scoped differently between apps. Tracker covers MLB + 4 MiLB + ROK + DSL (7 levels); PD-Goals had only 4 MiLB. Promoted batters' P95 diverges.
**Fix:** Copy tracker's `EV_MISREAD_CTE` verbatim. BIP-only (`pitch_result_id IN (12,13,14)`), hit_exit_speed > 0 AND < 125, 7-level scope.

### Trap 7 — "End date" is a red herring
The apps' different date handling (tracker live vs PD-Goals `<= :end_date`) is almost never the actual cause of drift. It usually produces 1-2 PA jitter, not 0.003 xwoba or 1-point wRC+ gaps. When the user reports drift and claims "same date range," BELIEVE THEM and hunt structural bugs first.

## Diagnostic: `sql-queries/xwoba-parity-diag.sql`
Runs tracker-pattern AND PD-Goals-pattern xwoba side-by-side for HOU. If numer + pa are identical, SQL is aligned and any display drift is in Python post-processing (weight/exponent fetch helpers, aggregation). If numer or pa differ, it's a SQL structural bug — diff the WHERE/CASE/JOINs.

**Run this diag FIRST** when investigating org hitting parity. Saves hours of speculation.

## Reference Docs

- `.claude/rules/three-surface-parity.md` — BLOCKING rules + domain surface map + hitting bug history
- `.claude/rules/woba-rules.md` — wOBA/xwOBA formulas, denom, weights, exponents
- `.claude/rules/multi-level-rollup.md` — per-metric weight reference (catcher + OF/IF + hitting)
- `.claude/rules/db-columns.md` — `ev.pa` / `ev.ibb` / `ev.sh` semantics, PA count vs wOBA denom
- `memory/hitting-org-parity-apr20.md` — full Apr 20 2026 session log, 5 bug classes, open/deferred items
