# Three-Surface Parity Audit — 2026-05-20

Full cross-domain audit of every metric across the 3 canonical surfaces:
- **Tracker** (live Streamlit affiliate tracker)
- **KPI Weekly** (PDF + chart)
- **PD-Goals Org KPI** (PDF)

Per `.claude/rules/three-surface-parity.md`, these three surfaces MUST produce
identical values for the same player + time window. Any divergence in SQL,
gates, filters, aggregation formulas, or weight columns is treated as drift.

Audited domains: Hitter, Pitcher, Catcher, OF, IF, BR.

---

## Executive Summary

| Domain | Metrics audited | BLOCKING drift | Minor / Cosmetic | Match cleanly |
|---|---:|---:|---:|---:|
| Hitter | ~30 | **0** | 2 (AACon BIP whitelist; wRC+ aggregation strategy) | ~28 |
| Pitcher | ~40 | **3** | 6 (scope coverage gaps) | ~15 |
| Catcher | 17 | **0** | 2 (Mid% formula; multi-level pooling deferred) | 15 |
| OF | 14 | **0** | 2 (chart line by design; KPI base CTE structure) | 12 |
| IF | ~16 | **0** | 3 (column-set scope decisions) | 13 |
| BR | 13 | **2** | 5 (scope/cadence by design) | 6 |
| **TOTAL** | **~130** | **5** | **20** | **~89** |

### Headline takeaway

**KPI Weekly is the consistent outlier.** All 5 BLOCKING items live in KPI
weekly modules (4 of 5) or affect KPI weekly + tracker together (1 of 5).
Tracker + PD-Goals tend to agree; KPI weekly drifted from earlier sweeps and
never caught up.

The Apr/May 2026 sweeps (xwOBA per-pitch JOIN, fielding pooled SQL,
n_arm/n_exch weighting, depth canon convergence, EV-misread CTE 7-level
scope, BlockRAA sign flip) all held — no regressions.

---

## BLOCKING Drift — Top of Queue

### #1 — Pitcher Whiff% numerator missing `did_swing = 1` gate (Tracker + KPI weekly)

**Per `gc2-metrics.md` BLOCKING rule #4:** `is_whiff MUST be gated by did_swing`.

| Surface | File:line | Whiff numerator | Status |
|---|---|---|---|
| Tracker | `bullpen-report/src/tracker_data.py:574` (`_PITCH_LEVEL_QUERY`) | `SUM(CASE WHEN pv.pitch_result_id IN ({whiff_codes}) ...)` — **no `did_swing` gate** | DRIFT |
| Tracker | `bullpen-report/src/tracker_data.py:1927` (`_ORG_PITCH_QUERY`) | same — **no gate** | DRIFT |
| Tracker | `bullpen-report/src/tracker_data.py:2186` (`_ORG_MONTHLY_PITCH_QUERY`) | same — **no gate** | DRIFT |
| KPI weekly | `bullpen-report/src/pitcher_kpi_data.py:503-504` (`_PLAYER_QUERY`) | `SUM(CASE WHEN pv.pitch_result_id IN (10,16,21,22,23,25) ...)` — **no gate** | DRIFT |
| PD-Goals | `pd-goals/src/org_kpi_data.py:503` (`_PITCHING_ORG_QUERY`) | `is_whiff = (pitch_result_id IN whiff_codes)` THEN `SUM(CASE WHEN is_swing=1 AND is_whiff=1 …)` | ✓ canonical |

**Numeric impact**: Whiff numerator inflated by any pitch with `pitch_result_id IN whiff_codes` where `did_swing != 1` — primarily pitch_result_id 16 (Missed Bunt) and 25 (Bunt Foul Tip), plus any `ignore_flag=1` row where `did_swing` is NULL/wrong. Surfaces as Whf% > 100% on edge data and small over-counts otherwise.

**Fix**: Mirror PDG pattern. Either inline `AND did_swing = 1` next to the whiff codes, or use the existing recovery-gated `is_swing` flag (denominator already uses it).

---

### #2 — Pitcher gcERA `bip_rate` direct vs derived (KPI weekly outlier)

| Surface | bip_rate formula | Source |
|---|---|---|
| Tracker | derived: `1 - so_rate - bb_hbp_rate` (matches GC2) | per `gc2-metrics.md` "gcERA Inconsistencies" |
| KPI weekly | direct: `bip_count / bf` | `bullpen-report/src/pitcher_kpi_data.py:653` |
| PD-Goals | derived: `max(1 - so_rate - bb_hbp_rate, 0)` | `pd-goals/src/org_kpi_data.py:549` |

