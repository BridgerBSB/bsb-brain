---
paths:
  - "bullpen-report/**/*"
---

# Arm Farm — Pitching Analytics

## Purpose
Multi-page landscape PDF postgame pitcher reports + bullpen session analysis + affiliate tracking. Multi-page Streamlit app.

**Streamlit page convention (BLOCKING):** PDF-generation block goes LAST in any page script. See `.claude/rules/pdf-last-in-script.md`. Reference impl in this app: `pages/5_Pitcher_KPI.py:443` (canonical).

**Deployed on Posit Connect.** App GUID: `13482bcb-8ff2-4f20-92c9-5465f49e5846`

## Key Files
- `bullpen-report/Arm_Farm.py` — Landing page (retro arcade, 5 cards)
- `bullpen-report/pages/1_Side_Reports.py` — Bullpen session analysis [LIVE]
- `bullpen-report/pages/2_Postgame.py` — Postgame pitcher reports (~1770 lines) [LIVE]
- `bullpen-report/pages/3_Affiliate_Tracker.py` — Affiliate leaderboard [ALPHA V1]
- `bullpen-report/pages/4_Pitching_Advance.py` — MiLB advance scouting (series cascade + batter lookup) [LIVE]
- `bullpen-report/pages/5_Pitcher_KPI.py` — Pitcher KPI charts + tables (same pattern as Barrelsville KPI) [LIVE]
- `bullpen-report/src/postgame_report.py` — PDF drawing (plottable tables, custom column params)
- `bullpen-report/src/postgame_data.py` — Game pitch/PA queries, stat computation, gcERA
- `bullpen-report/src/postgame_percentiles.py` — League distributions + color mapping (6 queries)
- `bullpen-report/src/postgame_app_data.py` — App-specific queries (sidebar, game sessions)
- `bullpen-report/src/bullpen_data.py` — Shared constants (PITCH_TYPE_COLORS, enrich_pitches)
- `bullpen-report/src/plots.py` — Plotly charts (rolling velo, movement scatter, pie charts)
- `bullpen-report/src/reclassify.py` — Pitch reclassification (CSV-based)
- `bullpen-report/src/video.py` — Video URL lookup (Synergy)
- `bullpen-report/src/tracker_data.py` — Affiliate Tracker data + SQL queries
- `bullpen-report/src/advance_pitching_data.py` — Advance scouting data (hitter search, series, roster)
- `bullpen-report/src/advance_pitching_report.py` — Advance PDF (matchup KDE heatmaps, fb_grade/rv_gain)
- `bullpen-report/src/pitcher_kpi_data.py` — KPI chart data (30-org trends) + player table data
- `bullpen-report/src/pitcher_kpi_report.py` — KPI PDF (cover + 5 charts + 2 tables + overflow)
- `bullpen-report/scripts/generate_postgame.py` — CLI entry point

## Architecture
- `sys.path.insert(0, str(Path(__file__).parent.parent))` for src/ imports
- **DUAL QUERY PATH:** `get_game_pitches()` vs `get_game_pitches_for_app()` — MUST stay in sync
- `enrich_pitches()` in `bullpen_data.py` flips plate_x/horzbreak/release_x to **pitcher's view**

## LVA Pitch Result Marker Shapes (Page 2)
| Result | matplotlib | Plotly | Definition |
|--------|-----------|--------|------------|
| Whiff | `'o'` filled | `circle` | pitch_result_id IN (10,16,21,22,23) |
| Foul | `'s'` square | `square` | pitch_result_id IN (7,8,9) |
| Hard Hit | `'X'` cross | `x` | BIP with EV >= 89 |
| Weak | `'^'` triangle | `triangle-up` | BIP with EV < 89 or NULL |
| Take | `'o'` hollow | `circle-open` | Everything else (did_swing=0) |

## Key Features
- Click-to-video: Plotly chart click → video opens in new tab (see rules/pdf-patterns.md)
- Pitch reclassification via CSV overrides
- gcERA, gcPerf, stuff grades, Loc Grade
- Rolling velo charts, movement scatter, zone analysis
- **Player Plan Goals on postgame report** — reads from Posit Connect pin (`zbridger/pd_goals_data`)

## Postgame Tab1 Interactivity (May 14, 2026)

Per-pitch click-to-video now lives on **every per-pitch plotly chart** on
the Postgame tab1 main flow. Coaches can click any dot anywhere on the
page to open the CF angle video in a new tab — no per-plot UX
inconsistency.

| Chart | Customdata layout | Video index |
|---|---|---|
| Location scatter (line 1351) | `[pitch_num, date, velo, sched_id, pitch_id, url]` | 5 |
| Movement scatter (line 1359) | `[pitch_num, date, sched_id, pitch_id, velo, url]` | 5 |
| Release Point scatter (line 1412) | `[pitch_num, date, velo, sched_id, pitch_id, url]` | 5 |
| Rolling chart dots (line 1314) | `[pitch_num, date, raw_value, sched_id, pitch_id, url]` | 5 |
| LVA grid cells (lines 1580-1623) | `[sched_id, pitch_id, url]` | 2 |

Velo Distribution + Extension intentionally NOT click-to-video — they're
aggregate views (histogram / KDE), not per-pitch scatters. Rolling chart
in "Avg" mode maps each dot to the **anchor pitch** (most recent of the
5-pitch window). All plots use the count-based `_handle_chart_click()`
variant at line 335 of `pages/2_Postgame.py` (legacy, OK because the
dots are small enough that a re-click on the same dot is rare).

**Individual Pitches table** (line 1660) now respects the sidebar
pitch_type filter. Previously `pitch_log_df` (loaded from
`_cached_pitch_log()`) was independent of the filtered `pitch_df` —
deselecting a pitch type narrowed every chart but the table still
showed all types. Fix: filter `pitch_log_df` to `pitch_df['pitch_type']
.dropna().unique()` right after the concat, preserving NaN per the
ignore_flag recovery rule in `pitfalls.md`.

