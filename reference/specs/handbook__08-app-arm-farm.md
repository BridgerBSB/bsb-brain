# App: Arm Farm (Pitching)

Arm Farm is the pitching counterpart to Barrelsville. It ships
postgame pitcher reports, bullpen-session analysis, advance scouting,
KPI weekly, and the Affiliate Tracker. The naming is the only thing
non-obvious about the app --- the directory is `bullpen-report/` (it
started as bullpen-only, then grew).

| | |
|---|---|
| **Branch** | `feature/bullpen-reports` |
| **Worktree** | `C:\Users\<user>\bsb-wt-bullpen` |
| **App directory** | `bullpen-report/` |
| **Posit Connect URL** | `connect2.astros.com/arm-farm/` |
| **App GUID** | `13482bcb-8ff2-4f20-92c9-5465f49e5846` |
| **Status** | LIVE |

## What it ships

| Surface | Type | Cadence |
|---|---|---|
| **Postgame pitcher PDFs** | Per-pitcher landscape PDF, per-game | Daily on game days |
| **Bullpen session PDFs** | Per-pitcher bullpen analysis (release point, mvmt, velo) | Bullpen days |
| **Pitching advance scouting PDFs** | Pitcher vs opposing hitter overlay, KDE heatmaps | On series |
| **Pitcher KPI weekly PDFs** | Per-level PDFs (all HOU pitchers at level) | Sunday |
| **Affiliate Tracker** | Multi-tab leaderboard (per-pitcher + org rankings + monthly + yearly) | Live, parquet pins |
| **Postgame app page** | Streamlit interactive postgame --- click-to-video on charts | Live |
| **Advance app page** | Pitching advance interactive | Live |
| **Pitcher KPI app page** | Plotly KPI dashboard | Live |
| **Side Reports app page** | Bullpen session analysis | Live |
| **Org-wide pitcher analysis (one-off)** | Single multi-page PDF for all HOU MiLB pitchers (auto-splits at HTTP 413) | Periodic |
| **Pitcher KPI snapshot** | Org-wide single PDF | Periodic |

## Key files

```
bullpen-report/
├── Arm_Farm.py                  # Landing page (retro arcade, 5 cards)
├── manifest.json
├── pages/
└── src/
└── scripts/
└── connect_pins/                # Connect-scheduled pin refresh job
```

### Pages

| File | Purpose | Status |
|---|---|---|
| `pages/1_Side_Reports.py` | Bullpen session analysis | LIVE |
| `pages/2_Postgame.py` (~1770 lines) | Postgame pitcher reports | LIVE |
| `pages/3_Affiliate_Tracker.py` | Affiliate leaderboard | ALPHA V1 |
| `pages/4_Pitching_Advance.py` | MiLB advance scouting (series cascade + batter lookup) | LIVE |
| `pages/5_Pitcher_KPI.py` | Pitcher KPI charts + tables | LIVE |

### Source modules (selected)

| File | Purpose |
|---|---|
| `src/postgame_report.py` | PDF drawing (plottable tables, custom column params) |
| `src/postgame_data.py` | Game pitch/PA queries, stat computation, gcERA, arm-angle by pitch type |
| `src/postgame_percentiles.py` | League distributions + color mapping (6 queries) |
| `src/postgame_app_data.py` | App-specific queries (sidebar, game sessions) |
| `src/bullpen_data.py` | Shared constants (`PITCH_TYPE_COLORS`, `enrich_pitches`) |
| `src/plots.py` | Plotly charts (rolling velo, movement scatter, pie charts, arm angle box) |
| `src/reclassify.py` | Pitch reclassification (CSV-based overrides) |
| `src/video.py` | Video URL lookup (Synergy) |
| `src/tracker_data.py` | Affiliate Tracker data + SQL queries |
| `src/advance_pitching_data.py` | Advance scouting data (hitter search, series, roster) |
| `src/advance_pitching_report.py` | Advance PDF (matchup KDE heatmaps, fb_grade/rv_gain) |
| `src/pitcher_kpi_data.py` | KPI chart data (30-org trends) + player table data |
| `src/pitcher_kpi_report.py` | KPI PDF (cover + 5 charts + 2 tables + overflow) |
| `src/pins_config.py` | Pin board connection |
| `src/tracker_pins.py` | Tracker pin read/write |