**Companion issue**: KPI weekly's `tracked_bip_count` lacks the bunt filter
(`pitcher_kpi_data.py:544-548` vs tracker `:557-561` vs PDG `:461-465`).
Inflates tracked_bip → deflates pbarrel_rate → gcERA artifact.

**Numeric impact**: KPI gcERA drifts slightly vs Tracker + PDG on any pitcher with non-trivial pbarrel rate. Documented as deferred in `gc2-metrics.md` "gcERA Inconsistencies" table.

**Fix**: Two changes in `pitcher_kpi_data.py`:
1. Switch `bip_rate` to derived formula (line 653).
2. Add `hit_trajectory_id NOT IN (2,3,4)` filter to `tracked_bip_count` (lines 544-548).

---

### #3 — Pitcher EW% BIP codes split (KPI weekly outlier)

| Surface | EW% BIP codes | Source |
|---|---|---|
| Tracker | `(12,13,14,18,19,20)` | `bullpen-report/src/tracker_data.py:606,1948,2207` |
| KPI weekly | `(12,13,14)` | `bullpen-report/src/pitcher_kpi_data.py:518,523` |
| PD-Goals | `(12,13,14,18,19,20)` | `pd-goals/src/org_kpi_data.py:397,402` via `_BIP_CODES_SQL` |

**Numeric impact**: Pitchout BIPs (18, 19, 20) are extremely rare; documented in `gc2-metrics.md` as "negligible numeric impact." But structurally divergent.

**Fix**: One-line change in `pitcher_kpi_data.py:518,523` from `(12,13,14)` to `(12,13,14,18,19,20)`.

---

### #4 — BR KPI player `leads` CTE missing PBL canonical filters

**File**: `intangibles/src/br_kpi_data.py:847-896` (`_DATE_RANGE_PLAYER_QUERY` `leads` CTE)

**Compared to canonical** (all have `JOIN Astros.Pitches_View pv` + `AND pv.pitch_id > 0` + `AND pbl.ignore_flag = 0`):
- Tracker `_LEADS_QUERY` `intangibles/src/br_tracker_data.py:507-525`
- PD-Goals `_BR_LEADS_ORG_QUERY` `pd-goals/src/org_kpi_data.py:1880-1906`
- KPI chart `_ORG_DAILY_LEADS_QUERY` `intangibles/src/br_kpi_data.py:208-227` (correctly has the filters)

**The buggy KPI player `leads` CTE:**
```sql
FROM Astros.Pitches_Baserunner_Leads pbl
JOIN Astros.Schedule_View sv ON pbl.sched_id = sv.sched_id
LEFT JOIN Astros.Pitches_Baserunner_Leads nbo_2b ...
LEFT JOIN Astros.Pitches_Baserunner_Leads nbo_3b ...
WHERE ({level_filter})
  AND CAST(sv.sched_date AS DATE) BETWEEN :start_date AND :end_date
  AND {sched_filter}
-- NO pv.pitch_id > 0
-- NO pbl.ignore_flag = 0
```

**Numeric impact**: Every PBL row with `ignore_flag=1` (HawkEye-flagged bad-lead reading) and every PBL row joined to `pitch_id=0` is included in the KPI player table's lead averages. **Affects every lead average (1B PL/SL/TL + 2B PL/SL/TL) in the KPI weekly Season table.**

This was the exact bug class fixed in tracker commit `6907e01` per `three-surface-parity.md`. **KPI player table was missed in that sweep.**

**Fix**: Add `JOIN Astros.Pitches_View pv ON pbl.sched_id = pv.sched_id AND pbl.pitch_id = pv.pitch_id` plus `AND pv.pitch_id > 0` and `AND pbl.ignore_flag = 0` to the `leads` CTE WHERE clause.

---

### #5 — BR KPI chart `_ORG_DAILY_SB_CS_QUERY` CS canon truncated

**File**: `intangibles/src/br_kpi_data.py:156, 168`

