# App: Barrelsville (Hitting)

Barrelsville is the hitting analytics app --- postgame hitter
reports, advance scouting, KPI weekly, and a half-dozen specialized
analyses. It's the second-largest of the four apps by code volume
(behind PD Engine + Org Board).

| | |
|---|---|
| **Branch** | `feature/barrelsville` |
| **Worktree** | `C:\Users\<user>\bsb-wt-hitting` |
| **App directory** | `barrelsville/` |
| **Posit Connect URL** | `connect2.astros.com/barrelsville/` |
| **App GUID** | `bbb53548-a7c5-4a03-9146-44647e7c88c0` |
| **Status** | DEPLOYED |

## What it ships

| Surface | Type | Cadence |
|---|---|---|
| **Postgame hitter PDFs** | Per-batter PDF, per-game on doubleheader days | Daily on game days |
| **Hitter advance scouting PDFs** | One PDF per opposing pitcher per affiliate level (combined RHH+LHH or per-side) | On series |
| **Hitter KPI weekly PDFs** | Per-level PDFs (all HOU hitters at that affiliate level) | Sunday |
| **Affiliate Tracker (live app page)** | Multi-tab leaderboard --- per-batter + org rankings + monthly + yearly | Live, refreshed via parquet pins (6h current-year; historical years frozen) |
| **Postgame app page** | Streamlit interactive postgame --- same data as the PDF | Live |
| **Advance app page** | Three tabs: Series Scouting, Pitcher Lookup, Pitcher Diagnostic (multi-gc-id stitching) | Live |
| **Hitter KPI app page** | Plotly version of the weekly KPI PDF | Live |
| **Org-wide hitter analysis (one-off PDF)** | Single multi-page PDF for all HOU MiLB hitters | Periodic (run from CLI) |
| **Hitter KPI snapshot** | Org-wide single PDF with percentile-colored table | Periodic |
| **Boxscore reports** | Single-game landscape PDF | Per-game |
| **Blast Motion reports** | Per-player swing-sensor analysis | On-demand |

## Key files

### Top-level

```
barrelsville/
├── Barrelsville.py              # Landing page (retro arcade, 3 active cards)
├── manifest.json                # rsconnect deploy allow-list
├── pages/                       # Streamlit pages
├── src/                         # Data + report modules
└── scripts/                     # CLI entry points
```

### Pages

| File | Purpose |
|---|---|
| `pages/1_Postgame.py` (~1300 lines) | Postgame hitting dashboard --- per-batter, per-game |
| `pages/3_Advance.py` | MiLB advance scouting (Level → Org → Pitcher flow) |
| `pages/4_Blast_Motion.py` | Per-player Blast Motion swing sensor app |
| `pages/5_KPI_Report.py` | Weekly KPI Plotly version + PDF download |

### Source modules (selected highlights)

| File | Purpose |
|---|---|
| `src/postgame_data.py` | Batter queries, game/timeframe stats, bat tracking, EV misread cleaning, gcOBA computation |
| `src/postgame_report.py` | PDF: header, configurable tables (17 metrics), 6 zone plots, RV heatmap |
| `src/postgame_percentiles.py` | Batter percentile distributions (per-level pools) |
| `src/postgame_app_data.py` | App-specific queries (sidebar, game sessions, BBC/WIN sched filter) |
| `src/advance_data.py` | Opposing roster (parameterized `ORG_LK`), scouting pitches (last 30 IP), count-state usage |
| `src/advance_report.py` | Advance PDF (2 summary pages + per-pitch-type density pages) |
| `src/advance_percentiles.py` | Pitcher percentiles at level (IZ%, velo, movement, release) |
| `src/advance_diagnostic.py` | Multi-gc-id stitching backend for the Pitcher Diagnostic app tab + the `generate_advance_oneoff.py` CLI |
| `src/hitter_kpi_data.py` | KPI chart data + player table data (17 metric columns) |
| `src/hitter_kpi_report.py` | KPI PDF (cover + 5 charts + 2 tables + overflow) |
| `src/tracker_data.py` | Affiliate Tracker SQL (single source for tracker page) |
| `src/weekly_hitter_data.py` | Weekly Hitter Player Report data |
| `src/weekly_hitter_report.py` | Weekly Hitter Player Report PDF |
| `src/bat_speed_clean.py` | Canonical bat speed cleaning helper (mirrors `pd-goals/src/bat_speed_clean.py`) |
| `src/video.py` | Video URL query + merge (batter hand-aware, `fallback_bat_side`) |
| `src/roster.py` | Roster queries, player lookup |
| `src/deliver.py` | Logic App delivery (`send_reports_via_logic_app` + `send_to_channel`) |
| `src/pins_config.py` | Posit Connect pins board connection (joblib-friendly) |
| `src/tracker_pins.py` | Tracker parquet pin read/write helpers |