### CLI scripts

| Script | Purpose |
|---|---|
| `scripts/generate_postgame.py` | Daily pitcher postgame |
| `scripts/generate_reports.py` | Bullpen session PDFs |
| `scripts/pitcher_analysis.py` | Org-wide MiLB pitcher analysis batch (auto-splits at HTTP 413 with `--split` flag) |
| `scripts/pitcher_kpi_snapshot.py` | Pitcher KPI snapshot PDF |
| `scripts/generate_pitcher_kpi_report.py` | Weekly per-level pitcher KPI |
| `scripts/generate_advance_pitching.py` | Pitching advance overlay |
| `scripts/generate_advance_pitching_batch.py` | Batch advance overlay for upcoming series |
| `scripts/velo_extremes_batch.py` | 10 fastest + 10 slowest per pitcher (video links) |
| `scripts/velo_durability.py` | Velo & stuff durability (early vs late innings) |

## Architecture

Same general shape as Barrelsville: app pages call data modules for
DB queries, app pages render Plotly inline, PDF download buttons call
the same data + report modules that the CLI scripts call.

```
Streamlit App                   CLI scripts (work laptop)
     │                                │
     ▼                                ▼
data.py modules ←─── shared ───→ data.py modules
     │                                │
     ▼                                ▼
Plotly inline                   matplotlib / reportlab PDF
                                       │
                                       ▼
                                 deliver.py → Logic App → Slack
```

::: blocking
**`enrich_pitches()` in `bullpen_data.py` flips `plate_x`,
`horzbreak`, and `release_x` to pitcher's view.** Every other module
that reads pitch data assumes pitcher's-view orientation. Don't
re-flip in downstream code.
:::

## Key features

### LVA pitch result marker shapes

The Live Velocity Analysis chart on `pages/2_Postgame.py` distinguishes
pitch outcomes by marker shape:

| Result | matplotlib | Plotly | Definition |
|---|---|---|---|
| Whiff | `'o'` filled | `circle` | `pitch_result_id IN (10,16,21,22,23)` |
| Foul | `'s'` square | `square` | `pitch_result_id IN (7,8,9)` |
| Hard Hit | `'X'` cross | `x` | BIP with `EV >= 89` |
| Weak | `'^'` triangle | `triangle-up` | BIP with `EV < 89` or NULL |
| Take | `'o'` hollow | `circle-open` | Everything else (`did_swing=0`) |

### Click-to-video

Plotly chart click → video opens in new tab. Same pattern as
Barrelsville.

### Player Plan Goals on the postgame report

Goals display on page 1 of the pitcher postgame PDF, left column. Data
flows through the Posit Connect pin (`zbridger/pd_goals_data`):

```
generate_postgame.py
   ├── load_player_goals(gc_id)
   │     └── _load_goals_data() — pin-first, CSV fallback
   ├── postgame_report._draw_goals(fig, goals)
   └── PDF rendered
```

This is the cross-app integration pattern --- Arm Farm reads goals
data that PD Engine writes. See Chapter 11 for cross-app patterns.

### Movement plot enhancements

#### Season covariance ellipses

95% confidence (2.0 σ), built from season pool (cascading 2025+2026
R-game data --- same as LVA chart). Only drawn for pitch types thrown
in the current outing, minimum 10 pitches per type. Computed via numpy
2D covariance + eigenvalue decomposition.

#### Arm angle dashed line

Black dashed line from origin (0,0) at the pitcher's average arm
angle. RHP: line goes upper-right. LHP: mirrored upper-left. Source:
`groundcontroltracking.tracking.pitch_hit_trajectories` +
`play_starting_positions` + `mlbam.players` (height feet/inches).
Works at all Astros affiliates (HawkEye coverage).

