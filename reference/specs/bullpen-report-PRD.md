# Postgame Pitcher Report — Product Requirements Document

## Overview

Single-page landscape PDF report generated for each Astros org pitcher after every game. Delivered to coaching staff via Slack channels through the OneDrive → Power Automate pipeline.

## Target Users

- MiLB pitching coordinators and coaches
- Player development staff

## Report Sections

### 1. Header
- Player headshot (from MiLB CDN via mlbam_id)
- Full name, game date, report title (e.g., "(AA) Postgame Report")
- Affiliate, position, B/T
- Astros logo

### 2. Player Plan Goals (left column)
- Up to 3 PD goals from `pd-goals/data/goals.csv`
- Sourced by groundcontrol_id

### 3. Key KPIs (left column, under goals)
- 4 game-level metrics: **FPinZ%, R2K%, EW%, 2K Proj**
- Colored by percentile gradient (higher = better)
- 2K Proj uses dedicated `proj_2k` distribution (NOT general `proj`)

### 4. Pitch Arsenal (left column, under KPIs)
- Color swatches per pitch type with usage %
- Sorted by usage descending

### 5. Rolling Pitch Velo (center)
- Line chart: pitch number (per type) vs velocity
- One line per pitch type, colored by pitch type
- Y-axis: 5 mph increments, floor/ceil to nearest 5

### 6. Pitch Movement (right)
- Scatter: HorzBreak (x) vs Hop/IVB (y)
- One color per pitch type, crosshairs at origin
- Legend includes usage %

### 7. Statline Table
Single-row summary with percentile-colored cells:

| #P | IP | BF | H | K | BB | Strk% | SWM% | 0-1 IZ% | FPinZ% | pBrl% | Proj | gcERA | gcPerf |

App "Customize Table Columns" expander allows adding/removing columns. PDF reflects app selections when generated from app; CLI uses defaults.

### 8. Pitch Characteristics Table (left)
Per pitch type, one row each:

| Pitch | # | Velo | Spin | Hop | HB | Eff | Tilt | RelHt | RelSd | Ext | StuffRelVelo |

- Pitch column: colored rectangle per pitch type
- StuffRelVelo: percentile-colored per pitch type
- Velo format: "92.3 (89-95)" — avg 1 decimal, range floor integers

### 9. Pitch Results Table (right)
Per pitch type, rows aligned with Characteristics:

| InZ% | 2KProj | 0-1 IZ% | Avg EV | SWM% | Strk% | SwDec | pBrl% | EW% | Whiff% | R2K% |

- Most columns percentile-colored with rounded rectangle backgrounds
- **InZ% has NO percentile coloring** (value only)
- Per-pitch-type percentiles: 2KProj, 0-1 IZ%, Avg EV, SWM%, Strk%, SwDec, pBrl%, Whiff%
- Game-level percentiles: R2K%, EW%
- App "Customize Table Columns" expander allows adding/removing columns

### 10. Pie Charts (bottom)
6 pies in a row: Usage / Early (0-0 & 1-1) / Putaway (2K) × vs LHH / vs RHH

## Metric Definitions

### Statline Metrics
| Metric | Formula | Percentile Pool |
|--------|---------|-----------------|
| **#P** | Total pitches | — |
| **IP** | (AB - Hits + SF) / 3 | — |
| **BF** | Batters faced (PA count) | — |
| **H** | 1B + 2B + 3B + HR from Events_View | — |
| **K** | Strikeouts from Events_View | — |
| **BB** | Walks from Events_View | — |
| **Strk%** | Non-ball pitches / total pitches | Game-level: all appearances ≥20 P |
| **SWM%** | Swinging strikes / total pitches | Game-level: all appearances ≥20 P |
| **0-1 IZ%** | Zone rate on pre-2-strike pitches (CSC ≥ 0.5 where strikes_before < 2) | Game-level: all appearances ≥20 P |
| **FPinZ%** | Zone rate on 0-0 count (CSC ≥ 0.5 where balls=0, strikes=0) | Game-level: 1stPZ% distribution |
| **pBrl%** | Parabolic barrels / BIP. Formula: EV ≥ 0.011×LA² - 0.91×LA + 95.0 | Game-level: appearances with Hits join |
| **Proj** | AVG(fb_grade) from Projections_Pitches_Grades | Game-level: appearances with Projections join |
| **gcERA** | GC2 pitch-weighted product-of-averages: (3.9+31.1×HR_rate)×bip_rate×pBrl_rate + 3.5×bip_rate×(1-pBrl_rate) + (-3.3)×so_rate + 9.9×bb_hbp_rate | Game-level: pitch-level AVG() matching GC2, ≥20 P |
| **gcPerf** | 50.0 - 1500.0 × AVG(per-pitch run values). RVs: whiff=-0.08, called_strike=-0.03, ball=+0.03, HBP=+0.10, pBarrel_BIP=+0.08, other_BIP=-0.03 | Game-level: appearances with Hits join |