**PDF gen relocation** — see `.claude/rules/pdf-last-in-script.md` and
its graduation-log entry. PDF block now lives at end of tab1 instead
of mid-script, so charts paint immediately on player switch.

## Postgame — Per-PA Strike Zone Cards (Jun 7, 2026)

Coordinator request: in the pitch-log section, couple each plate
appearance's pitches together with a strike zone showing the sequence.
This **REPLACED** the flat pitch-log table on BOTH the PDF report and
the app (App↔Report parity) — pitches are no longer listed twice.

**Structure (report + app identical):** per outing → per PA → a "card" =
minimal header (`PA n — F. Last → Result`) + that PA's full pitch rows +
a plain-white strike zone below. In the zone, each pitch is plotted at
its location with the existing result-shaped, pitch-type-colored marker
(whiff ● / foul ■ / hard ✕ / weak ▲ / take ○) and a **small sequence
number rendered just ABOVE the marker** (offset, not centered, so it
doesn't cover the marker). No heatmap (plain white).

**Data layer — `src/postgame_data.py::_PITCH_LOG_QUERY`:** added
`-pv.plate_x AS plate_x` (flipped to **pitcher's view** to match the LVA
zones — the flat log query is otherwise raw; see `coordinates.md`),
`pv.plate_z`, `pv.batter_id`, `bp.first_name/last_name` (new
`LEFT JOIN Astros.Players bp ON bp.groundcontrol_id = pv.batter_id`),
and `ev.event_result AS pa_result` (`ev` already joined on `ab_event_id`
= the PA-terminal event). `ab_event_id` (PA grouping) + `ab_pitch_number`
(sequence) were already selected. `get_postgame_pitch_log` returns all
query columns, so these flow through to BOTH the report and the app
(the app's `_cached_pitch_log` wraps the same function — single source
of truth).

**Report — `src/postgame_report.py`:**
- `_render_pitch_log_table(ax_table, pitch_df, active_cols, percentiles)`
  — extracted from `_draw_pitch_log_page` so the table styling /
  percentile coloring / video links are one source of truth, reused by
  the cards.
- `_draw_pa_zone(ax, pa_df)` — plain-white SZ (reuses `_SZ_*`,
  `_HP_VERTS`, `_classify_pitch_result`, `_CAT_MARKER` from
  `_RESULT_MARKERS`, `PITCH_TYPE_COLORS`). Sequence number at
  `plate_z + ~0.20 ft`. Click-to-video via `_attach_clickable(... v_url)`.
- `_draw_pa_card` / `_draw_pa_card_page` — up to `PA_PER_PAGE` (3) cards
  per page; card/zone figure coords are **tunable**.
- Wired into the per-outing loop in `generate_postgame_report`, grouping
  `_outing_pitches` by `ab_event_id` (chronological, `sort=False`). The
  old flat pitch-log chunk loop was removed. `_draw_pitch_log_page` is
  kept defined but has **no live caller** (easy revert toggle).

**App — `pages/2_Postgame.py`:** the "Individual Pitches" flat table was
replaced by a "Plate Appearances" section. Per PA (grouped by sched_id
then `ab_event_id`): header (`**PA n — F. Last → Result**`) + the same
styled `st.dataframe` scoped to that PA (`_render_pa_pitch_table`, with
the V/Side ▶ LinkColumns preserved) + the report's `_draw_pa_zone`
rendered via `st.pyplot` in a narrow left column. The app reuses the
matplotlib `_draw_pa_zone` (no Plotly rewrite) per "as simply as
possible". The zone in-app is static (video access stays on the table's
▶ links). PDF-download block is below this section (pdf-last rule holds).

**Decisions (locked via brainstorming):** PA-card stack; full rows in
each card; plain-white zone; number offset above marker; cards REPLACE
the flat table (not additive). Design doc:
`bullpen-report/docs/plans/2026-06-07-pitcher-postgame-pa-strike-zones-design.md`.

**What NOT to do:**
- Don't reintroduce the flat pitch-log table alongside the cards (the
  whole point was to stop duplicating pitches).
- Don't add a heatmap behind the PA zones (plain white only).
- Don't center the sequence number on the marker — offset it above.
- Don't drop the `-pv.plate_x` flip — the zone must be pitcher's view
  to match the LVA zones.
- Don't let the report and app diverge — both render PA cards from the
  same `get_postgame_pitch_log` data and the shared `_draw_pa_zone`.

Commits (`feature/bullpen-reports`): `78b9aaea` (report cards) →
`b1defa7a` (cards replace flat table) → app mirror (this session).

## Unclassified-Outing Fallback + Position-Player Pitchers (Jun 2026)

### The fallback helper — ONE source of truth

Position players who pitch (mop-up / two-way), and some untagged FCL/DSL
games, come back **fully tracked** — velo / IVB / spin / location all
present — but with `pitch_type` **all NULL** because the classifier never
tagged them. Anything that groups or colors by `pitch_type` then drops the
all-NaN group: every pitch-type plot blanks, and on the CLI
`compute_pbp_results` returns an empty frame so the report bails
("no classified pitch types"). Only the PA-zone plot (plots by location)
survives.

Fix: **`bullpen_data.coerce_unclassified_outing(pitch_df, *, player_name=None,
verbose=False)`** — when the WHOLE outing is unclassified, coerce to one
neutral `UN` / "Unclassified" / `#888888` bucket so every plot renders.
Scoped to **fully** unclassified outings only — a normal pitcher's stray
untagged pitch is left as-is. `UN` is registered in `PITCH_TYPE_NAMES` +
`PITCH_TYPE_COLORS` so name/color resolve.

