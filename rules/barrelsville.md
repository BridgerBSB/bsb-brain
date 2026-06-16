---
paths:
  - "barrelsville/**/*"
---

# Barrelsville — Hitting Analytics

## Purpose
Postgame hitting reports + advance scouting for MiLB batters. Multi-page Streamlit app (same pattern as Arm Farm/Intangibles).

**Streamlit page convention (BLOCKING):** PDF-generation block goes LAST in any page script. See `.claude/rules/pdf-last-in-script.md`. Reference impl in this app: `pages/5_KPI_Report.py:437` (canonical).

**Deployed on Posit Connect.** App GUID: `bbb53548-a7c5-4a03-9146-44647e7c88c0`

## Key Files
- `barrelsville/Barrelsville.py` — Landing page (retro arcade, 3 active cards)
- `barrelsville/pages/1_Postgame.py` — Postgame hitting dashboard (~1300 lines)
- `barrelsville/pages/3_Advance.py` — MiLB advance scouting (Level→Org→Pitcher flow)
- `barrelsville/src/postgame_data.py` — Batter queries, game/timeframe stats, bat tracking
- `barrelsville/src/postgame_report.py` — PDF: header, configurable tables (17 metrics), 6 zone plots, RV heatmap
- `barrelsville/src/postgame_percentiles.py` — Batter percentile distributions
- `barrelsville/src/postgame_app_data.py` — Game sessions, BBC/WIN sched filter, batters
- `barrelsville/src/advance_data.py` — Opposing roster (parameterized ORG_LK), scouting pitches (30 IP), count-state usage, `get_pitcher_height_str()` (mlbam.players cross-walk)
- `barrelsville/src/advance_report.py` — Advance PDF: 2-summary-page layout + per-pitch-type density pages. Shared `_render_summary_page()` helper drives both `generate_advance_report` (single side) and `generate_combined_advance_report` (both sides)
- `barrelsville/src/advance_percentiles.py` — Pitcher percentiles at level (IZ%, velo, movement, release)
- `barrelsville/src/advance_diagnostic.py` — Multi-gc-id stitching backend for the Pitcher Diagnostic app tab + the `generate_advance_oneoff.py` CLI. Owns `fetch_outings`, `walk_to_max_ip`, `fetch_pitches`, `build_synthetic_pitcher`, plus diagnostic helpers (`search_all_players_by_name`, `get_pitch_activity_by_gc_ids`, `get_r4_draft_records`, `lookup_pp_master_metadata`, `auto_cluster_same_humans`, `suggest_default_selection`, `r4_bridge_status`)
- `barrelsville/src/video.py` — Video URL query + merge (batter hand-aware, fallback_bat_side)
- `barrelsville/src/roster.py` — Roster queries, player lookup (includes bats)
- `barrelsville/src/deliver.py` — Logic App delivery (send_reports_via_logic_app + send_to_channel)
- `barrelsville/scripts/generate_postgame.py` — CLI with --date, --batter, --level, --milb, --deliver, --exclude, --sched-type, --full-spring, --z-channel
- `barrelsville/scripts/generate_advance.py` — Single-pitcher CLI (combined PDF). Args: `--level`, `--org`, `--pitcher`, `--bat-side`, `--start-date`, `--deliver`. Default generates combined RHH+LHH
- `barrelsville/scripts/generate_advance_batch.py` — Batch CLI: auto-detect upcoming series. Args: `--level`, `--days` (default 7 = this week), `--series` (override), `--deliver`. App shows all series (no day limit)

## Architecture
- `sys.path.insert(0, str(Path(__file__).parent.parent))` for src/ imports
- **DUAL QUERY PATH:** `get_game_pitches()` (CLI) vs `get_game_pitches_for_app()` (app) — MUST stay in sync

## Postgame CLI — Doubleheader Split (BLOCKING, May 3 2026)

`generate_postgame.py` produces ONE PDF per (batter, sched_id), not per
(batter, date). Doubleheader days yield TWO PDFs per affected batter,
ordered by sched_id ascending (G1 / G2). Single-game days are unchanged
(no suffix).

Implementation lives in the per-batter loop:
- Fetch `pitch_df` + `pa_df` ONCE for the full day; merge video URLs once.
- `sched_ids_seen = sorted(pitch_df["sched_id"].unique())`. If `len > 1`,
  it's a DH and the loop slices both DataFrames by sched_id per render.
