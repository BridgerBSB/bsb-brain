# App: Intangibles (BR / OF / IF / Catcher)

Intangibles is the largest app by domain count: it covers Baserunning,
Outfield, Infield, AND Catcher, each with its own postgame, weekly,
KPI weekly, and tracker. The shared `fielding_base.py` module backs
everything, and the unified `fielding_tracker_*` modules power both
OF and IF trackers via a single dispatch.

| | |
|---|---|
| **Branch** | `feature/astros-intangibles` |
| **Worktree** | `C:\Users\<user>\bsb-wt-intangibles\astros-intangibles` |
| **App directory** | `intangibles/` |
| **Posit Connect URL** | `connect2.astros.com/intangibles/` |
| **App GUID** | `295a5205-5568-4fb6-a759-26dc63bc9439` |
| **Status** | IN PROGRESS (most surfaces LIVE; some catcher items code-complete) |

## Four domains, four pages

| Page | Domain | Status |
|---|---|---|
| `pages/1_Baserunning.py` | BR postgame dashboard + tracker + KPI weekly | LIVE |
| `pages/2_Outfield.py` | OF postgame dashboard + tracker (via `fielding_tracker_page.render("OF")`) + KPI weekly | LIVE |
| `pages/3_Infield.py` | IF postgame dashboard + tracker (via `render("IF")`) + KPI weekly | LIVE |
| `pages/4_Catching.py` | Catcher report dashboard + tracker + KPI weekly | CODE COMPLETE |

## What it ships

| Surface | Type | Cadence |
|---|---|---|
| **BR postgame PDFs** | Per-runner PDF, per-game | Game days |
| **BR daily team report** | Per-level PDF, all runners on the affiliate | Game days |
| **OF/IF daily postgame PDFs** | Per-affiliate-level PDF (one PDF per level), all qualifying fielders | Game days |
| **Catcher postgame PDFs** | Per-catcher PDF | Game days |
| **OF/IF weekly individual reports** | Per-fielder weekly PDF (KPI bars, YTD boxes, play tables, direction rose, difficulty buckets) | Weekly |
| **OF/IF/BR/Catcher KPI weekly PDFs** | Per-level PDF (all HOU at affiliate level) | Sunday |
| **Hitter advance scouting PDF** | Opposing hitter defensive positioning (IF + OF KDE heatmaps) | On series |
| **Tracker app pages** | Live multi-tab leaderboards (per-domain, per-level, per-org, monthly, yearly) | Live, parquet pins |
| **KPI snapshot** | Position player KPI snapshot (OF/IF/BR/Catcher --- delivery TBD) | Periodic |
| **Specialized analysis (CLIs)** | Tag-up 2→3, pickoff outs, fielding tracker spec doc | On-demand |

## Key files

```
intangibles/
├── Intangibles.py
├── manifest.json
├── pages/
└── src/                         # Heavy: ~30 modules
└── scripts/                     # ~20 CLIs
└── connect_pins_br/             # BR tracker pin refresh
└── connect_pins_fielding/       # OF + IF tracker pin refresh (one Connect content, both pins)
└── connect_pins_catcher/        # Catcher tracker pin refresh
```

### Live vs dead file map (BLOCKING)

A prior refactor consolidated OF + IF trackers into a shared module
but left the per-domain files on disk. They look live (same function
names, same SQL shape) but nothing imports them. Verify before editing
any file with "tracker" in the name:

```bash
grep -rn "from.*<module_name>\|import <module_name>" \
    intangibles/pages/ intangibles/scripts/
```

| File | Status | Used by |
|---|---|---|
| `src/fielding_tracker_page.py` | **LIVE** | `pages/2_Outfield.py` and `pages/3_Infield.py` via `render("OF")` / `render("IF")` |
| `src/fielding_tracker_data.py` | **LIVE** | Imported only by `fielding_tracker_page.py` --- single source for both OF + IF tracker SQL |
| `src/br_tracker_page.py` | **LIVE** | `pages/1_Baserunning.py` |
| `src/br_tracker_data.py` | **LIVE** | Imported only by `br_tracker_page.py` |
| `src/catching_tracker_page.py` | **LIVE** | `pages/4_Catching.py` |
| `src/catching_tracker_data.py` | **LIVE** | Imported only by `catching_tracker_page.py` |
| `src/of_tracker_page.py` | **DEAD** | Nothing |
| `src/of_tracker_data.py` | **DEAD** | Only imported by dead `of_tracker_page.py` |
| `src/if_tracker_page.py` | **DEAD** | Nothing |
| `src/if_tracker_data.py` | **DEAD** | Only imported by dead `if_tracker_page.py` |