**This is the single source of truth — never re-inline the coercion.** It
was copy-pasted in postgame CLI + app (the dual-query-path trap, see
`dual-query-path.md`) before being centralized. Three call sites:

| Surface | File | Call |
|---|---|---|
| Postgame CLI | `scripts/generate_postgame.py` | after `apply_reclassifications` (verbose, named) |
| Postgame app | `pages/2_Postgame.py` | after video-merge, before pitch-type filter |
| Pitcher Analysis | `scripts/pitcher_analysis.py` | in `collect_player_data`, both season frames, post-query |

Apply AFTER any reclassification so manual `(sched_id, pitch_id)` tags
still win. Any NEW per-pitcher surface that groups by `pitch_type` MUST
call the helper, not re-copy the block. Shipped `22c91f9c`.

### Position-player pitchers — pools ALREADY count them (don't re-derive)

A position player who pitches needs **no special inclusion** in the pool
reports. Every Arm Farm pool query — KPI weekly (`pitcher_kpi_data.py`
`_PLAYER_QUERY`) and the affiliate tracker (`tracker_data.py`) — is
**pitch-driven**: `FROM Astros.Pitches_View pv ... GROUP BY pv.pitcher_id`,
with **no `player_type='P'` gate**. Whoever threw a pitch at that level is
in it. So position-player pitching has always been recorded in KPI weekly +
tracker, and it's baked into the tracker pin on every normal refresh —
**no re-pin is triggered by a position player pitching**, and there is
nothing to "add." (The KPI weekly roster filter at `pitcher_kpi_data.py`
~877 only narrows the **Season-table display** to active HOU roster via
`get_active_roster_ids`, which gates on `LEVELOFPLAY_LK` + `ORG_LK`, not
player_type.)

Inclusion (Fix B) is therefore scoped to **postgame only** (so a
position-player's outing gets a per-game report + flows to their zzz coach
channel in the daily cascade) — `roster.get_position_players_who_pitched`
augments the pitcher dropdown + the daily-cascade gate. The render-time
fallback above (Fix A) is the only thing the pool/per-pitcher *plots*
needed. Do NOT add a "exclude position-player pitching from the pitcher
percentile pool" change without explicit user direction — it's a judgment
call (mild noise in the distribution), and it currently lives in the pool
by design.

## Affiliate Tracker — Trends Tab YoY Row Filter = Level-Only (BLOCKING)

The Trends tab's **YoY** Player view filters its row set by **selected
levels ONLY** (`min_pitches=1`) — NEVER by `_PCTILE_THRESHOLD` (the
300-pitch *percentile-coloring* gate). MoM, WoW, and all four sibling
trackers (Barrelsville / Fielding / BR / Catcher) filter level-only; Arm
Farm alone had diverged, gating YoY rows on 300 pitches. In a partial
current season (e.g. 2026 before anyone reaches 300) that dropped **every
current-season row**, so 2026 silently vanished from YoY while showing in
MoM/WoW. Per-point coloring is independent (uses `trend_dists`), so it's
unaffected. Canonical: `pages/3_Affiliate_Tracker.py` YoY block calls
`_filter_df(yearly_df, selected_level_codes, min_pitches=1)`. Display-layer
only — **no re-pin**. Fixed Jun 2026.

## Player Plan Goals on Postgame Report (Apr 14, 2026)

Goals display on page 1 of the pitcher postgame PDF, left column (y=0.855→0.80).

**Data flow:**
1. `generate_postgame.py` line 311: `goals = load_player_goals(gc_id)`
2. `postgame_data.py::load_player_goals()` calls `_load_goals_data()` — pin first, CSV fallback
3. Filters to player's `groundcontrol_id`, takes `iloc[-1]` (most recent row)
4. Returns list of 3 goal strings (em dash `\u2014` for empty/missing/`"0"`)
5. `postgame_report.py::_draw_goals(fig, goals)` renders on PDF

**Files:**
- `src/pins_config.py` — board connection (identical to pd-goals copy)
- `src/postgame_data.py` — `load_player_goals()` + `_load_goals_data()` helper
- `src/postgame_report.py` — `_draw_goals()` rendering (lines 691-708)

**Env var:** `CONNECT_API_KEY` in Arm Farm app's Connect Vars tab.

## Movement Plot Enhancements (Apr 4, 2026)

### Season Covariance Ellipses
- 95% confidence (2.0 sigma), built from season pool (same cascading 2025+2026 R-game data as LVA)
- Only drawn for pitch types the pitcher threw in that outing, minimum 10 pitches per type
- Computed via numpy 2D covariance + eigenvalue decomposition

### Arm Angle Dashed Line
- Black dashed line from origin (0,0) at pitcher's average arm angle
- RHP: line goes upper-right. LHP: mirrored upper-left
- Data from `groundcontroltracking.tracking.pitch_hit_trajectories` + `play_starting_positions` + `mlbam.players`
- HawkEye venues — installed at ALL Astros affiliates, so all levels have data.
- App pages pass `sched_ids` so arm angle is reactive to selected outings

### Per-Pitch-Type Arm-Angle Box (Postgame Page 1 + App Row 3)
Added Apr 17 2026. Sits to the right of the Pitch Arsenal legend on the PDF and as a third chart row on the app. NOT the same as the movement-plot dashed line — that line stays as the pooled pitcher average; the box shows each pitch type separately for tipping detection.

**Layout:**
- Single quadrant. Origin lives at one corner; two dashed axes form the 'L' at that corner. Quadrant auto-picks from handedness + submarine detection (RHP normal → upper-right, LHP normal → upper-left, submarine → lower quadrant).
- One **dashed line per pitch type** from origin to `(flip_x · cos θ, sin θ)`, colored by `PITCH_TYPE_COLORS`. `flip_x = -1` for LHP so lefties mirror cleanly.
- **Per-type labels** stacked in the corner opposite the origin: `"FF 45.2° (40.1-50.3)"`, one decimal, colored by pitch. Sorted by angle descending so highest arm slot is on top.