- `compute_game_stats` runs on the per-game slice → "Game" timeframe row
  reflects only that game.
- `compute_timeframe_stats` runs ONCE (Month/Season are date-scoped, not
  per-game). When DH, the per-game Game row replaces `timeframe_full[0]`;
  Month/Season rows are reused as-is.
- Percentiles, zone bounds, season heatmap data are all batter-scoped
  and fetched once per batter (NOT per game).
- `generate_postgame_report(filename_suffix=...)` appends `_G1` / `_G2`
  to the filename so DH outputs don't collide.

Why per-sched_id, not per-date: a coach reading the day's PDF can't
separate game 1 swing decisions from game 2 swing decisions when they're
merged. Heatmaps blend two pitcher matchups, the PA strip becomes 8 ABs
in one block, "Game" timeframe row aggregates both. Each game is a
separate competitive event and gets its own PDF.

App path (`pages/1_Postgame.py`) was unaffected by this change — it
already lets the user select sched_ids individually via the sidebar
multi-select.

NEVER undo this split. NEVER strip the `filename_suffix` kwarg from
`generate_postgame_report`. The single-game path still works because
`is_dh = False` → `suffix = ""` → filename matches the original pattern.

Same pattern would apply to Arm Farm pitcher postgame CLI
(`bullpen-report/scripts/generate_postgame.py`) if a coach asks for it
— that CLI currently still merges DH games into one PDF. Not yet ported.

## ignore_flag Recovery (Apr 2026) — BLOCKING
All Barrelsville queries include `pv.ignore_flag` as SELECT column (not WHERE filter). When `ignore_flag=1`: only `did_swing` and `pitch_type` are NULL. `plate_x`, `plate_z`, `release_speed`, `spin_rate`, `pitch_result_id`, `hit_exit_speed` are all populated.
- **SWING_CODES** constant in `postgame_data.py` = BIP + WHIFF + FOUL codes
- `enrich_pitches()` recovers `is_swing` from `pitch_result_id` when `ignore_flag=1 AND did_swing IS NULL`
- `pitch_name` maps NULL to "Unknown", `pitch_color` to "#888888"
- App pitch_type filter (line ~511 in 1_Postgame.py) includes `.isna()` for NULL pitch_type
- Strike zone plots loop over NULL pitch_type separately as grey markers
- Swing table handles None pitch_type/color/pitcher_throws with fallbacks
- SQL CASE WHEN `did_swing=1` has OR clause for recovery everywhere
- See `rules/pitfalls.md` for full 5-layer checklist

## Strike Zone Framework — BLOCKING RULE (Updated Apr 21, 2026)

**See `.claude/rules/visual-standards.md` for the full two-framework spec.** This rule codifies the Barrelsville enforcement.