::: blocking
**Editing dead files produces zero runtime change.** Multiple
sessions have wasted 4+ commits on these four files. Always grep
before editing any file matching `*tracker*`.
:::

### Source modules (selected)

| File | Purpose |
|---|---|
| `src/fielding_base.py` | **SHARED MODULE** --- Events_View architecture, position configs, filter functions, Tier 1/2/3 gates, difficulty bucket helper |
| `src/br_data.py` | BR statline + PBP queries |
| `src/br_report.py` | BR PDF (plottable tables, percentile coloring) |
| `src/br_percentiles.py` | Lead length percentile engine (1B + 2B distributions) |
| `src/of_postgame_data.py` | OF event-level play queries, error detection |
| `src/of_postgame_report.py` | OF daily PDF (landscape, plottable tables) |
| `src/of_postgame_percentiles.py` | OF season distributions (9 tracking KPIs + PAA) |
| `src/if_postgame_data.py` | IF event-level play queries, OPG infield |
| `src/if_postgame_report.py` | IF daily PDF (per-level, affiliate logos, KPI header) |
| `src/if_postgame_percentiles.py` | IF season distributions (8 tracking KPIs + OPG) |
| `src/catcher_data.py` (864 lines) | Catcher queries |
| `src/catcher_report.py` (1110 lines) | Catcher PDF |
| `src/catcher_percentiles.py` | Catcher percentile distributions |
| `src/of_individual_page.py` / `src/if_individual_page.py` | OF/IF individual player page (called via `render()`) |
| `src/of_weekly_data.py` / `src/if_weekly_data.py` | Weekly per-fielder data (tracking, value, plays) |
| `src/of_weekly_report.py` / `src/if_weekly_report.py` | Weekly per-fielder PDF |
| `src/hitter_advance_data.py` | Opposing hitter roster + BIP query + series detection |
| `src/hitter_advance_report.py` | Hitter advance PDF (2 KDE density heatmaps) |

### CLI scripts

Daily: `generate_br_report.py`, `generate_br_daily_report.py`,
`generate_of_report.py`, `generate_if_report.py`,
`generate_catcher_report.py`.

Weekly KPI: `generate_br_kpi_report.py`, `generate_of_kpi_report.py`,
`generate_if_kpi_report.py`, `generate_c_kpi_report.py`.

Weekly individual: `generate_of_weekly_report.py`,
`generate_of_weekly_batch.py`, `generate_if_weekly_report.py`,
`generate_if_weekly_batch.py`.

Advance: `generate_hitter_advance.py`.

Specialized: `generate_kpi_snapshot.py`, `generate_pickoff_report.py`,
`tagup_2to3_analysis.py`, `build_guide_pdf.py`.

Pin refresh: `pin_br_tracker_seasons.py`,
`pin_fielding_tracker_seasons.py`, `pin_catching_tracker_seasons.py`,
`repair_tracker_pin.py`.

## Fielding tier system (`fielding_base.py`)

Three tiers + a NO-gate class for cumulative value metrics ---
detailed in Chapter 6. Quick recap:

| Tier | Purpose | Filter | Used for |
|---|---|---|---|
| **Tier 1** (KPI) | Physical tool metrics | 6-term: `OM + DCBP.CP + DCBP.CT + TDM.CP + TDM.CT + (arm >= floor) > 0` | TopSpd, React, Arm, Exchange, etc. |
| **Tier 2** (Plays) | Display-worthy plays | 5-condition OR (1stD, CP+out_prob, bearing fallback, wall_ball, orphaned tracking) | Play tables in weekly reports |
| **Tier 3** (Difficulty) | Routine play conversion | `first_defender_id = fielder_id AND out_prob IS NOT NULL` | Difficulty buckets only |
| **No Gate** (Value) | Cumulative credit/blame | ALL DCBP rows for the fielder, no filter | **OAA, PAA, PAA/EO, RAA** |