### CLI scripts

| Script | Purpose |
|---|---|
| `scripts/generate_postgame.py` | Daily hitter postgame. **Doubleheader split**: produces ONE PDF per `(batter, sched_id)`, not per `(batter, date)` --- coaches can't separate G1 from G2 swing decisions when merged |
| `scripts/generate_advance.py` | Single-pitcher advance PDF (combined or per-side) |
| `scripts/generate_advance_batch.py` | Auto-detect upcoming series, generate advance PDFs for whole series |
| `scripts/generate_advance_oneoff.py` | Multi-gc-id stitching (non-EBIZ pitchers, mid-season callups) |
| `scripts/generate_hitter_kpi_report.py` | Weekly KPI per-level |
| `scripts/hitter_analysis.py` | Org-wide MiLB hitter analysis batch (8 pages/hitter) |
| `scripts/kpi_snapshot_3.py` | Full org hitter KPI snapshot PDF (roster-driven, percentile-colored) |
| `scripts/boxscore_report.py` | Single-game landscape PDF |
| `scripts/blast_report.py` | Per-player Blast Motion swing report |
| `scripts/generate_blast_leaderboard.py` | Org-wide Blast Motion leaderboard |
| `scripts/heart_zone_report.py` | Heart-of-the-zone org comparison |
| `scripts/lineup_card.py` | Printable lineup card |
| `scripts/pin_tracker_seasons.py` | Refresh tracker parquet pins (run from work laptop) |

## Architecture

```
Streamlit App (Posit Connect)
   │
   ├── pages/1_Postgame.py
   │     └── postgame_app_data.py (sidebar)
   │     └── postgame_data.py (data fetch)
   │     └── postgame_percentiles.py (color thresholds)
   │     └── postgame_report.py (PDF download)
   │
   ├── pages/3_Advance.py
   │     └── advance_data.py / advance_diagnostic.py
   │     └── advance_report.py
   │
   ├── pages/5_KPI_Report.py
   │     └── hitter_kpi_data.py
   │     └── hitter_kpi_report.py (PDF download)
   │
   └── pages/4_Blast_Motion.py
         └── BlastMotion.Metrics_View (DB direct)


CLI (work laptop)
   │
   ├── scripts/generate_postgame.py
   │     └── postgame_data + postgame_report
   │     └── deliver.py → Logic App → Slack
   │
   ├── scripts/generate_advance_batch.py
   │     └── advance_data + advance_report
   │     └── ZIP delivery (one PDF per pitcher in series)
   │
   └── scripts/generate_hitter_kpi_report.py
         └── hitter_kpi_data + hitter_kpi_report
         └── deliver.py → per-domain Slack channel
         └── (combined KPI stapler in PD Engine handles affiliate channels)
```

::: blocking
**DUAL QUERY PATH:** `get_game_pitches()` (CLI) vs
`get_game_pitches_for_app()` (app) MUST stay in sync. Same metric
computed on both paths must produce identical results. See Chapter 11
for the dual-query-path pattern.
:::