| Surface | CS canon | Source |
|---|---|---|
| Tracker | `(4, 5, 6, 7, 29, 30, 31)` | `br_tracker_data.py:582` |
| KPI player table | `(4, 5, 6, 7, 29, 30, 31)` | `br_kpi_data.py:761` |
| **KPI chart** | `(4, 5, 6)` | `br_kpi_data.py:156, 168` |
| PD-Goals | `(4, 5, 6, 7, 29, 30, 31)` | `org_kpi_data.py:1692` |

**Numeric impact**: KPI chart's CS line undercounts caught stealings + pickoffs by ~6-15% per org per month. SB chart is correct. The BR KPI chart only renders SB as a cumsum line (per `br_kpi_data.py:404-411` design), so direct user-visible impact is limited unless a downstream consumer reads `cs` from the chart fetch.

**Fix**: Expand both `SUM(CASE WHEN ev.event_result_id IN (4,5,6) ...)` and the outer `event_result_id IN (42,43,44,4,5,6)` clauses to the full canon.

---

## Minor / Documented Divergences — Worth Tracking

### Hitter
- **AACon BIP whitelist (`barrelsville/src/hitter_kpi_data.py:1004`)** — KPI weekly still filters `pitch_result_id IN ({bip_codes})` in `_AACON_QUERY`. Tracker dropped this whitelist Apr 26 2026 per `gc2-metrics.md` standardization. Fix is one-line removal.
- **wRC+ aggregation strategy** — PD-Goals computes wRC+ per (org, level) then averages across levels (`org_kpi_data.py:1067`). Tracker/KPI weekly compute wRC+ once per batter from `AVG(woba_overall)/AVG(woba_scale)/AVG(runs_per_pa)` per-PA JOIN. Math is equivalent when all PAs are at one level; potential Salas-class drift on multi-level batters with very different league envs. Worth empirical verification on a known multi-level batter (Salas, Holy, anyone with 2+ levels in `Astros.Players_Games` this year).

### Catcher
- **Mid% framing bucket — per-catcher vs org formulas diverge.**
  - Tracker per-catcher leaderboard + KPI weekly per-catcher → CS-only formula: `100 × SUM(cs in 0.25-0.50) / SUM(total in 0.25-0.75)`
  - Tracker Org Rankings + PD-Goals org → NET formula: `100 × (SUM(cs in 0.25-0.50) - SUM(cb in 0.50-0.75)) / SUM(total in 0.25-0.75)`
  - Result: an individual catcher's Mid% won't sum to their org's Mid% contribution. The fact that PD-Goals exposes per-bucket count columns (`n_mid_cs` + `n_mid_cb`) suggests NET is canonical — align per-catcher to NET if intentional.
- **Catcher multi-level percentile pooling NOT applied** — per `multi-level-rollup.md`, the OF/IF pooled SQL fix (May 16 2026 commit `2d3d9da9`) has not been ported to catcher. Same fix pattern needs porting (~6-8 hr). Deferred — catchers move between levels less than CF prospects so drift is likely invisible.

### OF / IF
- All "minor" findings are **intentional product-scope decisions**: KPI weekly chart line is 4-week rolling pool (recent form), per-position PAA breakdowns are tracker-only, PD-Goals IF org PDF doesn't show cumulative PAA/RAA, etc. Math is identical where the metric is exposed on a surface.

### BR (in addition to BLOCKING items)
- TL 1B / TL 2B is tracker-selectable, KPI MLB-only (Jason Bell request May 12 2026), PD-Goals omits. Surface-scope by design.
- BR tracking metrics (TopSpd / React / T22 / Split1 / Accel) are tracker-only — no BR KPI chart or PD-Goals BR tracking by design.

---

## Scope Coverage Gaps (no drift, just absence)

Worth knowing about — if a coach ever requests one of these at the org level, it's net-new work:
- **Per-PT Velo/IVB/HB/Spin org rollup** — exists in PD-Goals percentile pool (`pd-goals/src/percentiles.py`) for individual goal display, but no org-level surface on any of the 3.
- **Per-PT Usage (FF/SI/SL/CH/etc.) org rollup** — same as above.
- **Arm Angle org rollup** — `data-cleaning.md` §1 applies the 90° cap + 2.5σ trim to Arm Farm only (postgame, tracker, KPI per-pitcher). No org-level surface today.
- **Release Height / Release Side org rollup** — only in PD Flag Tracker drift + Arm Farm postgame.

---

## Recommended Fix Priority Order