Two coexisting frameworks:
- **Framework 1 (ABS display SZ):** the solid rectangle that gets drawn. Width ±0.708 ft, Z = `0.27×h` to `0.535×h` (no pad). Default height = `MLB_AVG_HITTER_HEIGHT_FT = 6.0212` ft.
- **Framework 2 (Tango classification):** the taxonomy for Heart/Shadow/Chase/Waste. Fixed X bounds (Heart ±0.558, Shadow ±1.108, Chase ±1.667). Z bands from Tango-extended zone (ABS SZ + 1.5" pad) at 67%/133%/200%.

**ALL hitting zone boundaries — visual rendering AND data classification — MUST derive from the single source of truth.** Never hardcode.

### Source of Truth

| Component | File / Function |
|---|---|
| Framework math | `barrelsville/src/plots.py::abs_zone_bounds(height_ft)` |
| Batter height lookup | `barrelsville/src/postgame_data.py::_lookup_batter_height(batter_id)` |
| Per-batter wrapper | `barrelsville/src/postgame_data.py::get_batter_zone_bounds(batter_id)` |

### Where This Applies

Every zone-aware Barrelsville surface — visual AND classification — must route through `abs_zone_bounds()`:

- `compute_game_stats()` — Hrt/Shd/Chase/Waste Sw%/Tk% classification (accepts `height_ft` param)
- `compute_timeframe_stats()` — looks up height once, passes to all `compute_game_stats()` calls
- `1_Postgame.py` — Plotly zone rendering (SZ solid + Heart dotted + Shadow dotted) + game stats
- `postgame_report.py` — PDF zone rectangles via `get_batter_zone_bounds()`, same 3-layer render
- `postgame_percentiles.py` — percentile pool (per-batter via SQL JOIN on `mlbam.players`)
- `weekly_hitter_data.py` — heart-pitch SQL classification (per-batter via Tango X+Z formulas)
- `weekly_hitter_report.py` — heart chart visual (SZ solid + Heart dotted + Shadow dotted)
- `hitter_analysis.py` — player stats + handedness splits
- `kpi_snapshot_3.py` — snapshot stats
- `heart_zone_report.py` — org heart-zone comparison SQL (Tango X + per-batter Z)
- `generate_postgame.py` — CLI spring + daily paths

### Rendering Policy (locked Apr 21, 2026)

Three-surface parity — postgame PDF, postgame app, weekly hitter heart chart render identically:

- SZ rect: solid black, linewidth 2
- Heart rect: dotted, edge `#555555`, lw 0.9, fill `#90EE90` (mpl) / `rgba(76,175,80,0.1)` (Plotly)
- Shadow rect: dotted, edge `#888888`, lw 0.7, fill `#f5f5f5` (mpl) / `rgba(200,200,200,0.1)` (Plotly)

### BLOCKING — Visual AND Data Must Match (Tango)

If you DRAW a Heart rect at given bounds, the `Hrt Sw%` / `Hrt Tk%` you report must be computed against THE SAME bounds. Both come from a single `abs_zone_bounds()` call — never re-derive inline, never hardcode alongside.

### NEVER Hardcode These Retired Values

- **Retired X bounds:** `±0.587`, `±0.829`, `±0.121` (ball-radius-inset system)
- **Retired Z defaults:** `1.5/3.5` generic default, `1.83/3.17`, `1.665/3.335` (fixed ranges)
- **Retired Z math:** `sz_bot + 0.121` / `sz_top - 0.121` (ball-radius inset formulas)
- **Retired older system:** `±0.75 / ±0.939 / ±1.128` (pre-ABS)

### Bug History

- **Apr 18 2026:** `compute_game_stats()` was using hardcoded 5'10" for all batters. Visual rectangle and percentile pool already used actual height. A 6'5" batter's heart was drawn correctly but Hrt Sw% counted pitches with a 5'10" box.
- **Apr 21 2026:** Refactored Heart/Shadow/Chase classification from ball-radius-inset (Heart ±0.587 X, Z inset by 0.121) to Tango framework (Heart ±0.558 X, Z 67% band from Tango-extended center). Visual + data unified via single `abs_zone_bounds()` source. BREAKING change for historical comparisons; forward values only. See `docs/plans/2026-04-21-tango-sz-refactor.md` and `.claude/rules/sz-planning-prompts.md` for the full refactor history.

## Key Features
- gcOBA, xwOBA, wRC+, pBarrel, video URLs, bat tracking (EV, LA, Hard%, PullAir%)
- 6-category Customize Table Columns: Statline, Damage, Contact, Approach, Ball Flight, Proj Outcome
- Supplementary metrics: Hard% (Damage), Ch% (Contact) — toggle-able, default OFF
- 2×3 zone grid (Pre-2K / 2K × Takes / Swings / BIPs) with RV Gain heatmap backgrounds
- Zone metric selector: RV Gain (default), xwOBA, zxwOBA
- Glossary (English + Spanish) at bottom of app + final PDF page
- Daily Tracker: "Download Report" generates + downloads PDF directly
- PDF null fix: transparent bbox for null values (see rules/pdf-patterns.md)
- Video: CF (M→a→v), Side by batter hand (RHH→F/7, LHH→H/6), `fallback_bat_side` from roster

## Affiliate Tracker — DSL Organization Split (LIVE May 27 2026, pilot)

LIVE on `feature/barrelsville` commit `a4ed17ae`. On the Org Rankings
tab, a new **"DSL" radio toggle** (Off / Split) appears at the top
when DSL is in the selected level set. "Split" expands DSL franchises
into one row per sub-team (HOU → "DSL - Blue" / "DSL - Orange"). Other
30 orgs with multi-team DSL get the same treatment.

**Scope (locked, do NOT extend without user direction):**
- Org Rankings tab ONLY (per-player leaderboard, monthly trends,
  league pools, KPI weekly, postgame all unchanged)
- Pool definition unchanged — percentile coloring still uses full DSL
  pool per `level-codes.md` two-layer rule
- H/A orthogonal; R/L hand-split deferred
- Live DB v1 — does NOT use pins (pins are unsplit by definition)
- Hitter pilot; propagation to BR/Catcher/OF/IF awaits user direction
  after pilot validation

**Files (touchpoints — keep in sync when changing):**
| Role | File |
|---|---|
| Data layer queries (with `{team_select_*}` / `{team_group_*}` placeholders) | `barrelsville/src/tracker_data.py` (6 `_ORG_*_QUERY` constants) |
| `_get_single_level_dsl_split_org_stats()` helper | same file, after `_get_single_level_org_stats` |
| `get_org_rankings_dsl_split()` wrapper | same file, after `get_org_rankings` |
| Team-name resolver + hardcoded HOU map | same file, `_DSL_TEAM_LABELS` + `_resolve_dsl_team_label` |
| `DSL_SPLIT_NO_COLOR_COLS` frozenset (currently empty for hitter) | same file |
| UI toggle + dispatch + relabel + HOU expansion | `barrelsville/pages/2_Affiliate_Tracker.py` |
| Cache loader | same file, `_load_org_rankings_dsl_split` |
| Spec doc | `barrelsville/docs/plans/2026-05-27-dsl-org-split-design.md` |

**v1 known limitation:** Hardcoded HOU team labels (Blue = 599,
Orange = 10000055). Other 29 orgs' DSL sub-teams render as "Team N"
with the raw team_id. Follow-up: load all 30 orgs' labels from
`MLB_eBis.GBL_CLUB_LKUP` at module init (pattern from
`pd-goals/pages/5_Org_Board.py::load_global_club_map`). Discovery SQL
at `sql-queries/dsl-split-discovery.sql` verifies the schema before
that integration.

**What NOT to do (BLOCKING):**
- Don't extend split to other tabs without explicit user direction
- Don't add a per-sub-team percentile pool — pool stays full-DSL
- Don't ship to BR/Catcher/OF/IF until pilot validated
- Don't suppress coloring on rate/avg/P-metric columns — only
  cumulative SUM cols (and hitter's `DSL_SPLIT_NO_COLOR_COLS` is empty)
- Don't drop the `{team_select_*}` / `{team_group_*}` placeholder
  passthrough in `_get_single_level_org_stats` — defaults to empty
  strings (zero behavior change for non-split path); removing breaks
  the format() calls

See `docs/plans/2026-05-27-dsl-org-split-design.md` for the 13 locked
design decisions + concrete shape diagrams + the full architecture.

## Advance Scouting
- **Three tabs in `pages/3_Advance.py`:**
  - Series Scouting — Level → Series → Pitcher (batch flow)
  - Pitcher Lookup — name search across all orgs/levels (single-id one-off).
    **Custom Dates mode (NEW May 14 2026)** — Scope selectbox above Early
    Mode lets the coach swap "Default (last 30+ IP)" for "Custom Dates"
    + a date range (defaults Jan 1 current year → today) + a sched-types
    multi-select (R/S/E/I, all checked by default). When active: Early
    Mode checkbox disables; `get_scouting_pitches()` bypasses the
    30-IP cap entirely, runs `BETWEEN start AND end` with no `YEAR()`
    constraint (cross-year ranges supported). Percentile pool uses
    `start.year`. PDF filename gets a `_YYYY-MM-DD_to_YYYY-MM-DD`
    suffix so multiple windowed scouts of the same pitcher don't
    collide. Series Scouting + Pitcher Diagnostic tabs + all 3 CLI
    scripts (`generate_advance.py`, `generate_advance_batch.py`,
    `generate_advance_oneoff.py`) are intentionally untouched.
  - Pitcher Diagnostic (NEW May 5 2026) — multi-gc-id stitching for non-EBIZ /
    just-promoted / split-tracking-id pitchers; in-app version of
    `generate_advance_oneoff.py`. Walks user through Players-rows table,
    pitch-activity-per-gc_id, R4 draft bridge auto-verdict, multi-select
    gc_ids (pre-checked DOB cluster), metadata override fields, generate
    button → renders inline + Download PDF. See `advance-non-ebiz-pitchers.md`.
- **Arm angle:** `get_arm_angle()` in `advance_data.py` computes via Brodie formula.
  Wired into app, CLI, batch, and one-off. Draws dashed line on break chart via
  `_draw_arm_angle_mpl()`.
- Opposing pitcher roster via PP_MASTER with parameterized `ORG_LK`. Pitcher
  Diagnostic uses raw `Astros.Players` (no PP_MASTER inner-join) so stubs +
  amateur tracking ids surface alongside the real row.
- Data scope: last 30 IP at selected level (walks backwards, crosses season
  boundaries). Permissive level filter — see `advance-levels.md`.
- Count-state buckets: First Pitch, 0/1K, Plus2, Full, 2K
- Usage% color thresholds (FIXED, not percentile): <45%=white, 45-55=light green, etc.
- **Single-pitcher CLI:** Two PDFs per pitcher (vsLHH + vsRHH)
- **Batch CLI:** One combined PDF per pitcher (RHH + LHH), ZIP delivery
- **One-off CLI:** `generate_advance_oneoff.py` IN-clauses N gc_ids for
  multi-id humans. Same module (`advance_diagnostic.py`) powers both this
  CLI and the Pitcher Diagnostic app tab — single source of truth.
- **Batch flow:** Auto-detect upcoming series via `MLBAM.Schedule` + `MLBAM.Teams` + `mlb_ebis.gbl_club_lkup`
- **Org quirks in `gbl_club_lkup`:** `la→lad`, `chi→chc`, `ny→nym` — eBis club codes don't match ORG_LK directly
- **DSL series query:** Must pass `sport_code='rok'` (not 'dsl') and isolate DSL via `gbl_club_lkup` with `LEVELOFPLAY_LK='ds'`

### Page-1 Layout (Kyle Brennan spec May 5 2026)

After a month of coach feedback, the summary page was reshuffled to match
how dugout coaches actually consume the report (~30-90s window for a
relief-pitcher matchup). Lives in `_render_summary_page()`:

```
y 0.88-1.00  Header (name | org | level | pos | T: hand | Ht: 6'2" | Age: 23.4)
y 0.855      RHH/LHH handedness badges
y 0.816      BB% / GB-FB% / FB Ext stats row (LEFT 60% only)
y 0.55-0.765 TOP ROW   : Characteristics table (LEFT 60%) + Break chart (RIGHT)
y 0.315-0.515 MID ROW  : Pitch velo + IZ% bars (LEFT 40%) + Usage% count-state (RIGHT 60%)
              ← right table capped at h=0.20 to align with left bottom (May 6 2026)
y 0.03-0.315 BOTTOM ROW: Top-3 Pitch Heatmaps (cells flush w/ mid-row bottom)
```

- IZ% bar in pitch velo table renders a full-100% white container so
  un-shaded headroom is visible at a glance (May 5 2026)
- Top-3 heatmap row uses pooled-across-all-counts strike-zone density
  via `_draw_top3_heatmap_row()`. **Pitch order = top-3 most-used pitch
  types vs that side; if pitcher has only 2 pitches, 3rd cell is blank
  (per Kyle's spec).** Each pitch's plate_x is NEGATED for pitcher's-view
  orientation matching the rest of the report's density plots
  (despite `coordinates.md` saying "advance = catcher's view" — the
  whole advance report is actually pitcher's view).
- **SZ outline canonical (May 6 2026):** `_SZ_BOT`/`_SZ_TOP` driven by
  `plots.abs_zone_bounds(None)` → 1.626–3.221 ft (avg MLB hitter), matching
  every other Barrelsville report. Legacy hardcoded 1.5/3.5 (2.0 ft tall)
  was 25% taller than canonical and was the source of a hitting-coordinator
  flag. Pitcher-view scope → no hitter-specific Z, so `None` is correct.
- **Heatmap aspect ratio (May 6 2026):** `_draw_density_heatmap` calls
  `ax.set_aspect("equal")` so 1 ft x = 1 ft y on page. SZ rectangle
  renders at true 0.89 W:H proportions. Top-3 cell shape derived from
  data aspect (4 ft × 4.3 ft → 0.93 W:H) so cells fill with no interior
  whitespace. Each cell ~2.25" × 2.42" with 0.55" gap between, centered
  with 1.57" side margins.
- **Usage table sort (May 6 2026):** count-state Usage% rows are sorted
  to mirror the IZ% table on the left (pitch_summary's num_pitches-desc
  order via the new `pitch_type_order` param). Type column starts further
  left (axes-x 0.05) and first count-state column at axes-x 0.22 so
  longer pitch names ("Curveball", "Changeup") don't bump "First Pitch".
- **Section title removed (May 6 2026):** the "Top 3 Pitch Heatmaps
  (all counts)" header above the row is gone — cells self-label with
  pitch type + count, and removing it lets cell tops reach the mid-row
  table bottoms (fig-y 0.315) for max rendered area.
- Header height resolved via `get_pitcher_height_str(mlbam_id)` from
  `mlbam.players`. Age computed in SQL (`FLOOR(... / 365.25 * 10) / 10`)
  and displayed 1 decimal per BLOCKING rule #9.

### Page Order (combined PDF)
1. RHH summary (page 1)
2. LHH summary (page 2)  ← coaches flip back-and-forth between summaries
3. RHH per-pitch-type pages (sorted by usage)
4. LHH per-pitch-type pages (sorted by usage)

If one side has 0 pitches, that side's pages are skipped entirely.

## Hitter KPI Metric Standardization (Audited Apr 6, 2026)
All KPI metrics verified to match tracker/postgame formulas:
- **K%, BB%:** PA-weighted sums. Match tracker exactly.
- **wOBA:** IBB excluded from both numerator and denominator. Match tracker exactly.
- **wRC+:** Recomputed per-batter from wOBA + league env (never averaged). Match tracker exactly.
- **gcOBA:** Same swing-dist coefficients, both use MLB OBP base. Match tracker exactly.
- **xwOBA:** PA-weighted `SUM(numer)/SUM(denom)` at daily→weekly→4-week rolling levels (fixed Apr 6, was mean-of-ratios).
- **Dmg%, Avg EV:** Bunt filter `hit_trajectory_id NOT IN (2,3,4)` applied in BOTH org chart queries AND player table queries (fixed Apr 6, was missing from charts).

## Hitter Weekly Batch CLI
- `--end` (required), `--level`, `--deliver` (zzz), `--deliver-z` (z athlete channels)
- Delivery flags stackable — send to both z and zzz with `--deliver --deliver-z`

## Scripts (beyond core CLIs above)
- `scripts/hitter_analysis.py` — Org-wide MiLB hitter analysis batch (all AAA-DSL). 8 pages/hitter: results, zones, contact density, heatmaps. Args: `--season`, `--levels`, `--min-pa`
- `scripts/kpi_snapshot_3.py` — Full org **hitter KPI snapshot** PDF (roster-driven, percentile-colored). Args: `--season`, `--level`, `--spring`
- `scripts/generate_hitter_kpi_report.py` — Weekly per-level hitter KPI reports. Args: `--end`, `--weeks`, `--level`, `--deliver`
- `scripts/hitter_whiff_analysis.py` — Per-player whiff analysis (13-zone grids + count-state). Args: `--batter`, `--season`
- `scripts/boxscore_report.py` — Single-game landscape PDF box score. Args: `--date`, `--sched-id`, `--level`, `--deliver`, `--logic-app-url`. All boxscores → `milb_boxscores` channel (`C0APYUYFYMP`)
- `scripts/blast_report.py` — Blast Motion per-player swing report (DB-powered). Spanish glossary
- `scripts/generate_blast_leaderboard.py` — Blast Motion org-wide leaderboard PDF. Args: `--start`, `--end`, `--output`
- `scripts/generate_bat_speed_report.py` — Org bat speed rankings PDF
- `scripts/generate_milb_org_rankings.py` — MiLB org-wide bat speed rankings (all 30 orgs)
- `scripts/heart_zone_report.py` — Heart of the zone 2025 org comparison (4 pages)
- `scripts/lineup_card.py` — Printable lineup card PDF

## Hitter KPI File Map (report + app — ALWAYS update BOTH)
| Component | File |
|-----------|------|
| Data | `barrelsville/src/hitter_kpi_data.py` |
| Report (PDF) | `barrelsville/src/hitter_kpi_report.py` |
| App Page (Plotly) | `barrelsville/pages/5_KPI_Report.py` (inline chart builder) |

## Hitter KPI Table Columns (17 cols, Apr 13 2026)
Player, PA, gcOBA, xwOBA, wRC+, K%, BB%, K-BB%, Avg EV, Dmg%, Ctct%, ZCtct%, ZSw%, OSw%, Whf%, PullAir%, BS

**Chart metrics (5):** K%, BB%, Dmg%, xwOBA, Avg EV
**Rank badges:** Season-to-date from `get_org_cumulative_ranks()` (not rolling chart values)

## Barrelsville Metric Definitions — Cross-File Reference (Audited Apr 7, 2026)

These are the SETTLED, VERIFIED definitions. Do NOT re-audit these — they are consistent across
`postgame_data.py`, `postgame_percentiles.py`, `tracker_data.py`, `hitter_kpi_data.py`, `weekly_hitter_data.py`.

### BIP Filters (applied to ALL BIP metrics: Avg EV, Hard%, Barrel%, PullAir%, Dmg%, Max EV)
- **Tracked BIP:** `hit_exit_speed > 0 AND < 125`
- **Bunt exclusion:** `hit_trajectory_id NOT IN (2,3,4)` (via Events_View)
- **EV misread exclusion:** `NOT (EV >= 100 AND LA < -35 AND EV > P95)` via `batter_ev_p95` CTE

### PullAir%
- **Pull side:** RHH `hit_bearing <= -15` OR LHH `hit_bearing >= 15`
- **Air ball:** `hit_vertical_angle >= 14 AND <= 50`
- **Denominator:** tracked non-bunt BIP count
- Consistent across ALL files (fixed Apr 7 — postgame_data.py had LA >= 26, now 14)

### Max EV — MAX() after misread cleaning, everywhere
- **All queries:** true MAX() after EV misread cleaning. One cleaning pass, then take the real maximum.
- **Per-game (postgame_data.py):** `tracked_bip["hit_exit_speed"].max()` — `clean_ev_misreads()` runs upstream (line 237), misreads already nulled
- **Season pool (postgame_percentiles.py):** `MAX(h.hit_exit_speed)` — misread CTE in WHERE clause
- **Tracker (tracker_data.py):** `MAX(CASE WHEN ...)` — misread filter in CASE condition
- **Standardized Apr 12 2026.** Never use P99 for Max EV — that double-filters already-clean data. GC2 uses P99 (no separate misread filter) — may revisit if we ever drop the misread cleaning. See `gc2-metrics.md` for full rationale.

### Hard%
- `hit_exit_speed >= 95` on tracked non-bunt BIP. Consistent everywhere.

### Barrel% (GC2 Linear)
- `EV * 1.5 - LA >= 117 AND EV + LA >= 124 AND EV >= 98 AND LA > 4 AND LA < 50`
- Bunt-excluded, EV < 125 cap. Consistent everywhere.

### Dmg% (Logistic)
- Constants: `1.6, 1.3, -0.34 rad, EV_center=98.0, LA_center=27.0, 0.02 quad, denom=7.0`
- Averaged across BIP. Consistent everywhere.

### Whiff% / Ctct% / ZCtct% / OSw% / ZSw%
- See `gc2-metrics.md` for formulas. All CSC-weighted (except Chase% which is binary CSC < 0.01).
- WHIFF_CODES: `(10, 16, 21, 22, 23, 25)`. Consistent everywhere.

### Bat Speed at Contact (3-step filter)
- Source: `groundcontroltracking.tracking.swing_contact_values` via `tracking.plays`. Whiffs auto-absent (no SCV row); BIP + fouls + foul tips counted.
- Formula: `SQRT(POWER(scv.batvx_con,2) + POWER(scv.batvy_con,2) + POWER(scv.batvz_con,2)) * 0.681818` = MPH
- Step 1: Drop bottom 10% per player (Savant "competitive swings"). Step 2: Hard floor 57 mph, NO upper cap. Step 3: Remove > 2.5σ from mean. Min 20 contact rows.
- See `.claude/rules/data-cleaning.md` §3 for full cleaning spec, `gc2-metrics.md` for canonical SQL.
- Consistent everywhere across Barrelsville src/ + scripts/ + PD Goals.

### K%, BB%
- `100 * SO / PA`, `100 * BB / PA`. PA-weighted for rollups. Consistent everywhere.

## Hitter KPI Percentile Pool Gate (Apr 7, 2026)
- **Pool gate:** 50+ PA required to enter percentile distribution (`MIN_PA_SEASON`)
- **Span display:** 20+ PA to get colored in L2W table (`MIN_PA_SPAN`)
- **Season display:** 50+ PA to get colored in season table
- Players always display regardless of volume — gate only controls coloring
- xwOBA: PA-weighted rolling (SUM numer / SUM denom), bunt filter on BIP metrics

## BlastMotion — Swing Sensor Data (Apr 17, 2026)

### Data Source
- **Table:** `GroundControl2.BlastMotion.Metrics_View` — one row per swing, 99 columns
- **Schema CSV:** `IQ_blast_motion/blast_column_names.csv` (full column list + types)
- **NO schedule linkage:** No `sched_id`, `sched_type`, or `level_code`. Cannot filter by level or game type.
- **Flags:** `bad_data` (bit), `bad_accel_data` (bit) — always filter `ISNULL(bad_data, 0) = 0 AND ISNULL(bad_accel_data, 0) = 0`
- **Other flags:** `game_swing` (bit), `weak_swing` (bit), `deployment` (varchar)
- **Player ID:** `groundcontrol_id` (int) — joins to `Astros.Players`
- **Date:** `swingdate` (date), `sensortimestamp` (datetimeoffset)

### Unit Conversions — BLOCKING
Raw DB values are metric/radians. MUST convert before display:

| Column | Raw Unit | Conversion | Display Unit |
|--------|----------|-----------|-------------|
| `bat_speed` | m/s | × 2.23694 | mph |
| `peak_hand_speed` | m/s | × 2.23694 | mph |
| `attack_angle` | radians | × 180/π | degrees |
| `vertical_bat_angle` | radians | × 180/π | degrees |
| `rotational_acceleration` | m/s² | ÷ 9.81 | g |
| `planar_efficiency` | 0-1 | × 100 | % |
| `body_equipment_early_connection` | radians | × 180/π | degrees |
| `body_equipment_connection` | radians | × 180/π | degrees |
| `time_to_contact` | seconds | none | seconds |

### Affiliate Benchmarks (white threshold for coloring)

| Metric | Benchmark | Direction |
|--------|:---------:|-----------|
| Avg Bat Speed | 70.17 mph | HIB |
| 90th% Bat Speed | 75.14 mph | HIB |
| Peak Hand Speed | 21.72 mph | HIB |
| Time to Contact | 0.15 sec | LIB (lower = better) |
| Attack Angle | 10° center | Range: 4-16° optimal |
| AA Range (4-16%) | 53.20% | HIB |
| Efficiency (BS/PHS) | 3.25 | HIB |

Multi-level benchmarks (Indy, College, HS, Youth) in `blast_report.py::BENCHMARKS`.

### Leaderboard Coloring
- **Benchmark-based, NOT rank-based.** Benchmark value = white. Above trends green (HIB) or red (LIB). Below trends opposite.
- **Attack Angle:** Range coloring — 10° = greenest, 4°/16° = white, outside = red.
- **TtC:** Inverted — lower (faster) = green.
- **Never add arbitrary minimum swing gates** without explicit direction.

### Key Files

| File | Purpose |
|------|---------|
| `pages/4_Blast_Motion.py` | Per-player Streamlit app page (summary tables, distributions, trends) |
| `scripts/blast_report.py` | Per-player PDF report (DB or CSV, multi-level benchmarks) |
| `scripts/generate_blast_leaderboard.py` | Org-wide leaderboard PDF (Rectangle table style) |
| `src/weekly_hitter_data.py` | `get_blast_metrics()` — game-day swings via Schedule_View date join |
| `IQ_blast_motion/blast_column_names.csv` | Full Metrics_View schema (99 columns + types) |

### Two Different Blast Views — Do NOT Confuse
| View | Granularity | Has `groundcontrol_id` | Has `sensortimestamp` |
|------|------------|:---:|:---:|
| `Metrics_View` | **Per-swing summary** (one row per swing) | YES | YES |
| `Series_Metrics_View` | **Time-series** (many rows per swing, per timestamp) | NO (via Adv views) | NO |

`Metrics_View` is what all our code queries. `Series_Metrics_View` is raw positional data — not used in reports.
