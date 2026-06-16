---
name: PD Flag Tracker — Live Status + Open Items
description: Current shipping config for the PD Flag Tracker CLI (drift_alert.py). All thresholds, gates, modules, recent changes, and open work as of the last commit on feature/pd-goals.
type: project
originSessionId: 28f6e904-6554-438b-a427-98d7522dcb9f
---
# PD Flag Tracker — Live Status (May 10 2026 evening)

## Worktree + branch
- `bsb-resources` / `feature/pd-goals` (CLI lives in `pd-goals/` subdir)
- Run from work laptop: `python pd-goals/scripts/drift_alert.py ...`

## Two cadences
- **Weekly mode** (default) — L2W (14-day rolling) vs season-to-date for the current season
- **YoY mode** (`--yoy`) — full prior season vs current YTD. Default years: `to_year=current`, `from_year=current-1`. Override with `--from-year YYYY --to-year YYYY` (any two seasons, e.g. 2023 vs 2024 historical comparison)

## Modules (5-file touchpoint pattern)
1. `pd-goals/src/drift_thresholds.py` — config: threshold, direction, volume_gate, higher_better, label, unit, fmt + YOY_VOLUME_OVERRIDES
2. `pd-goals/src/drift_pitching.py` — pitcher SQL + dispatcher
3. `pd-goals/src/drift_hitting.py` — hitter SQL + dispatcher
4. `pd-goals/src/drift_br.py` — BR SQL + dispatcher (NEW May 10 2026)
5. `pd-goals/src/drift_catcher.py` — catcher SQL + dispatcher (NEW May 10 2026, NetK only)
6. `pd-goals/scripts/drift_alert.py` — CLI orchestrator, PDF render, Slack delivery, CSV export

Adding a new metric → touch the threshold config, the domain SQL module's metric_map + SQL, AND the drift_alert glossary entry + (if new domain) section render.

## Roster filter (BLOCKING)
All 14 `active_*` CTEs JOIN `MLB_eBis.PP_MASTER` via Alvaro pattern (`rules/pd-goals.md` Roster filter section). Released/traded players (Willingham, Sanchez) no longer leak. Same filter as KPI weekly Season tables (`kpi-roster-filter.md`).

## Current thresholds (May 10 2026 end-of-day)

### Pitching (`drift_pitching.py`)
| Metric | Threshold | Weekly gate | YoY gate | Direction |
|---|---|---|---|---|
| FB velo (FF/FT/SI pooled) | ±1.0 mph | 30 FB | 100 FB | Up=good |
| FF velo | ±1.0 mph | 20 FFs | 100 FFs | Up=good |
| SL velo | ±1.0 mph | 15 SLs | 50 SLs | Up=good |
| CH velo | ±1.0 mph | 10 CHs | 50 CHs | Up=good |
| K% | ±4 pp | 5 BF | 50 PA | Up=good |
| BB% | ±4 pp | 5 BF | 50 PA | Down=good |
| Release height | ±0.5 ft | 50 pitches | 300 pitches | Mechanical (red) |
| Release side | ±0.5 ft | 50 pitches | 300 pitches | Mechanical (red) |
| Extension | ±0.4 ft | 50 pitches | 300 pitches | Mechanical (red) |
| InZ% overall | ±7 pp | 50 pitches | 300 pitches | Up=good |
| 0-0 InZ% (FPinZ%) | ±7 pp | 10 first pitches | 50 first pitches | Up=good |
| R2K% | ±8 pp | 10 PA-to-pitch-3 | 50 PA-to-pitch-3 | Up=good |
| GB% | ±8 pp | 15 BIP allowed | 50 BIP allowed | Up=good |
| HH% allowed | ±8 pp | 15 BIP allowed | 50 BIP allowed | Down=good |
| Per-PT SRV (FF/FT/SI/SL/FC/CH/CU/FS — 8 metrics) | ±5 grade | 15 of that PT | 50 of that PT | Up=good |
| Per-PT Whf% (same 8) | ±7 pp | 15 swings of that PT | 50 swings | Up=good |
| Per-PT InZ% (same 8) | ±7 pp | 15 of that PT | 50 of that PT | Up=good |

### Hitting (`drift_hitting.py`)
| Metric | Threshold | Weekly gate | YoY gate | Direction |
|---|---|---|---|---|
| Bat speed | ±1.0 mph | 20 swings | 50 swings | Up=good |
| Attack angle | ±3° | 20 swings | 50 swings | Up=good |
| VBA | ±3° | 20 swings | 50 swings | Mechanical (red) |
| Loft | ±5° | 20 swings | 50 swings | Mechanical (red) |
| Tilt | ±5° | 20 swings | 50 swings | Mechanical (red) |
| SwDec | ±10 grade | 20 PA | 100 PA | Up=good |
| Damage% | ±3 pp | 15 BIP | 50 BIP | Up=good |
| gcOBA | ±0.050 | 15 PA | 50 PA | Up=good (YoY deferred) |
| Hitter Whiff% | ±7 pp | 20 swings | 100 swings | Down=good |
| Swing% | ±7 pp | 20 pitches | 300 pitches | Mechanical (red) |
| OSw% (CSC-wtd O-Swing) | ±6 pp | 20 OOZ pitches | 200 OOZ pitches | Down=good |
| PoC (depth in front of plate, in) | ±2.5 in | 20 BIP | 50 BIP | Up=good |