### Key KPI Metrics
| Metric | Formula | Percentile |
|--------|---------|------------|
| **FPinZ%** | Zone rate on 0-0 count (CSC ≥ 0.5, balls=0 strikes=0) | Game-level: fps_pct dist |
| **R2K%** | GC2 formula: on pitch 3, strikes_after >= 2, gated by (pa=0 OR so=1). Excludes 3-pitch PAs ending in non-K contact | Game-level: r2k_pct dist |
| **EW%** | Early count (0-0, 1-0, 0-1, 1-1) BIP with EV ≤ 89 AND LA outside 10-35° / early count BIP | Game-level: ew_pct dist |
| **2K Proj** | AVG(fb_grade) on 2-strike pitches (excluding 3-2 counts) | **Game-level: dedicated proj_2k dist** (NOT general proj) |

### Pitch Results Metrics (per pitch type)
| Metric | Formula | Percentile Pool |
|--------|---------|-----------------|
| **InZ%** | CSC ≥ 0.5 / total for that pitch type | **No percentile** (value only) |
| **2KProj** | AVG(fb_grade) on 2-strike pitches of that type (excl 3-2) | Per-pitch-type: dedicated proj_2k dist, ≥30 pitches |
| **0-1 IZ%** | CSC ≥ 0.5 where strikes_before < 2, for that pitch type | Per-pitch-type: ≥30 pitches of type |
| **Avg EV** | AVG(hit_exit_speed) for BIP of that pitch type | Per-pitch-type: lower=better for pitcher |
| **SWM%** | Swinging strikes / total for that pitch type | Per-pitch-type: whiff% distribution |
| **Strk%** | Non-ball pitches / total for that pitch type | Per-pitch-type: ≥30 pitches of type |
| **SwDec** | AVG(swing_decision_grade_2080) for that pitch type (20-80 scale) | Per-pitch-type: higher=WORSE for pitcher |
| **pBrl%** | Parabolic barrels / BIP for that pitch type | Per-pitch-type: lower=better for pitcher |
| **EW%** | Early count BIP soft contact | Game-level: ew_pct dist (not per-PT) |
| **Whiff%** | Swinging strikes / swings for that pitch type | Per-pitch-type: ≥30 pitches of type |
| **R2K%** | Game-level R2K% (same in all rows) | Game-level: ≥5 PAs per appearance |

### Pitch Characteristics (per pitch type)
| Column | Source | Notes |
|--------|--------|-------|
| **Pitch** | pitch_type → PITCH_TYPE_NAMES | Colored rectangle per type |
| **#** | COUNT of pitches | — |
| **Velo** | "AVG (MIN-MAX)" from release_speed | Avg=1 decimal, range=floor integers |
| **Spin** | AVG(spin_rate) | Integer |
| **Hop** | AVG(inducedvertbreak) | 1 decimal |
| **HB** | AVG(horzbreak), flipped to pitcher perspective | 1 decimal |
| **Eff** | AVG(spin_eff) or useful_spin/spin_rate fallback | Percentage |
| **Tilt** | compute_tilt(raw_hb, ivb) → clock face string | e.g., "11:30" |
| **RelHt** | AVG(release_z) | 1 decimal |
| **RelSd** | AVG(release_x), flipped to pitcher perspective | 1 decimal |
| **Ext** | AVG(extension) | 1 decimal |
| **StuffRelVelo** | AVG(stuffrelvel_grade_2080) (20-80 scale) | Per-pitch-type percentile |

## Percentile Distribution Queries

6 separate SQL queries run per level+season (all in `src/postgame_percentiles.py`):

1. **_STATLINE_QUERY**: Game-level Strike%, SWM%, InZ%, 1stPZ%, Pre-2K InZ% (≥20 pitches/appearance)
2. **_PITCH_TYPE_QUERY**: Per-pitch-type Whiff%, Chase%, SwDec, StuffRelVelo, Strike%, 0-1 IZ%, InZ% (≥30 pitches/type)
3. **_R2K_GAME_QUERY**: Game-level R2K% via CTE (≥5 PAs/appearance)
4. **_ADVANCED_STATLINE_QUERY**: Game-level pBrl%, Proj, gcPerf, EW%, Avg EV, **2K Proj** with Hits+Projections JOINs (≥20 pitches)
5. **_ADVANCED_PITCH_TYPE_QUERY**: Per-pitch-type pBrl%, Avg EV, 2KProj with Hits+Projections JOINs (≥30 pitches/type)
6. **_GCERA_GAME_QUERY**: Game-level gcERA via GC2 product-of-averages formula (≥20 pitches)

