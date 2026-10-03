# Astros Barrelsville - Product Requirements Document

## Overview

Astros Barrelsville is a multi-page Streamlit app for hitting development analytics. It mirrors the Arm Farm architecture (retro arcade landing page, multi-page Streamlit, shared src/ modules) but focuses on hitter-facing analytics rather than pitching.

**Status:** DEPLOYED on Posit Connect (Feb 2026)
**App GUID:** `bbb53548-a7c5-4a03-9146-44647e7c88c0`

## Target Users

- MiLB hitting coordinators
- Affiliate hitting coaches
- Player development staff
- Front office (hitting analytics)

## Built Features

### Page 1: Postgame Hitting Reports [DEPLOYED]

Game-day hitter analysis covering all Astros org affiliates (MLB through DSL).

#### Player Header
- Navy header bar with headshot (MLBAM photo), player name, date, affiliate, B/T
- Astros logo, report generation timestamp

#### Daily Results (Statline Cards)
- Per-game stat cards with percentile coloring (red-white-green gradient)
- Default: PA, #P, K, BB, BIP, H, HH, Brl, Max EV, gcOBA, xwOBA
- Configurable via "Customize Table Columns" expander

#### Key KPI Tables (5 sections, 3 rows: Game / Month / Season)
- **Damage:** EV, Max EV, Dmg%, BS, Hard% (supplementary)
- **Contact:** Ctct%, ZCtct%, Whf%, Ch% (supplementary)
- **Approach:** OSw%, ZSw%, Hrt Sw%, Hrt Tk%
- **Ball Flight:** PullAir%, LA, AA
- **Proj Outcome:** xwOBA, gcOBA
- All percentile-colored (CSC-weighted zone metrics, league distributions)

#### Swings Table
- Per-swing detail: Pitch (type-colored), Hand, Count, Velo, Spin, Zone, Result, EV, LA, AA, BS
- Video links: Side + M (CF) columns with clickable play buttons
- Result classification: Ball, Called Strike, Foul, Whiff, 1B/2B/3B/HR/Out/Error, HBP

#### Strike Zones (2x3 grid)
- Columns: Pre-2K | 2K
- Rows: Takes | Swings | BIPs
- Per-batter personalized zones (heart/shadow/SZ z-bounds from ABS height formula via `abs_zone_bounds()`)
- Heatmap backgrounds from season data (100+ pitch threshold, cascading year/sched fallback)
- Zone metric selector: RV Gain (default), xwOBA, gcOBA
- Pitch-type colored markers with result-shaped symbols
- Click-to-video on zone markers

#### Configurable Columns (6-category expander)
- Statline, Damage, Contact, Approach, Ball Flight, Proj Outcome
- Toggle supplementary metrics (Hard%, Ch%) on/off
- Selections apply to BOTH app tables AND PDF output

#### Percentile System
- League-wide distributions by level + season (R-games)
- Red-white-green gradient: Poor (red) to Great (green)
- Metrics: EV, Max EV, Dmg%, Hard%, gcOBA, xwOBA, Ctct%, ZCtct%, Whf%, Ch%, OSw%, ZSw%, Hrt Sw%, Hrt Tk%, PullAir%

#### Glossary
- English + Spanish definitions for all metrics
- Zone explanations (Heart, Strike Zone, Shadow/Chase)

#### PDF Export
- Sidebar "Save PDF" → generates → "Download PDF" button
- Landscape 11"x8.5" with headshot, plottable tables, 2x3 zone grid with heatmaps
- Null values render as clean dashes (transparent bbox)
- Configurable columns match app selections
- Glossary on final page

#### Sidebar Controls
- Level selector (All Levels default)
- Player selector (roster dropdown)
- Schedule type multi-select (R/S/E/V/I + BBC/WIN pseudo-types)
- Period radio: Selected Dates, Recent Outing, Last 2 Weeks, Last Month
- Game outing multi-select (Select All / Clear All)
- Pitch type filter
- Pitch result filter (Whiff, Foul, Hard Hit, Weak, Take)

### Tab 2: Daily Tracker [DEPLOYED]

- Date picker → shows all hitters with appearances that day
- Sorted by level, expandable per-batter cards
- "Download Report" button generates + downloads PDF directly (no navigation)
- Mini metrics: PA, #P, P/PA

### Video Pipeline [WORKING]

- CF angle: M → a → v fallback (Video_Network)
- Side angle: by batter hand (RHH → F, LHH → H), fallback_bat_side from roster
- Swings table: LinkColumn with play button display
- Zone charts: click-to-video via customdata

### Slack Delivery [WORKING]

- `deliver.py`: parses groundcontrol_id from filename → CSV lookup → channel_id → POST to Logic App
- Azure Logic App: dumb pipe (HTTP trigger → Slack file upload)

## Data Sources

- `Astros.Pitches_View` — pitch-level data (plate_x, plate_z, pitch_result, CSC, swing_zone)
- `Astros.Events_View` — PA outcomes (1b, 2b, 3b, hr, bb, k, event_result)
- `Astros.Hits` — exit velo (`hit_exit_speed`), launch angle (`hit_vertical_angle`), spray (`hit_bearing`)
- `Astros.Hits_Probabilities` — per-BIP outcome probabilities for xwOBA
- `Astros.Bat_Tracking_Metrics` — bat speed, attack angle (HawkEye venues only)
- `Astros.Schedule_View` — game dates, levels, schedule types
- `Astros.Players` — player info, mlbam_id for headshots
- `Astros.Video` / `Astros.Video_Network` — pitch video URLs
- `Guts.woba_lwts` — wOBA weights by level + year (DB access)
- `Guts.hit_specs_ratios` — xwOBA exponents by season (DB access)

## Tech Stack

- **Language:** Python 3.11+
- **Framework:** Streamlit (multi-page app)
- **Database:** SQL Server (GCSQL02 / GroundControl2) via SQLAlchemy + pyodbc
- **Visualization:** Plotly (app), matplotlib + plottable (PDF)
- **PDF:** matplotlib + plottable (no reportlab)
- **Hosting:** Posit Connect (connect2.astros.com)

## Architecture

```
barrelsville/
├── Barrelsville.py              # Retro arcade landing page
├── pages/
│   └── 1_Postgame.py           # Postgame hitting reports [DEPLOYED]
├── src/
│   ├── database.py              # Dual-mode DB connection (Posit/local)
│   ├── roster.py                # Org roster queries (hitter-default)
│   ├── plots.py                 # Shared Plotly charts, heatmap helpers
│   ├── video.py                 # Video URL query + merge (batter hand-aware)
│   ├── postgame_data.py         # Batter queries, game stats, timeframe stats, bat tracking
│   ├── postgame_report.py       # PDF: header, KPI tables, swings, 6 zone plots, glossary
│   ├── postgame_percentiles.py  # Batter percentile distributions
│   └── postgame_app_data.py     # Game sessions, BBC/WIN sched filter, batters
├── assets/
│   └── astros_logo.png
├── scripts/
│   └── generate_postgame.py     # CLI: --date, --batter, --deliver, --exclude
├── reports/                     # Generated PDFs
├── manifest.json                # Posit Connect deployment
└── requirements.txt
```

## Next

- 2x3 zone heatmap iteration (layout refinement)
- BlastMotion integration for sensor bat speed (separate system from Hawkeye; captures both practice and in-game swings)
- Spray chart visualization
- MiLB Advance Reports (future page)