## Key features

### gcOBA, xwOBA, wRC+, pBarrel

All the canonical hitting metrics. See Chapters 4-5 for formulas.
Reference impl: `tracker_data.py` for SQL, `postgame_data.py` for
Python (event-anchored, `(sched_id, ab_event_id)` composite groupby
for swing distribution).

### Bat tracking (EV, LA, Hard%, PullAir%)

EV misread filter applied uniformly via `clean_ev_misreads()` and
`EV_MISREAD_CTE`. Bat speed at contact through the canonical helper
(see Ch 6).

### 6-category customizable table columns

Postgame app has six togglable column groups: Statline, Damage,
Contact, Approach, Ball Flight, Proj Outcome. Default-OFF supplementary
metrics: Hard% (Damage), Ch% (Contact).

### 2×3 zone grid + RV heatmap

Pre-2K / 2K × Takes / Swings / BIPs grid with RV Gain heatmap
backgrounds. Zone metric selector lets coaches switch between RV Gain
(default), xwOBA, zxwOBA.

### Strike zone framework (BLOCKING --- updated Apr 2026)

Two coexisting frameworks --- detailed in `.claude/rules/visual-standards.md`
and `.claude/rules/barrelsville.md`:

- **Framework 1 (ABS display SZ):** the solid rectangle drawn on
  every zone plot. Width ±0.708 ft, Z = `0.27 × height_ft` to
  `0.535 × height_ft`. Default height = `MLB_AVG_HITTER_HEIGHT_FT = 6.0212` ft.