#### Per-pitch-type arm angle box (Apr 17 2026)

Sits to the right of the Pitch Arsenal legend on the PDF and as a
third chart row on the app. NOT the same as the movement-plot dashed
line --- that line stays as the pooled pitcher average; the box shows
each pitch type separately for tipping detection.

```
Single quadrant (auto-picks corner from handedness + submarine detection):
  RHP normal  → upper-right
  LHP normal  → upper-left
  Submarine   → lower quadrant

One dashed line per pitch type from origin to (cos θ, sin θ) per type.
Per-type labels stacked: "FF 45.2° (40.1-50.3)", colored by pitch.
```

### Pitcher KPI table columns (16, Apr 13 2026)

```
Player, BF, FPinZ%, InZ%, R2K%, EW%, 2K Proj, K%, BB%, K-BB%,
FB Velo, Whf%, SRV, Proj, gcERA, gcPerf
```

**Chart metrics (5):** FPinZ%, InZ%, R2K%, EW%, 2K Proj.

### Pitching advance heatmap normalization

Tuned Mar 27 2026 to data-driven bounds:

- `_PROJ_MIN, _PROJ_MAX = 10.0, 70.0` --- fb_grade
- `_RV_MIN, _RV_MAX = -0.10, 0.10` --- rv_gain

Visual-only change. Data and smoothing untouched. Was previously
30-70 / ±0.05, which clipped 25-27% of player averages.

### IP calculation (BLOCKING)

Three sections (per-pitcher leaderboard, monthly breakdown, org
rankings) all use **`Gamelog_Pitching` as the gold standard** with
`combine_first` fallback to `outs_after - outs_before`.

::: blocking
**NEVER use `AB - H + SF` for IP.** That's the historical bug pattern.
The canonical impl is `_get_gamelog_outs()` in `tracker_data.py`. See
`.claude/rules/ip-calculation.md`.
:::

## Channel routing

Per-pitcher postgame PDFs route via slack_channels.csv lookup. KPI
weekly per-domain channels:

| Level | Channel |
|---|---|
| MLB | `mlb_armfarm` (in CSV) |
| AAA | `sugarland_armfarm` |
| AA | `corpus_armfarm` |
| A+ | `asheville_armfarm` |
| A | `fayetteville_armfarm` |
| FCL | `fcl_armfarm` |

Org-wide pitcher analysis + KPI snapshot go to `weekly-player-updates`
(`C0AVBKPEG8H`).

### Pitcher analysis auto-split (HTTP 413 mitigation)

Pitcher analysis is the ONLY org-wide script that auto-splits today.
The 6-pages-per-pitcher output (4 KDE density pages + 2 table pages)
at full org size (~120 pitchers) exceeds the Logic App HTTP trigger
payload limit (~100MB after base64 encoding).

Trigger: explicit `--split` flag (user opts in). Default behavior is
a single full-org PDF (will return HTTP 413 if too large; that's the
user's signal to retry with `--split`). When `--split` fires:

- First `ceil(N/2)` pitchers → `_Part1.pdf`
- Remaining `floor(N/2)` → `_Part2.pdf`
- Each pitcher's report is COMPLETE --- all levels, all sched_types
  within the run's filters. We split the LIST, not the data per pitcher.

## Tracker parquet pins

Same pattern as Barrelsville. Pin name:
`zbridger/arm_farm_tracker_<year>`. Connect-scheduled refresh every
6h. See Chapter 13.

## Where to look next

- **Chapter 11** for three-surface parity (Arm Farm pitching metrics
  parity is documented in `.claude/rules/three-surface-parity.md`).
- **Chapter 13** for the Connect pin pattern (Arm Farm was the second
  tracker to ship pin refresh after Barrelsville).
- `.claude/rules/arm-farm.md` --- the canonical app rule file.
- `bullpen-report/Arm_Farm.py` --- start here when reading code.
