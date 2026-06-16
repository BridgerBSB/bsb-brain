---
paths:
  - "pd-goals/**/*"
---

# PD Goals + PD Engine — App Family

## Purpose
PD Engine is the umbrella Streamlit multipage app at `pd-goals/`. Three Streamlit features shipped so far + one CLI sibling:

1. **PD Goals** (LIVE since Apr 10, 2026) — tracks 6-week player development goals for MiLB players with percentile-ranked stats + per-player PDF reports.
2. **Transition Report** (LIVE since Apr 24, 2026) — questionnaire-style form for documenting when players move between levels. Submissions persist to a parquet pin; PDFs deliver to Slack in-app on submit. See §"Transition Report — Card 2" below.
3. **WPA Plays** (LIVE since Apr 25, 2026) — daily top/bottom win-probability swings per affiliate game with click-to-video on every play. Streamlit presentation layer over the existing CLI/PDF pipeline (no data divergence). See §"WPA Plays — Card 3" below.
4. **PD Flag Tracker** (CLI LIVE since Apr 26, 2026 — IN ITERATION) — weekly/L2W drift report comparing each HOU MiLB player's recent metrics to their season-to-date baseline; PDF delivered to Slack via Logic App. CLI-only today; **planned to become an app page (e.g. `pages/5_PD_Flag_Tracker.py`) once the threshold round stabilizes.** See §"PD Flag Tracker — CLI Sibling" below.

**Streamlit page convention (BLOCKING):** PDF-generation block goes LAST in any page script. See `.claude/rules/pdf-last-in-script.md`. Reference impl: `barrelsville/pages/5_KPI_Report.py:437` (canonical across the codebase).

**LIVE on Posit Connect.** App GUID: `79f52369-8244-46da-a4d6-95df956bacad`

## Key Files
- `pd-goals/PD_Engine.py` — Landing page (card nav, matches Barrelsville/Arm Farm pattern)
- `pd-goals/pages/1_PD_Goals.py` — Streamlit dashboard (formerly app.py)
- `pd-goals/src/report.py` — PDF report generation
- `pd-goals/src/goal_parser.py` — Parses goal text like "K% > 28%"
- `pd-goals/src/stats.py` — Stat calculations (audited against GC production SQL)
- `pd-goals/src/metrics.py` — Metric definitions (Damage, pBarrel formulas)
- `pd-goals/src/percentiles.py` — League-wide percentile engine (8 groups)
- `pd-goals/src/database.py` — DB connection + `SCHED_TYPES` config
- `pd-goals/src/roster.py` — Roster queries
- `pd-goals/src/pins_config.py` — Posit Connect pins board connection + SSL workaround
- `pd-goals/src/goals_loader.py` — `load_goals_df()` (pin → CSV fallback) + `pin_write_goals()`
- `pd-goals/scripts/pin_goals.py` — CLI to push goals.csv to Connect as parquet pin
- `pd-goals/data/goals.csv` — PRODUCTION goals (persists to disk, also pinned to Connect)
- `pd-goals/data/slack_channels.csv` — Channel mapping for Slack delivery (also used by ALL projects for player ID lookups). **Cross-worktree sync is BLOCKING — see `slack-channels-sync.md`.**
- `pd-goals/PRD.md` — Full product requirements document


## Transition Report — Card 2 (LIVE Apr 24, 2026)

**Moved to `rules/pd-goals-transition.md`** to slim this file. Card 2 on
PD Engine landing, questionnaire app for player level moves. Architecture
= the `in-app-submission.md` reusable pattern (read that first when
making changes).

Quick pointers:
- Files: 8 modules under `pd-goals/src/transition_*.py` + `pages/2_Transition.py` + `pages/3_Transitions_View.py`
- Pins: `zbridger/transition_reports` (submissions) + `zbridger/transition_drafts`
- BLOCKING: deferred-load pattern for widget-key state (§5 in-app-submission.md)
- Pitcher variant LIVE May 3 2026 — `report_type` column splits position vs pitcher question blocks

## Goal Compliance — Tab (LIVE May 21 2026)