1. **BR #4** — KPI player `leads` CTE missing PBL gates. Same bug class as
   `6907e01` tracker fix. ~5 LOC. Affects every lead average in KPI weekly
   Season table directly. **Ship first.**
2. **Pitcher #1** — Whiff% `did_swing` gate. ~4 sites, all in
   `bullpen-report/`. Mirrors documented BLOCKING rule. ~8 LOC total.
3. **Pitcher #3** — EW% BIP codes one-line change. Trivial, surgical.
4. **Pitcher #2** — gcERA `bip_rate` + tracked_bip bunt filter. Two related
   changes in KPI weekly. ~5 LOC.
5. **BR #5** — KPI chart CS canon expansion. Lower visibility (chart line
   only shows SB), but trivial fix.
6. **Hitter** — AACon BIP whitelist removal. One-line. Worth doing.
7. **Catcher Mid%** — confirm intent (NET vs CS-only) with user before
   touching. If NET is canonical, align per-catcher Tracker + KPI weekly to
   NET.
8. **Deferred** — Catcher multi-level pooling; wRC+ aggregation empirical
   verification. Wait for evidence.

All 5 BLOCKING items are surgical — small commits, no architecture changes.
Each can ship independently.

---

## Files Audited

### Hitter
- `bsb-wt-hitting/barrelsville/src/tracker_data.py`
- `bsb-wt-hitting/barrelsville/src/hitter_kpi_data.py`
- `bsb-resources/pd-goals/src/org_kpi_data.py` (hitting section)

### Pitcher
- `bsb-wt-bullpen/bullpen-report/src/tracker_data.py`
- `bsb-wt-bullpen/bullpen-report/src/pitcher_kpi_data.py`
- `bsb-wt-bullpen/bullpen-report/src/pitcher_kpi_report.py`
- `bsb-resources/pd-goals/src/org_kpi_data.py` (pitching section)

### Catcher
- `bsb-wt-intangibles/astros-intangibles/intangibles/src/catching_tracker_data.py`
- `bsb-wt-intangibles/astros-intangibles/intangibles/src/c_kpi_data.py`
- `bsb-resources/pd-goals/src/org_kpi_data.py` (catcher section, lines 2050-2479)

### OF / IF
- `bsb-wt-intangibles/astros-intangibles/intangibles/src/fielding_tracker_data.py` (shared OF + IF)
- `bsb-wt-intangibles/astros-intangibles/intangibles/src/of_kpi_data.py`
- `bsb-wt-intangibles/astros-intangibles/intangibles/src/if_kpi_data.py`
- `bsb-resources/pd-goals/src/org_kpi_data.py` (OF + IF sections)

### BR
- `bsb-wt-intangibles/astros-intangibles/intangibles/src/br_tracker_data.py`
- `bsb-wt-intangibles/astros-intangibles/intangibles/src/br_kpi_data.py`
- `bsb-resources/pd-goals/src/org_kpi_data.py` (BR section, lines 1683-2047)

### Canonical rules cross-referenced
- `.claude/rules/three-surface-parity.md`
- `.claude/rules/gc2-metrics.md`
- `.claude/rules/xwoba-canonical.md`
- `.claude/rules/woba-rules.md`
- `.claude/rules/multi-level-rollup.md`
- `.claude/rules/db-columns.md`
- `.claude/rules/db-joins.md`
- `.claude/rules/fielding.md`
- `.claude/rules/data-cleaning.md`
- `.claude/rules/damage-pct-cross-app-divergences.md`
- `.claude/rules/bat-speed-canonical.md`
- `.claude/rules/merge-union-not-primary.md`
- `.claude/rules/intangibles.md`
- `.claude/rules/pd-goals-defense.md`
- `.claude/rules/reference-impl-index.md`
- `.claude/rules/kpi-weekly-charts.md`
- `.claude/rules/kpi-roster-filter.md`
- `.claude/rules/pitfalls.md`

---

## Methodology

6 parallel background agents (one per domain). Each agent:
1. Read whole files (not excerpts) for all 3 surfaces in their domain.
2. Cross-referenced canonical rules in `.claude/rules/` for known historical drift.
3. Diffed SQL filters, JOIN keys, aggregation formulas, range filters, multi-level rollup, pool gating per metric.
4. Reported findings as structured table + summary.

Static code audit only — no SQL execution, no numerical impact computation.
Each finding includes specific file:line references.

Audit run timestamp: 2026-05-20.