**The "No Gate" row is the easy-to-miss one.** PAA / OAA / RAA / PAA/EO
are summed across **every** DCBP row for the fielder, with no
Tier 1 / 2 / 3 gate. Verified in `pd-goals/src/stats.py:2070-2086`
(query) + `:2920-2929` (computation). See Chapter 6 §"Cumulative
value metrics" for the actual computation pattern.

### Position configs

| Position | pos_ids | Arm Floor | Arm Ceiling | UseReact? | Exchange Col |
|---|---|---|---|---|---|
| OF | (7,8,9) | 75 | 108 | Yes | `exchange` |
| IF | (3,4,5,6) | 70 | 108 | No | `exchange_dp` |

### Difficulty buckets (Tier 3)

| Label | out_prob Range |
|---|---|
| Routine | 0.90 - 1.00 |
| Extended | 0.75 - 0.90 |
| Good | 0.50 - 0.75 |
| Great | 0.25 - 0.50 |
| Elite | 0.00 - 0.25 |

Routine play conversion = `AVG(out_made) * 100` on plays where
`out_prob >= 0.90`.

## App ↔ Report parity rule (BLOCKING)

When changing ANY filter, tier gate, or rendering logic on a report
OR app page, ALWAYS update BOTH. Even if the user only mentions one,
the other must match. The app's PDF download button calls the report
generator with the same data --- filters applied inside the report
function and inside the app rendering must produce identical results.

**Files that must stay in sync (OF example):**

| Section | Report (`of_weekly_report.py`) | App (`of_individual_page.py`) |
|---|---|---|
| Spray | `_display_tier_filter()` before render | `_display_tier_filter()` before render |
| Direction rose | Tier 1 + `fielder_direction_txt` not null | Same |
| Difficulty | `first_defender == "Y"` + `out_prob` not null | Same |
| Play table | `_display_tier_filter()` | Same |
| KPI bars | Same DB query | Same |

Same pattern applies to IF (`if_weekly_report.py` ↔ `if_individual_page.py`).

## OF/IF Weekly Individual Report

The "weekly" report is per-fielder, not per-affiliate. KPI bars at the
top, year-to-date percentile-colored boxes (8 metrics) at the bottom,
plus play tables, direction rose, and difficulty buckets.

### YTD boxes (Apr 11 2026; rendering gate fix Apr 27 2026)

Bottom of KPI page (page 2), left 60%. Each box shows:

1. Metric label with percentile aggregate (e.g. `TopSpd (P95)`)
2. Large season value (same P95/P75/P25/P99/P10 as battery bars above)
3. Percentile ordinal (e.g. "62nd"), colored by season distribution
4. **Lvl Rank**: `#3/45` --- rank among all players at level (all
   orgs), 10+ Tier 1 events gate
5. **Org Rank**: `#1/8` --- rank among HOU org players at level only

::: blocking
**Rendering gate** (Apr 27 2026, commit `9583f8a`): both
`_draw_ytd_boxes()` calls MUST gate on `season_tracking` only, not on
`season_tracking and season_ranks`. `season_ranks` is empty `{}` for
just-promoted players (10-event pool gate); the empty dict is falsy
and previously suppressed the entire YTD section. The renderer's
per-metric guards handle missing rank data gracefully.
:::

### Cross-level vs level-scoped

| Box element | Pool | Player value used |
|---|---|---|
| YTD value (e.g. `28.4 mph`) | n/a | **Cross-level** --- full season, all levels combined |
| Percentile ordinal + bg color | Current level's season distribution | Cross-level value ranked against current-level pool |
| Lvl Rank `#3/45` | Current level only, 10+ Tier 1 events to enter pool | Player's **current-level-only** aggregate |
| Org Rank `#1/8` | Current level × HOU only, 10+ Tier 1 events | Same |

A just-promoted player with <10 Tier 1 events at the new level will
see the YTD value, percentile, and color populate, but the Lvl/Org
rank lines hide until they accumulate.

## H/A split — direction mapping (BLOCKING, non-obvious)

All 6 affiliate trackers have the H/A filter. `_build_ha_filter(ha_split)`
produces the `{ha_filter}` SQL substitution.