Percentile pool: Regular season ('R') only. Falls back to prior year if current season has insufficient data.

### Key Percentile Notes
- **2K Proj** has its own dedicated game-level distribution (`proj_2k`), separate from general `Proj`
- **InZ%** has NO percentile coloring (value displayed without background color)
- **SwDec** is FLIPPED for pitchers: higher SwDec = batter decided better = WORSE for pitcher (`higher_is_better=False`)
- **Avg EV** is FLIPPED: lower EV = better for pitcher (`higher_is_better=False`)
- **pBrl%** is FLIPPED: lower barrels = better for pitcher (`higher_is_better=False`)

### 11. Page 2: LVA (Location vs Action) Grid
Strike zone heatmap grid showing pitch location patterns by count state and batter handedness.

**Layout:** Rows = pitch types (usage desc), Columns = 6: (0-0 / Pre-2K / 2K) × (vs LHH / vs RHH)

**Each cell contains (blank if 0 game-day pitches for that combination):**
- Strike zone rectangle + home plate (pitcher's POV, plate_x already flipped)
- **Season-long** projection-grade heatmap: pitcher's entire R-season `fb_grade` data (from Projections_Pitches_Grades, 20-80 scale) for that pitch type + count + hand, normalized to [0,1] via `(grade-20)/60`, placed on a 50×50 grid, smoothed with `scipy.ndimage.gaussian_filter(sigma=3)`, rendered with diverging Red→White→Blue colormap
- Game-day pitch location dots colored by pitch type (overlaid on season heatmap)
- Pitch count badge (top-right corner, game-day count)

**Count state definitions:**
| State | Filter |
|-------|--------|
| **0-0** | `balls_before=0 AND strikes_before=0` |
| **Pre-2K** | `strikes_before < 2` (all pre-2-strike counts, includes 0-0) |
| **2K** | `strikes_before = 2` (all 2-strike counts including 3-2) |

**Heatmap coloring (diverging Red → White → Blue):**
- Red (#D32F2F) = low projection grade (worse for pitcher)
- White (#FFFFFF) = average projection grade (~50)
- Blue (#1565C0) = high projection grade (better for pitcher)
- Scale: fb_grade 20-80 scouting scale (50 = league average)
- Alpha: proportional to pitch density (max 0.7), transparent where no data
- Only season pitches with non-null fb_grade contribute to heatmap; all game-day pitches show as dots
- Battery gradient key displayed at top of page (between LHH/RHH headers)
- Data source: `get_season_pitches()` queries R-game pitches for current season (falls back to prior year)

**Dependencies:** `scipy>=1.10.0` for gaussian smoothing (falls back to no heatmap if unavailable)

## Technical Stack

- Python 3.11+, matplotlib, plottable, pandas, Pillow, scipy
- SQL Server (GroundControl2) via sqlalchemy + pyodbc
- Posit Connect for hosting

## Streamlit App Features (`pages/2_Postgame.py`)

### Tab 1: Postgame (main analysis)
- **Sidebar:** Level → Pitcher search → Sched type multi-select → Period radio → Outing multi-select → Pitch type filter
- **Player switch:** Auto-detects new player's most recent sched type + resets date range + outing selection
- **Key KPIs:** FPinZ%, R2K%, EW%, 2K Proj with percentile-colored backgrounds
- **Statline:** Single-row metric cards with percentile coloring
- **Customize Table Columns:** Expander with 3 multiselects (Statline, Pitch Char, Pitch Results). Extra columns available: pBrl%, InZ%, R2K%, EW%, FPinZ% (statline); VAA, HAA, VRA, HRA (pitch char); pBrl%, EW%, Whiff%, R2K% (pitch results)
- **PDF "Save Report":** Passes custom column selections + rolling metric/mode to `generate_postgame_report()`. CLI automation uses defaults.
- **Rolling Chart:** Metric selector (Velo, Spin, Hop, HB, Ext, StuffRelVelo, SwDec, Proj, RelHt, RelSd, VAA) + On Pitch / Avg toggle
- **Click-to-video:** Movement scatter + rolling chart clicks open Synergy video

### Tab 2: Daily Tracker
- **Date picker** → shows all pitchers who appeared that day
- **Per-pitcher expander:** Movement chart (lasso/box select) + pitch table with Spin + video links
- **Pitch reclassification:** Select points → breakdown display → selectbox + Apply/Remove buttons (same pattern as Bullpen Daily)
- **Download PDF / bulk ZIP** per pitcher or all

## Schedule Types for Data

Games: R (Regular), S (Spring), E (Exhibition), V (Live BP), I (Intrasquad)
Percentiles: R only (Regular Season)