**Data:** `get_arm_angle_by_pitch_type()` in `postgame_data.py`. Wraps Brodie's per-pitch formula in a CTE, then aggregates `AVG/MIN/MAX per pitch_type`. Returns `{pitch_type: {'avg', 'min', 'max'}}`. The per-pitch CTE avoids trying to compute min/max inside the nested `AVG(...)` Brodie expression.

**Reactive on app:** PDF generator now accepts `arm_angles_by_type` kwarg (see pdf-patterns.md → "App-Reactive PDF"). App page filters the dict to the pitch types present in the filtered `pitch_df` and passes the same dict to the chart and to the PDF generator.

**Renderers:**
- PDF: `_draw_arm_angle_box()` in `postgame_report.py`, axes `[0.17, 0.574, 0.134, 0.126]`
- App: `create_arm_angle_plotly()` in `plots.py`, added to Row 3 of `pages/2_Postgame.py`

### Render Locations (7 total)
| Location | File | Renderer |
|----------|------|----------|
| Postgame PDF | `src/postgame_report.py` | matplotlib |
| Bullpen PDF | `src/report.py` | matplotlib (arm angle only, no ellipses) |
| Side Reports app (event + daily) | `pages/1_Side_Reports.py` | Plotly |
| Postgame app (game + daily) | `pages/2_Postgame.py` | Plotly |
| Barrelsville advance PDF | `barrelsville/src/advance_report.py` | matplotlib |

### Key Functions
- `get_arm_angle()` — `postgame_data.py` (Arm Farm), `advance_data.py` (Barrelsville)
- `_compute_ellipses()` — `plots.py` (Arm Farm), `advance_report.py` (Barrelsville)
- `_draw_ellipses_mpl()` / `_draw_ellipses_plotly()` — matplotlib/Plotly renderers
- `_draw_arm_angle_mpl()` / `_draw_arm_angle_plotly()` — matplotlib/Plotly renderers

## Scripts
- `scripts/generate_postgame.py` — Game-day pitcher postgame PDFs. Args: `--date`, `--pitcher`, `--level`, `--milb`, `--deliver`, `--sched-type`, `--exclude`, `--z-channel`
- `scripts/generate_reports.py` — Bullpen session PDF reports. Args: `--date`, `--pitcher`, `--level`, `--milb`, `--deliver`, `--exclude`, `--z-channel`
- `scripts/pitcher_analysis.py` — Org-wide MiLB pitcher analysis batch (AAA-DSL). 6 pages/pitcher: results, usage pies, density plots. Args: `--season`, `--levels`, `--min-bf`
- `scripts/generate_count_usage.py` — Per-pitcher count-tree "diamond" PDF (12 counts 0-0 → 3-2). Pies = pitch-type usage at each count; edges = transition volume between counts. HOU MiLB only (MLB-rostered + MLB pitches excluded). Args: `--season` (required), `--individual` (per-pitcher PDFs instead of single batch), `--pitcher <gc_id>`, `--min-pitches N`, `--out <dir>`. Data layer: `src/count_usage_data.py`. See "Count Usage Tree" section below.
- `scripts/pitcher_kpi_snapshot.py` — **Pitcher KPI snapshot** PDF (org-wide, percentile-colored). Columns: K%, BB%, K/BB, Zone%, FIP, Whiff%, FB Velo, gcERA. Args: `--season`, `--levels`, `--spring`
- `scripts/generate_pitcher_kpi_report.py` — Weekly per-level pitcher KPI reports. Args: `--end`, `--weeks`, `--level`, `--deliver`
- `scripts/generate_advance_pitching.py` — Pitching advance overlay (pitcher vs opposing hitters). Args: `--opponent-org`, `--season`
- `scripts/generate_advance_pitching_batch.py` — Batch advance overlay for upcoming series. Args: `--level`, `--deliver`
- `scripts/velo_extremes_batch.py` — 10 fastest + 10 slowest per pitcher (video links). Args: `--season`, `--n`
- `scripts/velo_durability.py` — Velo & stuff durability (early vs late innings). Args: `--season`, `--levels`

## Pitcher KPI Metric Standardization (Audited Apr 6, 2026)
All KPI metrics verified to match tracker/postgame formulas:
- **EW%:** `balls_before<=1 AND strikes_before<=1` — all 4 early counts (fixed Apr 6, was only 0-0/1-1)
- **R2K%:** GC2 formula — ab_pitch_number=3, strikes_after>=2, gated by (pa=0 OR so=1). Excludes 3-pitch PAs ending in non-K contact. Switched Apr 13 2026.
- **Whiff%:** Gated by `did_swing=1`. Matches postgame.
- **FPinZ%, InZ%, 2K Proj, gcPerf, pBarrel:** All match tracker/postgame exactly.
- **gcERA:** PA-weighted everywhere (matches GC2). Global MLB HR rate with before-May fallback. See gc2-metrics.md.

## Affiliate Tracker — Pitch-Efficiency Metrics (P/Out, P/PA, P/K, P/BB) — Jun 23 2026

Four count-derived efficiency columns on the tracker — selectable in the
"Metric Columns" picker, OFF by default (opt-in, like GB%/BABIP/Kill%; NOT in
`_DEFAULT_METRICS` per Zac Jun 23). All `f1` (one decimal). Shipped Jun 23 2026
(commits `aa6bff96` add, `7b194c25`
K/BB-PA fix). Available in every grain — season leaderboard, org rankings, and
the MoM/WoW/YoY trend pickers (player + org), DSL split — because the derivation
lives in shared functions (`_add_pitch_efficiency_metrics()` per-pitcher +
`_merge_org_pa_metrics()` org).