`top_of_inning` direction depends on the domain:

| Domain | Home | Away | Why |
|---|---|---|---|
| Batting / BR | toi=0 | toi=1 | Home bats bottom of inning (toi=0) |
| Pitching / Fielding / Catching | toi=1 | toi=0 | Home fields top of inning (toi=1) |

## IF daily report — per-level Slack delivery

| Route Key | Channel Name | Channel ID |
|---|---|---|
| mlb | pd-automation-test | `C0ABHSF6SCA` |
| aaa | sugarland_intangibles | `C0AKNKW1UKU` |
| aax | corpus_intangibles | `C0AL1HM1CDP` |
| afa | asheville_intangibles | `C0AK76YS1NK` |
| afx | fayetteville_intangibles | `C0AKNL9BGN6` |
| rok | fcl_intangibles | `C0AKG8WA267` |
| dsl | dsl_intangibles | `C0AK777QM47` |

DSL/FCL split: both use `level_code='rok'` in DB. Split by
`gc2_level_code`.

## Catcher metric standardization (Apr 16 2026)

Three-surface parity for catcher metrics is the most heavily-audited
domain in the codebase. Reference: `.claude/rules/three-surface-parity.md`.

| Metric | Source / Formula | CSC column / Range |
|---|---|---|
| **NetK** | `SUM(pv.net_k)` | `called_strike_chance` (level-adjusted), strict `> 0.05 AND < 0.95`, result_id `(4,5,6)`, `ignore_flag=0` |
| **NetK/P** | `SUM(net_k) / COUNT(edge)` | Tracker only |
| **FramRAA** | `SUM((CS_indicator - CSC) * (rv_ball - rv_strike))` | `called_strike_chance_mlb`, inclusive `BETWEEN 0.05 AND 0.95` |
| **SurPP** | `SUM(passed_pitch) - SUM(pp_prob)` | --- |
| **BlockRAA** | `SurPP × baserunner_advance_rv` (NEGATED --- pitching-team perspective) | --- |
| **Pop2B** | P01 within 1.70-2.35 | --- |
| **Pop3B** | P01 within 1.40-1.85 | --- |
| **AugPop2B** | P01 with `aug_pop IS NOT NULL` (NEVER AVG) | --- |
| **Arm** | P99 within 60-94 | --- |
| **Exch** | P10 with `exchange >= 0.4 AND arm >= 60` | --- |

### 7-bucket framing system

| Bucket | CSC Range | Color | Meaning |
|---|---|---|---|
| E Stl | 0-5% | `#1B5E20` (dk green) | Extra steal |
| Stl | 5-25% | `#66BB6A` (green) | Steal |
| Mid+ | 25-50% | `#42A5F5` (blue) | Mid gain |
| Exp | matched | `#BBBBBB` (grey) | Expected |
| Mid− | 50-75% | `#FDD835` (yellow) | Mid loss |
| Loss | 75-95% | `#FF9800` (orange) | Loss |
| B Loss | 95-100% | `#F44336` (red) | Bad loss |

## Tracker parquet pins

Five trackers, three Connect-deployed pin refresh notebooks:

- `connect_pins_br/` → `zbridger/intangibles_br_tracker_<year>`
- `connect_pins_fielding/` → both `zbridger/intangibles_of_tracker_<year>` AND `zbridger/intangibles_if_tracker_<year>` (single Connect content writes both pins)
- `connect_pins_catcher/` → `zbridger/intangibles_catcher_tracker_<year>`

All refresh every 6 hours during the season. See Chapter 13 for the
full pin pattern, including the dual-layout detection for the
intangibles worktree (`bsb-wt-intangibles/astros-intangibles/intangibles/`
on personal laptop vs `bsb-wt-intangibles/intangibles/` on work
laptop).

## Where to look next

- **Chapter 11** for three-surface parity --- catcher and OF/IF
  metrics live in trackers + KPI weekly + PD Goals org KPI.
- `.claude/rules/intangibles.md` --- the canonical app rule file.
- `.claude/rules/fielding.md` --- the 6-term Tier 1 gate canon.
- `.claude/rules/three-surface-parity.md` --- parity invariants.
- `intangibles/Intangibles.py` --- start here when reading code.
