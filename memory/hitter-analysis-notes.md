# Hitter Analysis Batch PDF — Notes

## Status (Mar 10, 2026)
- **Script:** `barrelsville/scripts/hitter_analysis.py` on `feature/barrelsville`
- **CLI:** `python scripts/hitter_analysis.py --season 2025 [--levels aaa aax] [--min-pa 50]`
- **Output:** `barrelsville/reports/Hitter_Analysis_2025_YYYY-MM-DD.pdf`
- **Status:** NEEDS WORK LAPTOP TEST — R-only default, data pipeline working

## What Works
- Roster: 76 MiLB hitters (excl MLB, DSL) from PP_MASTER
- Percentile distributions: 5 levels × 22 metrics, pre-fetched
- Per-player data: pitch_df + pa_df via `_query_timeframe`, both 2025 and 2024
- Per-level stats + PA-weighted Total row (wOBA, xwOBA, gcOBA, wRC+ all PA-weighted)
- SB query: `Events_StolenBases` with CAST(success AS INT)
- TopSpeed query: FIXED — `Baserun_Tracking_Metrics.groundcontrol_id` + direct Schedule_View join
- Results tables: hidden index, percentile coloring, removed OBP/SLG/OPS
- KPI tables: 2 stacked (vs RHP, vs LHP), rows: 2024/2025/Change with green/red arrows
- Zone heatmaps: L-shaped outer zones (Savant style), "xwOBA —" titles
- LHH video fallback: H → 6 (pushed to video.py)

## Current Columns — Results Table
Level | PA | K% | BB% | K/BB | wOBA | xwOBA | wLuck | gcOBA | wRC+ | Barrel% | TopSpd | SB

## Current Columns — KPI Tables
PA | Dmg% | BS | Barrel% | Ctct% | ZCtct% | Whf% | OSw% | ZSw% | HrtSw% | HrtTk% | PullAir% | LA | AA | xwOBA | gcOBA

## Zone Heatmaps — PER-BATTER ZONES IMPLEMENTED (Mar 10)
- **Visual:** Fixed 13-cell Savant-style grid (unchanged)
- **Metric classification:** Per-batter zone bounds from `get_batter_zone_bounds()` in `postgame_data.py`
  - SZ x = ±0.939 (equidistant heart/shadow), interior thirds at ±0.313
  - SZ z = per-batter from `swing_zone` in Pitches_View (heart/shadow midpoint)
  - Interior 3×3: player's SZ divided into thirds (x and z)
  - Outer zones (11-14): everything outside player's SZ, split by quadrant (x=0, z=midpoint)
  - Pitches left/right of SZ but within z-range → assigned to outer zones by vertical half