| Metric | Formula | Direction | Notes |
|---|---|---|---|
| **P/Out** | total pitches / outs | lower = better | outs = gamelog gold w/ PA-outs fallback |
| **P/PA** | total pitches / BF | lower = better | every pitch belongs to a PA |
| **P/K** | **pitches in K-ending PAs** / strikeouts | lower = better (quick putaways) | NOT total pitches / K |
| **P/BB** | **pitches in BB-ending PAs** / walks | HIGHER = better (no cheap 4-pitch walks) | NOT total pitches / BB |

**BLOCKING — P/K and P/BB count only the pitches in the specific K/BB PAs** (Sean
Buchanan, Jun 23 2026): "average pitches per strikeout PA" / "per walk PA", NOT
`total_pitches / K`. Numerators `n_pitch_k_pa` / `n_pitch_bb_pa` =
`SUM(CASE WHEN ev.so/bb=1 THEN pv.ab_pitch_number END)` on the PA-final pitch
(`cur_event_id` join; `ab_pitch_number` 1-indexed = that PA's pitch count). Added
to all 4 base PA queries (`_PA_LEVEL_QUERY`, `_ORG_PA_QUERY`, `_ORG_MONTHLY_PA_QUERY`,
`_MONTHLY_PA_QUERY`); weekly inherits via `_monthly_to_weekly_sql`. Carried through
col_order + 7 stale-pin shims + org rollup + page `_combine_multi_level`. Re-pin
required for deployed values (stale-pin shim NaNs the columns until then). Standalone
one-off: `sql-queries/hou-current-pitchers-efficiency-2026.sql`.

## Affiliate Tracker — Org Rankings Must Match Individual
**BLOCKING RULE:** Any metric/formula used in the per-pitcher leaderboard MUST also be used in the org rankings tab. They share `_merge_org_pa_metrics()` but have separate SQL queries — check BOTH when changing formulas.

### IP Calculation (all three sections use Gamelog_Pitching gold standard):
| Section | Query | Gamelog Source |
|---------|-------|---------------|
| Per-pitcher leaderboard | `_get_gamelog_outs()` → merge by pitcher_id | `_get_gamelog_outs()` |
| Monthly breakdown | `_get_gamelog_outs(monthly=True)` → merge by pitcher_id + month | `_get_gamelog_outs()` |
| Org rankings (season) | `_ORG_GAMELOG_OUTS_QUERY` → merge by org | `glp.team_id → mt.org_abbrev` |
| Org rankings (monthly) | `_ORG_MONTHLY_GAMELOG_OUTS_QUERY` → merge by org + month | `glp.team_id → mt.org_abbrev` |

All four use `combine_first` fallback to `outs_after - outs_before` if Gamelog unavailable.
**NEVER use `AB - H + SF` for IP.** See `rules/ip-calculation.md`.

## Pitching Advance Heatmap Normalization (Tuned Mar 27, 2026)
- `_PROJ_MIN, _PROJ_MAX = 10.0, 70.0` — fb_grade (was 30-70, clipped 27% of player avgs)
- `_RV_MIN, _RV_MAX = -0.10, 0.10` — rv_gain (was ±0.05, clipped 25% of player avgs)
- Data-driven from per-player-per-pitch-type distributions (50+ sample min, 2025 R games)
- Visual-only change — data and smoothing untouched

## Pitcher KPI File Map (report + app — ALWAYS update BOTH)
| Component | File |
|-----------|------|
| Data | `bullpen-report/src/pitcher_kpi_data.py` |
| Report (PDF) | `bullpen-report/src/pitcher_kpi_report.py` |
| App Page (Plotly) | `bullpen-report/pages/5_Pitcher_KPI.py` (inline chart builder) |

## Pitcher KPI Table Columns (16 cols, Apr 13 2026)
Player, BF, FPinZ%, InZ%, R2K%, EW%, 2K Proj, K%, BB%, K-BB%, FB Velo, Whf%, SRV, Proj, gcERA, gcPerf

**Chart metrics (5):** FPinZ%, InZ%, R2K%, EW%, 2K Proj
**Rank badges:** Season-to-date from `get_org_cumulative_ranks()` (not rolling chart values)

## Pitcher KPI Percentile Pool Gate (Apr 7, 2026)
- **Pool gate:** 300+ pitches required to enter percentile distribution (`MIN_PITCHES_SEASON`)
- **Span display:** 50+ pitches to get colored in L2W table (`MIN_PITCHES_SPAN`)
- **Season display:** 300+ pitches to get colored in season table
- Players always display regardless of volume — gate only controls coloring
- EW%: all 4 early counts (balls<=1 AND strikes<=1), fixed Apr 6

## Count Usage Tree (May 13 2026)

Per-pitcher PDF: 12-node count "diamond" (0-0 → 3-2) where each node
is a pie of pitch-type usage in that count and grey edges show
transition volume between counts. Reference visual style:
`docs/plans/2026-05-13-pitcher-count-usage-design.png` (or any prior
Sporty-Clips-style count tree).

Designed for **MiLB only** (MLB pitches AND MLB-rostered pitchers
excluded by the SQL layer — `count_usage_data.py::_LEVELS` whitelist
+ `LOWER(pm.LEVELOFPLAY_LK) <> 'ml'`).

### Files
| Path | Purpose |
|---|---|
| `bullpen-report/scripts/generate_count_usage.py` | CLI + PDF renderer (matplotlib + PdfPages). Batch is default; `--individual` opt-in. |
| `bullpen-report/src/count_usage_data.py` | SQL + aggregation. Public API: `fetch_pitch_rows`, `add_transition_targets`, `aggregate_pitcher`. Topology constants: `COUNT_NODES`, `COUNT_EDGES`. |

### Topology (BLOCKING)
* 12 counts: `(0,0)` → `(3,2)` in `COUNT_NODES` order.
* 17 directed edges in `COUNT_EDGES`. Terminal counts (3-0 walk, 0-2 K-3, 3-2 resolution) only emit non-terminal edges since the next pitch is in the next PA.
* Fouls at 2 strikes do NOT generate an edge (no count change) — filtered in `aggregate_pitcher`.
* Edges are computed in pandas via lead-lag of `(balls_before, strikes_before)` within each `(sched_id, ab_event_id)` ordered by `ab_pitch_number`. PA-ending pitches contribute no outbound edge.

### Diamond layout (BLOCKING — do NOT use `b-s` math)
`_NODE_GRID` in `generate_count_usage.py` is the explicit (b, s) → (gx, gy) lookup. Rows 3-5 (1-2 / 2-1 / 3-0, then 2-2 / 3-1, then 3-2) sit DIRECTLY BELOW their row-2 / row-1 / row-0 mirror counterparts so 2-1 is vertically under 1-1, 1-2 under 0-2, 3-0 under 2-0, etc. The earlier sliding-column layout (`x = b - s`) is wrong — left in git history if needed.

### Edge widths (BLOCKING)
`_scale_edge_lw(n, max_n) = 1.6 + 12.5 * (n / max_n) ** 0.7`
* Per-pitcher max_n — a 300-pitch reliever and a 2,000-pitch starter both render a full-range diagram.
* Range: ~1.6pt (rarest active edge) → ~14.1pt (heaviest, usually 0-0 → 0-1 or 0-0 → 1-0).
* Inactive edges (n=0) render at 0.5pt linewidth + 0.20 alpha so the topology is still visible but the volume signal isn't muddied.
* Power 0.7 (not sqrt, not linear) — sqrt would over-flatten the thick side, linear would crush the thin side. Tuned to match the reference image's clear thick/thin contrast.

### Filter scope (BLOCKING — must mirror pitcher_analysis._get_milb_pitchers)
* `pm.ORG_LK = 'hou'` AND `pm.EMPLOYEE_FLG = 0`
* `pm.POSITION_LK IN ('RHS','RHR','LHS','LHR','TWP','SHS','P')`
* `LOWER(pm.LEVELOFPLAY_LK) <> 'ml'` — **MLB-rostered excluded**
* Inactive-status COALESCE NOT IN block (REL/FA/VOL/DIS/TI/RES + lowercase variants)
* `sv.sched_type = 'R'`, `YEAR(sv.sched_date) = :season`
* Level whitelist (6 MiLB levels): aaa, aax, afa, afx, rok, dsl. DSL/FCL split via `gc2_level_code` per `rules/level-codes.md`.
* Per-pitch: `pitch_id > 0`, `ignore_flag = 0`, non-null `pitch_type` / `balls_before` / `strikes_before`.
* **Conditional org gate (Jun 3 2026):** the `pm.ORG_LK='hou'` activity gate in `_get_milb_pitchers` is now bypassed when `--pitcher-ids` is passed (acquisition mode — see "Acquisition mode" above). Count-usage mirrors the NORMAL gate; acquisition mode is a manual one-off, never in the cascade.

### Pitch type colors
Canonical from `src/bullpen_data.py::PITCH_TYPE_COLORS`. Don't re-roll. If a new pitch type lands in `pv.pitch_type`, fallback color is `#888888` and pitch name displays the raw code.

### Dashboard reuse (planned)
The data layer (`count_usage_data.py`) is the dashboard integration point. A Streamlit / Plotly widget would call:
```python
from src.count_usage_data import (
    fetch_pitch_rows, add_transition_targets, aggregate_pitcher,
    COUNT_NODES, COUNT_EDGES,
)
raw = fetch_pitch_rows(season)
raw = add_transition_targets(raw)
agg = aggregate_pitcher(raw, pitcher_id)
# agg['by_count'], agg['by_transition'], agg['pitch_totals'], agg['meta']
```
A Plotly version would reuse `_NODE_GRID` + `_scale_edge_lw` from the script for layout/widths and emit `go.Scatter(mode='lines')` for edges + `go.Pie(domain=...)` for nodes. Legend mechanics unchanged.

### Future flex points (when integrating into the app)
* `sched_type = 'R'` is hard-coded — parameterize for Spring / Exhibition views.
* `pm.LEVELOFPLAY_LK <> 'ml'` is hard-coded — drop for an "all org incl. MLB" toggle.
* Level whitelist is fixed — pass a subset of `_LEVELS` for per-level filtering.
* `bat_side` is not filtered — adding `pv.bat_side = 'R'` / `'L'` produces vs-RHH / vs-LHH diamonds.
* Roster active filter (COALESCE NOT IN inactive) is hard-coded — drop for "include released" mode.
* Single-year scope — for multi-year, run once per year and concat; same `aggregate_pitcher` works.

### What NOT to do
* **Never** derive node positions from `x = b - s` arithmetic. Use `_NODE_GRID` lookup.
* **Never** include MLB pitches or MLB-rostered pitchers without an explicit user-facing toggle. This is intentionally MiLB-only.
* **Never** add a min-pitches gate at the data layer. Display-layer `--min-pitches` flag handles "hide sparse pages." Data layer must return every qualifying pitcher's rows so an interactive widget can render even a 30-pitch DSL kid if the user asks.
* **Never** filter level junk codes (win, int, bbc, hsb, sum, ind, etc.) ad-hoc. Use `_build_level_filter` from `src.database` for every level entry in the whitelist — same canonical pattern as `pitcher_analysis._get_milb_pitchers`.
* **Never** flatten pitches across (sched_id, ab_event_id) for transitions — the same physical sched_id+ab_event_id_id pair is one PA, and shifting across PAs would produce nonsense transitions (last pitch of PA-A "transitioning" to first pitch of PA-B).

## Pitcher Analysis — Current Page Layout (May 13 2026)

`scripts/pitcher_analysis.py` generates one PDF per pitcher with **8 pages** (or **4** with `--no-heatmaps`). User-direction-locked structure as of May 13 2026 — change only on explicit user feedback.

### Acquisition mode — `--pitcher-ids` (one-off scouting of non-HOU arms, shipped Jun 3 2026)

Run the same report on arbitrary pitchers by `groundcontrol_id`, bypassing the
HOU roster gate — for scouting potential acquisitions (e.g. Jack Dashwood).

```bash
python scripts/pitcher_analysis.py --season 2026 --pitcher-ids <gc_id> [<gc_id> ...]
```

* **Mechanism:** `_get_milb_pitchers()` takes an optional `pitcher_ids` param. When set, the `WHERE pm.ORG_LK='hou'` activity subquery is swapped for `pv.pitcher_id IN (<ids>)`; the gate also includes the **MLB** level (a pro target's only vs-HOU data may be MLB-level). Metadata `LEFT JOIN PP_MASTER`, percentile-pool level mapping, and the entire render path are **unchanged** — the target's real org/level/name resolve for free and they're colored vs their PP_MASTER level pool.
* **Purely opt-in, zero side effects.** With no `--pitcher-ids`, `acq_mode=False` and the run is byte-identical to before (same roster/SQL/PDF/delivery). The Monday `pit-analysis` cascade phase never passes it, so it's unaffected.
* **Local-only.** `--deliver` is **ignored** in acquisition mode (no channel routing for non-HOU arms) — it prints a notice and writes `output/..._ACQ.pdf` (the `_ACQ` suffix prevents clobbering an org run). No `LOGIC_APP_URL` needed.
* **`--pitcher-ids a b c` = three DISTINCT targets** (each own report). Single-human-split-across-multiple-gc_ids stitching is NOT this — that's the advance diagnostic flow (see `advance-non-ebiz-pitchers.md`).
* **Position-player pitchers render too.** `collect_player_data` calls `coerce_unclassified_outing` on both season frames, so an arm whose entire season is untagged `pitch_type` (a position player who pitched) renders as one "Unclassified" bucket instead of a blank PDF. See the Unclassified-Outing Fallback section above.
* **Data caveat (the real gate, not the code).** `Astros.Pitches_View` only holds a target's outings **vs HOU affiliates** (whether GC2 carries a wider pro feed is unverified). So coverage is thin or empty for an arm that hasn't faced our affiliates. Acquisition mode prints `[ACQ] N/M requested pitcher(s) have <season> data` + lists any gc_ids with no vs-HOU data, and **exits cleanly with a message instead of a blank PDF** when none found. A fuller-than-just-vs-HOU result is the signal GC2 has broader pro coverage — worth a follow-up to widen this if so.
* **What NOT to do:** don't wire `--pitcher-ids` into the Monday cascade or any scheduled job — it's a manual one-off scouting tool. Don't add channel delivery for it without a deliberate decision (non-HOU pitchers have no coach/affiliate channel).
* Shipped `9c3ae2c3` on `feature/bullpen-reports`.

### Page count
* `pages_per_pitcher = 4 if no_heatmaps else 8`. Total pages stamped in the "Page X of Y" footer.

### Page 1 — Results + All Batters KPI + Pitch Chars + Pitch Results (LANDSCAPE)
* **Header strip** (Astros navy + orange accent) — name, level, throws, season.
* **Per-level Results tables** — pitcher's per-affiliate W/L/IP/etc. Two side-by-side panels in dual-year mode (cur LEFT, prev RIGHT); full-width single panel in single-year.
* **KPI "All Batters" table** — single combined-handedness KPI block. Categories rendered as group headers above the column block: **Command** (FPinZ%, InZ%, R2K%, Loc) · **Swing & Miss** (Whiff%, EW%, SwDec) · **Contact Quality** (pBrl%, Avg EV) · **Projection** (SRV, Proj, 2K Proj, gcPerf) · **Ball Flight** (GB%, FB%). 3 data rows when dual-year: prev year / cur year / Chg.
* **Pitch Characteristics table (LEFT)** — combined-year (`'25` above `'26` per pitch). Column order `Yr | # | Pitch | Usg% | Velo | Spin | Hop | HB | Eff | Tilt | RelHt | RelSd | Ext | SRV`. Pitch col color-coded by pitch type via `PITCH_TYPE_COLORS`. Percentile cell coloring on Velo / Ext / SRV. **No arrows.**
* **Pitch Results table (RIGHT)** — combined-year. Column order `InZ% | Str% | Whiff% | 2KProj | 0-1 IZ% | Avg EV | SwDec | gcPerf | Proj` (no `Yr`/`Pitch` cols — chars table on the left labels each row). Percentile cell coloring on every metric. **No arrows.**
* **YoY Change row** — dual-year only. One row per pitch. Columns: Pitch + Usg% / Velo / Spin / Hop / HB / SRV / InZ% / Whf% / AvgEV / SwDec / gcPrf / **GB% / FB%**. Deltas colored green/red on perf metrics; black on Spin/Hop/HB/Usg/GB/FB (informational `hib=None`).

### Page 2 — Handedness (LANDSCAPE) — UNIQUE LAYOUT
Page 2 is intentionally unique — it's the side-by-side YoY comparison page. Layout rules below are BLOCKING; don't drift.
* **vs RHH KPI table** — same Command / Swing & Miss / Contact Quality / Projection / **Ball Flight** category grouping as page 1's All Batters block.
* **vs LHH KPI table** — same shape directly below.
* **Pitch Results vs RHH** — full-width combined-year. Column order `Yr | # | Pitch | InZ% | Str% | Whiff% | 2KProj | 0-1 IZ% | Avg EV | SwDec | SRV | Proj | gcPerf | GB% | FB%`. Differs from page 1's Pitch Results in three ways:
  - **Yr / # / Pitch** lead the row (page 1 results uses chars-table labels).
  - **SRV inserted before Proj** + **gcPerf moved to the very end** (page 2 unique).
  - **GB% / FB% appended after gcPerf** (Ball Flight at the trailing edge).
  - Coloring is TWO LAYERS:
    1. Cell bbox = percentile heat-map (BOTH `'25` and `'26` rows colored — same `_RESULT_PCTILE` map used elsewhere).
    2. Arrow overlay on `'26` row ONLY = colored ▲ / ▼ showing YoY direction vs `'25`. Green ▲ / red ▼ on perf metrics (per `_RESULT_HIB`); black ▲ / ▼ on GB% / FB% (informational `hib=None`).
* **Pitch Results vs LHH** — same shape below.
* **No footer** ("Generated YYYY-MM-DD | Page X of Y" intentionally removed from page 2).

### Page 3 — Pitch Usage Pies (LANDSCAPE)
* 2×3 grid: Usage / 0-0 & 1-1 / Putaway × LHH / RHH. One row per year in dual-year mode.

### Page 4 — Count Usage Tree (PORTRAIT — 8.5×11)
**Different orientation than every other page.** PdfPages handles the mix.
* Embedded via `_build_count_usage_agg(pitch_df, player)` + `render_count_tree_page` from `src/count_usage_render.py`. Same renderer as the standalone `generate_count_usage.py` CLI — byte-identical output.
* Computed from the already-fetched `pitch_df` (no second DB query).
* Renders in **both** `--no-heatmaps` and default mode (the page is inserted before the heatmap short-circuit `continue`).

### Pages 5-8 — KDE Density Heatmaps (LANDSCAPE) — `--no-heatmaps` SKIPS THESE
* Page 5: Location Density (RHH then LHH)
* Page 6: Whiff Density
* Page 7: Early Win Density
* Page 8: Hard Hit Density

### Per-pitch-type sort order (BLOCKING)
* `_compute_pitch_type_stats` returns rows sorted by `n_pitches` descending (most-used first).
* `_interleave_by_pitch_year` sorts pitch types by the MOST-RECENT year present in the input. Pitches only in older years append at bottom. Within each pitch, year rows follow input list order (callers pass `[(prev, ...), (cur, ...)]` so `'25` displays above `'26`).

### Cell-render mechanics (BLOCKING — Page 2 results table)
The percentile-bbox + colored-arrow combination on Page 2 Pitch Results requires two text artists per cell:
1. `cell.text` content = the formatted value only (e.g., `"57.0%"`). Default black color. Percentile bbox set via `cell.text.set_bbox(...)`.
2. **Separate overlay** = a small Text artist added via `ax.text(arrow_x, txt_y, "▲", color=arrow_color, ...)` at `txt_pos[0] + 0.40` (right of cell center, in plottable's column-width units where 1.0 = one metric col).

This is because matplotlib `Text` artists are single-color — you cannot mix colors within `cell.text`. Don't try to fix this with `cell.text.set_color()` — it tints the entire cell text and overrides the readability of the percentile-bbox-on-black-text pattern.

### Metric definitions (BLOCKING — all sourced from canonical references)
All metrics in pitcher_analysis match `gc2-metrics.md` + `arm-farm.md` canon, with two acknowledged display-only drifts (NOT blockers, deferred per user direction May 13 2026):

* **pBarrel% / Avg EV** — bunt filter (`hit_trajectory_id NOT IN (2,3,4)`) NOT applied here, despite being applied in `postgame_data.py` and `tracker_data.py`. Magnitude: ~0.1-0.3 mph drift on Avg EV at most, since bunts that survive the `EV > 0 AND < 125` gate are rare. Three call sites if/when this is fixed: `_compute_total_row`, `_compute_split_stats`, `_compute_pitch_type_stats`.
* **EV misread cleaning** — per-batter P95 deviation outliers NOT cleaned. Tracker applies `_EV_MISREAD_FILTER` in SQL; postgame applies `clean_ev_misreads()` in Python. pitcher_analysis is unaffected for gcOBA (per gc2-metrics.md rule #9 EV cleaning is excluded from gcOBA pool), but display Avg EV cells may be slightly inflated by misreads.

### Pitch type ordering (BLOCKING)
* `_PITCH_TYPE_ORDER` (in `count_usage_render.py` + sorted-by-usage elsewhere) is the canonical fastball→cutter→slider→curve→offspeed→exotic order. Both the count-usage diamond wedges AND the count-usage legend AND the per-pitch-type tables on pages 1/2 follow this convention.
* Pitch colors are owned by `src/bullpen_data.py::PITCH_TYPE_COLORS`. Never re-roll.

### What NOT to do (BLOCKING)
* **Never** add arrows to the Pitch Characteristics table or to the Pitch Results table on Page 1. Arrows are exclusive to: the YoY Change row (page 1) AND the Page 2 Pitch Results table.
* **Never** tint Page 2 Pitch Results cell values green/red — only the bbox (percentile) and the arrow overlay are colored. The value text stays black for readability.
* **Never** put GB% / FB% into the per-pitch-type Pitch Results tables on Page 1. They live in the KPI tables (per-handedness summary) + Page 1 YoY Change row + Page 2 per-pitch-type results. The Page 1 Pitch Results table stays minimal.
* **Never** add gcERA per pitch type. It's a PA-outcome metric (runs / outs) — there's no defensible attribution to a single pitch type in a PA where 5 pitches were thrown. Deferred indefinitely unless a per-pitch run-value attribution model lands.
* **Never** change Page 4 to landscape. The diamond geometry needs vertical room. PdfPages mixing orientations across pages is a feature, not a bug.
* **Never** add the footer back to Page 2. User direction May 13 2026 — handedness page reads clean.
* **Never** reorder Page 1 vs Page 2 layouts to match each other. They're intentionally different — Page 1 is the All Batters single-view page, Page 2 is the YoY+handedness comparison page.