- **Framework 2 (Tango classification):** the taxonomy for
  Heart/Shadow/Chase/Waste. Fixed X bounds (Heart ±0.558, Shadow
  ±1.108, Chase ±1.667). Z bands from Tango-extended zone (ABS SZ +
  1.5" pad) at 67% / 133% / 200%.

**ALL hitting zone boundaries --- visual rendering AND data
classification --- MUST derive from the single source of truth:**
`barrelsville/src/plots.py::abs_zone_bounds(height_ft)`. Never
hardcode.

### Glossary (English + Spanish)

At the bottom of every postgame app page and the final PDF page.
Generated from `astros-docs/Astros Glossary.pdf` (the same one
embedded as Chapter 5 of this handbook).

### Click-to-video

Plotly chart click → opens the video URL in a new tab. Pattern is in
`pdf-patterns.md`. Implementation: `@st.fragment` + `on_select` +
`_handle_chart_click(video_url_index=2)`. Used on strike zone, swing
zone, throws, blocks panels.

### Doubleheader split (BLOCKING --- May 3 2026)

`generate_postgame.py` produces ONE PDF per `(batter, sched_id)`, not
per `(batter, date)`. Doubleheader days yield TWO PDFs per affected
batter, ordered by sched_id ascending (`_G1` / `_G2` filename suffix).
Single-game days unchanged (no suffix).

Why per-sched_id, not per-date: a coach reading the day's PDF can't
separate game 1 swing decisions from game 2 swing decisions when
they're merged. Heatmaps blend two pitcher matchups, the PA strip
becomes 8 ABs in one block, "Game" timeframe row aggregates both.

## Hitter KPI table columns (17, Apr 13 2026)

```
Player, PA, gcOBA, xwOBA, wRC+, K%, BB%, K-BB%, Avg EV, Dmg%,
Ctct%, ZCtct%, ZSw%, OSw%, Whf%, PullAir%, BS
```

**Chart metrics (5):** K%, BB%, Dmg%, xwOBA, Avg EV.
**Rank badges:** Season-to-date from `get_org_cumulative_ranks()`,
not rolling chart values.

## Advance scouting

Three tabs in `pages/3_Advance.py`:

1. **Series Scouting** --- Level → Series → Pitcher (batch flow). Auto-detect upcoming series via `MLBAM.Schedule` + `MLBAM.Teams` + `mlb_ebis.gbl_club_lkup`.
2. **Pitcher Lookup** --- name search across all orgs/levels (single-id one-off).
3. **Pitcher Diagnostic** (May 5 2026) --- multi-gc-id stitching for non-EBIZ / just-promoted / split-tracking-id pitchers. In-app version of `generate_advance_oneoff.py`. Walks user through Players-rows table → pitch-activity-per-gc_id → R4 draft bridge auto-verdict → multi-select gc_ids (pre-checked DOB cluster) → metadata override fields → generate button → render inline + download PDF.

### Page-1 layout (Kyle Brennan spec, May 5 2026)

After a month of coach feedback, the summary page was reshuffled to
match how dugout coaches actually consume the report (~30-90s window
for a relief-pitcher matchup). Lives in `_render_summary_page()`:

```
y 0.88-1.00  Header (name | org | level | pos | T: hand | Ht | Age)
y 0.855      RHH/LHH handedness badges
y 0.816      BB% / GB-FB% / FB Ext stats row (LEFT 60%)
y 0.55-0.765 TOP ROW   : Characteristics table + Break chart (right)
y 0.315-0.515 MID ROW  : Pitch velo + IZ% bars + Usage% count-state
y 0.03-0.315 BOTTOM ROW: Top-3 Pitch Heatmaps (cells flush)
```

### Data scope

Last 30 IP at the selected level (walks backwards, crosses season
boundaries). Permissive level filter --- advance reports allow
amateur level codes (`bbc`, `sum`, `hsb`, `jcb`, `ind`, `int`, `min`)
because they window on recency, not level purity.

## Channel routing

Per-player postgame + KPI weekly PDFs route via
`pd-goals/data/slack_channels.csv` lookup:

- `zzz_<player_name>` --- coach channel (postgame, KPI metrics)
- `z_<player_name>` --- athlete channel (PD goals --- not Barrelsville)

KPI weekly per-domain channels:

| Level | Channel | ID |
|---|---|---|
| AAA | `sugarland_barrelsville` | (in CSV) |
| AA | `corpus_barrelsville` | (in CSV) |
| A+ | `asheville_barrelsville` | (in CSV) |
| A | `fayetteville_barrelsville` | (in CSV) |
| FCL | `fcl_barrelsville` | (in CSV) |

Boxscore PDFs go to a single fixed channel: `milb_boxscores` (`C0APYUYFYMP`).
Org-wide analysis + KPI snapshots go to `weekly-player-updates`
(`C0AVBKPEG8H`).

::: blocking
**Affiliate-channel delivery is NOT in this app.** That's owned by
`pd-goals/scripts/generate_combined_kpi.py` --- the combined KPI
stapler. After the 6 weekly KPI runs finish, the stapler combines the
PDFs and sends ONE per-level combined PDF to `z1_sugar_land`,
`z2_corpus_christi`, etc. Never re-add affiliate-channel delivery to
this script. See Chapter 13.
:::

## Tracker parquet pins

Six historical years (2020-2025) frozen as joblib pin bundles on
Posit Connect. Cold-load on those years drops from 5-60 s → sub-second.
Current year (2026) refreshes every 6 hours via Connect-scheduled
notebook (`barrelsville/connect_pins/`).

Pin name: `zbridger/barrelsville_tracker_<year>`. See Chapter 13 for
the full pin pattern.

## Where to look next

- **Chapter 11** for three-surface parity (tracker / KPI weekly / PD Goals org KPI for hitting metrics).
- **Chapter 12** for the SQL query playbook (Barrelsville is the largest consumer).
- `.claude/rules/barrelsville.md` --- the canonical app rule file.
- `.claude/rules/bat-speed-canonical.md` --- the bat speed playbook (Barrelsville is the canonical impl).
- `barrelsville/Barrelsville.py` --- start here when reading the actual code.