### BR (`drift_br.py`) — NEW May 10 2026
| Metric | Threshold | Weekly gate | YoY gate | Direction |
|---|---|---|---|---|
| 1B PL | **±1.0 ft** (raised from 0.7 May 10 evening) | 10 base-pitches | 50 base-pitches | Up=good |
| 2B PL | **±1.0 ft** | 10 base-pitches | 30 base-pitches | Up=good |

PL cleaning matches canonical `intangibles/src/br_tracker_data.py`:
- LEFT JOIN nbo_2b / nbo_3b for next-base-occupied gate (NOT NOT-EXISTS — SQL error 130)
- 1B PL has fielder ≤ 10 ft gate + 5.0 ft floor (data-cleaning.md §2)
- 2B PL has no fielder gate, no 5.0 ft floor
- NO `runner_going` filter on PL (only on SL/TL which we don't surface in drift)

### Catcher (`drift_catcher.py`) — NEW May 10 2026, NetK only
| Metric | Threshold | Weekly gate | YoY gate | Direction |
|---|---|---|---|---|
| NetK | ±5.0 net strikes | 1500 total pitches | **1500 TOTAL pitches caught** | Up=good |

NetK SQL gates: `pv.called_strike_chance > 0.05 AND < 0.95`, `pitch_result_id IN (4, 5, 6)`, `pv.ignore_flag = 0`, `ev.c_id IS NOT NULL`. Per `gc2-metrics.md` NetK BLOCKING rules. Cumulative SUM, baseline = full from_year.

**Volume gate column = TOTAL pitches caught (`COUNT(*)` of all pitches with that c_id), NOT the edge-pitch subset.** Earlier May 10 versions were gating on edge pitches (~20% of total), which filtered out every real flag candidate. Verified via `sql-queries/netk-diagnostic-2025-vs-2026.sql` — 9 catchers had |delta| ≥ 5 with > 1500 total pitches in 2026 YTD; only one of them had > 500 edge pitches.

Other catcher metrics (Pop2B, AugPop, FramRAA, BlockRAA) stay in the catcher weekly KPI report by design — not duplicated in drift.

## Recent change log (May 10 2026)

1. **Roster filter added** (commit `6873d2c`) — `MLB_eBis.PP_MASTER` JOIN to all 14 active-CTE blocks. Fixed Willingham/Sanchez leak.
2. **drift_br.py + drift_catcher.py shipped** (commit `6873d2c`) — 2 BR metrics + NetK. Plus `feedback_ask_active_roster_filter_first.md` memory rule.
3. **NOT-EXISTS → LEFT JOIN fix** (commit `4f63d44`) — SQL error 130 from first BR run. Mirrored canonical br_tracker_data.py pattern. Plus `feedback_mirror_canonical_br_fielding_patterns.md` memory rule.
4. **PL threshold + NetK gate tuning** — 0.7 → 1.0 ft on both PLs.
5. **NetK gate corrected** (current commit) — gate column was edge-pitch
   count (wrong); now TOTAL pitches caught. Gate restored to 1500. Verified
   via diagnostic that this fires for Schiavone / Janek / Flores / Bush /
   Salazar / Vasquez / Batista / Perez / Collin Price in the next YoY run.

## What lives elsewhere (intentionally NOT in drift)

- **Fielding (IF/OF)**: weekly KPI fielding reports (OF KPI / IF KPI PDFs). Per user direction May 10 — fielding drift has too much small-sample noise at L2W cadence; the weekly KPI L2W vs Season colored cells are the right surface.
- **Other catcher metrics** (Pop2B, AugPop, FramRAA, BlockRAA): weekly KPI catcher report.
- **Hitting gcOBA in YoY**: deferred. Multi-component Python aggregation needs more refactor. Weekly mode computes it normally.

## Open items / next moves

1. **Re-run YoY after this commit** — expect NetK flags to fire (Flores et al). 1B PL flag count should drop with tighter ±1.0 ft threshold.
2. **Connect-scheduled deploy** — drift CLI runs from work laptop today. Next: wire as Connect scheduled content for Sunday/Monday auto-delivery. Pattern in `tracker-parquet-pins.md` §12 handles this.
3. **KPI snapshot review** — user mentioned modifying weekly KPI fielding reports as the fielding-drift surface. Separate workstream, not started.
4. **Tuning** — more real runs will surface threshold-fine-tune needs. Easy retune in `drift_thresholds.py`.

## CLI usage

```bash
# Weekly mode (default)
python pd-goals/scripts/drift_alert.py --week-ending 2026-05-10 --csv out.csv --deliver

# YoY mode (Sam Niedorf intervention-candidate compilation)
python pd-goals/scripts/drift_alert.py --yoy --csv intervention_2026-05-10.csv --deliver

# YoY with explicit years
python pd-goals/scripts/drift_alert.py --yoy --from-year 2024 --to-year 2026 --csv compare.csv

# Dry run (no PDF, no Slack)
python pd-goals/scripts/drift_alert.py --yoy --dry-run
```

CSV columns: `domain, player, level, id, metric, baseline_label, baseline_value, current_label, current_value, current_n, delta, direction, is_good, fmt, unit`. Sortable in Excel; coordinator pastes top rows into meeting notes.