- Same `zone_bounds` dict used for both 2025 and 2024 (player's current zone profile)

## Key Imports from src/
- `postgame_data.py`: enrich_pitches, compute_game_stats, _query_timeframe, get_woba_weights, _compute_xwoba, _enrich_season_heatmap, get_batter_zone_bounds, BIP_CODES
- `postgame_percentiles.py`: get_level_percentiles, percentile_to_color, percentile_from_distribution
- `roster.py`: get_roster (player_type="H")
- `database.py`: run_query, _build_level_filter

## Formatting Fixes (Mar 10)
- `_fmt()` must pass through strings unchanged (Change row has "▲ 2.1" etc.)
- f3 format strips leading zero: `.340` not `0.340` (via `.lstrip("0")`)
- K/BB is a RATIO (K%/BB%), not subtraction. Format `f2`. Lower is better for hitters.
- Results tables: even 50-50 split (both 0.47 width)
- TopSpd: per-level P95 query, Total = max across levels
- SB: per-level count query, Total = sum across levels

## KPI Snapshot Script (Mar 10)
- **Script:** `barrelsville/scripts/kpi_snapshot.py`
- **CLI:** `python scripts/kpi_snapshot.py --season 2025 [--sched-types R]`
- **Output:** `barrelsville/reports/KPI_Snapshot_2025_YYYY-MM-DD.pdf`
- One landscape page: hitters top, pitchers bottom, percentile coloring
- Hitter KPIs: K%, BB%, K/BB, wRC+, xwOBA, Barrel%, TopSpeed, SBs
- Pitcher KPIs: K%, BB%, K/BB, Zone%, FIP, Whiff%, FB Velo, gcERA
- 3 hitters + 8 pitchers hardcoded (one-off ask)
- **Sched types: R-only default** (both stats and percentiles). CLI `--sched-types R S E` to include spring/exhibition.
- **Percentiles: ALWAYS R-only** (hardcoded in `get_level_percentiles()`)
- **2024 fallback:** No data for requested season → tries season-1 automatically
- **No-data players:** Show as rows with dashes (never dropped from table)
- **Hidden index:** `ColumnDefinition(name="index", width=0.001)` — ALWAYS use this pattern
- **Blue cell fix:** bbox with explicit `facecolor="#FFFFFF"` default. Color set post-render per row.
- **Per-row percentile coloring (affiliate tracker pattern):** Each player percentiled against MERGED distribution of ALL levels they played at, using the player's ACTUAL year (not always the CLI season — 2024 fallback players get 2024 distributions). Cache keyed by `"{level}_{year}"`. Render table with bbox (no cmap), then post-process each cell via `tab.cells[row_idx, col_idx + 1].text.get_bbox_patch().set_facecolor(color)`.
- **CRITICAL: plottable tab.cells off-by-one:** Hidden index column is at position 0, so display_df column indices need `col_idx + 1`. Without +1, colors go on wrong column — last columns (SBs, gcERA) get no color.
- **Distribution thresholds (match affiliate trackers):** Hitters: 50 PA. Pitchers: 200 pitches + 15 PA.
- **ALL metrics percentiled:**
  - Hitters: K%(k_pct,↓), BB%(bb_pct,↑), K/BB(k_bb,↓), wRC+(wrc_plus,↑), xwOBA(xwoba,↑), Barrel%(barrel_pct,↑), TopSpd(top_speed,↑), SBs(sb_count,↑)
  - Pitchers: K%(k_pct,↑), BB%(bb_pct,↓), K/BB(k_bb,↑), Zone%(zone_pct,↑), FIP(fip,↓), Whiff%(whiff_pct,↑), FB Velo(fb_velo,↑), gcERA(gcera,↓)
- **gcERA:** Calculated from pBarrel formula (EV >= 0.011*LA²-0.91*LA+95, EV<125 cap). pBarrel computed in Python from `h.hit_exit_speed` + `h.hit_vertical_angle` — NOT from `hp.pbarrel` (that column doesn't exist in Hits_Probabilities).
- **SB distribution:** Per-batter SB counts from `Events_StolenBases`, R-only. Higher = better (green).
- **Level exclusion in KPI snapshot:** `NOT IN ('win','bbc','int')` — int added because it's internal/private data.
- **Plottable kwargs that DON'T EXIST:** `columns_header_props`, `col_label_text_kw`. Use `col_label_divider_kw` only.

## Level Exclusion Standard (CRITICAL — Updated Mar 10)
**Apps/trackers standard:** `NOT IN ('win','bbc')` — matches `EXCLUDE_LEVELS_SQL` in `postgame_data.py`.
**Standalone scripts (KPI snapshot, hitter analysis):** `NOT IN ('win','bbc','int')` — int added explicitly because int can have R-tagged data that leaks through R-only sched_type filter.
- `win` = Winter League pseudo level
- `bbc` = pseudo sched type level code
- `int` = internal/private tracking — has some R-tagged data. Apps filter via `_build_sched_filter()`, but standalone scripts need explicit exclusion.

**Where exclusion happens:**
- `postgame_data.py`: `EXCLUDE_LEVELS_SQL = "('win','bbc')"` on all queries
- `postgame_app_data.py`: `NOT IN ('win','bbc')` + `_build_sched_filter()` handles pseudo types
- `tracker_data.py`: `_EXCLUDE_LEVELS_FROM_R` excludes pseudo level codes from R sched_type
- `_query_timeframe()`: excludes `win`/`bbc` + sched_type filter
- `kpi_snapshot.py`: `EXCLUDE_LEVEL_CODES = {"win", "bbc", "int"}` + SQL `NOT IN ('win','bbc','int')`

**DSL is separate from FCL/ACL:**
- DSL = `sv.level_code = 'rok' AND sv.league = 'DSL'` (gc2_level_code='dsl')
- FCL = `sv.level_code = 'rok' AND sv.league = 'FCL'`
- For MiLB roster queries, DSL excluded: `roster["level_code"] != "ds"`
- For wOBA weights, DSL uses `level_code = 'rok'` in Guts.woba_lwts

**Valid MiLB level_codes for reporting:** `rok` (FCL/ACL only), `afx`, `afa`, `aax`, `aaa`
**MLB:** `mlb` (included in some reports, excluded in MiLB-only contexts)

## Box Score Report (Mar 10)
- **Script:** `barrelsville/scripts/boxscore_report.py`
- **CLI:** `python scripts/boxscore_report.py --sched-id 12345`
- **Output:** `barrelsville/reports/Boxscore_{away}_{home}_{date}.pdf`
- **Status:** INITIAL STRUCTURE — needs work laptop testing
- Page 1: Linescore + batting tables (both teams)
  - Batting: Name | PA | 1B | 2B | 3B | HR | HBP | BB | SO | R | RBI | SB | FB S/M | OSS/M | HH | Av EV
- Page 2: Pitching tables with per-pitch-type breakdowns
  - Summary: Name | IP | BF | R | ER | H | HR | BB | SO | HBP | PIT | STR | Str% | P/PA | P/IP | 1PS | 1BO
  - Per-pitch: Pitch | Total | Use% | S/M | Str% | Velo | Spin | IVB | HB
- **TODOs:** R/RBI/ER need PBP table or Gamelog (not in Events_View). Team names via MLBAM.Teams.
- Team assignment: `ev.top_of_inning` (1=away batting, 0=home batting)