Second tab on the PD Goals page (`pages/1_PD_Goals.py`, `tab_compliance`).
Org compliance matrix (left) + Individual Compliance table (right) for
currently-rostered HOU players. Compliance% = (# measurable goals met) ÷
(# measurable goals).

### Key files
- `pd-goals/src/compliance.py` — `compute_compliance` (live SQL) + `try_load_pinned_compliance` + `_aggregate_from_detail` + `attach_pin_meta`
- `pd-goals/scripts/pin_compliance.py` — pin CLI (`--season --start --end`)
- `pd-goals/connect_pins_compliance/` — Connect-scheduled bundle (6h refresh)
- Pin name: `zbridger/pd_compliance_<season>` (single parquet detail table)

### Behavior invariants (BLOCKING)
1. **Decoupled from the sidebar date selector** (May 22 2026). Each player
   is evaluated over THEIR OWN goal window from goals.csv, not the page's
   date picker.
2. **Roster-driven.** The player universe is the CURRENT roster
   (`get_roster()` / PP_MASTER). Released players drop off automatically —
   correct for "now," but it's why a *historical* view (below) can't reuse
   this path.
3. **Pin-only read on the page.** No live 3-8 min fallback on auto-load;
   empty-state diagnostic shows on a pin miss. Rebuild via
   `pin_compliance.py`; Connect refreshes every 6h.
4. **Goal selection is date-aware** (Jun 2026, was `gp.iloc[0]`). When a
   player has multiple goal rows, pick the one with the **latest
   `start_date` that has started** (`<= today`). Blank `start_date` counts
   as started; future-dated rows excluded; fall back to first row if none
   qualify. `end_date` is **ignored for selection** so a closed period
   keeps showing until a newer one supersedes it (matches the batch-PDF
   most-recent-period fallback in `pd-goals-batch-always-fallback.md`).
5. **Evaluation window respects `end_date`.** Selection ignores end_date,
   but the metric-fetch window is `start_date → end_date` (frozen, closed
   period) or `start_date → today` (rolling, blank end_date). Fallbacks:
   start → Jan 1 of season, end → today (pin-build date).
6. Each detail row carries `goal_start` / `goal_end` (raw CSV dates of the
   selected row) → surfaced as Start/End columns on the Individual table +
   CSV. Page guards for old pins lacking these columns.

### Individual Compliance table — toggle + CSV (Jun 2026)
All / P / H segmented toggle filters ONLY that table (Org matrix untouched);
maps to the raw `type` codes (`P`/`H`). Save CSV download exports exactly the
on-screen columns for the current toggle. Subjective goals show BLANK
Current/Target (not an em-dash) in both table and CSV.

### DATA RETENTION CONVENTION (BLOCKING — Jun 5 2026 user direction)
**Do NOT delete old goal rows from goals.csv when a new goal period
starts.** Append the new period as a new row (same `groundcontrol_id`,
new `start_date`/`end_date`); keep the old row with its dates intact. The
date-aware selection (#4) automatically picks the current period, so old
rows are inert for "now" but preserve the history needed for the planned
historical-compliance feature. Deleting old rows permanently loses the
ability to look back at a closed period. Released players also stay on the
sheet — their rows persist even after they drop off the roster.

### PLANNED NEXT FEATURE — Historical / former-period compliance
Not built yet. Lets a user view a CLOSED goal period instead of just the
current one. Requires: (a) the retention convention above (keep old rows),
(b) a period picker on the tab, (c) selection targeting the chosen period,
(d) a goals.csv-driven player universe for that period (so released players
who were rostered then still appear — can't use the current-roster path).
Spec: `pd-goals/docs/plans/2026-06-05-historical-compliance-design.md`.
Don't build until there are real multi-period rows to look back on.

## Defense Matrix — Page 7 (LIVE May 19, 2026)

HOU MiLB defender matrix on PD Engine. One row per currently-rostered
HOU MiLB defender (per `PP_MASTER`), columns for each position (1B-RF
PAA/EO + C cumulative NetK), cross-level stat aggregation per player.

Streamlit version of the PDF the user signed off on May 15 2026
(`intangibles/scripts/generate_paa_eo_matrix.py`).

### Files

| Role | File |
|---|---|
| Page | `pd-goals/pages/7_Defense_Matrix.py` |
| Data layer (live SQL) | `pd-goals/src/paa_eo_matrix_data.py` |
| Pin write CLI | `pd-goals/scripts/pin_defense_matrix.py` |
| Connect-scheduled bundle | `pd-goals/connect_pins_defense/` |
| Pin board helper | `pd-goals/src/pins_config.py::defense_matrix_pin(season)` |

### Pin

`zbridger/defense_matrix_<season>` (parquet). One pin per season.
Contains the matrix value columns + parallel `<col>_pctile` columns
(0-100) per metric. App reads pin first, falls back to live SQL on miss.

Refreshed every 6h on Connect by `pd-engine-pin-defense-matrix-2026`
(content GUID `bdecc4c2-4b6f-4536-927e-eb49ab32f258`). Historical
years (2022-2025) pinned once from work laptop via
`python pd-goals/scripts/pin_defense_matrix.py --all` — frozen, no
scheduled refresh.

### Why a dedicated pin (NOT the existing tracker pins)

The intangibles fielding tracker pin (`intangibles_of_tracker_<season>`,
`_if_*`) DOES have `paa_cal_<pos>` per position. But it does NOT have
`expected_outs_<pos>` per position — only one aggregate `expected_outs`
across all positions a fielder played. PAA/EO cross-level requires
`SUM(paa_cal_<pos>) / SUM(expected_outs_<pos>)` per position, so we
can't reconstruct from the tracker pin alone. The earlier hybrid loader
(May 17 night) tried pin + live `expected_outs` and broke; replaced
with a single dedicated pin May 19.

Future: if `expected_outs_<pos>` ever gets added to the fielding
tracker pin SQL (separate planned work), the dedicated pin becomes
redundant and can be retired.

### Percentile coloring

Each metric cell colored red→white→green via the canonical
`pctile_to_color` scheme (`visual-standards.md`). Percentile rank is
vs the all-30-orgs pool at the player's **current** PP_MASTER level —
so a player who played 1B at AA and is now AAA-rostered is colored vs
the AAA 1B pool. Same convention the PDF uses (rules graduation log
2026-05-15 §"per-row coloring against player's current-level pool").

Pool queries: `get_fielding_paa_eo_pool(season, level_code)` per of
6 MiLB levels × 7 positions + `get_catcher_netk_pool(season,
level_code)` per of 6 levels. 12 pool SQLs per season, ~80s total
build (sum with matrix build + roster query).

### NaN sentinel for click-sort (BLOCKING — May 19 2026)

Streamlit's `st.dataframe` underlying renderer (glide-data-grid) sorts
null/NaN values inconsistently — they SCATTER through the rows when
the user clicks a column header. Fix: replace NaN with `-1e9` sentinel
in the display DataFrame's metric columns BEFORE handing to
`st.dataframe`. Custom formatters detect the sentinel via
`v <= -1e8` and render `—`. Click-sort descending: sentinels pile at
the bottom. Ascending: pile at the top. Never in the middle.

Underlying `matrix` DataFrame stays NaN — only the rendered `display`
copy gets the sentinel. Percentile-color lookup reads the source
matrix's `<col>_pctile` (still NaN for blank cells) so coloring is
unaffected — blank cells render with no background.

See `pages/7_Defense_Matrix.py::_fmt_paa` + `_fmt_netk` for the
canonical formatter pattern.

### Cross-references

- `rules/tracker-parquet-pins.md` §5.16 — STUB `src/__init__.py` in
  the deploy bundle (project's real `__init__.py` re-exports from
  `goal_parser` which the pin job doesn't need)
- `rules/tracker-parquet-pins.md` §5.17 — pyarrow required for
  `type="parquet"` pin writes (joblib tracker pins don't need it;
  single-DataFrame parquet pins do)
- `rules/tracker-parquet-pins.md` §5.15 — deploy bundle import-graph
  audit (`audit_pin_deploy.py`)
- `intangibles/src/paa_eo_matrix_data.py` — the PDF's data layer; the
  pd-goals copy mirrors it but inlines the NetK SQL to avoid the
  cross-worktree `catching_tracker_data` import (per
  `feedback_no_cross_worktree_imports.md`).

### What NOT to do

- Don't try to reuse the intangibles fielding tracker pin's
  `paa_cal_<pos>` columns alone — missing `expected_outs_<pos>` makes
  cross-level PAA/EO unreconstructable. The dedicated pin is the
  right shape.
- Don't drop the NaN sentinel — click-sort NaN-in-middle is the bug
  that triggered May 19 ship-day fix.
- Don't refresh historical years (2022-2025) on the Connect schedule.
  Only `--season 2026` refreshes there; historical pins are frozen and
  only re-pin manually if you want to refresh `current_level` (changes
  when players retire / move orgs).
- Don't bundle `src/__init__.py` from the project (re-exports
  `goal_parser`). The deploy.ps1 ships a STUB. See §5.16 in
  tracker-parquet-pins.md.
- Don't write the pin without `pyarrow` in requirements. See §5.17.

## Posit Connect Pin — Shared Goals Data Layer (Apr 14, 2026)

Goals CSV is pinned to `zbridger/pd_goals_data` on connect2.astros.com as parquet. All load points in this app try the pin first, fall back to local CSV. Arm Farm postgame also reads from this pin for "Player Plan Goals" section.

**Pin workflow:** Edit goals.csv → push to branch → work laptop: `python scripts/pin_goals.py` → all apps see new goals immediately (no redeploy).

**5 load points in this app all use `goals_loader.load_goals_df()`:**
1. `pages/1_PD_Goals.py` — session state init (with hardened CSV fallback)
2. `pages/1_PD_Goals.py` — CSV upload (also writes to pin via `pin_write_goals()`)
3. `src/report.py` — `load_goals_csv()`
4. `generate_reports.py` — `load_goals()`
5. `scripts/generate_goals_batch.py` — batch report generation

**Env var required:** `CONNECT_API_KEY` — set in Connect UI → Vars tab per app, or in PowerShell session for CLI scripts.

## Tech Stack
- Python 3.11+, Streamlit, matplotlib, reportlab, pandas
- Database: SQL Server (GCSQL02.ASTROS.COM → GroundControl2)
- Hosting: Posit Connect (connect2.astros.com)

## Percentile Engine
- 8 groups, Astros tables
- Stats audited against GC production SQL

## Level — BLOCKING RULES

1. **CSV level column is IRRELEVANT.** Ignore it. Players get promoted/demoted — CSV is stale.
2. **Player's actual level comes from the DB (roster/schedule).** Shown in the app sidebar.
3. **Stat queries have NO level filter.** All games in the time period count, regardless of level.
4. **Percentile pool uses the player's actual level.** Season-long distribution at THAT level.
5. **NEVER use `get_primary_level()` or any dynamic "where did they have the most PAs" logic.** That cuts off valid goal data.

## Percentile Pools — Season-Long, Per-Level

Build ONE season-long distribution per level. Player's time-period value ranks against it.
NO separate pools per time period — always full season pool at the player's actual level.
Pool-size floor is **5 players** (lowered from 10 on Apr 20, 2026) — fewer than 5 qualified
pool entries → percentile returns None (bar value + target still display).

### Pool Minimums — Complete Reference (Updated Apr 20 2026)

Full domain/gate table in `pd-goals/src/percentiles.py`. Summary by metric family:

**Hitter pools:**

| Metric(s) | Source | Per-player gate |
|---|---|---|
| K%, BB%, SLG | `MLBAM.SplitsBat` | 50 PA (`ab+bb+hbp+sf >= 50`), per level+sit_code |
| Chase%, OSw%, ZSw%, ZCon%, OCtct%, ZWhiff%, Whiff%, Contact%, Zone% | `Pitches_View` | 200 pitches ⚠️ |
| Heart Swing% | `Pitches_View` + `mlbam.players` | 50 heart-zone pitches, **per-batter ABS geometry** |
| Damage, Barrel%, Top50EV | `Astros.Hits` | 30 BIP |
| Hard%, Avg EV | `Astros.Hits` | per query defaults |
| Bat Speed | `swing_contact_values` via `tracking.plays` | 20 contact rows (BIP + fouls + foul tips) + 90% comp + 57 mph floor + 2.5σ; **no upper cap** |
| Zswing 0-0, Oswing 0-0 / 2K | `Pitches_View` | 20 pitches in that count |
| Swing Decision (SwDec) | **`ppg.swing_decision`** from `Projections_Pitches_Grades` | 200 pitches |
| Stolen Bases | `Events_View` event_result_id | 50 times on base |

**Pitcher pools:**

| Metric(s) | Source | Per-player gate |
|---|---|---|
| K%, BB% (pitcher) | `Pitches_View` | 200 pitches ⚠️ |
| Whiff%, Chase%, OSw%, ZSw% | `Pitches_View` | 200 pitches |
| Zone%, InZ%, FPinZ%, FPS%, CSW%, R2K% | `Pitches_View` | 200 pitches |
| FF Velo/IVB/Spin/Ext | `Pitches_View` | 100 FFs |
| FT IVB/HB, FC IVB/HB, SL IVB/HB | `Pitches_View` | 100 of that pitch |
| SL Velo/Spin, CH Velo | `Pitches_View` | 100 of that pitch |
| Split Velo (FS only, matches stats.py) | `Pitches_View` | 100 splitters |
| Stuff Grade | `Pitches_View` (`stuffrelvel_grade_2080`) | 200 pitches |
| Proj Grade (overall) | `Projections_Pitches_Grades.fb_grade` | 300 graded pitches |
| 2K Proj | same, `strikes_before=2 AND balls_before!=3` | 100 graded 2K pitches |
| FB Usage | `Pitches_View` | 300 total pitches (FB is universal) |
| FF Usage (Pre-2K), FC Usage (Pre-2K) | `Pitches_View`, `strikes_before<2` | 50 of that pitch in Pre-2K |
| SL Usage (overall), Split Usage (FS+ST overall) | `Pitches_View` | 100 of that pitch |
| CH Usage (2K / Even), SL Usage (2K) | `Pitches_View`, count-gated | 50 of that pitch in that count state |

**Fielding pools (OF + IF):**

All scoped by `position_category` (goal-text-driven via `_extract_position_override`).
Gate = 10 Tier 1 plays per fielder (6-term OR: DCBP.om + DCBP.CP + DCBP.CT + TDM.CP +
TDM.CT + (arm ≥ floor) > 0).

| Metric | Aggregation | Arm floor | Pool scope |
|---|---|---|---|
| TopSpd | P95, cap at 34 | — | IF or OF |
| AccelCU, AccelCD | P75 | — | IF or OF |
| React, ReactRad | P25 | — | IF or OF |
| UseReact | P25 | — | **OF only** |
| ReactAccRad | P25 | — | **IF only** |
| Arm (OF) | P99 | 60-100 mph | OF (pos 7/8/9) |
| Arm (IF) | P99 | 60-94 mph | IF (pos 3/4/5/6) |
| Exch (OF) | P10 | exchange ≥ 0.4, arm ≥ 60 | OF |
| Exch (IF) | P10 | exchange_dp ≥ 0.4, arm ≥ 60 | IF |
| **PAA/EO** | per-fielder ratio `SUM(paa)/SUM(out_prob) - AVG(offset)` | 70 IF / 75 OF | goal-text scope (1B/2B/3B/SS/LF/CF/RF or INF/OF) |
| **Routine Conversion** | per-fielder `AVG(out_made) * 100` over Tier 3 routine plays (`out_prob > 0.90`) | 70 IF / 75 OF | same as PAA/EO |

**Catcher pools:**

| Metric(s) | Source | Per-player gate |
|---|---|---|
| Frame650 | `CatcherDefense_Framing` weighted avg | 500 qualifying pitches |
| NetK | `Pitches_View` `SUM(net_k)`, called strikes CSC 0.05-0.95 | 500 edge pitches |
| Block650 | `CatcherDefense_Blocking` `7560*SUM(r)/SUM(np)` | SUM(np)>0, 500 pitches |
| Pop Time, Exch Time (catcher) | `CatcherDefense_Throwing` | value >0 |

⚠️ **Deferred:** 200-pitch hitter/pitcher Pitchfx pool gate diverges from SplitsBat's 50 PA.
See `memory/pd_goals_pool_gates_future.md` and inline TODO in
`_get_pitchfx_distribution`. Edge case — aggressive early-count swingers could clear 50 PA
but not 200 pitches.

### Player Minimum — NONE (PD Goals exclusive)

**The player has NO minimum sample size to show a percentile.** Even with 1 PA or 1 play,
their value gets ranked against the full pool. This is a PD Goals-specific rule — other apps
(KPI, tracker, postgame) have their own player-side minimums.

**Why:** PD Goals tracks 6-week development periods. Players may have small samples early in
a period. Showing their percentile (even unstable) is more useful than hiding it. The pool
quality is maintained by the pool minimums above — the distribution is always built from
qualified players with sufficient sample. The individual player just ranks against it.

**Other apps differ:**
- KPI reports: `min_obs=1` for individual display, `n>=3` per metric for pool entry
- Tracker/Snapshot: per-pitch rate metrics, season pool gates
- Weekly individual (OF/IF): `min_obs=1` for player bars
- **PD Goals: NO player minimum, ALWAYS show percentile if value exists**

## Display Formatting

- **Fielding play rates** (Routine Conversion, difficulty buckets): display as `95.5%` (one decimal, percent sign). NOT `0.95`, `95`, or `1.0`.
- **Age:** NEVER round up, one decimal. `FLOOR(DATEDIFF(day,...) * 10.0 / 365.25) / 10.0` — matches all apps.
- **Damage:** Percentage format (`4.0%` not `.040`). Stored as decimal, displayed × 100.
- **Fielding tracking** (React, UseReact, ReactRad, ReactAccRad, Exchange): `.000` format (3 decimals).
- **PAA/EO:** `.000` format (3 decimals).
- **IVB/HB (pitch shape):** `12.3"` format (1 decimal + inches suffix). Raw inches, no percentile.
- **Stolen bases grey text:** "bases on" (not "SB" or "bases").
- **Subjective/descriptive goals:** NO grey sample size text. Skip `format_sample_size()` entirely.

## Grey Sample Size Text — BLOCKING RULES

1. **NO fallback.** If a metric doesn't have a dedicated branch in `get_threshold_counts()`, grey text is empty — NOT "0 PA" or "0 P". The fallback was deleted (Apr 7 bug fix).
2. **Single source of truth.** Each query branch sets its own `result['unit']`. There is NO early default assignment. This prevents divergence bugs (e.g. "bases" vs "bases on").
3. **Unrecognized metrics** return `skip=True` → both report and app render empty string.
4. **Descriptive goals** are blocked BEFORE `format_sample_size()` is called (`direction != 'descriptive'` check). They never reach `get_threshold_counts()`.
5. **App and report must both check `skip`.** Report: line 186 checks `counts.get('skip')`. App: line 1082 checks same. Both return `""` on skip.

## Subjective Goals — App vs Report

- **Report (PDF):** `direction == 'descriptive'` → skips grey text, shows goal text only, no progress indicators
- **App (Streamlit):** `parsed.direction == Direction.DESCRIPTIVE` → shows "Subjective / Non-measurable goal" label, skips squares/charts/percentiles entirely (`continue` in goal loop)
- **Both MUST skip.** If you add a new display path, gate it on direction.

## Previously Subjective Goals — Now Measurable (Apr 7 2026, Cristian direction)

- **Baseline Organizational Goals** → `Increase FPinZ% to 57%` (Oakes, Pentecost, Potter) — FPinZ% = AVG(CSC) on 0-0 counts (balls_before=0, strikes_before=0)
- **Maintain Velocity throughout outings** → `Increase FF Velo to 93mph` (Oakes)
- **Continue defensive progress** → `Increase Arm to 85mph in IF` (Forrester, P99 arm via Tier 1 gate, arm_floor=70 for IF)
- **Usages (60% Hard / 40% Slider)** → `Increase FB Usage to 60%` (Potter) — FB = FF+FT+SI+FC / total pitches

## Compound Shape Goals — IVB + HB Architecture (Apr 7 2026)

Pitch shape development goals track TWO metrics (IVB + HB) in a single goal slot.

### CSV Pattern
```
Avg {PT} IVB above {n} and HB above/below {n}
```
Examples:
- `Avg FT IVB above 10 and HB above 15` (Perez — two-seam run)
- `Avg FC IVB above 5 and HB below -5` (Pentecost — cutter cut)

### Parser Output
`ParsedGoal` has compound fields:
- `metric` / `target` / `direction` — primary metric
- `metric2` / `target2` / `direction2` — secondary metric

**FT: HB is primary** (arm-side run is the development focus). IVB is secondary.
**FC: IVB is primary.** HB is secondary with `direction2=DECREASE` (cutter cuts glove-side = negative HB).

### HB Sign Convention — BLOCKING RULE
**Raw DB `horzbreak` is catcher's perspective.** All apps negate it to pitcher's perspective.
PD Goals SQL uses `-p.horzbreak` for shape goals. After negation:
- Positive HB = arm-side movement (FT run, sinker run)
- Negative HB = glove-side movement (FC cut, SL sweep)

This matches `enrich_pitches()` in Arm Farm and all movement plots.

### SQL Columns (pitcher query in stats.py)
```sql
AVG(CASE WHEN p.pitch_type = 'FT' THEN p.inducedvertbreak END) as ft_ivb,
AVG(CASE WHEN p.pitch_type = 'FT' THEN -p.horzbreak END) as ft_hb,
AVG(CASE WHEN p.pitch_type = 'FC' THEN p.inducedvertbreak END) as fc_ivb,
AVG(CASE WHEN p.pitch_type = 'FC' THEN -p.horzbreak END) as fc_hb,
```

### Display
Report and app show two lines per period column:
```
HB: 14.8"    (colored by status vs target)
IVB: 11.2"   (colored by status vs target)
```
Green checkmark ONLY when **both** metrics are met. Yellow if one is met.

### Metric Map Keys
`ft_ivb`, `ft_hb`, `fc_ivb`, `fc_hb`, `sl_ivb`, `sl_hb` — all in stats dict, `_empty_pitcher_stats()`, and `METRIC_MAP` in `get_metric_value()`.

### Supported Pitch Types
FT, FC, SL (and extensible to FF, CH, CU, FS via the regex). Each needs SQL columns + stats dict + empty stats + metric map.

## Per-PT Metric Expansion — 5-Place Checklist (BLOCKING)

When adding a per-pitch-type metric (e.g. SL InZ%, CU Velo, FT Usage),
touch ALL 5 places or the metric silently falls back to the overall
variant. May 19 2026 SL/CU/FT/FC/FS InZ% expansion (Ardines goal class,
commit `d90d48bb`) is the reference impl.

| # | File | What |
|---|---|---|
| 1 | `pd-goals/src/stats.py` | Per-PT SQL `AVG(CASE WHEN pitch_type='X' THEN col END)` + stats dict population + `_empty_pitcher_stats()` + `METRIC_MAP` aliases + grey-text `_get_pitch_type_count` branch |
| 2 | `pd-goals/src/percentiles.py` | Pool template SQL + `_PFX_ALIASES` routing + `higher_is_better` list + percentage-normalization list |
| 3 | `pd-goals/src/rolling_stats.py` | Rolling-base SQL `*_sum` + `*_denom` columns + `_PARSER_TO_INTERNAL` dispatcher + rate-metric mapping |
| 4 | `pd-goals/src/goal_parser.py` | `PITCHING_METRICS` aliases (raw + InZone% variants) + `pitching_indicators` keyword |
| 5 | Verify post-normalization keys | `_normalize` does `%`→`_pct`, ` `→`_`, `-`→`_`, `/`→`_`. So "SL InZone%" → `sl_inzone_pct` — that's the live key, NOT `sl_inz%`. Add BOTH the parser's metric form (`sl_inz_pct`) AND the alias forms (`sl_iz_pct`, `sl_inzone_pct`) to every routing dict. |

**Pool gate convention:** FF=50 (every pitcher throws fastballs),
non-FF=30 (CH/SL/CU/FT/FC/FS). Match the existing FF/CH `HAVING COUNT(...) >= N` pattern in `percentiles.py`.

**Symptom when incomplete:** goal value shows the **overall** InZ% / Velo / etc.
across all pitch types instead of the requested pitch type. Two same-stat
goals on the same player render IDENTICAL values (Ardines SL+CU pre-fix).
No error, no warning — silent fallback.

## Parser Trap — Catcher Goal With Descriptive Prefix Alone (BLOCKING)

If a catcher goal pairs a descriptive prefix (e.g. "Dominate the
fundamentals behind the plate:") with a single NetK target (no AugPop),
the compound-catcher regex requires BOTH metrics and falls through →
`DESCRIPTIVE_KEYWORDS` intercepts "Dominate the fundamentals" → goal
marked **unmeasurable**.

Fix lives in `goal_parser.py` as a NetK-alone math-operator block that
runs AFTER the compound NetK+AugPop check but BEFORE descriptive scan.
Matches `r'NetK\s*[:>]?\s*([<>]=?)\s*(-?(?:\d+\.?\d*|\.\d+))'` — only
fires on math-operator forms (`>`, `<`, `>=`, `<=`), so existing
"NetK above 0.020" / "NetK (Goal: 0.025 or higher)" goals still flow
through the normal single-metric path. May 19 2026 fix (Mitchell goal,
commit `d90d48bb`).

**When adding any future single-metric-with-prefix pattern**: mirror
this approach — pre-empt with a precise regex before the descriptive
scan, scope tight so it doesn't override existing working paths.

## Open-Ended Goal Periods (no end_date)

Per `goals.csv`, some players have `start_date` filled but `end_date`
blank (placeholder rows, or open-ended development periods —
e.g. Pereira/Fraide May 19 2026). The PD Goals page handles this in
two places:

1. **Sidebar period button** (`1_PD_Goals.py`) — drops `.dropna()` on
   end_date, treats blank as today, renders label "May 1-now" with ●
   active status. Clicking sets `end_date = current date`.
2. **"Open-ended" banner** (line ~793, boss directive May 19 2026) —
   when `goals_end_date` is None but goals exist, shows "Open-ended"
   instead of "No goals loaded".

If the player has start_date but NO goal text in goal_1/2/3, the button
still renders but report is empty — that's a data issue (placeholder
row), not a UI bug.

## Pitch Usage Metrics — Full Inventory

| Metric Key | Formula | Example Goal |
|-----------|---------|-------------|
| `fb_usage` | `(FF+FT+SI+FC) / total_pitches * 100` | "Increase FB Usage to 60%" |
| `fb_usage_even` | `(FF+FT+SI+FC in even counts) / even_count_pitches * 100` | "FB usage in even counts" |
| `sl_usage_overall` | `SL / total_pitches * 100` | "Increase SL usage to 10% vs LHH" |
| `sl_usage_2k` | `SL in 2K / 2K_pitches * 100` | "SL Usage in 2K counts > 35%" |
| `split_usage` | `(FS+ST) / total_pitches * 100` | "Increase Split usage to BHH to 30%" |
| `fc_usage` | `FC in Pre2K / Pre2K_pitches * 100` | "Increase FC Usage to 20% in Pre2K" |
| `ff_usage` | `FF in Pre2K / Pre2K_pitches * 100` | "Decrease FF Usage to 50% Pre2K vs RHH" |
| `ch_usage_2k` | `CH in 2K / 2K_pitches * 100` | "CH usage in 2K counts to 28%" |
| `ch_usage_even` | `CH in even / even_pitches * 100` | "CH usage in even counts to 30%" |

**BLOCKING RULE:** Every usage metric MUST be computed in the stats dict (not just the raw count). The `sl_usage_overall` and `split_usage` bugs (Apr 7) were caused by having the count in SQL but never dividing by `pitch_count` in Python.

## Schedule Type + Level Filter
`sched_type_filter()` in `database.py` is the **blanket gate** for ALL queries:
- `AND s.sched_type IN ('R')` — R-only
- `AND s.level_code NOT IN ('win','bbc','int','sum','nae','hsb','ind','jcb')` — junk level exclusion

Both are applied automatically by every query that calls `sched_type_filter()`. One function, one place.

## Data Flow — CRITICAL ARCHITECTURE

```
goals.csv → goal_parser.py → fetch_stats() → get_metric_value() → display
                                   ↓
                    routes to 1-3 stat functions per goal:
                    ├── get_pitcher_stats()   (K%, BB%, FF Velo, InZ%, R2K%, usage, shape, etc.)
                    ├── get_hitter_stats()    (Damage, zCon, oSwing, Barrel%, etc.)
                    ├── get_defense_stats()   (React, TopSpd, AccelCD, Arm, PAA/EO, Routine)
                    └── get_catcher_stats()   (Block650, NetK, Frame650, PopTime)
```

### BLOCKING RULE: fetch_stats must route to ALL needed stat functions
`fetch_stats()` checks each parsed goal's metric and calls the appropriate stat function(s).
A hitter with a fielding goal needs BOTH `get_hitter_stats()` AND `get_defense_stats()`.
A catcher with a hitting goal needs BOTH `get_hitter_stats()` AND `get_catcher_stats()`.

**If you add a new stat function, you MUST wire it into `fetch_stats()`.** The grey sample size
(`get_threshold_counts()`) is a SEPARATE query path — it working does NOT mean the value works.

### Why this matters (Apr 7 2026 bug)
Defense and catcher stat functions existed in stats.py but `fetch_stats()` only called
pitcher/hitter. All fielding goals (React, Routine, PAA/EO) and catcher goals (Block650, NetK)
showed grey sample sizes but blank values. The sample size query worked independently;
the value query was never called.


## Defense Stats — Tier Architecture (BLOCKING)

**Moved to `rules/pd-goals-defense.md`** to slim this file. ~240 lines
covering: Tier 1 6-term gate (matches `rules/fielding.md`), defense base
query FROM tracking-tables CTE (NOT Events_View — Apr 20 2026 fix),
Position Override BLOCKING rule (goal-text drives `'ALL'` fallback,
NOT roster pos_cat), parser routing for goal-text position keywords
(Apr 20 fix), and Schedule_View vs Schedule trap in percentile queries.

Single most important takeaway: ALL defense fetches MUST resolve
position as `defense_pos_override or 'ALL'` — NEVER fall back to roster
`pos_cat`. See pd-goals-defense.md §"Position Override" for the audit
checklist applied to every new defense fetch.

## Target=0 Goals (PAA/EO "above 0") — BLOCKING RULE

When `target == 0`:
- **Cannot use percentage-based comparison** (division by zero)
- **Check direction directly:** `actual >= 0` for "above" = met, `actual < 0` = off
- **No "close" state** — met or off, no yellow

This MUST be handled in ALL status functions:
- `report.py::get_goal_status()` — lines 92-97
- `1_PD_Goals.py::get_goal_status_color()` — target=0 guard before percentage calc
- `1_PD_Goals.py::get_trend_arrow()` — target=0 guard

## Damage Target Normalization — BLOCKING RULE

Goals say "4%" meaning 0.040. Stats return damage as raw decimal.
**BOTH app and report** must normalize: `if target >= 1.0: target = target / 100.0`

- Report: `report.py` line 501-503
- App: `app.py` line 996-998

Without this, 3.9% target compares as 3.9 vs 0.039 = -99% off = RED (Narbe Cruz bug).

## Stolen Bases

Source: `Events_View.event_result_id` (official scoring), NOT ESB. See `db-columns.md` SB/SBA Count Rule.
- SB: `event_result_id IN (42, 43, 44)` — stolen_base_2b/3b/home
- CS: `event_result_id IN (4, 5, 6, 7, 29, 30, 31)` — caught_stealing variants
- Filter: `ev.sb | ev.cs = 1` on Events_View
**FIXED Apr 14, 2026:** stats.py switched to Events_View event_result_id.

Wired in BOTH:
- `get_hitter_stats()` → `stolen_bases` key in stats dict (for the actual value)
- `get_threshold_counts()` → grey text display (unit = "bases on")

## Known Parser Typo Handling

| Typo | Normalized To | Player |
|------|--------------|--------|
| `zConvs LHP` / `zConvs RHP` | `Zcon` (+ platoon from text) | Schiavone |
| `FF  Hop` (double space) | `FF Hop` | Various |
| `FF Hpo` | `FF Hop` | Sample goals |
| `CF%` | `FC Usage` (CF% was cutter typo) | Various |

## App ↔ Report Parity — BLOCKING RULE (Audited Apr 8 2026)

Both must handle identically:
1. **Damage target normalization** — `/100` when target >= 1.0
2. **Descriptive goals** — skip display (report: empty grey text, app: "Subjective" label + continue)
3. **Compound shape goals** — show both IVB/HB with independent coloring + direction2
4. **Sample size skip signal** — check `counts.get('skip')`, return empty string
5. **Target=0 handling** — PAA/EO: direct comparison, no percentage
6. **Position override** — goal text position takes priority over roster for defense stats
7. **Damage format** — percentage (2.3% not .023) in BOTH the goal display AND the no-goals preview
8. **No double stat fetch** — app fetches per-goal with platoon, not a wasted overall fetch first

## Apr 20, 2026 — Percentile Wiring + Parity Audit

Large session touching `percentiles.py`, `stats.py`, `goal_parser.py`, `report.py`.
Summary for future sessions:

### 1. Wired 20+ missing pools (commits 049e512, 56ddd60, d6abd65, 0b40aa2)

Gates chosen to be "users of the metric" (Option A) rather than all pitchers (Option B).
Shape/velo: 100 of that pitch type. Usage: 100 of that pitch (FB uses 300 total pitches
since everyone throws fastballs; count-specific usage uses 50 of that pitch in that count
state). See the Percentile Pools table above for the full gate reference.

Pool-size floor lowered 10 → 5 across all pool functions to survive thin MiLB levels.

**New Group 8b** in `get_percentile_rank` for `PAA/EO` + `Routine Conversion`. Pool scope
follows `position_category` from goal text (`_extract_position_override` returns
`1B`/`2B`/`3B`/`SS`/`LF`/`CF`/`RF`/`INF`/`OF` distinctly) so "PAA/EO at 1B" pools only
1B plays, "PAA/EO in IF" pools all four IF positions. Tier 1 gate of 10 plays per fielder
applied to the scoped pool.

**New Group 9** for Stolen Bases — 50 times-on-base gate, raw SB count per runner.

### 2. Hitter metric parity with Barrelsville postgame (commits cb34aa3, 7adf099)

Two formulas diverged from the Barrelsville reference (which is the source of truth for
hitter formulas per gc2-metrics.md). Fixed in both stats.py + percentiles.py:

- **Heart Swing%** was `CSC_mlb >= 0.75 threshold`. Switched to **per-batter ABS
  plate geometry**: `|plate_x| <= 0.5867 AND plate_z BETWEEN 0.27*h + 1.45/12 AND
  0.535*h - 1.45/12` where `h` joins `mlbam.players` for per-batter height (fallback
  6.0 ft). Matches `barrelsville/src/postgame_percentiles.py:76-84` exactly. Same
  geometry applies in all 5 Barrelsville hitter surfaces (postgame, weekly, tracker).
- **Hitter SwDec** was `pv.swing_decision_grade_2080` (Pitches_View column). Switched
  to **`ppg.swing_decision`** from `Projections_Pitches_Grades` (join on
  sched_id+pitch_id). Matches the GC2 hitter-leaderboard source. Pitcher-side SwDec
  stays on `pv.swing_decision_grade_2080` — that matches Arm Farm's pitcher reference.

**Full audit result:** 20+ hitter + pitcher metrics verified line-by-line against
Barrelsville / Arm Farm references. Heart Swing and hitter SwDec were the only real
divergences. All other core formulas (Whiff%, Ctct%, Chase%, OSw%, ZSw%, ZCon%, OCtct%,
ZWhiff%, Zone%, Barrel%, pBarrel%, Hard%, Avg EV, Damage, K%, BB%, FPinZ%, FPS%, CSW%,
R2K%, all per-PT shape/velo, Usage, EW%, Proj, Stuff Grade) match their references.

### 3. Display bug — value < 1% inflating to 100× (commit 58bca84)

`format_metric_value` in report.py had `display_val = value * 100 if abs(value) < 1 else
value` in its percentage branch. Meant to handle Damage's 0-1 storage, but broke any
legitimately-sub-1% value: Aguilar's 0.9% SL usage vs LHH displayed as "90.0%" red.
Removed the auto-multiply from the percentage branch (Damage has its own branch higher
up that still does the conversion).

This was a pure display bug — the bar height rendered correctly (at ~0.9 on a 0-10 axis),
only the text label and goal-status badge were wrong. No Pool / stats math was affected.

Same `abs < 1 → *100` pattern removed from `format_target_display` for consistency
(dead code today but latent risk, commit 2994845).

Target NORMALIZATION logic at `report.py:547` and `1_PD_Goals.py:1027` keeps the
`abs(target) < 1 → target *= 100` pattern — this one is intentional (converts
decimal-form targets like "0.10" to "10" for comparison against 0-100 stats output).
Latent edge case if someone writes a goal with a literal sub-1% percentage target
("Increase X to 0.5%" → would normalize to 50). No such goals in current goals.csv.

### 4. Platoon parser — spelled-out variants (commit e119677)

`extract_platoon_from_text` now recognizes "right-handed pitcher(s)", "lefthanded
hitters", "vs. left handed pitching", "vs righty/lefty" shorthand, etc. Previously
only `against right handed pitching`/`against left handed pitching` of the spelled-out
forms was caught. Defensive — current goals.csv has exactly one spelled-out case
(Salas "Swing decisions against Left Handed Pitching") and it always worked.

### 5. Thin-pool risk — at-risk goals, current snapshot

Six goals stack platoon + pitch-type/count filters. Value displays always correct;
percentile badge may be blank if the narrowed pool drops below 5 entries.

- `A Fayetteville`: "Decrease FF Usage 50% Pre-2K vs RHH" (low risk), "SL usage 10%
  vs LHH" (medium-high risk, April early-season)
- `A+ Asheville`: "2K Proj to LHH 60" (low-medium)
- `AA Corpus`: "SL usage to LHH 18%" (low)
- `AAA Sugar Land`: "SL usage to LHH 30%" (very low), "0-0 IZ 45% to LHH" (low)

Fills out by mid-May as sample grows. Not a correctness issue.


## WPA Plays — Cards 3 + CLI (LIVE Apr 19 & 25, 2026)

**Moved to `rules/pd-goals-wpa-plays.md`** to slim this file. ~150 lines
covering both the CLI PDF report (`generate_wpa_plays.py`) and the
Streamlit app page (`pages/4_WPA_Plays.py`). Daily top/bottom WP swings
per affiliate, click-to-video, 2x2 PDF layout.

Quick pointers:
- Home-team-centric WPA sign flip via `top_of_inning`
- 6-bucket ranking per game (off_top/bot/ks + def_top/bot/ks)
- Canonical pitch-identity click-to-video helper (NOT count-based)


## Rolling Value Chart — 6 Week Per-Goal Time Series (LIVE Apr 25 2026)

**Moved to `rules/pd-goals-rolling-chart.md`** to slim this file. ~185 lines
covering the dispatcher / mode-detection / `_translate` normalization
and the May 18 2026 change to **window = (today − 42 days) → today**
(decoupled from goal_start/goal_end). Plus the Apr 25 painful
`tdm.reaction_time` (alias-not-column) lesson — use `print()` not
`logger.warning()` in try/except.


## PD Flag Tracker — CLI Sibling (LIVE Apr 26 2026, IN ITERATION)

**Moved to `rules/pd-goals-flag-tracker.md`** to slim this file. ~250
lines covering the L2W weekly + YoY drift PDF + Slack delivery. CLI-only
today; planned app page (`pages/5_PD_Flag_Tracker.py`) when thresholds
stabilize.

Quick pointers:
- 5-file touchpoint pattern (config + 4 domain modules + CLI render)
- BLOCKING: domain modules mirror canonical (`br_tracker_data.py`,
  `catching_tracker_data.py`, `fielding_tracker_data.py`)
- Roster filter (Alvaro pattern) on every `active_*` CTE
